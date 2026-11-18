#!/bin/bash
# Code Runner for Zed - installer.
#
# Safe to re-run: runner.sh and run_code.py are replaced with the latest
# version, runner.custom.sh (your own commands) is never touched, and the
# "Run File" task and keybinding are added to your existing tasks.json and
# keymap.json without removing anything else in them.

echo "🚀 Code Runner for Zed - Universal Installer"
echo "============================================="
echo ""

# Detect OS and config directory
if [[ "$OSTYPE" == "darwin"* ]]; then
    OS="mac"
    CONFIG_DIR="$HOME/.config/zed"
    KEY_BINDING="cmd-r"
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    OS="linux"
    CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/zed"
    KEY_BINDING="ctrl-r"
else
    echo "❌ Unsupported OS: $OSTYPE"
    echo "   This installer supports Linux and macOS only."
    exit 1
fi

if ! command -v python3 > /dev/null 2>&1; then
    echo "❌ python3 not found. It is needed to install and to run Code Runner."
    exit 1
fi

echo "📍 OS: $OS"
echo "📁 Config: $CONFIG_DIR"
echo ""

mkdir -p "$CONFIG_DIR" || exit 1

TASKS_FILE="$CONFIG_DIR/tasks.json"
KEYMAP_FILE="$CONFIG_DIR/keymap.json"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

echo "📝 Creating Python wrapper (handles paths with spaces/special chars)..."
cat > "$CONFIG_DIR/run_code.py" << 'EOF'
#!/usr/bin/env python3
"""
Wrapper script to run code files in Zed editor.
Handles file paths with spaces, parentheses, and special characters.
"""
import subprocess
import sys
import os

