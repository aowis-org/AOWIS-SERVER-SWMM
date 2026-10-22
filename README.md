# AOWIS-SERVER-SWMM

Native SWMM simulation integration for AOWIS. This repository wraps the C-based
[Open Water Analytics SWMM engine](https://github.com/pyswmm/Stormwater-Management-Model)
using the [AOWIS fork](https://github.com/aowis-org/pyStormwater-Management-Model).
It requires **no Python runtime**. The wrapper is a C++17 library suitable for
in-process use by AOWIS-SERVER-STANDALONE. An HTTP interface is planned as a
separate layer and is **not** implemented in this initial integration.

## Source and reproducibility

SWMM lives in `external/swmm` as a Git submodule, pinned to the OWA 5.2.4
release commit `27dc6990cda8bce21f6c16ddae631b37e7510ffc`. The submodule
origin is `https://github.com/aowis-org/pyStormwater-Management-Model.git`.
The official OWA upstream is `https://github.com/pyswmm/Stormwater-Management-Model`.

**After applying the initial ZIP patch**, run this once from the repo root:

```bash
./tools/init_swmm_submodule.sh
```

The helper adds the submodule, checks out the exact pinned commit, and stages
`.gitmodules` plus the `external/swmm` gitlink. ZIP patches cannot create Git
submodule entries themselves. Commit the staged Git entries with your changes.
For ordinary future clones or checkouts, initialize the submodule with:

```bash
git submodule update --init --recursive
```

Do not use `git submodule update --remote` without reviewing and deliberately
committing the new engine version. This initial integration intentionally uses
an immutable pinned commit, not a moving `develop` branch.

## Build and test

Requirements: CMake 3.23+, Ninja, a C/C++ compiler supporting C++17,
Git, and Python 3 (for snapshot tooling). No Qt dependency yet. The pinned
OWA 5.2.4 engine requires an OpenMP-capable C compiler and runtime on Linux.

The recommended Linux builds use the **Ninja** generator through CMake
presets. From the project root, configure, build, and test Debug with:

```bash
cmake --preset linux-debug
cmake --build --preset linux-debug --parallel
ctest --preset linux-debug
```

For an optimized Release build, use `linux-release` instead:

```bash
cmake --preset linux-release
cmake --build --preset linux-release --parallel
ctest --preset linux-release
```

Each preset has its own ignored build directory (`build-linux-debug` and
`build-linux-release`). This also avoids the CMake generator-mismatch error
if an older `build-linux` directory was configured with Unix Makefiles.
If configuring manually, pass `-G Ninja` when *first* configuring a build
directory, for example:

```bash
cmake -S . -B build-linux-ninja -G Ninja -DCMAKE_BUILD_TYPE=Debug
cmake --build build-linux-ninja --parallel
ctest --test-dir build-linux-ninja --output-on-failure
```

Ninja generally reduces build orchestration overhead, especially for
incremental builds; actual speedups depend on the compiler and workload.
The generator choice applies to standalone builds of this repository;
when included by AOWIS-SERVER-STANDALONE, the parent project selects the
CMake generator.

The default upstream `BUILD_SHARED_LIBS=ON` builds `swmm5` as a shared library;
`aowis-swmm-core` is currently a static C++ convenience library which links
to it. For a native standalone build, try `-DBUILD_SHARED_LIBS=OFF` after
validating the target toolchain. We have not yet established production Windows
or standalone integration testing.

The smoke test runs an actual small SWMM drainage scenario in
`tests/data/basic.inp`, verifying the return code and nonempty `.rpt` and
`.out` results. It writes to the selected build directory's `smoke-output/`, never into sources.
The solver's CMake may generate an export header under the submodule source
directory; this is upstream behavior and should not be committed as an AOWIS
engine modification.

For embedding, link `aowis::swmm-core` from CMake. The C++ API in
`include/aowis/swmm/Simulation.hpp` exposes `engineVersion()` and
`runSimulation(input, report, binaryOutput)`; it returns the engine's numerical
error code, with no exception thrown for normal SWMM error codes.

**Concurrency:** SWMM uses process-global state. The AOWIS interface serializes
its own calls with a process-wide mutex; code outside this wrapper must not call
SWMM's raw C API concurrently. For multiple simultaneous simulations, run
independent solver worker **processes**. This library does not create a new
independent simulation context for each C++ object.

## Repository tools

Run commands from the repository root.

### Apply patches

```bash
./tools/apply_patch.sh ~/Downloads/aowis-server-swmm-<description>.zip
```

The patch filename must start with `aowis-server-swmm-` and end with `.zip`.
Archive contents must be scoped under `AOWIS-SERVER-SWMM/`; foreign project
patches, unsafe paths and symlinks are rejected. Updated files receive current
timestamps. Patches contain only this project's changes, not SWMM source files.

### Package complete project for sharing

```bash
./tools/zip_swmm.sh
# or specify the output location
./tools/zip_swmm.sh ~/Downloads/swmm.zip
```

The export produces `../swmm.zip` by default and contains ordinary tracked and
untracked, non-ignored files **including all initialized Git submodule source
files**. It excludes Git metadata, ignored build artifacts, symlinks and common
secrets. It is a source snapshot for sharing here, *not* an incremental patch
and *not* a faithful Git clone (history and gitlinks are absent from the ZIP).
The script fails rather than silently exporting an incomplete source tree if
a registered Git submodule is missing. Existing Git repositories are still
required for local development and future submodule updates.
