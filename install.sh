#!/bin/bash

echo "🚀 Code Runner for Zed - Simple Installer"
echo "=========================================="
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
    exit 1
fi

echo "📍 OS: $OS"
echo "📁 Config: $CONFIG_DIR"
echo ""

# Create config directory
mkdir -p "$CONFIG_DIR"

# Backup existing files
TASKS_FILE="$CONFIG_DIR/tasks.json"
KEYMAP_FILE="$CONFIG_DIR/keymap.json"

if [ -f "$TASKS_FILE" ]; then
    BACKUP="${TASKS_FILE}.backup.$(date +%Y%m%d_%H%M%S)"
    echo "📦 Backing up existing tasks.json to:"
    echo "   $BACKUP"
    cp "$TASKS_FILE" "$BACKUP"
fi

if [ -f "$KEYMAP_FILE" ]; then
    BACKUP="${KEYMAP_FILE}.backup.$(date +%Y%m%d_%H%M%S)"
    echo "📦 Backing up existing keymap.json to:"
    echo "   $BACKUP"
    cp "$KEYMAP_FILE" "$BACKUP"
fi

echo ""
echo "📝 Creating tasks.json..."

# Create tasks.json - this will REPLACE any existing file
cat > "$TASKS_FILE" << 'EOF'
[
  {
    "label": "Run File",
    "command": "$HOME/.config/zed/runner.sh",
    "args": ["$ZED_FILE"],
    "use_new_terminal": false,
    "allow_concurrent_runs": true,
    "reveal": "always",
    "tags": ["code-runner-run"]
  }
]
EOF

# Verify tasks.json was created
if [ -f "$TASKS_FILE" ] && [ -s "$TASKS_FILE" ]; then
    echo "✅ tasks.json created successfully"
    echo "   Size: $(wc -c < "$TASKS_FILE") bytes"
else
    echo "❌ Failed to create tasks.json"
    exit 1
fi

echo ""
echo "📝 Create runner.sh script.."
cat > $CONFIG_DIR/runner.sh << 'EOF'
#!/usr/bin/env bash
set -e

eel() { echo -e "$@"; }
ee() { echo ""; }

FILE="$1"
STEM="${FILE%.*}"
filename_ext=$(basename "$FILE")

clear
[ -z "$FILE" ] && echo "Error: No file" && exit 1

case "$FILE" in
    *.py) eel -e ">>> Running Python... | $filename_ext\n"; python3 "$FILE";;
    *.js) eel ">>> Running JavaScript... | $filename_ext\n"; node "$FILE";;
    *.dart) eel ">>> Running Dart... | $filename_ext\n"; dart run "$FILE";;
    *.java) eel ">>> Running Java... | $filename_ext\n"; java "$FILE";;
    *.go) eel ">>> Running Go... | $filename_ext\n"; go run "$FILE";;
    *.rb) eel ">>> Running Ruby... | $filename_ext\n"; ruby "$FILE";;
    *.cpp|*.cc) eel ">>> Compiling C++... | $filename_ext\n"; g++ "$FILE" -o "$STEM" -Wall -Wextra -O2 -std=c++20 && "$STEM" && rm -f "$STEM";;
    *.c) eel ">>> Compiling C... | $filename_ext\n"; gcc "$FILE" -o "$STEM" -Wall -Wextra -O2 -std=c17 && "$STEM" && rm -f "$STEM";;
    *.cs) eel ">>> Running C#... | $filename_ext\n"; dotnet run;;
    *.ts) eel ">>> Running TypeScript... | $filename_ext\n"; ts-node "$FILE";;
    *.php) eel ">>> Running PHP... | $filename_ext\n"; php "$FILE";;
    *) eel "Unsupported: $FILE"; exit 1;;
esac

ee
eel "✅ Finished running code successfully."
EOF

# Make the script executable
chmod +x ~/.config/zed/runner.sh

echo ""
echo "📝 Creating keymap.json..."

# Create keymap.json - this will REPLACE any existing file
if [ "$OS" = "mac" ]; then
    cat > "$KEYMAP_FILE" << 'EOF'
[
  {
    "context": "Editor",
    "bindings": {
      "cmd-r": ["task::Spawn", {"task_name": "Run File"}]
    }
  }
]
EOF
else
    cat > "$KEYMAP_FILE" << 'EOF'
[
  {
    "context": "Editor",
    "bindings": {
      "ctrl-r": ["task::Spawn", {"task_name": "Run File"}]
    }
  }
]
EOF
fi

# Verify keymap.json was created
if [ -f "$KEYMAP_FILE" ] && [ -s "$KEYMAP_FILE" ]; then
    echo "✅ keymap.json created successfully"
    echo "   Size: $(wc -c < "$KEYMAP_FILE") bytes"
else
    echo "❌ Failed to create keymap.json"
    exit 1
fi

echo ""
echo "🔍 Verifying installation..."
echo ""

# Show what was created
echo "📄 tasks.json content:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
cat "$TASKS_FILE"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

echo "📄 keymap.json content:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
cat "$KEYMAP_FILE"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

echo "✅ Installation Complete!"
echo ""
echo "⚠️  IMPORTANT: You MUST restart Zed completely!"
echo ""
echo "🎯 How to Use:"
echo "  1. Close Zed completely"
echo "  2. Reopen Zed"
echo "  3. Open any code file (test.py, test.js, etc.)"
echo "  4. Press $KEY_BINDING"
echo "  5. Code runs in the terminal!"
echo ""
echo "🧪 Quick Test:"
echo "  echo 'print(\"Hello, World!\")' > test.py"
echo "  zed test.py"
echo "  # Press $KEY_BINDING"
echo ""
echo "📚 Supported: Python, JavaScript, Dart, Java, Go, Ruby, C++, C, C#, TypeScript, PHP"
echo ""
echo "🔧 Troubleshooting:"
echo "  • If nothing happens: Make sure you restarted Zed"
echo "  • Check files exist: ls -la $CONFIG_DIR"
echo "  • Manual test: Open Zed → Ctrl/Cmd+Shift+P → 'task: spawn' → 'Run File'"
echo ""
echo "📦 Your old configs were backed up with .backup.* extension"
echo ""
