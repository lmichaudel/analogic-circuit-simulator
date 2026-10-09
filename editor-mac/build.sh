#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
BUILD_DIR="${ROOT_DIR}/build"
APP_DIR="${BUILD_DIR}/CircuitSimulator.app"
CACHE_DIR="${TMPDIR:-/tmp}/clang-cache"

mkdir -p "${CACHE_DIR}"
mkdir -p "${BUILD_DIR}"
mkdir -p "${APP_DIR}/Contents/MacOS"
mkdir -p "${APP_DIR}/Contents/Resources"

cp "${SCRIPT_DIR}/Info.plist" "${APP_DIR}/Contents/Info.plist"

echo "[1/3] Compiling CircuitBridge.cpp..."
clang++ -std=c++23 -O2 \
    -I"${ROOT_DIR}" \
    -I"${ROOT_DIR}/solver" \
    -I"${ROOT_DIR}/editor/imgui" \
    -c "${SCRIPT_DIR}/CircuitBridge.cpp" \
    -o "${BUILD_DIR}/CircuitBridge.o"

echo "[2/3] Compiling Swift macOS Editor..."
swiftc -module-cache-path "${CACHE_DIR}" -O \
    -I"${SCRIPT_DIR}" \
    -import-objc-header "${SCRIPT_DIR}/CircuitBridge.h" \
    "${SCRIPT_DIR}/Sources/Models/"*.swift \
    "${SCRIPT_DIR}/Sources/Simulation/"*.swift \
    "${SCRIPT_DIR}/Sources/Views/"*.swift \
    "${SCRIPT_DIR}/Sources/App.swift" \
    "${BUILD_DIR}/CircuitBridge.o" \
    "${BUILD_DIR}/libsolver_core.a" \
    -lc++ \
    -o "${APP_DIR}/Contents/MacOS/CircuitSimulator"

echo "[3/3] Creating editor launcher..."
cp "${APP_DIR}/Contents/MacOS/CircuitSimulator" "${BUILD_DIR}/CircuitSimulator"
ln -sf "CircuitSimulator.app/Contents/MacOS/CircuitSimulator" "${BUILD_DIR}/editor"

echo "Build complete! App bundle is at: ${APP_DIR}"
echo "You can launch it via: open ${APP_DIR} or ${BUILD_DIR}/CircuitSimulator"
