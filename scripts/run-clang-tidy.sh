#!/usr/bin/env sh
set -eu

DEVTOOLS_ROOT=$(cd "$(dirname "$0")/.." && pwd)
SOURCE_DIR=""
BUILD_DIR=""
TARGET_NAME=""
PATTERN=""
AUTO_FIX=0
FIX_ERRORS=0

usage() {
  cat <<'EOF'
Usage: run-clang-tidy.sh --source-dir <dir> [--build-dir <dir>] [--target <name>] [--pattern <regex>] [--autofix] [--fix-errors] [--check-only] [--help]

Options:
  --source-dir   Project source directory (required)
  --build-dir    Build directory (default: <source-dir>/cmake-build-debug)
  --target       Build target to compile before tidy (optional)
  --pattern      File regex for run-clang-tidy (default: <source-dir>/src/.*\.(ixx|cpp)$)
  --autofix      Enable automatic fixes (-fix)
  --fix-errors   Also use -fix-errors (implies --autofix)
  --check-only   Force analysis-only mode without fixes
  --help         Show this help

Environment:
  SKIP_BUILD=1                   Skip build step
  CLANG_TIDY_BUILD_JOBS=<n>      Build parallelism (default: 4)
  HELIOS_TIDY_C_COMPILER=<path>  Optional C compiler override
  HELIOS_TIDY_CXX_COMPILER=<path> Optional C++ compiler override
EOF
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --source-dir)
      SOURCE_DIR=$2
      shift 2
      ;;
    --build-dir)
      BUILD_DIR=$2
      shift 2
      ;;
    --target)
      TARGET_NAME=$2
      shift 2
      ;;
    --pattern)
      PATTERN=$2
      shift 2
      ;;
    --autofix)
      AUTO_FIX=1
      shift
      ;;
    --fix-errors)
      AUTO_FIX=1
      FIX_ERRORS=1
      shift
      ;;
    --check-only)
      AUTO_FIX=0
      FIX_ERRORS=0
      shift
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    --*)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
    *)
      echo "Unexpected positional argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if [ -z "$SOURCE_DIR" ]; then
  echo "--source-dir is required" >&2
  usage >&2
  exit 1
fi

if [ -z "$BUILD_DIR" ]; then
  BUILD_DIR="$SOURCE_DIR/cmake-build-debug"
fi

if [ -z "$PATTERN" ]; then
  PATTERN="$SOURCE_DIR/src/.*\\.(ixx|cpp)$"
fi

TIDY_CONFIG="$DEVTOOLS_ROOT/clang/.clang-tidy"
if [ ! -f "$TIDY_CONFIG" ]; then
  echo "Missing clang-tidy config: $TIDY_CONFIG" >&2
  exit 1
fi

if [ -f "$BUILD_DIR/CMakeCache.txt" ]; then
  if ! grep -q '^CMAKE_GENERATOR:INTERNAL=Ninja$' "$BUILD_DIR/CMakeCache.txt"; then
    echo "Build directory is not using Ninja, resetting $BUILD_DIR" >&2
    rm -rf "$BUILD_DIR"
  fi
fi

if ! command -v run-clang-tidy >/dev/null 2>&1; then
  echo "run-clang-tidy not found. Please install llvm/clang-tools." >&2
  exit 1
fi

if ! command -v clang-tidy >/dev/null 2>&1; then
  echo "clang-tidy not found. Please install llvm/clang-tools." >&2
  exit 1
fi

if [ ! -f "$BUILD_DIR/compile_commands.json" ]; then
  echo "Generating compile_commands.json in $BUILD_DIR" >&2
  if [ -n "${HELIOS_TIDY_C_COMPILER:-}" ] && [ -n "${HELIOS_TIDY_CXX_COMPILER:-}" ]; then
    cmake -S "$SOURCE_DIR" -B "$BUILD_DIR" -G Ninja -DCMAKE_EXPORT_COMPILE_COMMANDS=ON \
      "-DCMAKE_C_COMPILER=${HELIOS_TIDY_C_COMPILER}" \
      "-DCMAKE_CXX_COMPILER=${HELIOS_TIDY_CXX_COMPILER}"
  elif command -v clang >/dev/null 2>&1 && command -v clang++ >/dev/null 2>&1; then
    cmake -S "$SOURCE_DIR" -B "$BUILD_DIR" -G Ninja -DCMAKE_EXPORT_COMPILE_COMMANDS=ON \
      "-DCMAKE_C_COMPILER=$(command -v clang)" \
      "-DCMAKE_CXX_COMPILER=$(command -v clang++)"
  else
    cmake -S "$SOURCE_DIR" -B "$BUILD_DIR" -G Ninja -DCMAKE_EXPORT_COMPILE_COMMANDS=ON
  fi
fi

if [ "${SKIP_BUILD:-0}" != "1" ]; then
  if [ -n "$TARGET_NAME" ]; then
    cmake --build "$BUILD_DIR" --target "$TARGET_NAME" -j "${CLANG_TIDY_BUILD_JOBS:-4}"
  else
    cmake --build "$BUILD_DIR" -j "${CLANG_TIDY_BUILD_JOBS:-4}"
  fi
fi

set -- run-clang-tidy -p "$BUILD_DIR" -config-file="$TIDY_CONFIG"

if [ "$AUTO_FIX" = "1" ]; then
  set -- "$@" -fix
fi

if [ "$FIX_ERRORS" = "1" ]; then
  set -- "$@" -fix-errors
fi

set -- "$@" "$PATTERN"
"$@"

