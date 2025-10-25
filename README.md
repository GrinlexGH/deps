# Dependency Installer for CMake Projects
## Overview

This module provides an autonomous way to build and install external dependencies during CMake configuration. It allows a project to remain self-contained without requiring preinstalled SDKs or system-wide packages.

###### Also provides some `FindXXX.cmake` modules.

**Features:**
- Builds external libraries (CMake-based) in **Release mode**
- Caches each dependency by **Git commit hash** to avoid redundant rebuilds
- Supports **per-ABI or per-runtime variants** using `${DEPS_INSTALL_DIR}`
- Integrates cleanly with VSCode's **CMake Tools kits**

## Why?

Managing external dependencies in CMake projects is often **error-prone** and inefficient:

1. Using `add_subdirectory()` for third-party libraries causes multiple builds across all configurations (Debug, Release, RelWithDebInfo, etc.), increasing build time and cluttering IDE solutions.

2. Many prebuilt binaries are either **unavailable** for certain platforms/toolchains, or **incompatible** due to differing compile flags, runtime libraries, or ABIs.

3.  Relying on contributors or CI systems to manually provide the correct library versions is fragile and reduces repository autonomy.

This script solves these problems by:

- Building all **CMake-based dependencies** in Release mode only, avoiding redundant builds
- **Caching builds** using Git commit hashes, so libraries are rebuilt only when sources change
- Installing libraries into a **structured, reproducible layout**:

  `${DEPS_INSTALL_DIR}/${DEPS_TARGET_SYSTEM}-${DEPS_TARGET_ARCH}/${DEPS_SUBFOLDER}`

  allowing multiple ABI/runtime variants side by side (e.g., MSVC vs Clang/libc++).
- Providing a consistent and automatic CMake environment, including `CMAKE_PREFIX_PATH`
  for `find_package()` lookups and `DEPS_HEADER_ONLY_INCLUDE_DIR` for header-only libraries.

Overall, this approach **simplifies dependency management**, reduces build times, ensures reproducibility, and keeps repositories self-contained.

## How it works

0. You need to clone git library repositories to `libs/src`.

1. Each dependency is registered during configuration using one of the helper functions: `deps_add_cmake_project()`, `deps_add_header_only()`, or `deps_add_manual_install()`. You can use the `DEPS_CMAKE_GLOBAL_ARGS` variable to set common cmake configuration arguments for all cmake libraries.

2. Once all dependencies are declared, a single call to `deps_build_all()` triggers the build process. This command invokes the external **Python script**, which compiles and installs each dependency into the target directory defined by `${DEPS_INSTALL_DIR}`.

3. After installation, this module automatically updates `CMAKE_PREFIX_PATH` so that standard CMake commands such as `find_package()` can locate the installed packages. All CMake-based dependencies are installed in **CONFIG mode**.

   Header-only libraries are made available through the variable
`${DEPS_HEADER_ONLY_INCLUDE_DIR}`, which points to the directory containing all header-only dependency include paths. You can add this directory using `include_directories()` or `target_include_directories()` as needed.

   For manually installed or non-CMake libraries, you may need to provide your own `Find<Package>.cmake` module to expose imported targets and include/link settings.

## Directory layout

```
libs/
  ├─ src/                     # Dependency source trees (must be git repositories)
  ├─ bin/
  │   ├─ Windows-x64/msvcrt/  # Example install location (MSVC runtime)
  │   ├─ Windows-x64/libcxx/  # Example install location (Clang + libc++)
  │   ├─ Linux-x64/           # Example install location (Linux)
  │   └─ cache/               # Git-hash build cache
  └─ install_dependencies.py  # Python helper script
```

## 🛠 Installation path scheme

`${DEPS_INSTALL_DIR}/${DEPS_TARGET_SYSTEM}-${DEPS_TARGET_ARCH}/${DEPS_SUBFOLDER}`

Example:

```
libs/bin/Windows-x64/msvcrt/  # MSVC runtime
libs/bin/Windows-x64/libcxx/  # Clang + libc++
```

This layout allows multiple binary variants to coexist:

- `${DEPS_TARGET_SYSTEM}` - target operating system ("Windows", "Linux", "Darwin")
- `${DEPS_TARGET_ARCH}` - target CPU architecture ("x64", "arm64", ...)
- `${DEPS_SUBFOLDER}` - optional runtime identifier ("msvcrt", "libcxx", "mingw", ...)
                           or any label to distinguish different library versions for the same system