def main():
    if len(sys.argv) < 2:
        print("Error: No file provided")
        print(f"Usage: {sys.argv[0]} <file_path>")
        sys.exit(1)

    file_path = sys.argv[1]

    # Check if file exists
    if not os.path.exists(file_path):
        print(f"Error: File not found: {file_path}")
        sys.exit(1)

    # runner.sh is installed next to this file
    runner_script = os.path.join(os.path.dirname(os.path.abspath(__file__)), "runner.sh")

    # Check if runner script exists
    if not os.path.exists(runner_script):
        print(f"Error: Runner script not found: {runner_script}")
        print("Please reinstall using install.sh")
        sys.exit(1)

    # The file path is passed as a list element, so it needs no escaping
    try:
        result = subprocess.run(
            ["/bin/bash", "--norc", "--noprofile", runner_script, file_path]
        )
        sys.exit(result.returncode)
    except KeyboardInterrupt:
        print("\n\n⚠️  Execution interrupted by user")
        sys.exit(130)
    except Exception as e:
        print(f"\n❌ Error running script: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()
EOF
chmod +x "$CONFIG_DIR/run_code.py"
echo "✅ run_code.py created"

echo ""
echo "📝 Creating runner.sh..."
cat > "$CONFIG_DIR/runner.sh" << 'RUNNEREOF'
#!/bin/bash
# Code Runner for Zed: runs one file, picking the command by its extension.
#
# This file is replaced every time install.sh runs. Put your own commands in
# runner.custom.sh next to it; that file is never overwritten.

FILE="$1"

if [ -z "$FILE" ]; then
    echo "❌ Error: No file provided"
    exit 1
fi

if [ ! -f "$FILE" ]; then
    echo "❌ Error: File not found: $FILE"
    exit 1
fi

# Absolute path, so a compiled program is never looked up in PATH by name
# (a relative "test.c" would otherwise run the shell's built-in `test`)
DIR=$(cd "$(dirname "$FILE")" && pwd)
FILENAME=$(basename "$FILE")
FILE="$DIR/$FILENAME"
STEM="${FILENAME%.*}"
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

# Compiled programs are built in a private temporary directory that is always
# removed, so nothing next to the source file is created, overwritten or deleted
BUILD_DIR=$(mktemp -d "${TMPDIR:-/tmp}/zed-code-runner.XXXXXX") || exit 1
BIN="$BUILD_DIR/$STEM"
trap 'rm -rf "$BUILD_DIR"' EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

rule() {
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

# say LABEL: announce what is about to run
say() {
    echo ">>> $1"
    echo ""
}

# finish CODE: report the result and exit with the program's exit code
finish() {
    echo ""
    rule
    if [ "$1" -eq 0 ]; then
        echo "✅ Finished successfully"
    else
        echo "❌ Exited with code $1"
    fi
    rule
    exit "$1"
}

# run CMD...: run a command, then finish with its exit code
run() {
    "$@"
    finish $?
}

# build_and_run CMD...: compile with CMD, which must write "$BIN", then run it
build_and_run() {
    "$@" || finish $?
    "$BIN"
    finish $?
}

# need CMD HINT: stop with a hint when CMD is not installed
need() {
    if ! command -v "$1" > /dev/null 2>&1; then
        echo "❌ $1 not found. $2"
        finish 127
    fi
}

# find_up PATTERN: print the nearest directory, from the file's own upwards,
# that contains a file matching PATTERN
find_up() {
    local d="$DIR" f
    while :; do
        for f in "$d"/$1; do
            if [ -e "$f" ]; then
                echo "$d"
                return 0
            fi
        done
        [ "$d" = "/" ] && return 1
        d=$(dirname "$d")
    done
}

clear
rule
echo "🚀 Running: $FILENAME"
echo "📁 Path: $FILE"
rule
echo ""

# Your own commands win over the built-in ones below
if [ -f "$SCRIPT_DIR/runner.custom.sh" ]; then
    . "$SCRIPT_DIR/runner.custom.sh"
fi

case "$FILE" in
    *.py)
        say "Running Python..."
        run python3 "$FILE"
        ;;
    *.js)
        say "Running JavaScript (Node.js)..."
        need node "Install Node.js."
        run node "$FILE"
        ;;
    *.ts)
        say "Running TypeScript..."
        need ts-node "Install it with: npm install -g ts-node"
        run ts-node "$FILE"
        ;;
    *.dart)
        say "Running Dart..."
        need dart "Please install the Dart SDK."
        run dart run "$FILE"
        ;;
    *.java)
        say "Running Java..."
        need java "Please install a JDK (11 or newer)."
        run java "$FILE"
        ;;
    *.go)
        say "Running Go..."
        need go "Please install Go."
        run go run "$FILE"
        ;;
    *.rb)
        say "Running Ruby..."
        run ruby "$FILE"
        ;;
    *.cpp|*.cc|*.cxx)
        say "Compiling and running C++..."
        need g++ "Please install g++."
        build_and_run g++ "$FILE" -o "$BIN" -Wall -Wextra -O2 -std=c++20
        ;;
    *.c)
        say "Compiling and running C..."
        need gcc "Please install gcc."
        build_and_run gcc "$FILE" -o "$BIN" -Wall -Wextra -O2 -std=c17
        ;;
    *.cs)
        need dotnet "Please install the .NET SDK."
        if PROJECT_DIR=$(find_up "*.csproj"); then
            say "Running C# project in $PROJECT_DIR..."
            run dotnet run --project "$PROJECT_DIR"
        else
            say "Running C# file (needs .NET 10 or newer)..."
            run dotnet run "$FILE"
        fi
        ;;
    *.php)
        say "Running PHP..."
        run php "$FILE"
        ;;
    *.sh)
        say "Running Shell Script..."
        run bash "$FILE"
        ;;
    *.pl)
        say "Running Perl..."
        run perl "$FILE"
        ;;
    *.lua)
        say "Running Lua..."
        run lua "$FILE"
        ;;
    *.r|*.R)
        say "Running R..."
        run Rscript "$FILE"
        ;;
    *.swift)
        say "Running Swift..."
        run swift "$FILE"
        ;;
    *.rs)
        say "Compiling and running Rust..."
        need rustc "Please install Rust (https://rustup.rs)."
        build_and_run rustc "$FILE" -o "$BIN"
        ;;
    *)
        echo "❌ Unsupported file type: $FILENAME"
        echo ""
        echo "Supported languages:"
        echo "  • Python (.py)"
        echo "  • JavaScript (.js)"
        echo "  • TypeScript (.ts)"
        echo "  • Dart (.dart)"
        echo "  • Java (.java)"
        echo "  • Go (.go)"
        echo "  • Ruby (.rb)"
        echo "  • C++ (.cpp, .cc, .cxx)"
        echo "  • C (.c)"
        echo "  • C# (.cs)"
        echo "  • PHP (.php)"
        echo "  • Shell (.sh)"
        echo "  • Perl (.pl)"
        echo "  • Lua (.lua)"
        echo "  • R (.r, .R)"
        echo "  • Swift (.swift)"
        echo "  • Rust (.rs)"
        echo ""
        echo "Add your own in $SCRIPT_DIR/runner.custom.sh"
        exit 1
        ;;
