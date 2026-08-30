#!/usr/bin/env sh
set -eu

DEVTOOLS_ROOT=$(cd "$(dirname "$0")/.." && pwd)
SOURCE_DIR=""
TARGET_PATH=""
CHECK_ONLY=0

usage() {
  cat <<'EOF'
Usage: run-clang-format.sh --source-dir <dir> [--path <path>] [--check-only] [--help]

Options:
  --source-dir   Project source directory (required)
  --path         File or directory to format (default: <source-dir>/src)
  --check-only   Check formatting only (no file changes)
  --help         Show this help
EOF
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --source-dir)
      SOURCE_DIR=$2
      shift 2
      ;;
    --path)
      TARGET_PATH=$2
      shift 2
      ;;
    --check-only)
      CHECK_ONLY=1
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

if [ -z "$TARGET_PATH" ]; then
  TARGET_PATH="$SOURCE_DIR/src"
fi

FORMAT_CONFIG="$DEVTOOLS_ROOT/clang/.clang-format"
if [ ! -f "$FORMAT_CONFIG" ]; then
  echo "Missing clang-format config: $FORMAT_CONFIG" >&2
  exit 1
fi

if ! command -v clang-format >/dev/null 2>&1; then
  echo "clang-format not found. Please install clang-format/llvm." >&2
  exit 1
fi

if [ ! -e "$TARGET_PATH" ]; then
  echo "Path does not exist: $TARGET_PATH" >&2
  exit 1
fi

TMP_FILE_LIST=$(mktemp)
trap 'rm -f "$TMP_FILE_LIST"' EXIT HUP INT TERM

if [ -f "$TARGET_PATH" ]; then
  case "$TARGET_PATH" in
    *.cpp|*.cxx|*.cc|*.h|*.hpp|*.ixx)
      printf '%s\n' "$TARGET_PATH" > "$TMP_FILE_LIST"
      ;;
    *)
      echo "File extension is not supported: $TARGET_PATH" >&2
      exit 1
      ;;
  esac
else
  find "$TARGET_PATH" -type f \( -name '*.cpp' -o -name '*.cxx' -o -name '*.cc' -o -name '*.h' -o -name '*.hpp' -o -name '*.ixx' \) > "$TMP_FILE_LIST"
fi

FILE_COUNT=$(wc -l < "$TMP_FILE_LIST" | tr -d ' ')
if [ "$FILE_COUNT" -eq 0 ]; then
  echo "No matching files found under: $TARGET_PATH"
  exit 0
fi

if [ "$CHECK_ONLY" -eq 1 ]; then
  echo "Checking formatting for ${FILE_COUNT} file(s)..."
  while IFS= read -r file; do
    [ -n "$file" ] || continue
    clang-format "--style=file:${FORMAT_CONFIG}" --dry-run --Werror "$file"
  done < "$TMP_FILE_LIST"
  echo "Formatting check passed."
else
  echo "Formatting ${FILE_COUNT} file(s)..."
  while IFS= read -r file; do
    [ -n "$file" ] || continue
    clang-format -i "--style=file:${FORMAT_CONFIG}" "$file"
  done < "$TMP_FILE_LIST"
  echo "Formatting complete."
fi

