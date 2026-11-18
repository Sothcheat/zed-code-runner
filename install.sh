#!/bin/bash
# Code Runner for Zed: installer, updater and uninstaller.
# https://github.com/Sothcheat/zed-code-runner
#
#   install.sh               install, or update to this version
#   install.sh --key f5      use another key for Run File (default ctrl-r / cmd-r)
#   install.sh --update      download the latest version from GitHub and install it
#   install.sh --uninstall   remove what the installer added (your custom.sh stays)
#   install.sh --doctor      show which language runtimes are installed
#
# From the web, pass options after "bash -s --":
#   curl -fsSL .../install.sh | bash -s -- --uninstall
#
# Safe to re-run: your other tasks, keybindings and comments in tasks.json and
# keymap.json are kept, a backup is saved before either file changes, and
# custom.sh (your own commands) is never overwritten.

REPO_RAW="https://raw.githubusercontent.com/Sothcheat/zed-code-runner/${CODE_RUNNER_REF:-main}"

ACTION="install"
KEY=""
while [ $# -gt 0 ]; do
    case "$1" in
        --key)
            KEY="${2:-}"
            if [ -z "$KEY" ]; then
                echo "❌ --key needs a key, for example: --key f5"
                exit 1
            fi
            shift 2
            ;;
        --update) ACTION="update"; shift ;;
        --uninstall) ACTION="uninstall"; shift ;;
        --doctor) ACTION="doctor"; shift ;;
        -h|--help)
            sed -n '2,17p' "${BASH_SOURCE[0]}" 2> /dev/null | sed 's/^# \{0,1\}//' \
                || echo "See https://github.com/Sothcheat/zed-code-runner"
            exit 0
            ;;
        *)
            echo "❌ Unknown option: $1 (try --help)"
            exit 1
            ;;
    esac
done

# Detect OS and config directory
if [[ "$OSTYPE" == "darwin"* ]]; then
    OS="mac"
    CONFIG_DIR="$HOME/.config/zed"
    DEFAULT_KEY="cmd-r"
    RERUN_KEY="cmd-alt-r"
    SPAWN_KEY="cmd-shift-r"
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    OS="linux"
    CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/zed"
    DEFAULT_KEY="ctrl-r"
    RERUN_KEY="ctrl-shift-r"
    SPAWN_KEY="alt-shift-t"
else
    echo "❌ Unsupported OS: $OSTYPE"
    echo "   This installer supports Linux and macOS only."
    exit 1
fi

APP_DIR="$CONFIG_DIR/code-runner"
TASKS_FILE="$CONFIG_DIR/tasks.json"
KEYMAP_FILE="$CONFIG_DIR/keymap.json"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

if [ "$ACTION" = "doctor" ]; then
    if [ -f "$APP_DIR/runner.sh" ]; then
        exec bash "$APP_DIR/runner.sh" --doctor
    fi
    echo "❌ Code Runner isn't installed in $APP_DIR"
    exit 1
fi

TMP_DIR=$(mktemp -d "${TMPDIR:-/tmp}/zed-code-runner-install.XXXXXX") || exit 1
trap 'rm -rf "$TMP_DIR"' EXIT

# ------------------------------------------------------------ JSON editing ---

