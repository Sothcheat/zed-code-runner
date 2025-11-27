#!/bin/bash

set -e

echo "🚀 Code Runner for Zed - Installer"
echo "===================================="
echo ""

# Detect OS
OS="unknown"
if [[ "$OSTYPE" == "darwin"* ]]; then
    OS="mac"
    CONFIG_DIR="$HOME/.config/zed"
    SED_CMD="sed -i ''"
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    OS="linux"
    CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/zed"
    SED_CMD="sed -i"
else
    echo "❌ Unsupported OS: $OSTYPE"
    exit 1
fi

echo "📍 Detected OS: $OS"
echo "📁 Config directory: $CONFIG_DIR"
echo ""

# Create config directory
mkdir -p "$CONFIG_DIR"

# Install tasks.json
TASKS_FILE="$CONFIG_DIR/tasks.json"

echo "📝 Installing task configuration..."

if [ -f "$TASKS_FILE" ]; then
    echo "⚠️  tasks.json already exists"

    # Check if our task already exists
    if grep -q '"label": "Run File"' "$TASKS_FILE" 2>/dev/null; then
        echo "✅ 'Run File' task already configured. Skipping..."
    else
        echo "📝 Backing up existing tasks.json..."
        cp "$TASKS_FILE" "${TASKS_FILE}.backup.$(date +%s)"

        echo "📝 Adding 'Run File' task to existing configuration..."

        # Read existing content
        EXISTING_CONTENT=$(cat "$TASKS_FILE")

        # Check if it's valid JSON array
        if echo "$EXISTING_CONTENT" | jq empty 2>/dev/null; then
            # Valid JSON - append our task
            echo "$EXISTING_CONTENT" | jq '. += [{
              "label": "Run File",
              "command": "bash",
              "args": [
                "-c",
                "FILE=\"$ZED_FILE\"; STEM=\"$ZED_STEM\"; set -e; clear; case \"$FILE\" in *.py) echo \">>> Running Python...\"; python3 \"$FILE\";; *.js) echo \">>> Running JavaScript (Node)...\"; node \"$FILE\";; *.dart) echo \">>> Running Dart...\"; dart run \"$FILE\";; *.java) echo \">>> Running Java (JIT compilation)...\"; java \"$FILE\";; *.go) echo \">>> Running Go...\"; go run \"$FILE\";; *.rb) echo \">>> Running Ruby...\"; ruby \"$FILE\";; *.cpp|*.cc) echo \">>> Compiling C++ (O2 Optimization)...\"; g++ \"$FILE\" -o \"$STEM\" -Wall -Wextra -O2 -std=c++20 && echo \">>> Running C++ executable...\" && ./\"$STEM\" && rm -f \"$STEM\";; *.c) echo \">>> Compiling C (O2 Optimization)...\"; gcc \"$FILE\" -o \"$STEM\" -Wall -Wextra -O2 -std=c17 && echo \">>> Running C executable...\" && ./\"$STEM\" && rm -f \"$STEM\";; *.cs) echo \">>> Running C# (.NET)...\"; dotnet run;; *.ts) echo \">>> Running TypeScript (ts-node)...\"; ts-node \"$FILE\";; *.php) echo \">>> Running PHP...\"; php \"$FILE\";; *) echo \"Unsupported file type\"; exit 1;; esac && echo \"\" && echo \"✅ Finished running code successfully.\""
              ],
              "use_new_terminal": false,
              "allow_concurrent_runs": true,
              "reveal": "always",
              "tags": ["code-runner-run"]
            }]' > "$TASKS_FILE.tmp"
            mv "$TASKS_FILE.tmp" "$TASKS_FILE"
            echo "✅ Task added successfully"
        else
            echo "⚠️  Existing tasks.json is not valid JSON array"
            echo "❌ Please manually add the task (see README.md)"
        fi
    fi
else
    # Create new tasks.json
    cat > "$TASKS_FILE" << 'EOF'
