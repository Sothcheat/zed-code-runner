# Code Runner for Zed

⚡ Run code files instantly with a single keybinding - just like your workflow!

## 🚀 Quick Install

```bash
curl -fsSL https://raw.githubusercontent.com/Sothcheat/zed-code-runner/main/install.sh | bash
```

That's it! Press `Ctrl+R` (or `Cmd+R` on Mac) to run any code file.

## ✨ Features

- **One-key execution**: `Ctrl+R` / `Cmd+R` to run
- **Auto-detection**: Automatically detects file type
- **11 languages**: Python, JavaScript, Dart, Java, Go, Ruby, C++, C, C#, TypeScript, PHP
- **Smart compilation**: C/C++ compiled with `-O2` optimization and auto-cleanup
- **Fast**: Runs directly in Zed's integrated terminal
- **Clean output**: Clears screen and shows execution status

## 📋 Supported Languages

| Language   | Extension     | Command              |
| ---------- | ------------- | -------------------- |
| Python     | `.py`         | `python3`            |
| JavaScript | `.js`         | `node`               |
| Dart       | `.dart`       | `dart run`           |
| Java       | `.java`       | `java` (JIT)         |
| Go         | `.go`         | `go run`             |
| Ruby       | `.rb`         | `ruby`               |
| C++        | `.cpp`, `.cc` | `g++ -O2 -std=c++20` |
| C          | `.c`          | `gcc -O2 -std=c17`   |
| C#         | `.cs`         | `dotnet run`         |
| TypeScript | `.ts`         | `ts-node`            |
| PHP        | `.php`        | `php`                |

## 📦 Installation

### Automatic (Recommended)

```bash
curl -fsSL https://raw.githubusercontent.com/Sothcheat/zed-code-runner/main/install.sh | bash
```

### Manual (Linux/Mac/Windows)

1. **Create `~/.config/zed/tasks.json`** (or open command palette (ctrl/cmd + shift + p)  and search `zed: open tasks`):

```json
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
```

2. **Create `~/.config/zed/keymap.json`** (or open command palette (ctrl/cmd + shift + p)  and search `zed: open keymap file`):

**For Linux/Windows**:

```json
[
  {
    "context": "Editor",
    "bindings": {
      "ctrl-r": ["task::Spawn", {"task_name": "Run File"}]
    }
  }
]
```

**For Mac**:

```json
[
  {
    "context": "Editor",
    "bindings": {
      "cmd-r": ["task::Spawn", {"task_name": "Run File"}]
    }
  }
]
```

## 🎯 Usage

### Basic Usage

1. Open any supported code file in Zed
2. Press `Ctrl+R` (Linux/Windows) or `Cmd+R` (Mac)
3. Code runs in the integrated terminal

### Example

```bash
# Create a test file
echo 'print("Hello, World!")' > test.py

# Open in Zed
zed test.py

# Press Ctrl+R to run
# Output: Hello, World!
```

### More Examples

**JavaScript**:

```bash
echo 'console.log("Hello from Node!");' > test.js
zed test.js
# Press Ctrl+R
```

**C++**:

```bash
cat > test.cpp << 'EOF'
#include <iostream>
int main() {
    std::cout << "Hello from C++!" << std::endl;
    return 0;
}
EOF
zed test.cpp
# Press Ctrl+R
```

**Dart**:

```bash
echo 'void main() { print("Hello from Dart!"); }' > test.dart
zed test.dart
# Press Ctrl+R
```

## 🔧 How It Works

1. Detects file extension (e.g., `.py`, `.js`)
2. Maps to appropriate command (e.g., `python3`, `node`)
3. Runs in Zed's integrated terminal
4. For compiled languages (C/C++):
    - Compiles with optimization (`-O2`)
    - Runs the executable
    - Automatically cleans up binary

## 📝 Requirements

Install the language runtimes you need:

```bash
# Python
python3 --version

# Node.js
node --version

# Dart
dart --version

# Java
java --version

# Go
go version

# Ruby
ruby --version

# C/C++
g++ --version
gcc --version

# .NET (C#)
dotnet --version

# TypeScript
npm install -g ts-node

# PHP
php --version
```

## 🎨 Customization

### Change Keybinding

Edit `~/.config/zed/keymap.json`:

```json
{
	"context": "Editor",
	"bindings": {
		"f5": ["task::Spawn", { "task_name": "Run File" }] // Use F5 instead
	}
}
```

### Customize Commands

Edit `~/.config/zed/tasks.json` to change how languages run:

```bash
# Example: Use python instead of python3
# Change: python3 \"$FILE\"
# To:     python \"$FILE\"
```

### Add More Languages

Add more cases to the `case` statement in `tasks.json`:

```bash
*.rs) echo ">>> Running Rust... | $filename_ext\n"; cargo run;;
*.swift) echo ">>> Running Swift... | $filename_ext\n"; swift "$FILE";;
```

## 🐛 Troubleshooting

### Task doesn't appear

1. Restart Zed completely
2. Check `~/.config/zed/tasks.json` exists and is valid JSON
3. Try manually: `Cmd+Shift+P` → "task: spawn" → "Run File"

### Keybinding doesn't work

1. Check for conflicts: `Cmd+K` then `Cmd+S` in Zed
2. Verify `keymap.json` is valid JSON
3. Try a different key: `F5`, `Ctrl+Shift+R`, etc.

### Command not found

Make sure the interpreter is installed and in your PATH:

```bash
which python3
which node
# etc.
```

## 🔄 Updating

Just run the installer again:

```bash
curl -sSL https://raw.githubusercontent.com/Sothcheat/zed-code-runner/main/install.sh | bash
```

## 🗑️ Uninstalling

Remove the "Run File" task from `~/.config/zed/tasks.json` or delete the entire file:

```bash
# Remove entire file (if it only contains Run File task)
rm ~/.config/zed/tasks.json

# Or manually edit to remove just the "Run File" task
```

## ❓ Why Not a Zed Extension?

Zed's extension system doesn't allow extensions to modify user configuration files (for security reasons). This simple installer approach:

- ✅ Works immediately
- ✅ No Rust compilation needed
- ✅ Easy to update
- ✅ Fully transparent (you see exactly what's installed)

## 🤝 Contributing

Contributions welcome! Feel free to:

- Add support for more languages
- Improve error messages
- Enhance the installer script
- Fix bugs

## 📄 License

MIT License - see [LICENSE](LICENSE) file

## 🙏 Acknowledgments

Inspired by your original `zed-runner.sh` script and VS Code's Code Runner extension.

## 📧 Support

- **Issues**: [GitHub Issues](https://github.com/Sothcheat/zed-code-runner/issues)
- **Discussions**: [GitHub Discussions](https://github.com/Sothcheat/zed-code-runner/discussions)

---

**Made with ❤️ for Zed users who want a simple, fast code runner**
