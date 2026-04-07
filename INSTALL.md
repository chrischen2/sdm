# Symphony Data Mapper — Installation Guide (macOS Sequoia, Intel x86_64)

This guide walks you through building and installing `sdm3`, the modernized
Symphony Data Mapper, from source on a modern Intel-chip Mac running macOS
Sequoia (or one version older). For background on what changed from the
original `sdm2`, see [`MODERNIZATION.md`](MODERNIZATION.md).

> **Architecture note:** The vendor frameworks bundled in `Libraries/` are
> **x86_64-only**. On an Intel Mac this is native. On an Apple Silicon Mac
> the build still works but the resulting binary runs through Rosetta 2
> (install with `softwareupdate --install-rosetta` if needed).

---

## 1. Prerequisites

### 1.1 Xcode command line tools
```bash
xcode-select --install
```

You also need a full Xcode install (the App Store version) for
`xcodebuild`. Launch Xcode once after installing so it finishes its
first-launch setup, or run:
```bash
sudo xcodebuild -runFirstLaunch
```

### 1.2 Homebrew
If you don't already have it:
```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

### 1.3 HDF5 and libaec (szip replacement)
```bash
brew install hdf5 libaec
```

The Xcode project hardcodes paths under `/usr/local/hdf5/`, so create
symlinks pointing at the Homebrew-installed copies:

```bash
sudo mkdir -p /usr/local/hdf5/lib /usr/local/hdf5/include
sudo ln -sf "$(brew --prefix hdf5)/lib/libhdf5.a"   /usr/local/hdf5/lib/libhdf5.a
sudo ln -sf "$(brew --prefix libaec)/lib/libsz.a"   /usr/local/hdf5/lib/libsz.a
sudo ln -sf "$(brew --prefix hdf5)"/include/*       /usr/local/hdf5/include/
```

Verify:
```bash
ls -lL /usr/local/hdf5/lib/libhdf5.a /usr/local/hdf5/lib/libsz.a
ls /usr/local/hdf5/include/hdf5.h
```
All three should resolve to real files.

---

## 2. Get the source

```bash
git clone https://github.com/chrischen2/sdm.git ~/sdm-build
cd ~/sdm-build
git checkout claude/update-sdm-macos-sequoia-iQi80
```

(For later updates: `cd ~/sdm-build && git pull`.)

---

## 3. Build the stub ExternalDevicesPlugin

The bundled `ExternalDevicesPlugin.plugin` in the repo is a 32-bit i386
binary that Sequoia cannot load. A drop-in x86_64 stub source is included.
Build it once:

```bash
cd ~/sdm-build
bash ExternalDevicesPluginStub/build.sh
```

Verify:
```bash
file ExternalDevicesPluginStub/ExternalDevicesPlugin.plugin/Contents/MacOS/ExternalDevicesPlugin
# Expect: Mach-O 64-bit bundle x86_64
```

Replace the i386 plugin in the repo so the framework build picks it up:
```bash
rm -rf SymphonyMappingKit/SymphonyMappingKit/Resources/ExternalDevicesPlugin.plugin
cp -R ExternalDevicesPluginStub/ExternalDevicesPlugin.plugin \
      SymphonyMappingKit/SymphonyMappingKit/Resources/
```

---

## 4. Build the framework (`SymphonyMappingKit.framework`)

```bash
cd ~/sdm-build/SymphonyMappingKit
xcodebuild -project SymphonyMappingKit.xcodeproj \
  -target SymphonyMappingKit \
  -configuration Release \
  clean build
```

On success, copy the freshly built framework next to the other vendor
frameworks so the app can link against it:

```bash
cp -R build/Release/SymphonyMappingKit.framework ../Libraries/
```

---

## 5. Build the app (`SymphonyDataMapper.app`)

```bash
cd ~/sdm-build/SymphonyDataMapper
xcodebuild -project SymphonyDataMapper.xcodeproj \
  -target SymphonyDataMapper \
  -configuration Release \
  CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO \
  clean build
```

The `CODE_SIGN_*` flags disable code-signing — fine for personal use. If
you have an Apple Developer ID and want a properly signed binary, omit
those flags and set `DEVELOPMENT_TEAM=<your team id>` instead.

Verify the build:
```bash
ls -la build/Release/SymphonyDataMapper.app
```

---

## 6. Install

```bash
# Copy to /Applications
sudo rm -rf /Applications/SymphonyDataMapper.app
sudo cp -R build/Release/SymphonyDataMapper.app /Applications/

# Strip the Gatekeeper quarantine attribute (unsigned build)
sudo xattr -dr com.apple.quarantine /Applications/SymphonyDataMapper.app

# Symlink the CLI binary into your PATH (name it sdm3)
sudo ln -sf /Applications/SymphonyDataMapper.app/Contents/MacOS/SymphonyDataMapper \
            /usr/local/bin/sdm3
```

If you'd rather call it `sdm2`, `sdm`, or anything else, change the last
component of the symlink target.

---

## 7. Use

```bash
cd /path/to/your/symphony/files
sdm3 my_experiment.h5
```

Output (next to the input file):
- `my_experiment.auisql` — Core Data SQLite store with metadata
- `my_experiment.auisql.h5` — companion HDF5 file with response traces,
  one dataset per response keyed by UUID, byte-compatible with the legacy
  sdm2 layout

You can confirm the h5 has real datasets:
```bash
h5ls -r my_experiment.auisql.h5 | head
h5ls -r my_experiment.auisql.h5 | wc -l   # should match your response count
```

---

## 8. Updating later

Whenever you pull new changes from the branch:

```bash
cd ~/sdm-build
git pull

# Re-build framework
cd SymphonyMappingKit
xcodebuild -project SymphonyMappingKit.xcodeproj -target SymphonyMappingKit \
  -configuration Release clean build
cp -R build/Release/SymphonyMappingKit.framework ../Libraries/

# Re-build app
cd ../SymphonyDataMapper
xcodebuild -project SymphonyDataMapper.xcodeproj -target SymphonyDataMapper \
  -configuration Release \
  CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO \
  clean build

# Reinstall
sudo rm -rf /Applications/SymphonyDataMapper.app
sudo cp -R build/Release/SymphonyDataMapper.app /Applications/
sudo xattr -dr com.apple.quarantine /Applications/SymphonyDataMapper.app
```

The `/usr/local/bin/sdm3` symlink keeps pointing at the right place; no
need to recreate it.

---

## 9. Troubleshooting

| Symptom | Fix |
|---|---|
| `xcodebuild: error: SDK "macosx10.6" cannot be located` | You're on the wrong branch. `git checkout claude/update-sdm-macos-sequoia-iQi80`. |
| `clang: error: no such file or directory: '/usr/local/hdf5/lib/libsz.a'` | Re-run the symlink step in §1.3. The `libaec` formula provides `libsz.a`. |
| `clang: error: no such file or directory: '/usr/local/hdf5/lib/libhdf5.a'` | Same — re-run §1.3. |
| `Unable to load external devices plugin` at runtime | The i386 plugin wasn't replaced. Re-run §3 and rebuild §4–§5. |
| `error: 'BWPluginManager.h' ... @property(assign) __weak` | You're on a stale branch — pull the latest commits, the header is patched in `Libraries/BWKit.framework/.../Headers/`. |
| App won't launch — Gatekeeper blocks it | `sudo xattr -dr com.apple.quarantine /Applications/SymphonyDataMapper.app` |
| `no such column: ZDATA` when poking the db | Expected — response data lives in `ZIOBASE.ZDATAUUID` and the companion `.auisql.h5`, not inline. |
| `.auisql.h5` is only ~1 KB | Your `SymphonyMappingKit.framework` is from before the direct-HDF5 writer commit. `git pull` and rebuild §4–§6. |

---

## 10. Uninstall

```bash
sudo rm -rf /Applications/SymphonyDataMapper.app
sudo rm -f /usr/local/bin/sdm3
rm -rf ~/sdm-build
# Optional — remove the HDF5 install dir if nothing else uses it
sudo rm -rf /usr/local/hdf5
brew uninstall hdf5 libaec   # only if you don't need them for other tools
```
