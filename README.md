# Dependency Installer for CMake Projects

This module automatically builds and installs external dependencies during CMake configuration, keeping the project self-contained without requiring preinstalled SDKs or repeated source rebuilds.

###### Also provides some `FindXXX.cmake` modules.

## Why this exists

Many CMake projects struggle with brittle, slow, or platform-dependent dependency handling. This module fixes that by building and installing external libraries automatically during configuration so your repository stays self-contained and reproducible.

### Problems

* `add_subdirectory()` forces third-party code to be built repeatedly for every configuration, slowing local and CI builds and cluttering IDE solutions.

* Prebuilt binaries are often missing or incompatible (different flags, runtimes, ABIs).

* Relying on contributors or CI to provide correct libraries is fragile and error-prone.

### How this module helps

* Builds CMake-based dependencies once in **Release** mode to avoid duplicate configuration/build cycles.

* **Caches** builds using Git commit hashes so libraries are rebuilt only when their sources change.

* Installs artifacts into a **reproducible layout** that supports multiple ABI/runtime variants side-by-side (e.g., vcruntime or libc++).

* Exposes a consistent CMake environment (`CMAKE_PREFIX_PATH` for `find_package()`, `DEPS_HEADER_ONLY_INCLUDE_DIR` for header-only libs), so your project finds the right dependencies automatically.

### Result

Faster, more reliable builds, fewer environment assumptions, and a self-contained repo that's easier to share, test, and maintain.

## How it works

### Quick overview

1. Clone the required git repositories into `third_party/src`.

2. Register each dependency during CMake configuration using these functions:
* `deps_add_cmake_project(...)`
* `deps_add_header_only(...)`
* `deps_add_manual_install(...)`  
Use `DEPS_CMAKE_GLOBAL_ARGS` to pass common CMake arguments to all CMake-based deps.  
Optionally set `DEPS_OUT_SUBDIR` to keep builds for different compiler/runtime combinations in separate output folders.

3. Call `deps_build_all()` once. That runs the external Python script, which configures, builds and installs each dependency into `third_party/bin/DEPS_OUT_SUBDIR`.

4. After install:
* The module updates `CMAKE_PREFIX_PATH` so `find_package()` finds installed packages (CMake-based deps are installed in CONFIG mode).
* Header-only libraries are exposed via `DEPS_HEADER_ONLY_INCLUDE_DIR` — add it with `include_directories()` or `target_include_directories()`.
* For manually installed or non-CMake libs you may need a `Find<Package>.cmake` to create imported targets and set include/link settings.

## Provided CMake functions

```cmake
# Adds define `-DVAR_NAME=VALUE` to the `DEPS_CMAKE_GLOBAL_ARGS`
  deps_append_cmake_define(VAR_NAME [VALUE])

# Registers a dependency that is built with CMake
  deps_add_cmake_project(<source_subdir> [INSTALL_SUBDIR <name>] [CMAKE_ARGS ...])

# Registers a header-only dependency
  deps_add_header_only(<source_subdir> [INSTALL_SUBDIR <name>] [HEADERS ...])

# Registers copy rules for non-CMake dependencies
  deps_add_manual_install(<source_subdir> [INSTALL_SUBDIR <name>] [RULES <pattern> <dst> ...])

# Triggers the installation process for all previously registered dependencies
  deps_build_all([VERBOSE])

# Copies runtime binaries of TARGETS next to the TARGET after build
  deps_copy_runtime_binaries(<TARGET> [TARGETS <lib>...])

# Same as `target_link_libraries`, but also calls `deps_copy_runtime_binaries` for all linked libraries
  deps_target_link_and_copy_runtime(...)
```

For more info see comments in [Deps.cmake](../cmake/Modules/Deps.cmake).

## CMake & environment variables

| Variable                          | Description |
|-----------------------------------|---------------------------------------------------------------------|
| DEPS_THIRD_PARTY_SUBDIR* (Env)    | Name of the directory with Python script and all third-party library files (default: `third_party`) |
| DEPS_SOURCES_DIR (Env)            | Path containing sources as git repositories (default: `${PROJECT_SOURCE_DIR}/${DEPS_THIRD_PARTY_SUBDIR}/src`) |
| DEPS_OUT_SUBDIR* (Env)            | Subdirectory in `DEPS_INSTALL_DIR` |
| DEPS_INSTALL_DIR (Env)            | Installation directory (default: `${PROJECT_SOURCE_DIR}/${DEPS_THIRD_PARTY_SUBDIR}/bin/${DEPS_OUT_SUBDIR}`) |
| DEPS_CACHE_DIR (Env)              | Path to git-hash build cache (default: `${DEPS_INSTALL_DIR}/cache`) |
| DEPS_PYTHON (Env)                 | Path to Python interpreter (optional override) |
| DEPS_PYTHON (Env)                 | Path to the Python script (default: `${PROJECT_SOURCE_DIR}/${DEPS_THIRD_PARTY_SUBDIR}/deps.py`) |
| DEPS_CMAKE_GLOBAL_ARGS (Env)      | Additional global arguments passed to dependency CMake builds |
| DEPS_HEADER_SUBDIR (Env)          | Subdirectory name for header-only libraries (default: `header-only`) |
| DEPS_HEADER_ONLY_INCLUDE_DIR      | Read-only variable. Directory with headers of header-only libraries |