# zed_json ACTION KIND FILE: add or remove the installer's own entries in
# tasks.json (KIND=tasks) or keymap.json (KIND=keymap). Zed allows comments
# and trailing commas, so entries are cut and inserted as text and the rest of
# the file is kept byte for byte.
# Exit codes: 0 changed, 10 nothing to do, 11 key taken, 12 can't parse.
zed_json() {
    python3 -I - "$@" "$TIMESTAMP" "$APP_DIR/runner.sh" "${KEY:-$DEFAULT_KEY}" "${KEY:+given}" << 'PYEOF'
import json, re, shutil, sys

action, kind, path, stamp, runner, key, key_given = sys.argv[1:8]

RUN_ACTION = ["task::Spawn", {"task_name": "Run File"}]
# Runnable tags of Zed's built-in languages: the run button next to main()
# (or `if __name__ == "__main__":`) runs Run File
RUNNABLE_TAGS = ["c-main", "cpp-main", "rust-main", "go-main",
                 "python-module-main-method", "bash-script"]

def task(label, args, **extra):
    t = {"label": label, "command": "bash", "args": [runner] + args,
         "cwd": "$ZED_DIRNAME", "use_new_terminal": False,
         "allow_concurrent_runs": True, "reveal": "always"}
    t.update(extra)
    return t

TASKS = [
    task("Run File", ["$ZED_FILE"], tags=RUNNABLE_TAGS),
    task("Run File (debug)", ["--debug", "$ZED_FILE"]),
    task("Run Selection", ["--selection", "$ZED_FILE", "$ZED_SELECTED_TEXT"]),
    {"label": "Code Runner: Doctor", "command": "bash",
     "args": [runner, "--doctor"], "use_new_terminal": False,
     "allow_concurrent_runs": True, "reveal": "always"},
]
LABELS = {t["label"] for t in TASKS}
KEYMAP = [{"context": "Editor", "bindings": {key: RUN_ACTION}}]


def blank(s):
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


def object_spans(clean):
    """(start, end) of each object in the top-level array."""
    spans, depth, in_str, esc, start = [], 0, False, False, None
    for i in range(clean.index("[") + 1, len(clean)):
        c = clean[i]
        if in_str:
            if esc:
                esc = False
            elif c == "\\":
                esc = True
            elif c == '"':
                in_str = False
        elif c == '"':
            in_str = True
        elif c in "[{":
            if depth == 0:
                start = i
            depth += 1
        elif c in "]}":
            if depth == 0:
                break
            depth -= 1
            if depth == 0:
                spans.append((start, i + 1))
    return spans


def parse(text):
    clean = blank(text)
    data = json.loads(clean) if clean.strip() else []
    if not isinstance(data, list) or not all(isinstance(d, dict) for d in data):
        raise ValueError("expected a JSON array of objects")
    return clean, data


def remove(text, indexes):
    """Cut the given top-level entries, with their separating comma."""
    clean = blank(text)
    for k in sorted(indexes, reverse=True):
        s, e = object_spans(clean)[k]
        j = e
        while j < len(clean) and clean[j] in " \t\r\n":
            j += 1
        if j < len(clean) and clean[j] == ",":
            # drop the comma and the rest of its line
            e = j + 1
            while e < len(clean) and clean[e] in " \t\r":
                e += 1
            if e < len(clean) and clean[e] == "\n":
                e += 1
        else:
            b = s - 1
            while b >= 0 and clean[b] in " \t\r\n":
                b -= 1
            if b >= 0 and clean[b] == ",":
                s = b
        # also drop the indentation before the entry
        while s > 0 and clean[s - 1] in " \t":
            s -= 1
        text, clean = text[:s] + text[e:], clean[:s] + clean[e:]
    return text


def insert(text, entries):
    body = ",\n".join("\n".join("  " + line for line in
                                json.dumps(e, indent=2).splitlines())
                      for e in entries)
    if not text.strip():
        return "[\n" + body + "\n]\n"
    clean, data = parse(text)
    pos = clean.index("[") + 1
    return text[:pos] + "\n" + body + ("," if data else "\n") + text[pos:]


def is_ours(block):
    b = block.get("bindings")
    return isinstance(b, dict) and b and all(v == RUN_ACTION for v in b.values())


try:
    with open(path, encoding="utf-8") as f:
        original = f.read()
except FileNotFoundError:
    original = ""

try:
    clean, data = parse(original)
except ValueError as e:
    print(f"   could not parse it: {e}")
    sys.exit(12)

text = original
if kind == "tasks":
    ours = [i for i, t in enumerate(data) if t.get("label") in LABELS]
    if action == "install":
        if [data[i] for i in ours] == TASKS and ours == list(range(len(TASKS))):
            sys.exit(10)
        text = insert(remove(text, ours), TASKS)
    else:
        if not ours:
            sys.exit(10)
        text = remove(text, ours)
else:
    ours = [i for i, b in enumerate(data) if is_ours(b)]
    elsewhere = [k for i, b in enumerate(data) if i not in ours
                 for k, v in (b.get("bindings") or {}).items() if v == RUN_ACTION]
    if action == "install":
        if (ours or elsewhere) and not key_given:
            sys.exit(10)
        for i, b in enumerate(data):
            bound = (b.get("bindings") or {}).get(key)
            if i not in ours and bound is not None and bound != RUN_ACTION:
                print(f"   {key} is already bound to {json.dumps(bound)}"
                      f" (context: {b.get('context', 'none')})")
                sys.exit(11)
        text = insert(remove(text, ours), KEYMAP)
    else:
        for k in elsewhere:
            print(f"   {k} → Run File is in a block with your own bindings;"
                  " remove that line yourself")
        if not ours:
            sys.exit(10)
        text = remove(text, ours)

if text == original:
    sys.exit(10)
try:
    parse(text)
except ValueError as e:
    print(f"   internal error, file left unchanged: {e}")
    sys.exit(12)
if original.strip():
    backup = f"{path}.backup.{stamp}"
    shutil.copy2(path, backup)
    print(f"   backup: {backup}")
with open(path, "w", encoding="utf-8") as f:
    f.write(text)
PYEOF
}

