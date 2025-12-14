#!/bin/bash

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

echo "📍 OS: $OS"
echo "📁 Config: $CONFIG_DIR"
echo ""

# Create config directory
mkdir -p "$CONFIG_DIR"

# Backup existing files
TASKS_FILE="$CONFIG_DIR/tasks.json"
KEYMAP_FILE="$CONFIG_DIR/keymap.json"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

if [ -f "$TASKS_FILE" ]; then
    BACKUP="${TASKS_FILE}.backup.${TIMESTAMP}"
    echo "📦 Backing up existing tasks.json to:"
    echo "   $BACKUP"
    cp "$TASKS_FILE" "$BACKUP"
fi

if [ -f "$KEYMAP_FILE" ]; then
    BACKUP="${KEYMAP_FILE}.backup.${TIMESTAMP}"
    echo "📦 Backing up existing keymap.json to:"
    echo "   $BACKUP"
    cp "$KEYMAP_FILE" "$BACKUP"
fi

echo ""
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
    
    runner_script = os.path.expanduser("~/.config/zed/runner.sh")
    
    # Check if runner script exists
    if not os.path.exists(runner_script):
        print(f"Error: Runner script not found: {runner_script}")
        print("Please reinstall using install.sh")
        sys.exit(1)
    
    # Run bash with --norc and --noprofile to avoid loading .bashrc
    # This prevents conflicts with custom bash configurations (like Omarchy)
    # File path is passed as a list element, so it's automatically properly escaped
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
echo "✅ run_code.py created successfully"

echo ""
echo "📝 Creating runner.sh script..."
cat > "$CONFIG_DIR/runner.sh" << 'RUNNEREOF'
#!/bin/bash
set -e

FILE="$1"

# Validate input
if [ -z "$FILE" ]; then
    echo "❌ Error: No file provided"
    echo "Arguments received: $@"
    exit 1
fi

if [ ! -f "$FILE" ]; then
    echo "❌ Error: File not found: $FILE"
    exit 1
fi

STEM="${FILE%.*}"
filename_ext=$(basename "$FILE")

clear
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🚀 Running: $filename_ext"
echo "📁 Path: $FILE"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

case "$FILE" in
    *.py) 
        echo ">>> Running Python..."
        echo ""
        python3 "$FILE"
        ;;
    *.js) 
        echo ">>> Running JavaScript (Node.js)..."
        echo ""
        node "$FILE"
        ;;
    *.ts) 
        echo ">>> Running TypeScript..."
        echo ""
        if ! command -v ts-node &> /dev/null; then
            echo "❌ ts-node not found. Install it with: npm install -g ts-node"
            exit 1
        fi
        ts-node "$FILE"
        ;;
    *.dart) 
        echo ">>> Running Dart..."
        echo ""
        if ! command -v dart &> /dev/null; then
            echo "❌ dart not found. Please install Dart SDK."
            exit 1
        fi
        dart run "$FILE"
        ;;
    *.java) 
        echo ">>> Running Java..."
        echo ""
        java "$FILE"
        ;;
    *.go) 
        echo ">>> Running Go..."
        echo ""
        go run "$FILE"
        ;;
    *.rb) 
        echo ">>> Running Ruby..."
        echo ""
        ruby "$FILE"
        ;;
    *.cpp|*.cc|*.cxx) 
        echo ">>> Compiling and running C++..."
        echo ""
        g++ "$FILE" -o "$STEM" -Wall -Wextra -O2 -std=c++20 && "$STEM"
        EXIT_CODE=$?
        rm -f "$STEM"
        exit $EXIT_CODE
        ;;
    *.c) 
        echo ">>> Compiling and running C..."
        echo ""
        gcc "$FILE" -o "$STEM" -Wall -Wextra -O2 -std=c17 && "$STEM"
        EXIT_CODE=$?
        rm -f "$STEM"
        exit $EXIT_CODE
        ;;
    *.cs) 
        echo ">>> Running C#..."
        echo ""
        dotnet run
        ;;
    *.php) 
        echo ">>> Running PHP..."
        echo ""
        php "$FILE"
        ;;
    *.sh) 
        echo ">>> Running Shell Script..."
        echo ""
        bash "$FILE"
        ;;
    *.pl) 
        echo ">>> Running Perl..."
        echo ""
        perl "$FILE"
        ;;
    *.lua) 
        echo ">>> Running Lua..."
        echo ""
        lua "$FILE"
        ;;
    *.r|*.R) 
        echo ">>> Running R..."
        echo ""
        Rscript "$FILE"
        ;;
    *.swift) 
        echo ">>> Running Swift..."
        echo ""
        swift "$FILE"
        ;;
    *.rs) 
        echo ">>> Compiling and running Rust..."
        echo ""
        rustc "$FILE" -o "$STEM" && "$STEM"
        EXIT_CODE=$?
        rm -f "$STEM"
        exit $EXIT_CODE
        ;;
    *) 
        echo "❌ Unsupported file type: $filename_ext"
        echo ""
        echo "Supported languages:"
        echo "  • Python (.py)"
        echo "  • JavaScript (.js)"
        echo "  • TypeScript (.ts)"
        echo "  • Java (.java)"
        echo "  • Go (.go)"
        echo "  • Ruby (.rb)"
        echo "  • C++ (.cpp, .cc, .cxx)"
        echo "  • C (.c)"
        echo "  • C# (.cs)"
        echo "  • PHP (.php)"
        echo "  • Dart (.dart)"
        echo "  • Shell (.sh)"
        echo "  • Perl (.pl)"
        echo "  • Lua (.lua)"
        echo "  • R (.r, .R)"
        echo "  • Swift (.swift)"
        echo "  • Rust (.rs)"
        exit 1
        ;;
