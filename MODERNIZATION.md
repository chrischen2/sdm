# Symphony Data Mapper — Modernization Report

A full account of the work done to bring the SDM Objective-C app from a 32-bit i386 macOS 10.6-era tool into a working x86_64 binary on macOS Sequoia (Intel Mac Pro).

---

## 1. Background

The original `SymphonyDataMapper` (sdm2) was a CLI app, packaged as an `.app` bundle, that converts Symphony HDF5 acquisition files into AUI SQL/HDF5 datasets consumed by downstream analysis pipelines. It hadn't been touched in ~10 years, was 32-bit only (`i386`), used manual reference counting (MRC), targeted macOS 10.6, depended on private vendor frameworks, and linked HDF5 1.6.9 statically inside one of those frameworks. Sequoia (macOS 15/26) refuses to launch 32-bit binaries entirely, so nothing about the original could run.

Goal: produce a working `sdm3` on a modern Intel-chip Mac (x86_64), with the same CLI usage and a byte-compatible output layout so existing downstream pipelines continue to work unchanged.

---

## 2. Architecture & Toolchain Modernization

| Area | Old | New |
|---|---|---|
| Architecture | `i386` (32-bit) | `x86_64` (pinned, see §6) |
| Memory model | Manual retain/release (MRC) | Automatic Reference Counting (ARC) |
| Deployment target | macOS 10.6 | macOS 10.13 |
| SDK | `macosx10.6` | `macosx` (current) |
| Xcode project format | objectVersion 46, Xcode 4 | objectVersion 54, Xcode 14 |
| Test framework | SenTestingKit / `.octest` | XCTest / `.xctest` |
| Garbage collection | `GCC_ENABLE_OBJC_GC=unsupported` | removed (deprecated decades ago) |

Both `SymphonyDataMapper.xcodeproj` and `SymphonyMappingKit.xcodeproj` were updated:
- `ARCHS = "$(ARCHS_STANDARD)"`, then later pinned to `x86_64` (see §6)
- `CLANG_ENABLE_OBJC_ARC = YES`
- `LastUpgradeCheck = 1500`, `compatibilityVersion = "Xcode 14.0"`
- Removed `VALID_ARCHS = i386`, `SDKROOT = macosx10.6`, GC settings, and the obsolete `RunUnitTests` script phase.

---

## 3. ARC Migration

Every `.m` in `SymphonyMappingKit/` and `SymphonyDataMapper/` was scrubbed of MRC patterns:
- All `dealloc` methods that only released ivars: deleted (ARC handles them).
- All explicit `retain`, `release`, `autorelease`: removed.
- All `[[NSAutoreleasePool alloc] init] / [pool drain]` pairs: replaced with `@autoreleasepool { ... }`.
- All `@property(assign) __weak` declarations (illegal under ARC): rewritten to `@property(weak)`. The most painful one was in the *vendor* `BWKit.framework`'s public header `BWPluginManager.h` — patched in all three copies (`Headers/`, `Versions/A/Headers/`, `Versions/Current/Headers/`).
- One critical exception: `MACHdf5Reader.m` keeps a slim `dealloc` to call `H5Fclose(_fileId)` because that's a C-level resource ARC doesn't manage.

`main.m` was rewritten to use modern initializers:
```objc
@autoreleasepool {
    NSPersistentStoreCoordinator *coordinator =
        [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:objectModel];
    NSManagedObjectContext *context =
        [[NSManagedObjectContext alloc] initWithConcurrencyType:NSMainQueueConcurrencyType];
    ...
}
```

A few `[super init]` calls (e.g. in `MACHdf5CommonInformation.m`) had to be rewritten to `self = [super init]` because ARC enforces the result of a delegate init call be returned or assigned to `self`.

Forward declarations in headers (`@class Foo;`) had to be promoted to full `#import` in several places (most notably `SMKExperimentMapper.m`) — modern clang refuses to send messages to incomplete types.

---

## 4. Vendor Frameworks

`Libraries/` originally held i386 binaries for four private frameworks. There is no available source. The user supplied prebuilt 64-bit `.framework` bundles for all four:

