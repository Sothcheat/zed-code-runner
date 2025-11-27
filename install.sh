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
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    OS="linux"
    CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/zed"
else
    echo "❌ Unsupported OS: $OSTYPE"
    exit 1
fi

echo "📍 Detected OS: $OS"
echo "📁 Config directory: $CONFIG_DIR"
echo ""

# Create config directory
mkdir -p "$CONFIG_DIR"

# The task JSON content
TASK_CONTENT='  {
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
  }'

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
        
        # Check if jq is available for proper JSON manipulation
        if command -v jq &> /dev/null; then
            # Use jq for safe JSON manipulation
            TEMP_FILE=$(mktemp)
            jq --argjson task "{\"label\":\"Run File\",\"command\":\"bash\",\"args\":[\"-c\",\"FILE=\\\"\$ZED_FILE\\\"; STEM=\\\"\$ZED_STEM\\\"; set -e; clear; case \\\"\$FILE\\\" in *.py) echo \\\">>> Running Python...\\\"; python3 \\\"\$FILE\\\";; *.js) echo \\\">>> Running JavaScript (Node)...\\\"; node \\\"\$FILE\\\";; *.dart) echo \\\">>> Running Dart...\\\"; dart run \\\"\$FILE\\\";; *.java) echo \\\">>> Running Java (JIT compilation)...\\\"; java \\\"\$FILE\\\";; *.go) echo \\\">>> Running Go...\\\"; go run \\\"\$FILE\\\";; *.rb) echo \\\">>> Running Ruby...\\\"; ruby \\\"\$FILE\\\";; *.cpp|*.cc) echo \\\">>> Compiling C++ (O2 Optimization)...\\\"; g++ \\\"\$FILE\\\" -o \\\"\$STEM\\\" -Wall -Wextra -O2 -std=c++20 && echo \\\">>> Running C++ executable...\\\" && ./\\\"\$STEM\\\" && rm -f \\\"\$STEM\\\";; *.c) echo \\\">>> Compiling C (O2 Optimization)...\\\"; gcc \\\"\$FILE\\\" -o \\\"\$STEM\\\" -Wall -Wextra -O2 -std=c17 && echo \\\">>> Running C executable...\\\" && ./\\\"\$STEM\\\" && rm -f \\\"\$STEM\\\";; *.cs) echo \\\">>> Running C# (.NET)...\\\"; dotnet run;; *.ts) echo \\\">>> Running TypeScript (ts-node)...\\\"; ts-node \\\"\$FILE\\\";; *.php) echo \\\">>> Running PHP...\\\"; php \\\"\$FILE\\\";; *) echo \\\"Unsupported file type\\\"; exit 1;; esac && echo \\\"\\\" && echo \\\"✅ Finished running code successfully.\\\"\"],\"use_new_terminal\":false,\"allow_concurrent_runs\":true,\"reveal\":\"always\",\"tags\":[\"code-runner-run\"]}" '. += [$task]' "$TASKS_FILE" > "$TEMP_FILE"
            
            if [ $? -eq 0 ]; then
                mv "$TEMP_FILE" "$TASKS_FILE"
                echo "✅ Task added successfully using jq"
            else
                rm -f "$TEMP_FILE"
                echo "❌ Failed to add task with jq. Trying manual method..."
                # Fall through to manual method below
            fi
        else
            # Manual JSON manipulation (without jq)
            echo "ℹ️  jq not found, using manual JSON manipulation"
            
            # Read the file, remove the closing bracket, add our task, add closing bracket
            TEMP_FILE=$(mktemp)
            
            # Remove last line (closing bracket) and trailing comma if exists
            head -n -1 "$TASKS_FILE" > "$TEMP_FILE"
            
            # Check if we need to add a comma
            if tail -n 2 "$TEMP_FILE" | head -n 1 | grep -q '}'; then
                echo "," >> "$TEMP_FILE"
            fi
            
            # Add our task
            echo "$TASK_CONTENT" >> "$TEMP_FILE"
            
            # Close the array
            echo "]" >> "$TEMP_FILE"
            
            # Replace original file
            mv "$TEMP_FILE" "$TASKS_FILE"
            echo "✅ Task added successfully"
        fi
    fi
else
    # Create new tasks.json from scratch
    echo "📝 Creating new tasks.json..."
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
    
    if [ -f "$TASKS_FILE" ] && [ -s "$TASKS_FILE" ]; then
        echo "✅ Created new tasks.json successfully"
    else
        echo "❌ Failed to create tasks.json"
        exit 1
    fi
fi

# Verify the tasks.json was created/updated properly
echo ""
echo "🔍 Verifying tasks.json..."
if [ -f "$TASKS_FILE" ] && [ -s "$TASKS_FILE" ]; then
    if grep -q '"label": "Run File"' "$TASKS_FILE"; then
        echo "✅ Verification passed: 'Run File' task found"
    else
        echo "❌ Verification failed: 'Run File' task not found"
        echo "📄 Please check: $TASKS_FILE"
        exit 1
    fi
else
    echo "❌ Verification failed: tasks.json is empty or missing"
    exit 1
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
    echo "📝 Creating new keymap.json..."
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
        echo "✅ Created keymap.json with $DEFAULT_KEY binding"
    else
        echo "❌ Failed to create keymap.json"
    fi
fi

echo ""
echo "✅ Installation Complete!"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📄 Files created/updated:"
echo "  • $TASKS_FILE"
echo "  • $KEYMAP_FILE"
echo ""
echo "🎯 How to Use:"
echo "  1. Restart Zed (important!)"
echo "  2. Open any code file"
echo "  3. Press $DEFAULT_KEY to run"
echo "  4. Output appears in terminal"
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
echo "🔧 If it doesn't work:"
echo "  1. Make sure Zed is completely restarted"
echo "  2. Check that tasks.json exists: cat $TASKS_FILE"
echo "  3. Try spawning manually: Cmd+Shift+P → 'task: spawn' → 'Run File'"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
