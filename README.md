# helios-devtools

Shared formatting and static-analysis tooling for helios repositories.

## Layout

- `clang/.clang-format`
- `clang/.clang-tidy`
- `scripts/run-clang-format.sh`
- `scripts/run-clang-tidy.sh`
- `cmake/HeliosDevtools.cmake`

## CMake integration

Use `FetchContent` and include `cmake/HeliosDevtools.cmake`.

```cmake
include(FetchContent)

FetchContent_Declare(
    helios_devtools
    GIT_REPOSITORY https://github.com/thorstensuckow/helios-devtools.git
    GIT_TAG v1.0.0
)

FetchContent_MakeAvailable(helios_devtools)
include("${helios_devtools_SOURCE_DIR}/cmake/HeliosDevtools.cmake")
```

Then configure a target:

```cmake
helios_configure_target(helios_core)
```

This adds:

- `CXX_CLANG_TIDY` with shared `.clang-tidy`
- custom targets `tidy-<target>`, `tidy-fix-<target>`
- custom targets `format-<target>`, `format-fix-<target>`
- convenience targets `tidy`, `tidy-fix`, `format`, `format-fix`

Example:

```bash
cmake --build cmake-build-debug --target tidy-helios_core
cmake --build cmake-build-debug --target format-helios_core
```

## Script usage

`run-clang-tidy.sh`:

```bash
sh scripts/run-clang-tidy.sh --source-dir /path/to/repo --build-dir /path/to/repo/cmake-build-debug --target helios_core
```

`run-clang-format.sh`:

```bash
sh scripts/run-clang-format.sh --source-dir /path/to/repo --path /path/to/repo/src --check-only
```