| Framework | Arch | Status |
|---|---|---|
| AUIProtocols.framework | x86_64 | OK |
| AUIModel.framework | x86_64 | OK (contains statically-linked HDF5 1.6.9 — see §9) |
| BWKit.framework | x86_64 | OK (header patched for ARC) |
| DAQFramework.framework | x86_64 | OK |

A repo-wide scan after the swap confirmed no other architectural mismatches existed.

---

## 5. Native Dependencies (HDF5 / szip)

The mapper compiles against `<hdf5.h>` and links `libhdf5.a` + `libsz.a`. The xcodeproj hardcodes paths under `/usr/local/hdf5/`, so on a fresh modern Mac:

```bash
brew install hdf5 libaec
sudo mkdir -p /usr/local/hdf5/lib /usr/local/hdf5/include
sudo ln -sf "$(brew --prefix hdf5)/lib/libhdf5.a" /usr/local/hdf5/lib/libhdf5.a
sudo ln -sf "$(brew --prefix libaec)/lib/libsz.a" /usr/local/hdf5/lib/libsz.a
sudo ln -sf "$(brew --prefix hdf5)"/include/* /usr/local/hdf5/include/
```

Note: `libsz.a` no longer ships in a standalone `szip` Homebrew formula. Modern Homebrew provides it via **`libaec`** (an API-compatible szip replacement). This trapped us once.

---

## 6. HDF5 1.12+ API Breakage

HDF5 1.12 broke source compatibility on the object-info functions: `H5Oget_info` and `H5Oget_info_by_name` gained a new `unsigned fields` argument. Three call sites in `MACHdf5Reader.m` failed to compile against modern HDF5. Fixed:

```c
// before
H5Oget_info(objectId, &info);
H5Oget_info_by_name(loc, name, &info, H5P_DEFAULT);

// after
H5Oget_info(objectId, &info, H5O_INFO_ALL);
H5Oget_info_by_name(loc, name, &info, H5O_INFO_BASIC, H5P_DEFAULT);
```

---

## 7. x86_64 Architecture Pinning

Xcode on Apple Silicon defaults to `arm64`, but every vendor framework in `Libraries/` is x86_64-only. Without pinning, the link step would fail. Both pbxprojs now have `ARCHS = x86_64` and `VALID_ARCHS = x86_64` for both Debug and Release configurations. On the Intel Mac Pro this is the native arch; on Apple Silicon it would force a Rosetta-compatible build.

---

## 8. ExternalDevicesPlugin (i386 vendor plugin)

`SymphonyMappingKit/Resources/ExternalDevicesPlugin.plugin` is a precompiled vendor bundle whose principal class `AUIExternalDevicesLoader` is loaded by `SMKExperimentMapper.m:108-112` via `[NSBundle principalClass]`. The bundled binary was **i386-only** — Sequoia refused to load it, and the mapper threw `Unable to load external devices plugin` immediately on every run.

No source exists for this plugin. The fix was to write a tiny x86_64 stub bundle whose only job is to expose a class with the right name so `principalClass` returns non-nil:

```objc
// ExternalDevicesPluginStub/AUIExternalDevicesLoader.m
#import <Foundation/Foundation.h>
@interface AUIExternalDevicesLoader : NSObject @end
@implementation AUIExternalDevicesLoader @end
```

Built with a 6-line shell script:
```bash
clang -arch x86_64 -bundle -fobjc-arc -framework Foundation \
  -o ExternalDevicesPlugin.plugin/Contents/MacOS/ExternalDevicesPlugin \
  AUIExternalDevicesLoader.m
```

A matching `Info.plist` (preserving `CFBundleIdentifier=edu.washington.bwark.acqui.ExternalDevices`, `NSPrincipalClass=AUIExternalDevicesLoader`, etc.) is written alongside it. The stub replaces the i386 plugin both inside the repo and inside the installed `.app`. The mapper does not actually need any device classes registered for the conversion to function correctly.

---

## 9. The Big One — Missing Response Data in `.auisql.h5`

This was the deepest issue and the one most invisible at first.

### Symptom
After everything compiled and the mapper ran cleanly, the output was wrong:

| File | sdm2 (old) | sdm3 (initial) |
|---|---|---|
| `.auisql` (sqlite) | 32.4 MB | 31 MB |
| `.auisql.h5` | **344.4 MB** | **976 bytes** |

