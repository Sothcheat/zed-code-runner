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
echo "📝 Creating runner.sh script..."
cat > "$CONFIG_DIR/runner.sh" << 'RUNNEREOF'
#!/bin/bash --norc --noprofile
set -e

# Debug: log what we receive
FILE="$1"

# Handle case where file path might be empty or malformed
if [ -z "$FILE" ]; then
    echo "Error: No file provided"
    echo "Arguments received: $@"
    exit 1
fi

STEM="${FILE%.*}"
filename_ext=$(basename "$FILE")

clear
echo "Running: $filename_ext"
echo "Full path: $FILE"
echo ""

case "$FILE" in
    *.py) 
        echo ">>> Running Python... | $filename_ext"
        echo ""
        python3 "$FILE"
        ;;
    *.js) 
        echo ">>> Running JavaScript... | $filename_ext"
        echo ""
        node "$FILE"
        ;;
    *.dart) 
        echo ">>> Running Dart... | $filename_ext"
        echo ""
        dart run "$FILE"
        ;;
    *.java) 
        echo ">>> Running Java... | $filename_ext"
        echo ""
        java "$FILE"
        ;;
    *.go) 
        echo ">>> Running Go... | $filename_ext"
        echo ""
        go run "$FILE"
        ;;
    *.rb) 
        echo ">>> Running Ruby... | $filename_ext"
        echo ""
        ruby "$FILE"
        ;;
    *.cpp|*.cc) 
        echo ">>> Compiling C++... | $filename_ext"
        echo ""
        g++ "$FILE" -o "$STEM" -Wall -Wextra -O2 -std=c++20 && "$STEM" && rm -f "$STEM"
        ;;
    *.c) 
        echo ">>> Compiling C... | $filename_ext"
        echo ""
        gcc "$FILE" -o "$STEM" -Wall -Wextra -O2 -std=c17 && "$STEM" && rm -f "$STEM"
        ;;
    *.cs) 
        echo ">>> Running C#... | $filename_ext"
        echo ""
        dotnet run
        ;;
    *.ts) 
        echo ">>> Running TypeScript... | $filename_ext"
        echo ""
        ts-node "$FILE"
        ;;
    *.php) 
        echo ">>> Running PHP... | $filename_ext"
        echo ""
        php "$FILE"
        ;;
    *) 
        echo "Unsupported file type: $FILE"
        exit 1
        ;;
esac

echo ""
echo "✅ Finished running code successfully."
RUNNEREOF

# Make the script executable
chmod +x "$CONFIG_DIR/runner.sh"
echo "✅ runner.sh created successfully"

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
