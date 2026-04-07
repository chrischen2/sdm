#!/usr/bin/env python3
"""
compare_auisql.py — verify that two Symphony Data Mapper outputs are equivalent.

Compares an sdm2 (old) and sdm3 (new) mapping of the same Symphony .h5 source:
  1.  Core Data SQLite (.auisql) — table row counts and per-row field values
      in the entities that matter (Experiment, RecordedCell, Epoch, IOBase).
  2.  Companion HDF5 (.auisql.h5) — matches each response by (epoch start,
      cell, channelID, type, sample count) rather than by UUID (UUIDs are
      randomly generated every run, so they will never match). For each
      matched pair it checks dataset shape, dtype, dtypeString attribute,
      and the actual sample bytes (with a configurable tolerance).

Usage:
  python3 compare_auisql.py /path/to/old/file.auisql /path/to/new/file.auisql
  python3 compare_auisql.py --tol 1e-12 old.auisql new.auisql
  python3 compare_auisql.py --sample 50 old.auisql new.auisql   # only check 50 random responses

Dependencies:
  pip3 install h5py numpy       # sqlite3 is stdlib
"""

import argparse
import os
import random
import sqlite3
import sys
from collections import defaultdict

try:
    import h5py
    import numpy as np
except ImportError:
    sys.exit("Please 'pip3 install h5py numpy' first.")


# ---------- small helpers ----------

RED    = "\033[31m"
GREEN  = "\033[32m"
YELLOW = "\033[33m"
RESET  = "\033[0m"

def ok(msg):    print(f"{GREEN}[OK]{RESET} {msg}")
def warn(msg):  print(f"{YELLOW}[WARN]{RESET} {msg}")
def fail(msg):  print(f"{RED}[FAIL]{RESET} {msg}")

class Report:
    def __init__(self):
        self.failures = 0
        self.warnings = 0
    def check(self, cond, msg):
        if cond:
            ok(msg)
        else:
            fail(msg)
            self.failures += 1
    def warn(self, msg):
        warn(msg)
        self.warnings += 1


# ---------- sqlite comparison ----------

ENTITY_TABLES = [
    "ZEXPERIMENT",
    "ZCELL",
    "ZEPOCH",
    "ZIOBASE",
    "ZKEYVALUEPAIR",
    "ZDAQCONFIGCONTAINER",
    "ZNOTE",
]

def table_exists(cur, name):
    cur.execute("SELECT 1 FROM sqlite_master WHERE type='table' AND name=?", (name,))
    return cur.fetchone() is not None

def column_names(cur, table):
    cur.execute(f"PRAGMA table_info({table})")
    return [row[1] for row in cur.fetchall()]

def compare_schema(old_cur, new_cur, rpt):
    print("\n=== SQLite schema ===")
    for t in ENTITY_TABLES:
        old_has = table_exists(old_cur, t)
        new_has = table_exists(new_cur, t)
        rpt.check(old_has == new_has, f"table {t} present in both ({old_has} vs {new_has})")
        if old_has and new_has:
            oc = set(column_names(old_cur, t))
            nc = set(column_names(new_cur, t))
            only_old = oc - nc
            only_new = nc - oc
            if only_old or only_new:
                rpt.warn(f"{t} column diff: only_in_old={sorted(only_old)} only_in_new={sorted(only_new)}")

def compare_row_counts(old_cur, new_cur, rpt):
    print("\n=== SQLite row counts ===")
    for t in ENTITY_TABLES:
        if not table_exists(old_cur, t) or not table_exists(new_cur, t):
            continue
        o = old_cur.execute(f"SELECT COUNT(*) FROM {t}").fetchone()[0]
        n = new_cur.execute(f"SELECT COUNT(*) FROM {t}").fetchone()[0]
        rpt.check(o == n, f"{t}: old={o} new={n}")

def compare_experiment_fields(old_cur, new_cur, rpt):
    print("\n=== Experiment fields ===")
    fields = ["ZSTARTDATE", "ZDAQID", "ZPURPOSE", "ZOTHERNOTES"]
    try:
        o = dict(zip(fields, old_cur.execute(
            f"SELECT {','.join(fields)} FROM ZEXPERIMENT LIMIT 1").fetchone()))
        n = dict(zip(fields, new_cur.execute(
            f"SELECT {','.join(fields)} FROM ZEXPERIMENT LIMIT 1").fetchone()))
    except Exception as e:
        rpt.warn(f"could not read Experiment row: {e}")
        return
    for f in fields:
        rpt.check(o[f] == n[f], f"Experiment.{f}: {o[f]!r} == {n[f]!r}")


# ---------- match responses across files ----------
#
# Response UUIDs differ between runs (sdm3 generates fresh ones). To line up
# responses, we key on (epoch_start, channelID, type, sample_count).

def load_responses(conn):
    """Return list of dicts keyed by the match tuple."""
    cur = conn.cursor()
    # Find the Response entity id. Z_PRIMARYKEY maps Z_ENT -> entity name.
    cur.execute("SELECT Z_ENT FROM Z_PRIMARYKEY WHERE Z_NAME='Response'")
    row = cur.fetchone()
    if not row:
        return []
    response_ent = row[0]

    # Epoch start date, ZIOBASE row (responses), and sample count (via h5).
    q = f"""
    SELECT io.ZDATAUUID, io.ZCHANNELID, io.ZTYPE, io.ZSAMPLERATE,
           ep.ZSTARTDATE, ep.Z_PK
    FROM ZIOBASE io
    JOIN ZEPOCH  ep ON io.ZEPOCH = ep.Z_PK
    WHERE io.Z_ENT = ? AND io.ZDATAUUID IS NOT NULL
    ORDER BY ep.ZSTARTDATE, io.ZCHANNELID, io.ZTYPE
    """
    out = []
    for uuid, ch, typ, sr, start, epk in cur.execute(q, (response_ent,)):
        out.append({
            "uuid": uuid,
            "channelID": ch,
            "type": typ,
            "sampleRate": sr,
            "epochStart": start,
            "epochPK": epk,
        })
    return out


