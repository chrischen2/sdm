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

1. Download `SymphonyDataMapper3.app.zip` from the
   [releases page](https://github.com/chrischen2/sdm/releases).
2. Unzip and copy `SymphonyDataMapper.app` to `/Applications`.
3. Remove the Gatekeeper quarantine flag:
   ```
   sudo xattr -dr com.apple.quarantine /Applications/SymphonyDataMapper.app
   ```
4. Symlink the CLI as `sdm3`:
   ```
   sudo ln -sf /Applications/SymphonyDataMapper.app/Contents/MacOS/SymphonyDataMapper /usr/local/bin/sdm3
   ```

### Option B — Build from source

Follow the step-by-step guide in [`INSTALL.md`](INSTALL.md).

## Usage

```
sdm3 /path/to/experiment.h5
```

Produces `experiment.auisql` and `experiment.auisql.h5` next to the source file.

## Verifying output against sdm2

If you have files previously mapped with sdm2, you can confirm sdm3 produces
equivalent output:

```
pip3 install h5py numpy
python3 tools/compare_auisql.py old/file.auisql new/file.auisql
```

The script compares SQLite schema, row counts, Experiment metadata, and every
response dataset (shape, dtype, raw sample bytes). Responses are matched across
files by `(epoch start, channel, type)` since UUIDs are regenerated each run.

## Requirements

- macOS 13+ (built and tested on Sequoia 15.x)
- Intel x86_64 Mac (Apple Silicon via Rosetta 2 — see MODERNIZATION.md)

## License

Licensed under the [MIT License](https://opensource.org/licenses/MIT).
