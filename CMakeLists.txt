cmake_minimum_required(VERSION 3.23)
project(aowis-server-swmm VERSION 0.1.0 LANGUAGES C CXX)

# This repository may be built independently or included by AOWIS-SERVER-STANDALONE.
# Do not bring Boost-heavy upstream tests into the AOWIS build.
set(BUILD_TESTS OFF)
set(BUILD_DOCS OFF)
set(BUILD_DEF OFF)

if(NOT EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/external/swmm/CMakeLists.txt")
    message(FATAL_ERROR
        "SWMM submodule is missing. Run ./tools/init_swmm_submodule.sh, "
        "or (for an existing clone) git submodule update --init --recursive.")
endif()

# OWA SWMM's post-build copy currently expects the destination to exist.
# This is upstream behavior; avoid modifying the vendored solver for it.
foreach(_config "" Debug Release RelWithDebInfo MinSizeRel)
    if(_config STREQUAL "")
        file(MAKE_DIRECTORY "${CMAKE_BINARY_DIR}/bin")
    else()
        file(MAKE_DIRECTORY "${CMAKE_BINARY_DIR}/bin/${_config}")
    endif()
endforeach()

add_subdirectory(external/swmm)

add_library(aowis-swmm-core STATIC
    src/core/Simulation.cpp
)
add_library(aowis::swmm-core ALIAS aowis-swmm-core)
target_compile_features(aowis-swmm-core PUBLIC cxx_std_17)
target_include_directories(aowis-swmm-core PUBLIC
    $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>
    $<INSTALL_INTERFACE:include>
)
target_link_libraries(aowis-swmm-core PUBLIC swmm5)

if(CMAKE_SOURCE_DIR STREQUAL PROJECT_SOURCE_DIR)
    set(_aowis_swmm_test_default ON)
else()
    set(_aowis_swmm_test_default OFF)
endif()
option(AOWIS_SWMM_BUILD_TESTS "Build AOWIS SWMM integration smoke tests" ${_aowis_swmm_test_default})

if(AOWIS_SWMM_BUILD_TESTS)
    enable_testing()
    add_executable(aowis-swmm-smoke tests/smoke.cpp)
    target_link_libraries(aowis-swmm-smoke PRIVATE aowis::swmm-core)
    # On Windows, a test executable must find the shared SWMM DLL.
    if(WIN32 AND BUILD_SHARED_LIBS)
        add_custom_command(TARGET aowis-swmm-smoke POST_BUILD
            COMMAND ${CMAKE_COMMAND} -E copy_if_different
                $<TARGET_FILE:swmm5> $<TARGET_FILE_DIR:aowis-swmm-smoke>
        )
    endif()
    set(_smoke_output "${CMAKE_CURRENT_BINARY_DIR}/smoke-output")
    file(MAKE_DIRECTORY "${_smoke_output}")
    add_test(NAME aowis-swmm-engine-smoke
        COMMAND aowis-swmm-smoke
            "${CMAKE_CURRENT_SOURCE_DIR}/tests/data/basic.inp"
            "${_smoke_output}/basic.rpt"
            "${_smoke_output}/basic.out")
endif()