print_manual_entries() {
    echo "   Add these yourself (see the README, \"What the installer changes\"):"
    echo "   • tasks.json: a \"Run File\" task running: bash \"$APP_DIR/runner.sh\" \"\$ZED_FILE\""
    echo "   • keymap.json: {\"context\": \"Editor\", \"bindings\": {\"${KEY:-$DEFAULT_KEY}\": [\"task::Spawn\", {\"task_name\": \"Run File\"}]}}"
}

# ------------------------------------------------------------- v1 cleanup ---

# Version 1 kept everything directly in the Zed config folder
remove_v1_files() {
    if [ -f "$CONFIG_DIR/run_code.py" ] \
        && grep -q "Wrapper script to run code files in Zed editor" "$CONFIG_DIR/run_code.py"; then
        rm -f "$CONFIG_DIR/run_code.py"
        echo "🧹 Removed old run_code.py (no longer needed)"
    fi
    if [ -f "$CONFIG_DIR/runner.sh" ] \
        && grep -qE 'Code Runner for Zed|filename_ext' "$CONFIG_DIR/runner.sh"; then
        rm -f "$CONFIG_DIR/runner.sh"
        echo "🧹 Removed old runner.sh (now in $APP_DIR)"
    fi
}

# --------------------------------------------------------------- uninstall ---

if [ "$ACTION" = "uninstall" ]; then
    echo "🗑️  Code Runner for Zed - Uninstall"
    echo ""
    if command -v python3 > /dev/null 2>&1; then
        zed_json uninstall tasks "$TASKS_FILE"
        case $? in
            0) echo "✅ Removed the Code Runner tasks from tasks.json" ;;
            10) echo "✅ No Code Runner tasks in tasks.json" ;;
            *) echo "⚠️  tasks.json left unchanged; remove the Run File, Run Selection and Code Runner tasks yourself" ;;
        esac
        zed_json uninstall keymap "$KEYMAP_FILE"
        case $? in
            0) echo "✅ Removed the Run File keybinding from keymap.json" ;;
            10) echo "✅ No Run File keybinding block in keymap.json" ;;
            *) echo "⚠️  keymap.json left unchanged; remove the Run File binding yourself" ;;
        esac
    else
        echo "⚠️  python3 not found: remove the Run File tasks and keybinding yourself"
    fi
    remove_v1_files
    rm -f "$APP_DIR/runner.sh" "$APP_DIR/install.sh"
    if [ -f "$APP_DIR/custom.sh" ]; then
        echo "📝 Kept your commands: $APP_DIR/custom.sh (delete it if you don't need it)"
    else
        rmdir "$APP_DIR" 2> /dev/null
    fi
    echo ""
    echo "✅ Code Runner removed"
    exit 0
fi

# ---------------------------------------------------------------- install ---

echo "🚀 Code Runner for Zed - Installer"
echo "=================================="
echo ""
echo "📍 OS: $OS"
echo "📁 Config: $CONFIG_DIR"
echo ""

# Use the files next to this script when run from a clone, otherwise
# (curl | bash, or --update) download them
SELF="${BASH_SOURCE[0]:-}"
SRC_DIR=""
if [ "$ACTION" != "update" ] && [ -n "$SELF" ] && [ -f "$SELF" ]; then
    SELF_DIR=$(cd "$(dirname "$SELF")" && pwd)
    if [ -f "$SELF_DIR/runner.sh" ] && [ -f "$SELF_DIR/custom.example.sh" ]; then
        SRC_DIR="$SELF_DIR"
    fi