esac

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Finished successfully"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
RUNNEREOF

chmod +x "$CONFIG_DIR/runner.sh"
echo "✅ runner.sh created successfully"

echo ""
echo "📝 Creating tasks.json..."

# Create tasks.json with proper quoting for paths with special characters
cat > "$TASKS_FILE" << 'EOF'
[
  {
    "label": "Run File",
    "command": "python3 $HOME/.config/zed/run_code.py \"$ZED_FILE\"",
    "use_new_terminal": false,
    "allow_concurrent_runs": true,
    "reveal": "always",
    "tags": ["code-runner-run"]
  }
]
EOF

if [ -f "$TASKS_FILE" ] && [ -s "$TASKS_FILE" ]; then
    echo "✅ tasks.json created successfully"
else
    echo "❌ Failed to create tasks.json"
    exit 1
fi

echo ""
echo "📝 Creating keymap.json..."

# Create keymap.json based on OS
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

if [ -f "$KEYMAP_FILE" ] && [ -s "$KEYMAP_FILE" ]; then
    echo "✅ keymap.json created successfully"
else
    echo "❌ Failed to create keymap.json"
    exit 1
fi

echo ""
echo "🔍 Verifying installation..."
echo ""

# Check Python is available
if ! command -v python3 &> /dev/null; then
    echo "⚠️  Warning: python3 not found. This is required for the runner."
fi

# List created files
echo "📄 Created files:"
echo "  • $CONFIG_DIR/run_code.py"
echo "  • $CONFIG_DIR/runner.sh"
echo "  • $CONFIG_DIR/tasks.json"
echo "  • $CONFIG_DIR/keymap.json"
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Installation Complete!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "⚠️  IMPORTANT: Restart Zed completely for changes to take effect!"
echo ""
echo "🎯 How to Use:"
echo "  1. Close Zed completely (Cmd/Ctrl+Q)"
echo "  2. Reopen Zed"
echo "  3. Open any supported code file"
echo "  4. Press $KEY_BINDING to run the file"
echo ""
echo "🧪 Quick Test:"
echo "  echo 'print(\"Hello, World!\")' > test.py"
echo "  zed test.py"
echo "  # Press $KEY_BINDING"
echo ""
echo "✨ Features:"
echo "  • Works with paths containing spaces and special characters"
echo "  • Bypasses custom bash configurations (like Omarchy)"
echo "  • Supports 18+ programming languages"
echo "  • Automatic compilation for C/C++/Rust"
echo "  • Helpful error messages"
echo ""
echo "🔧 Troubleshooting:"
echo "  • Nothing happens? Make sure you restarted Zed"
echo "  • Manual test: Cmd/Ctrl+Shift+P → 'task: spawn' → 'Run File'"
echo "  • Check logs in Zed's terminal panel"
echo "  • Test directly: python3 ~/.config/zed/run_code.py test.py"
echo ""
echo "📦 Backups: Old configs saved with .backup.$TIMESTAMP extension"
echo ""
