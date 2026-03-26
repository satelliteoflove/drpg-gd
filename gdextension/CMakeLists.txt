cmake_minimum_required(VERSION 3.22)
project(drpg_llm CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_POSITION_INDEPENDENT_CODE ON)

if(NOT CMAKE_BUILD_TYPE)
    set(CMAKE_BUILD_TYPE Release)
endif()

if(CMAKE_BUILD_TYPE STREQUAL "Debug")
    set(GODOT_BUILD_SUFFIX "template_debug")
else()
    set(GODOT_BUILD_SUFFIX "template_release")
endif()

set(GODOT_CPP_SYSTEM_HEADERS ON CACHE BOOL "" FORCE)
add_subdirectory(godot-cpp)

set(LLAMA_BUILD_EXAMPLES OFF CACHE BOOL "" FORCE)
set(LLAMA_BUILD_TESTS OFF CACHE BOOL "" FORCE)
set(LLAMA_BUILD_SERVER OFF CACHE BOOL "" FORCE)
add_subdirectory(llama.cpp)

add_library(drpg_llm SHARED
    src/llm_inference.cpp
    src/register_types.cpp
)

target_include_directories(drpg_llm PRIVATE
    llama.cpp/include
    llama.cpp/ggml/include
)

target_link_libraries(drpg_llm PRIVATE
    godot-cpp
    llama
)

set_source_files_properties(src/llm_inference.cpp PROPERTIES COMPILE_OPTIONS -fexceptions)

set_target_properties(drpg_llm PROPERTIES
    PREFIX "lib"
)

if(APPLE)
    set_target_properties(drpg_llm PROPERTIES
        OUTPUT_NAME "drpg_llm.macos.${GODOT_BUILD_SUFFIX}.universal"
        SUFFIX ".dylib"
    )
elseif(WIN32)
    set_target_properties(drpg_llm PROPERTIES
        PREFIX ""
        OUTPUT_NAME "drpg_llm.windows.${GODOT_BUILD_SUFFIX}.x86_64"
        SUFFIX ".dll"
    )
else()
    set_target_properties(drpg_llm PROPERTIES
        OUTPUT_NAME "drpg_llm.linux.${GODOT_BUILD_SUFFIX}.x86_64"
        SUFFIX ".so"
    )
endif()