fi

if [ -z "$SRC_DIR" ]; then
    echo "⬇️  Downloading from $REPO_RAW ..."
    for f in runner.sh custom.example.sh install.sh; do
        if command -v curl > /dev/null 2>&1; then
            curl -fsSL "$REPO_RAW/$f" -o "$TMP_DIR/$f"
        else
            wget -qO "$TMP_DIR/$f" "$REPO_RAW/$f"
        fi || { echo "❌ Download of $f failed"; exit 1; }
    done
    SRC_DIR="$TMP_DIR"
    echo ""
fi

mkdir -p "$APP_DIR" || exit 1
cp "$SRC_DIR/runner.sh" "$APP_DIR/runner.sh" || exit 1
cp "$SRC_DIR/install.sh" "$APP_DIR/install.sh" || exit 1
chmod +x "$APP_DIR/runner.sh" "$APP_DIR/install.sh"
VERSION=$(bash "$APP_DIR/runner.sh" --version)
echo "✅ Installed $VERSION in $APP_DIR"

remove_v1_files
if [ -f "$CONFIG_DIR/runner.custom.sh" ]; then
    if [ -f "$APP_DIR/custom.sh" ]; then
        echo "⚠️  Both $CONFIG_DIR/runner.custom.sh and $APP_DIR/custom.sh exist;"
        echo "   only custom.sh is used. Move anything you need from runner.custom.sh."
    else
        mv "$CONFIG_DIR/runner.custom.sh" "$APP_DIR/custom.sh"
        echo "📝 Moved your runner.custom.sh to $APP_DIR/custom.sh"
    fi
fi

if [ -f "$APP_DIR/custom.sh" ]; then
    echo "✅ custom.sh kept as it is (your own commands)"
else
    cp "$SRC_DIR/custom.example.sh" "$APP_DIR/custom.sh"
    echo "✅ custom.sh created (add your own commands here)"
fi

RUN_KEY="${KEY:-$DEFAULT_KEY}"
echo ""
if ! command -v python3 > /dev/null 2>&1; then
    echo "⚠️  python3 not found, so tasks.json and keymap.json were not changed."
    print_manual_entries
else
    echo "📝 tasks.json: Run File, Run File (debug), Run Selection, Code Runner: Doctor"
    zed_json install tasks "$TASKS_FILE"
    case $? in
        0) echo "✅ Tasks added or updated" ;;
        10) echo "✅ Tasks already up to date" ;;
        *)
            echo "⚠️  tasks.json was left unchanged."
            print_manual_entries
            ;;
    esac

    echo ""
    echo "📝 keymap.json: $RUN_KEY → Run File"
    zed_json install keymap "$KEYMAP_FILE"
    case $? in
        0) echo "✅ Keybinding added" ;;
        10)
            echo "✅ Keybinding already there, left as it is"
            echo "   (to change it: install.sh --key <key>)"
            RUN_KEY="your Run File key"
            ;;
        11)
            echo "⚠️  Your binding was kept. Pick a free key with: install.sh --key f9"
            RUN_KEY="(no key yet)"
            ;;
        *)
            echo "⚠️  keymap.json was left unchanged."
            print_manual_entries
            ;;
    esac
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Installation Complete!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "🎯 How to Use:"
echo "  • $RUN_KEY runs the current file; $RERUN_KEY runs it again from anywhere"
echo "  • Click ▶ next to main() in C, C++, Rust, Go and Python files"
echo "  • Task list ($SPAWN_KEY): Run File (debug), Run Selection,"
echo "    Code Runner: Doctor"
echo "  • Put NAME.in next to NAME.cpp (or any file) to use it as the input"
echo ""
echo "🔧 Manage:"
echo "  • Your commands:  $APP_DIR/custom.sh"
echo "  • Update:         bash \"$APP_DIR/install.sh\" --update"
echo "  • Uninstall:      bash \"$APP_DIR/install.sh\" --uninstall"
echo "  • Runtimes:       bash \"$APP_DIR/install.sh\" --doctor"
echo ""
