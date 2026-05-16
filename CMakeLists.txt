cmake_minimum_required(VERSION 3.20)
project(CircuitSolver CXX)

set(CMAKE_CXX_STANDARD 23)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

add_compile_options(-Wall -Wextra -Wpedantic)

find_package(PkgConfig REQUIRED)
pkg_check_modules(GLFW REQUIRED glfw3)

if(APPLE)
    find_library(OPENGL_LIBRARY OpenGL REQUIRED)
    find_library(COCOA_LIBRARY Cocoa REQUIRED)
    find_library(IOKIT_LIBRARY IOKit REQUIRED)
    set(EXTRA_LIBS ${OPENGL_LIBRARY} ${COCOA_LIBRARY} ${IOKIT_LIBRARY})
else()
    find_package(OpenGL REQUIRED)
    set(EXTRA_LIBS OpenGL::GL X11 pthread dl m)
endif()

include_directories(
    .
    solver/
    editor/imgui/
    editor/imgui/backends/
)

set(IMGUI_SRC
    editor/imgui/imgui.cpp
    editor/imgui/imgui_draw.cpp
    editor/imgui/imgui_tables.cpp
    editor/imgui/imgui_widgets.cpp
    editor/imgui/backends/imgui_impl_glfw.cpp
    editor/imgui/backends/imgui_impl_opengl3.cpp
)

add_library(solver_core STATIC
    solver/circuit.cpp
    solver/component.cpp
    solver/solver.cpp
    ${IMGUI_SRC}
)

add_executable(test.o tests/test.cpp)
target_link_libraries(test.o solver_core)

add_executable(benchmark.o tests/benchmark.cpp)
target_link_libraries(benchmark.o solver_core)

add_executable(landscape.o tests/landscape.cpp)
target_link_libraries(landscape.o solver_core)

add_executable(rc_transient.o tests/rc_transient.cpp)
target_link_libraries(rc_transient.o solver_core)

add_executable(editor editor/editor.cpp ${IMGUI_SRC})
target_link_libraries(editor
    solver_core
    ${GLFW_LIBRARIES}
    ${EXTRA_LIBS}
)
target_compile_options(editor PRIVATE ${GLFW_CFLAGS})