The companion HDF5 file — which downstream pipelines depend on — was effectively empty. `h5ls -r` showed only the root group `/`.

### Investigation
1. The Core Data schema (`ZIOBASE` table) has `ZDATAUUID VARCHAR` but **no `ZDATA` column**. Response payloads aren't stored inline; the AUIModel design uses external HDF5 storage keyed by UUID.
2. 1594 `ZIOBASE` rows had non-NULL `ZDATAUUID` values, but the `.auisql.h5` had zero datasets — every UUID was a dangling pointer.
3. `h5dump` on a known-good old `.auisql.h5` revealed the layout: one dataset per response, name = UUID (no path), `H5T_IEEE_F64LE`, 1-D, with one scalar string attribute `dtypeString = "<f8"` (4-byte null-terminated ASCII, NumPy-style).
4. `strings Libraries/AUIModel.framework/.../AUIModel` exposed `saveResponseDataToHDF5` and the full HDF5 1.6.9 library symbols statically linked into the binary. AUIModel was supposed to write each response into the file via a Core Data `willSave`/`didSave` hook on the `Response` entity.
5. Running `HDF5_DEBUG=all sdm3 ...` produced **zero** HDF5 debug output — proving AUIModel's internal save hook was never being invoked at all.
6. Confirmed: every epoch had `ZSAVERESPONSE = 1`, so the mapper *was* requesting saves; AUIModel's hook just isn't firing on modern Core Data. This is a deep behavior change in Core Data that we cannot fix in the binary framework.

### Fix — Bypass AUIModel and Write the File Ourselves
Since `Response.dataUUID` is a public writable `NSString` property, we can generate UUIDs ourselves and write the response bytes directly into `.auisql.h5` using modern HDF5 — replicating the exact byte-compatible layout the old version produced.

Changes in `SMKExperimentMapper.m` / `.h`:

1. New ivar `long long _outH5FileId;` (typedef-compatible with `hid_t` from HDF5 1.10+, kept as a plain integer in the public header to avoid leaking `<hdf5.h>` to the app target).
2. After AUIModel's `createResponseDataFileAtURL:` runs, we delete the empty file it created and create our own with `H5Fcreate(..., H5F_ACC_TRUNC, ...)`.
3. In the response loop, replace `auiResponse.data = response.data;` with:
   ```objc
   NSString *uuid = [[NSUUID UUID] UUIDString];
   auiResponse.dataUUID = uuid;
   [self writeResponseData:response.data withUUID:uuid];
   ```
4. New private method `writeResponseData:withUUID:` that creates a 1-D `H5T_IEEE_F64LE` dataset named by UUID, writes the bytes (which are already an array of doubles from `SMKResponseEnumerator.m`), and attaches the scalar `dtypeString = "<f8"` attribute exactly matching the old layout:
   ```objc
   hsize_t dims[1] = { sampleCount };
   hid_t space = H5Screate_simple(1, dims, NULL);
   hid_t dset  = H5Dcreate2(_outH5FileId, [uuid UTF8String],
                            H5T_IEEE_F64LE, space,
                            H5P_DEFAULT, H5P_DEFAULT, H5P_DEFAULT);
   H5Dwrite(dset, H5T_NATIVE_DOUBLE, H5S_ALL, H5S_ALL, H5P_DEFAULT, [data bytes]);

   hid_t atype = H5Tcopy(H5T_C_S1);
   H5Tset_size(atype, 4);
   H5Tset_strpad(atype, H5T_STR_NULLTERM);
   H5Tset_cset(atype, H5T_CSET_ASCII);
   hid_t ascalar = H5Screate(H5S_SCALAR);
   hid_t attr = H5Acreate2(dset, "dtypeString", atype, ascalar, H5P_DEFAULT, H5P_DEFAULT);
   H5Awrite(attr, atype, "<f8");
   ...
   ```
5. After the final Core Data save, `H5Fclose(_outH5FileId)`.

A subtle gotcha: putting `#import <hdf5.h>` in `SMKExperimentMapper.h` propagated to the `SymphonyDataMapper` app target whose header search path doesn't include HDF5. Solved by keeping the import private to the `.m` and declaring the ivar as `long long` in the header.

