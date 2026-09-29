cmake_minimum_required(VERSION 3.20)
project(CircuitSolver CXX)

set(CMAKE_CXX_STANDARD 23)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

add_compile_options(-Wall -Wextra -Wpedantic)

include_directories(
    .
    solver/
    editor/imgui/
    editor/imgui/backends/
)

set(IMGUI_CORE_SRC
    editor/imgui/imgui.cpp
    editor/imgui/imgui_draw.cpp
    editor/imgui/imgui_tables.cpp
    editor/imgui/imgui_widgets.cpp
)

add_library(solver_core STATIC
    solver/circuit.cpp
    solver/component.cpp
    solver/solver.cpp
    ${IMGUI_CORE_SRC}
)

add_executable(test.o tests/test.cpp)
target_link_libraries(test.o solver_core)

add_executable(benchmark.o tests/benchmark.cpp)
target_link_libraries(benchmark.o solver_core)

add_executable(landscape.o tests/landscape.cpp)
target_link_libraries(landscape.o solver_core)

add_executable(rc_transient.o tests/rc_transient.cpp)
target_link_libraries(rc_transient.o solver_core)

if(APPLE)
    # macOS: Swift Editor with modern macOS look and feel
    add_custom_target(editor ALL
        COMMAND ${CMAKE_CURRENT_SOURCE_DIR}/editor-mac/build.sh
        DEPENDS solver_core
        COMMENT "Building native macOS Swift Circuit Simulator..."
    )
else()
    # Windows & Linux: Dear ImGui + GLFW Editor
    find_package(PkgConfig REQUIRED)
    pkg_check_modules(GLFW REQUIRED glfw3)
    find_package(OpenGL REQUIRED)
    set(EXTRA_LIBS OpenGL::GL X11 pthread dl m)

    set(IMGUI_BACKENDS_SRC
        editor/imgui/backends/imgui_impl_glfw.cpp
        editor/imgui/backends/imgui_impl_opengl3.cpp
    )

    add_executable(editor editor/editor.cpp ${IMGUI_BACKENDS_SRC})
    target_link_libraries(editor
        solver_core
        ${GLFW_LIBRARIES}
        ${EXTRA_LIBS}
    )
    target_compile_options(editor PRIVATE ${GLFW_CFLAGS})
endif()