\* must be set before include of this module  
(Env) means that this variable **can** be override with the value of an environment variable with the same name.

## Directory layout

```
repo/
  └─ third_party/                     # <- DEPS_THIRD_PARTY_SUBDIR
          ├─ deps.py                  # Python helper script (called by deps_build_all)
          ├─ src/                     # Cloned dependency sources (git repositories)
          │     └─ SDL/
          ├─ bin/                     # Installation output root
          │   ├─ Windows-x64/msvcrt/  # <- DEPS_OUT_SUBDIR (build/runtime variant)
          │   │      ├─ cache/        # Git-hash build cache (reused across builds)
          │   │      └─ SDL3/         # SDL CONFIG install folder
          │   │─ Linux-x64/
          │   │      └─ cache/
          │   └─ SDL3/                # SDL CONFIG install folder
          └─ header-only/             # <- DEPS_HEADER_SUBDIR, collected headers
```

This is particularly useful when switching between **CMake toolchains** or [**VS Code kits**](https://gist.github.com/GrinlexGH/cffbe9727b7183d7044e2c4af378ffd2).

## When to use add_subdirectory() or system wide packages instead

Use `add_subdirectory()` for static libraries that must match your project's compiler flags and runtime options or if you need to use Link Time Optimization.

For all other external dependencies, prefer this system to reduce build complexity.  
Of course large libraries like Qt, that you will never want to build from source, are better handled via system packages and `find_package(EXACT)`.

## Usage example

**Toolchain file:**

```cmake
set(CMAKE_SYSTEM_NAME Linux)
set(CMAKE_SYSTEM_PROCESSOR arm)

set(tools /home/devel/gcc-4.7-linaro-rpi-gnueabihf)
set(CMAKE_C_COMPILER ${tools}/bin/arm-linux-gnueabihf-gcc)
set(CMAKE_CXX_COMPILER ${tools}/bin/arm-linux-gnueabihf-g++)

set(DEPS_OUT_SUBDIR "${CMAKE_SYSTEM_NAME}-${CMAKE_SYSTEM_PROCESSOR}-libstdcxx")

include(deps)
deps_append_cmake_define(CMAKE_SYSTEM_NAME)
deps_append_cmake_define(CMAKE_SYSTEM_PROCESSOR)
deps_append_cmake_define(CMAKE_C_COMPILER)
deps_append_cmake_define(CMAKE_CXX_COMPILER)
```

**CMakeLists.txt:**

```cmake
cmake_minimum_required(VERSION 3.26)
project("Skylabs" LANGUAGES CXX C)

list(APPEND CMAKE_MODULE_PATH "${PROJECT_SOURCE_DIR}/cmake/Modules")
include(Deps)

deps_append_cmake_define(CMAKE_MSVC_RUNTIME_LIBRARY MultiThreaded)
if(ANDROID)
    deps_append_cmake_define(ANDROID_ABI)
    deps_append_cmake_define(CMAKE_ANDROID_ARCH_ABI)
endif()

deps_add_cmake_project("SDL" INSTALL_SUBDIR "SDL3" CMAKE_ARGS -DSDL_TEST_LIBRARY=OFF)
deps_add_header_only("tinyobjloader" HEADERS "tiny_obj_loader.h")
deps_add_manual_install(
  "SteamworksSDK"
  RULES
    "redistributable_bin/**/*.dll"      "bin"
    "public/steam/lib/**/*.dll"         "bin"
    "public/steam/*.h"                  "include/steam"
    "redistributable_bin/**/*.lib"      "lib"
    "redistributable_bin/**/*.so"       "lib"
    "redistributable_bin/**/*.dylib"    "lib"
    "public/steam/lib/**/*.lib"         "lib"
    "public/steam/lib/**/*.so"          "lib"
    "public/steam/lib/**/*.dylib"       "lib"
)
deps_build_all()

include_directories(SYSTEM "${DEPS_HEADER_ONLY_INCLUDE_DIR}")
find_package(SDL3 REQUIRED)
find_package(SteamworksSDK REQUIRED)

add_subdirectory(third_party/src/glm EXCLUDE_FROM_ALL SYSTEM)

add_executable(skylabs src/main.cpp)
deps_target_link_and_copy_runtime(skylabs PRIVATE
    SDL3::SDL3
    SteamworksSDK::SteamAPI
    glm::glm
)
```