esac
RUNNEREOF
chmod +x "$CONFIG_DIR/runner.sh"
echo "✅ runner.sh created"

echo ""
CUSTOM_FILE="$CONFIG_DIR/runner.custom.sh"
if [ -f "$CUSTOM_FILE" ]; then
    echo "✅ runner.custom.sh kept as it is (your own commands)"
else
    cat > "$CUSTOM_FILE" << 'EOF'
# runner.custom.sh: your own commands for Code Runner for Zed.
#
# install.sh creates this file once and never overwrites it, so changes here
# survive updates. It is read before the built-in languages: a pattern that
# matches here wins, and any other file falls through to the defaults.
#
# Helpers:
#   run CMD...            run a command
#   build_and_run CMD...  compile with CMD (output to "$BIN"), then run "$BIN"
#   need CMD "hint"       stop with a hint when CMD is not installed
#   say "text"            print a ">>> text" line
# Variables:
#   $FILE (absolute path)  $DIR  $FILENAME  $STEM  $BIN
#
# Uncomment or add lines:

case "$FILE" in
    # *.py)  run python "$FILE" ;;
    # *.c)   build_and_run clang "$FILE" -o "$BIN" -O2 ;;
    # *.zig) run zig run "$FILE" ;;
    *) ;;
esac
EOF
    echo "✅ runner.custom.sh created (add your own commands here)"
fi

# merge_entry MODE FILE ENTRY_JSON: add the "Run File" task (MODE=tasks) or
# keybinding (MODE=keymap) to a Zed JSON file without touching anything else.
# Zed allows comments and trailing commas, so the entry is inserted as text
# right after the opening "[" and the rest of the file is kept byte for byte.
# Exit codes: 0 added, 10 already there, 11 key taken, 12 can't parse.
merge_entry() {
    python3 -I - "$@" "$TIMESTAMP" << 'PYEOF'
import json, re, shutil, sys

mode, path, entry_json, stamp = sys.argv[1:5]
entry = json.loads(entry_json)

try:
    with open(path, encoding="utf-8") as f:
        text = f.read()
except FileNotFoundError:
    text = ""

def blank_comments(s):
    """Replace comments and trailing commas with spaces, keeping offsets."""
    out, i, n, in_str = list(s), 0, len(s), False
    while i < n:
        c = s[i]
        if in_str:
            if c == "\\":
                i += 2
                continue
            if c == '"':
                in_str = False
        elif c == '"':
            in_str = True
        elif s.startswith("//", i):
            j = s.find("\n", i)
            j = n if j == -1 else j
            out[i:j] = " " * (j - i)
            i = j
            continue
        elif s.startswith("/*", i):
            j = s.find("*/", i + 2)
            j = n if j == -1 else j + 2
            out[i:j] = ["\n" if ch == "\n" else " " for ch in s[i:j]]
            i = j
            continue
        i += 1
    return re.sub(r",(\s*[\]}])", r" \1", "".join(out))

clean = blank_comments(text)
try:
    data = json.loads(clean) if clean.strip() else []
except ValueError as e:
    print(f"   could not parse it: {e}")
    sys.exit(12)
if not isinstance(data, list):
    print("   expected a JSON array at the top level")
    sys.exit(12)

if mode == "tasks":
    if any(isinstance(t, dict) and t.get("label") == entry["label"] for t in data):
        sys.exit(10)
else:
    key, action = next(iter(entry["bindings"].items()))
    for block in data:
        if not isinstance(block, dict):
            continue
        bound = (block.get("bindings") or {}).get(key)
        if bound == action:
            sys.exit(10)
        if bound is not None:
            print(f"   {key} is already bound to {json.dumps(bound)}"
                  f" (context: {block.get('context', 'none')})")
            sys.exit(11)

body = "\n".join("  " + line for line in json.dumps(entry, indent=2).splitlines())
if text.strip():
    start = clean.index("[") + 1
    text = text[:start] + "\n" + body + ("," if data else "\n") + text[start:]
    backup = f"{path}.backup.{stamp}"
    shutil.copy2(path, backup)
    print(f"   backup: {backup}")
else:
    text = "[\n" + body + "\n]\n"
with open(path, "w", encoding="utf-8") as f:
    f.write(text)
PYEOF
}