[
  {
    "label": "Run File",
    "command": "bash",
    "args": [
      "-c",
      "FILE=\"$ZED_FILE\"; STEM=\"$ZED_STEM\"; set -e; clear; case \"$FILE\" in *.py) echo \">>> Running Python...\"; python3 \"$FILE\";; *.js) echo \">>> Running JavaScript (Node)...\"; node \"$FILE\";; *.dart) echo \">>> Running Dart...\"; dart run \"$FILE\";; *.java) echo \">>> Running Java (JIT compilation)...\"; java \"$FILE\";; *.go) echo \">>> Running Go...\"; go run \"$FILE\";; *.rb) echo \">>> Running Ruby...\"; ruby \"$FILE\";; *.cpp|*.cc) echo \">>> Compiling C++ (O2 Optimization)...\"; g++ \"$FILE\" -o \"$STEM\" -Wall -Wextra -O2 -std=c++20 && echo \">>> Running C++ executable...\" && ./\"$STEM\" && rm -f \"$STEM\";; *.c) echo \">>> Compiling C (O2 Optimization)...\"; gcc \"$FILE\" -o \"$STEM\" -Wall -Wextra -O2 -std=c17 && echo \">>> Running C executable...\" && ./\"$STEM\" && rm -f \"$STEM\";; *.cs) echo \">>> Running C# (.NET)...\"; dotnet run;; *.ts) echo \">>> Running TypeScript (ts-node)...\"; ts-node \"$FILE\";; *.php) echo \">>> Running PHP...\"; php \"$FILE\";; *) echo \"Unsupported file type\"; exit 1;; esac && echo \"\" && echo \"✅ Finished running code successfully.\""
    ],
    "use_new_terminal": false,
    "allow_concurrent_runs": true,
    "reveal": "always",
    "tags": ["code-runner-run"]
  }
]
EOF
    echo "✅ Created new tasks.json"
fi

# Install keybinding
echo ""
echo "⌨️  Installing keybinding..."

KEYMAP_FILE="$CONFIG_DIR/keymap.json"
DEFAULT_KEY="ctrl-r"
if [ "$OS" = "mac" ]; then
    DEFAULT_KEY="cmd-r"
fi

if [ -f "$KEYMAP_FILE" ]; then
    # Check if keybinding already exists
    if grep -q '"Run File"' "$KEYMAP_FILE" 2>/dev/null || grep -q 'task::Spawn.*Run File' "$KEYMAP_FILE" 2>/dev/null; then
        echo "✅ Keybinding already configured"
    else
        echo "⚠️  keymap.json exists but keybinding not found"
        echo ""
        echo "📝 Please add this to your $KEYMAP_FILE manually:"
        echo ""
        if [ "$OS" = "mac" ]; then
            echo '  {"context": "Editor", "bindings": {"cmd-r": ["task::Spawn", {"task_name": "Run File"}]}}'
        else
            echo '  {"context": "Editor", "bindings": {"ctrl-r": ["task::Spawn", {"task_name": "Run File"}]}}'
        fi
        echo ""
    fi
else
    # Create new keymap.json
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
    echo "✅ Created keymap.json with $DEFAULT_KEY binding"
fi

echo ""
echo "✅ Installation Complete!"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "🎯 How to Use:"
echo "  1. Open any code file in Zed"
echo "  2. Press $DEFAULT_KEY to run"
echo "  3. Output appears in terminal"
echo ""
echo "📚 Supported Languages:"
echo "  • Python (.py)         → python3"
echo "  • JavaScript (.js)     → node"
echo "  • Dart (.dart)         → dart run"
echo "  • Java (.java)         → java"
echo "  • Go (.go)             → go run"
echo "  • Ruby (.rb)           → ruby"
echo "  • C++ (.cpp, .cc)      → g++ with -O2"
echo "  • C (.c)               → gcc with -O2"
echo "  • C# (.cs)             → dotnet run"
echo "  • TypeScript (.ts)     → ts-node"
echo "  • PHP (.php)           → php"
echo ""
echo "🧪 Test It:"
echo "  echo 'print(\"Hello!\")' > test.py"
echo "  zed test.py"
echo "  # Press $DEFAULT_KEY"
echo ""
echo "🔧 Uninstall:"
echo "  Remove the 'Run File' task from:"
echo "  $TASKS_FILE"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