This is particularly useful when switching between **CMake toolchains** or [**VS Code kits**](https://gist.github.com/GrinlexGH/cffbe9727b7183d7044e2c4af378ffd2).
Each compiler/runtime combination can store its own binary set independently.

## Provided CMake functions

- `deps_append_cmake_define(VAR_NAME [VALUE])`  
  Adds define (-DVAR_NAME=VALUE) to the `DEPS_CMAKE_GLOBAL_ARGS`

- `deps_add_cmake_project(<source_subdir> [INSTALL_SUBDIR <name>] [CMAKE_ARGS ...])`  
  Registers a dependency that is built with CMake

- `deps_add_header_only(<source_subdir> [INSTALL_SUBDIR <name>] [HEADERS ...])`  
  Registers a header-only dependency

- `deps_add_manual_install(<source_subdir> [INSTALL_SUBDIR <name>] [RULES <pattern> <dst> ...])`  
  Registers copy rules for non-CMake dependencies

- `deps_build_all()`  
  Triggers the installation process for all previously registered dependencies

- `deps_copy_runtime_binaries(<TARGET> [TARGETS <lib>...])`  
  Copies runtime binaries of TARGETS next to the TARGET after build

- `deps_target_link_and_copy_runtime(...)`  
  Same as `target_link_libraries`, but also calls `deps_copy_runtime_binaries` for all linked libraries

For more info see comments in [Deps.cmake](../cmake/Modules/Deps.cmake).

## CMake & environment variables

| Variable                          | Description |
|-----------------------------------|---------------------------------------------------------------------|
| DEPS_SOURCES_DIR (Env)            | Path containing dependency sources as git repositories (default: `${PROJECT_SOURCE_DIR}/libs/src`) |
| DEPS_INSTALL_DIR (Env)            | Installation directory (default: `${PROJECT_SOURCE_DIR}/libs/bin/${DEPS_TARGET_SYSTEM}-${DEPS_TARGET_ARCH}/${DEPS_SUBFOLDER}`) |
| DEPS_TARGET_SYSTEM* (Env)         | Target OS name (e.g., "Windows", "Linux", "Darwin") (default: `${CMAKE_SYSTEM_NAME}`) |
| DEPS_TARGET_ARCH* (Env)           | Target architecture (e.g., "x64", "arm64") (default: `${CMAKE_SYSTEM_PROCESSOR}`) |
| DEPS_SUBFOLDER* (Env)             | Runtime variant identifier (e.g., "msvcrt", "libcxx", "mingw") |
| DEPS_CACHE_DIR (Env)              | Path to git-hash build cache (default: `${DEPS_INSTALL_DIR}/cache`) |
| DEPS_PYTHON (Env)                 | Path to Python interpreter (optional override) |
| DEPS_PYTHON (Env)                 | Path to the Python script (default: `${PROJECT_SOURCE_DIR}/libs/install_dependencies.py`) |
| DEPS_CMAKE_GLOBAL_ARGS (Env)      | Additional global arguments passed to dependency CMake builds |
| DEPS_HEADER_SUBDIR (Env)          | Subdirectory name for header-only libraries (default: `header-only`) |
| DEPS_HEADER_ONLY_INCLUDE_DIR      | Read-only variable. Directory with headers of header-only libraries |

\* must be set before `DEPS_INSTALL_DIR` is defined  
(Env) means that this variable **can** use the value of an environment variable with the same name if this variable is not set.

## When to use add_subdirectory() instead

Use `add_subdirectory()` only for static libraries that must match your project's compiler flags
and runtime options.

For all other external dependencies, prefer this system to reduce build complexity.  
Of course large libraries like Qt are better handled via system packages and `find_package(EXACT)`.

## Usage example

**Toolchain file (linux-arm.cmake):**

```cmake
set(CMAKE_SYSTEM_NAME Linux)    # DEPS_TARGET_SYSTEM will equal CMAKE_SYSTEM_NAME
set(CMAKE_SYSTEM_PROCESSOR arm) # DEPS_TARGET_ARCH will equal CMAKE_SYSTEM_PROCESSOR

set(tools /home/devel/gcc-4.7-linaro-rpi-gnueabihf)
set(CMAKE_C_COMPILER ${tools}/bin/arm-linux-gnueabihf-gcc)
set(CMAKE_CXX_COMPILER ${tools}/bin/arm-linux-gnueabihf-g++)
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
  INSTALL_SUBDIR "SteamworksSDK"
  RULES
    "public/steam/*.h"              "include/steam"
    "redistributable_bin/**/*.dll"  "bin"
)
deps_build_all()

include_directories(SYSTEM "${DEPS_HEADER_ONLY_INCLUDE_DIR}")
find_package(SDL3 REQUIRED)
find_package(SteamworksSDK REQUIRED)

add_subdirectory(libs/src/glm EXCLUDE_FROM_ALL SYSTEM)

add_executable(skylabs src/main.cpp)
deps_target_link_and_copy_runtime(skylabs PRIVATE
    SDL3::SDL3
    SteamworksSDK::SteamAPI
    glm::glm
)
```