TASK_COMMAND="python3 \"$CONFIG_DIR/run_code.py\" \"\$ZED_FILE\""
TASK_ENTRY=$(python3 -I -c '
import json, sys
print(json.dumps({
    "label": "Run File",
    "command": sys.argv[1],
    "use_new_terminal": False,
    "allow_concurrent_runs": True,
    "reveal": "always",
    "tags": ["code-runner-run"],
}))' "$TASK_COMMAND")
KEY_ENTRY="{\"context\": \"Editor\", \"bindings\": {\"$KEY_BINDING\": [\"task::Spawn\", {\"task_name\": \"Run File\"}]}}"

echo ""
echo "📝 Adding the \"Run File\" task to tasks.json..."
merge_entry tasks "$TASKS_FILE" "$TASK_ENTRY"
case $? in
    0) echo "✅ Task added" ;;
    10) echo "✅ Task already there, left as it is" ;;
    *)
        echo "⚠️  tasks.json was left unchanged. Add this entry to it yourself:"
        echo "$TASK_ENTRY"
        ;;
esac

echo ""
echo "📝 Adding the $KEY_BINDING keybinding to keymap.json..."
merge_entry keymap "$KEYMAP_FILE" "$KEY_ENTRY"
case $? in
    0) echo "✅ Keybinding added" ;;
    10) echo "✅ Keybinding already there, left as it is" ;;
    11)
        echo "⚠️  Your binding was kept. To run files with another key, add this"
        echo "   to keymap.json with a free key in place of $KEY_BINDING:"
        echo "$KEY_ENTRY"
        ;;
    *)
        echo "⚠️  keymap.json was left unchanged. Add this entry to it yourself:"
        echo "$KEY_ENTRY"
        ;;
esac

echo ""
echo "📄 Installed files:"
echo "  • $CONFIG_DIR/run_code.py"
echo "  • $CONFIG_DIR/runner.sh"
echo "  • $CONFIG_DIR/runner.custom.sh (yours, never overwritten)"
echo "  • \"Run File\" entries in tasks.json and keymap.json"
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Installation Complete!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "🎯 How to Use:"
echo "  1. Open any supported code file in Zed"
echo "  2. Press $KEY_BINDING to run it"
echo "  (If nothing happens, restart Zed once.)"
echo ""
echo "🧪 Quick Test:"
echo "  echo 'print(\"Hello, World!\")' > test.py"
echo "  zed test.py"
echo "  # Press $KEY_BINDING"
echo ""
echo "🔧 Troubleshooting:"
echo "  • Manual test: Cmd/Ctrl+Shift+P → 'task: spawn' → 'Run File'"
echo "  • Test directly: python3 \"$CONFIG_DIR/run_code.py\" test.py"
echo "  • Your own commands: $CUSTOM_FILE"
echo ""