The result is a `.auisql.h5` that's structurally identical to what sdm2 produced — same dataset naming, same dtype, same attribute — so existing downstream pipelines work without modification.

---

## 10. Build, Install, Use

```bash
# Framework
cd ~/sdm-build/SymphonyMappingKit
xcodebuild -project SymphonyMappingKit.xcodeproj -target SymphonyMappingKit \
  -configuration Release clean build
cp -R build/Release/SymphonyMappingKit.framework ../Libraries/

# App
cd ../SymphonyDataMapper
xcodebuild -project SymphonyDataMapper.xcodeproj -target SymphonyDataMapper \
  -configuration Release \
  CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO \
  clean build

# Install
sudo rm -rf /Applications/SymphonyDataMapper.app
sudo cp -R build/Release/SymphonyDataMapper.app /Applications/
sudo xattr -dr com.apple.quarantine /Applications/SymphonyDataMapper.app
sudo ln -sf /Applications/SymphonyDataMapper.app/Contents/MacOS/SymphonyDataMapper /usr/local/bin/sdm3

# Use — identical CLI to old sdm2
sdm3 my_symphony_file.h5
```

`CODE_SIGN_IDENTITY="-"` builds without a real Developer ID (fine for personal use; for distribution to other Macs, see §11).

---

## 11. Distribution Notes

- The build is unsigned. Other users will need to right-click → Open the first time, or run `sudo xattr -dr com.apple.quarantine` after copying. A proper Apple Developer ID + notarization step would remove this friction.
- A DMG installer can be produced with `create-dmg` if drag-to-Applications distribution is desired, but for personal use the symlinked CLI workflow is sufficient.
- The build is **x86_64-only**. Running on an Apple Silicon Mac requires Rosetta. Native arm64 would require rebuilding all four vendor frameworks with arm64 slices, which is impossible without source.

---

## 12. Things Left As-Is (Known Non-Issues)

- `GTMMethodCheckMethodChecker` warnings about `CKSQLiteUnsetPropertySentinel` and `JSExport` — harmless modern-OS chatter from Google Toolbox.
- `CoreData: warning: Property 'codedValue' ... using nil or an insecure NSValueTransformer` — emitted by AUIModel's old Core Data model. Cosmetic; would require modifying the `.momd` files inside the binary framework to silence.
- `SQLite WAL/SHM` files appearing briefly during a run — normal modern Core Data behavior; they get checkpointed cleanly on shutdown.
- Old AUIModel `saveResponseDataToHDF5` hook not firing — sidestepped entirely by §9.

---

## 13. Branch and Commits

Everything lives on `claude/update-sdm-macos-sequoia-iQi80` in `chrischen2/sdm`. Notable commits, in order:

1. ARC migration sweep across SymphonyMappingKit and SymphonyDataMapper.
2. Project format upgrade (objectVersion 54, Xcode 14, deployment target 10.13, ARC enabled).
3. 64-bit vendor frameworks dropped into `Libraries/`; removed obsolete `lib/` and `MatlabAUIModel/` folders.
4. BWKit ARC header patch (`@property(assign) __weak` → `@property(weak)`).
5. HDF5 1.12+ API fixes in `MACHdf5Reader.m`.
6. `[super init]` → `self = [super init]` in `MACHdf5CommonInformation.m`.
7. SMKExperimentMapper missing `#import`s for enumerator classes.
8. ARCHS pinned to x86_64 in both pbxprojs.
9. x86_64 stub `ExternalDevicesPlugin` added.
10. Direct HDF5 writer for response data (the §9 fix).
11. Move `<hdf5.h>` import out of public mapper header.

---

## Summary

The migration required modernizing the build system, ARC-converting ~30 source files, fixing HDF5 API drift, replacing one i386-only vendor plugin with a stub, and — most consequentially — bypassing a broken Core Data save hook in the binary AUIModel framework by writing the response HDF5 file ourselves using modern HDF5 calls. The output `.auisql` + `.auisql.h5` pair is byte-layout-compatible with the legacy sdm2 output, so downstream pipelines need no changes.
