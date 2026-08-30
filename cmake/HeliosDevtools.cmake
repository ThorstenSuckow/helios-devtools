include_guard(GLOBAL)

# Resolve devtools root from this file location: <root>/cmake/HeliosDevtools.cmake
get_filename_component(_helios_devtools_cmake_dir "${CMAKE_CURRENT_LIST_FILE}" DIRECTORY)
get_filename_component(HELIOS_DEVTOOLS_SOURCE_DIR "${_helios_devtools_cmake_dir}/.." ABSOLUTE)

function(helios_enable_clang_tidy TARGET_NAME)
    find_program(HELIOS_CLANG_TIDY_EXECUTABLE NAMES clang-tidy)
    if(NOT HELIOS_CLANG_TIDY_EXECUTABLE)
        message(WARNING "clang-tidy not found; skipping CXX_CLANG_TIDY for target '${TARGET_NAME}'")
        return()
    endif()

    set(_helios_tidy_config "${HELIOS_DEVTOOLS_SOURCE_DIR}/clang/.clang-tidy")
    if(NOT EXISTS "${_helios_tidy_config}")
        message(FATAL_ERROR "Missing clang-tidy config in helios-devtools: ${_helios_tidy_config}")
    endif()

    set_target_properties(
            ${TARGET_NAME}
            PROPERTIES
            CXX_CLANG_TIDY "${HELIOS_CLANG_TIDY_EXECUTABLE};--config-file=${_helios_tidy_config}"
    )
endfunction()

function(helios_add_tidy_target TARGET_NAME)
    set(_helios_tidy_script "${HELIOS_DEVTOOLS_SOURCE_DIR}/scripts/run-clang-tidy.sh")
    if(NOT EXISTS "${_helios_tidy_script}")
        message(FATAL_ERROR "Missing devtools script: ${_helios_tidy_script}")
    endif()

    add_custom_target(
            tidy-${TARGET_NAME}
            COMMAND sh "${_helios_tidy_script}"
            --source-dir "${CMAKE_CURRENT_SOURCE_DIR}"
            --build-dir "${CMAKE_BINARY_DIR}"
            --target "${TARGET_NAME}"
            --check-only
            WORKING_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}"
            VERBATIM
    )

    add_custom_target(
            tidy-fix-${TARGET_NAME}
            COMMAND sh "${_helios_tidy_script}"
            --source-dir "${CMAKE_CURRENT_SOURCE_DIR}"
            --build-dir "${CMAKE_BINARY_DIR}"
            --target "${TARGET_NAME}"
            --autofix
            WORKING_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}"
            VERBATIM
    )

    if(PROJECT_IS_TOP_LEVEL AND NOT TARGET tidy)
        add_custom_target(tidy DEPENDS tidy-${TARGET_NAME})
    endif()

    if(PROJECT_IS_TOP_LEVEL AND NOT TARGET tidy-fix)
        add_custom_target(tidy-fix DEPENDS tidy-fix-${TARGET_NAME})
    endif()
endfunction()

function(helios_add_format_target TARGET_NAME)
    set(_helios_format_script "${HELIOS_DEVTOOLS_SOURCE_DIR}/scripts/run-clang-format.sh")
    if(NOT EXISTS "${_helios_format_script}")
        message(FATAL_ERROR "Missing devtools script: ${_helios_format_script}")
    endif()

    add_custom_target(
            format-${TARGET_NAME}
            COMMAND sh "${_helios_format_script}"
            --source-dir "${CMAKE_CURRENT_SOURCE_DIR}"
            --path "${CMAKE_CURRENT_SOURCE_DIR}/src"
            --check-only
            WORKING_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}"
            VERBATIM
    )

    add_custom_target(
            format-fix-${TARGET_NAME}
            COMMAND sh "${_helios_format_script}"
            --source-dir "${CMAKE_CURRENT_SOURCE_DIR}"
            --path "${CMAKE_CURRENT_SOURCE_DIR}/src"
            WORKING_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}"
            VERBATIM
    )

    if(PROJECT_IS_TOP_LEVEL AND NOT TARGET format)
        add_custom_target(format DEPENDS format-${TARGET_NAME})
    endif()

    if(PROJECT_IS_TOP_LEVEL AND NOT TARGET format-fix)
        add_custom_target(format-fix DEPENDS format-fix-${TARGET_NAME})
    endif()
endfunction()

function(helios_add_tidy_targets TARGET_NAME)
    helios_add_tidy_target(${TARGET_NAME})
endfunction()

function(helios_add_format_targets TARGET_NAME)
    helios_add_format_target(${TARGET_NAME})
endfunction()

function(helios_configure_target TARGET_NAME)
    helios_enable_clang_tidy(${TARGET_NAME})
    helios_add_tidy_target(${TARGET_NAME})
    helios_add_format_target(${TARGET_NAME})
endfunction()