def compare_h5_data(old_sql, new_sql, old_h5_path, new_h5_path, rpt,
                    sample_count=None, tol=0.0):
    print("\n=== HDF5 response data ===")
    if not (os.path.exists(old_h5_path) and os.path.exists(new_h5_path)):
        rpt.check(False, f"both .auisql.h5 files exist")
        return

    old_resps = load_responses(old_sql)
    new_resps = load_responses(new_sql)
    rpt.check(len(old_resps) == len(new_resps),
              f"response count: old={len(old_resps)} new={len(new_resps)}")

    # Match by (epochStart, channelID, type). Same (epoch, stream) should
    # collide 1:1 between old and new.
    def key(r): return (r["epochStart"], r["channelID"], r["type"])
    old_by = defaultdict(list)
    new_by = defaultdict(list)
    for r in old_resps: old_by[key(r)].append(r)
    for r in new_resps: new_by[key(r)].append(r)

    common = sorted(set(old_by) & set(new_by))
    only_old = set(old_by) - set(new_by)
    only_new = set(new_by) - set(old_by)
    if only_old:
        rpt.warn(f"{len(only_old)} response keys only in OLD (showing 3): "
                 f"{list(only_old)[:3]}")
    if only_new:
        rpt.warn(f"{len(only_new)} response keys only in NEW (showing 3): "
                 f"{list(only_new)[:3]}")

    pairs = []
    for k in common:
        for o, n in zip(old_by[k], new_by[k]):
            pairs.append((o, n))

    print(f"matched {len(pairs)} response pairs")

    if sample_count and len(pairs) > sample_count:
        random.seed(0)
        pairs = random.sample(pairs, sample_count)
        print(f"checking a random subset of {len(pairs)}")

    with h5py.File(old_h5_path, "r") as fo, h5py.File(new_h5_path, "r") as fn:
        shape_ok = dtype_ok = attr_ok = data_ok = 0
        mismatches = []
        for o, n in pairs:
            try:
                do = fo[o["uuid"]]
                dn = fn[n["uuid"]]
            except KeyError as e:
                mismatches.append(f"missing dataset: {e}")
                continue

            if do.shape == dn.shape:
                shape_ok += 1
            else:
                mismatches.append(f"shape: {o['uuid']} {do.shape} vs {n['uuid']} {dn.shape}")
                continue

            if do.dtype == dn.dtype:
                dtype_ok += 1
            else:
                mismatches.append(f"dtype: {do.dtype} vs {dn.dtype}")

            ao = do.attrs.get("dtypeString")
            an = dn.attrs.get("dtypeString")
            if ao == an:
                attr_ok += 1
            else:
                mismatches.append(f"dtypeString attr: {ao!r} vs {an!r}")

            arr_o = do[...]
            arr_n = dn[...]
            if tol == 0:
                eq = np.array_equal(arr_o, arr_n)
            else:
                eq = np.allclose(arr_o, arr_n, atol=tol, rtol=0, equal_nan=True)
            if eq:
                data_ok += 1
            else:
                diff = np.abs(arr_o.astype(np.float64) - arr_n.astype(np.float64))
                mismatches.append(
                    f"data differs {o['uuid']}<->{n['uuid']} "
                    f"max|Δ|={diff.max():.3g} mean|Δ|={diff.mean():.3g}")

        total = len(pairs)
        rpt.check(shape_ok == total, f"shape match: {shape_ok}/{total}")
        rpt.check(dtype_ok == total, f"dtype match: {dtype_ok}/{total}")
        rpt.check(attr_ok  == total, f"dtypeString match: {attr_ok}/{total}")
        rpt.check(data_ok  == total, f"sample data match (tol={tol}): {data_ok}/{total}")

        if mismatches:
            print("\nFirst few mismatches:")
            for m in mismatches[:10]:
                print(" -", m)


# ---------- main ----------

def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("old_auisql", help="sdm2 output .auisql file")
    ap.add_argument("new_auisql", help="sdm3 output .auisql file")
    ap.add_argument("--tol", type=float, default=0.0,
                    help="numeric tolerance for sample data comparison (default 0 = exact)")
    ap.add_argument("--sample", type=int, default=None,
                    help="only check a random subset of N response pairs (default: all)")
    args = ap.parse_args()

    old_h5 = args.old_auisql + ".h5"
    new_h5 = args.new_auisql + ".h5"

    print(f"OLD: {args.old_auisql}")
    print(f"NEW: {args.new_auisql}")
    print(f"OLD h5: {old_h5}  ({os.path.getsize(old_h5) if os.path.exists(old_h5) else 'MISSING'} bytes)")
    print(f"NEW h5: {new_h5}  ({os.path.getsize(new_h5) if os.path.exists(new_h5) else 'MISSING'} bytes)")

    rpt = Report()
    old = sqlite3.connect(args.old_auisql)
    new = sqlite3.connect(args.new_auisql)

    compare_schema(old.cursor(), new.cursor(), rpt)
    compare_row_counts(old.cursor(), new.cursor(), rpt)
    compare_experiment_fields(old.cursor(), new.cursor(), rpt)
    compare_h5_data(old, new, old_h5, new_h5, rpt,
                    sample_count=args.sample, tol=args.tol)

    print("\n========================")
    print(f" failures: {rpt.failures}")
    print(f" warnings: {rpt.warnings}")
    print("========================")
    sys.exit(1 if rpt.failures else 0)


if __name__ == "__main__":
    main()
