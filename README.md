# Symphony Data Mapper 3 (sdm3)

Maps Symphony HDF5 data files to AUI SQLite + HDF5 (`.auisql` / `.auisql.h5`) files.

`sdm3` is a modernized fork of the original Symphony Data Mapper 2, rebuilt to
run natively on **macOS Sequoia** (Intel x86_64) with a current toolchain
(Xcode 15+, ARC, HDF5 1.14). The output is byte-compatible with sdm2 — existing
downstream pipelines work unchanged.

See [`MODERNIZATION.md`](MODERNIZATION.md) for a full report of the changes
made to port from the original 32-bit i386 codebase.

## Installation

Two options:

### Option A — Prebuilt release (recommended)

Requires an Intel x86_64 Mac running macOS 13 or later. Apple Silicon users
must first install Rosetta 2: `softwareupdate --install-rosetta`.

1. Go to the [releases page](https://github.com/chrischen2/sdm/releases/latest)
   and download the latest `SymphonyDataMapper3-vX.Y.Z-macos-x86_64.zip` asset.

   Or from Terminal (replace the version):
   ```
   cd ~/Downloads
   curl -LO https://github.com/chrischen2/sdm/releases/download/v3.0.0/SymphonyDataMapper3-v3.0.0-macos-x86_64.zip
   ```

2. Unzip and move the app into `/Applications`:
   ```
   unzip SymphonyDataMapper3-v3.0.0-macos-x86_64.zip
   sudo mv SymphonyDataMapper.app /Applications/
   ```

3. Remove the Gatekeeper quarantine flag (required — the build is ad-hoc
   signed, so macOS will otherwise refuse to launch it):
   ```
   sudo xattr -dr com.apple.quarantine /Applications/SymphonyDataMapper.app
   ```

4. Symlink the CLI as `sdm3` so you can run it from any directory:
   ```
   sudo ln -sf /Applications/SymphonyDataMapper.app/Contents/MacOS/SymphonyDataMapper /usr/local/bin/sdm3
   ```

5. Verify it runs:
   ```
   sdm3
   ```
   You should see a usage message. If instead you get
   "cannot be opened because the developer cannot be verified", step 3 was
   skipped — run the `xattr` command and try again.

### Option B — Build from source

Follow the step-by-step guide in [`INSTALL.md`](INSTALL.md).

## Usage

```
sdm3 /path/to/experiment.h5
```

Produces `experiment.auisql` and `experiment.auisql.h5` next to the source file.

## Verifying output against sdm2

If you have the same experiment previously mapped with sdm2, you can confirm
that sdm3 produces an equivalent `.auisql` / `.auisql.h5` pair. The repo ships
`tools/compare_auisql.py` for this.

**One-time setup:**
```
pip3 install h5py numpy     # sqlite3 is stdlib
```

**Run the comparison** (pass just the `.auisql` path for each side — the
script finds the matching `.auisql.h5` next to it automatically):
```
python3 tools/compare_auisql.py \
    /path/to/sdm2_output/experiment.auisql \
    /path/to/sdm3_output/experiment.auisql
```

Example output for a matching pair:
```
=== SQLite row counts ===
[OK] ZEXPERIMENT: old=1 new=1
[OK] ZEPOCH: old=1594 new=1594
[OK] ZIOBASE: old=3188 new=3188
...
=== HDF5 response data ===
[OK] response count: old=1594 new=1594
[OK] shape match: 1594/1594
[OK] dtype match: 1594/1594
[OK] sample data match (tol=0.0): 1594/1594
========================
 failures: 0
 warnings: 0
========================
```

What it checks:
- SQLite schema presence and row counts for Experiment/Cell/Epoch/IOBase/etc.
- Experiment metadata fields (start date, DAQ ID, purpose, notes)
- Every response dataset in the companion `.auisql.h5`: shape, dtype,
  `dtypeString` attribute, and raw sample bytes

Responses are matched across files by `(epoch start, channel, type)` rather
than UUID, since UUIDs are regenerated on every run and will never match.

Options:
- `--tol 1e-12` — allow a floating-point tolerance instead of exact byte match
- `--sample 100` — only spot-check a random subset of responses (faster)

A non-zero exit code indicates at least one mismatch.

## Requirements

- macOS 13+ (built and tested on Sequoia 15.x)
- Intel x86_64 Mac (Apple Silicon via Rosetta 2 — see MODERNIZATION.md)

## License

Licensed under the [MIT License](https://opensource.org/licenses/MIT).
