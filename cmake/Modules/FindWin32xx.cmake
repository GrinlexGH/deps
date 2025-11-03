# Author: Grinlex
#
# Imported targets:
# ``Win32xx::Win32xx``
#
# Result variables:
# ``Win32xx_FOUND``
# ``Win32xx_INCLUDE_DIR``
# ``Win32xx_DEFAULT_RC``
#
# Searches for such folder structure:
# Win32xx/
# └── include
#     ├── ...
#     ├── default_resource.rc
#     ├── wxx_appcore.h
#     └── ...

include(FindPackageHandleStandardArgs)

find_path(Win32xx_INCLUDE_DIR
    NAMES
        wxx_appcore.h
    PATH_SUFFIXES
        include
        Win32xx/include
)

find_file(Win32xx_DEFAULT_RC
    NAMES
        default_resource.rc
    PATH_SUFFIXES
        include
        Win32xx/include
)

if(Win32xx_INCLUDE_DIR AND NOT TARGET Win32xx::Win32xx)
    add_library(Win32xx::Win32xx INTERFACE IMPORTED)
    set_target_properties(Win32xx::Win32xx PROPERTIES
        INTERFACE_INCLUDE_DIRECTORIES "${Win32xx_INCLUDE_DIR}"
    )
endif()

find_package_handle_standard_args(Win32xx DEFAULT_MSG
    Win32xx_INCLUDE_DIR
)

if(Win32xx_FOUND)
    mark_as_advanced(Win32xx_INCLUDE_DIR)
endif()
