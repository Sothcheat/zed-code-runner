# Code Runner for Zed

⚡ Run the file you're editing with a single keybinding, like VS Code's Code Runner.

## 🚀 Quick Install

```bash
curl -fsSL https://raw.githubusercontent.com/Sothcheat/zed-code-runner/main/install.sh | bash
```

That's it! Press `Ctrl+R` (or `Cmd+R` on Mac) to run any code file.

## ✨ Features

- **One-key execution**: `Ctrl+R` / `Cmd+R` to run
- **Auto-detection**: picks the command from the file extension
- **17 languages**: Python, JavaScript, TypeScript, Dart, Java, Go, Ruby, C++, C, C#, PHP, Shell, Perl, Lua, R, Swift, Rust
- **Smart compilation**: C, C++ and Rust are compiled with warnings on into a temporary folder that is always cleaned up, so nothing appears next to your source
- **Clear results**: shows ✅ on success or ❌ with the exit code on failure
- **Your own commands**: add or override languages in `runner.custom.sh`, which updates never touch
- **Safe install**: adds one task and one keybinding to your existing Zed config and keeps everything else

## 📋 Supported Languages

| Language   | Extension               | Command                                     |
| ---------- | ----------------------- | ------------------------------------------- |
| Python     | `.py`                   | `python3`                                   |
| JavaScript | `.js`                   | `node`                                      |
| TypeScript | `.ts`                   | `ts-node`                                   |
| Dart       | `.dart`                 | `dart run`                                  |
| Java       | `.java`                 | `java` (single-file source launcher, JDK 11+) |
| Go         | `.go`                   | `go run`                                    |
| Ruby       | `.rb`                   | `ruby`                                      |
| C++        | `.cpp`, `.cc`, `.cxx`   | `g++ -Wall -Wextra -O2 -std=c++20`          |
| C          | `.c`                    | `gcc -Wall -Wextra -O2 -std=c17`            |
| C#         | `.cs`                   | `dotnet run --project` inside a project, else `dotnet run file.cs` (.NET 10+) |
| PHP        | `.php`                  | `php`                                       |
| Shell      | `.sh`                   | `bash`                                      |
| Perl       | `.pl`                   | `perl`                                      |
| Lua        | `.lua`                  | `lua`                                       |
| R          | `.r`, `.R`              | `Rscript`                                   |
| Swift      | `.swift`                | `swift`                                     |
| Rust       | `.rs`                   | `rustc`                                     |

## 📦 Installation

Linux and macOS. The installer needs `python3`.

### Automatic (Recommended)

```bash
curl -fsSL https://raw.githubusercontent.com/Sothcheat/zed-code-runner/main/install.sh | bash
```

### Read it first

```bash
curl -fsSLO https://raw.githubusercontent.com/Sothcheat/zed-code-runner/main/install.sh
less install.sh
bash install.sh
```

### What the installer changes

In `~/.config/zed/` (or `$XDG_CONFIG_HOME/zed/` on Linux) it:

- writes `runner.sh` (picks and runs the command) and `run_code.py` (starts it from the Zed task); both are replaced on every update
- creates `runner.custom.sh` for your own commands, only if it doesn't exist yet
- adds a "Run File" task to `tasks.json` and a `ctrl-r` / `cmd-r` binding to `keymap.json`, keeping your existing entries and comments; a backup (`*.backup.<timestamp>`) is saved before either file is changed

Running it again is safe: entries that are already there are left alone.

If `ctrl-r` / `cmd-r` is already bound in your keymap, the installer keeps your binding and prints the entry to add with another key. If it can't read one of the files (for example, invalid JSON), it leaves the file alone and prints the entry to add yourself. The entries look like this:

`tasks.json` (command palette → `zed: open tasks`):

```json
{
  "label": "Run File",
  "command": "python3 \"/home/you/.config/zed/run_code.py\" \"$ZED_FILE\"",
  "use_new_terminal": false,
  "allow_concurrent_runs": true,
  "reveal": "always",
  "tags": ["code-runner-run"]
}
```

`keymap.json` (command palette → `zed: open keymap file`):

```json
{
  "context": "Editor",
  "bindings": {
    "ctrl-r": ["task::Spawn", { "task_name": "Run File" }]
  }
}
```

## 🎯 Usage

1. Open any supported code file in Zed
2. Press `Ctrl+R` (Linux) or `Cmd+R` (Mac)
3. The code runs in the integrated terminal, where you can also type input

### Example

```bash
echo 'print("Hello, World!")' > test.py
zed test.py
# Press Ctrl+R → Hello, World!
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

## 🔧 How It Works

1. Zed's "Run File" task passes the current file to `run_code.py`, which starts `runner.sh`
2. `runner.sh` first checks your `runner.custom.sh`, then the built-in languages, matching on the file extension
3. Compiled languages (C, C++, Rust) are built into a temporary folder, run from there, and the folder is removed afterwards, even when the program fails or you press `Ctrl+C`
4. The result line shows ✅ or ❌ with the exit code, and the task exits with the program's exit code

## 📝 Requirements

`python3` for the runner itself, plus the runtime for each language you use:

```bash
python3 --version   # Python (and the runner)
node --version      # JavaScript
npm install -g ts-node   # TypeScript
dart --version      # Dart
java --version      # Java 11+
go version          # Go
ruby --version      # Ruby
g++ --version       # C++
gcc --version       # C
dotnet --version    # C# (.NET 10+ for single files without a project)
php --version       # PHP
rustc --version     # Rust
```

A missing runtime is reported with a hint on how to install it.

## 🎨 Customization

### Your own commands

Edit `~/.config/zed/runner.custom.sh`. It's read before the built-in languages, so you can add new ones or change existing ones, and updates never overwrite it:

```bash
case "$FILE" in
    *.py)  run python "$FILE" ;;                       # change a built-in
    *.zig) run zig run "$FILE" ;;                      # add a language
    *.c)   build_and_run clang "$FILE" -o "$BIN" -O2 ;; # compile to $BIN, then run it
    *) ;;
esac
```

Available helpers: `run CMD...`, `build_and_run CMD...` (the compiler must write `"$BIN"`), `need CMD "install hint"` and `say "text"`. Available variables: `$FILE` (absolute path), `$DIR`, `$FILENAME`, `$STEM` and `$BIN`.

### Change the keybinding

In `~/.config/zed/keymap.json`, change the key in the "Run File" entry:

```json
{
  "context": "Editor",
  "bindings": {
    "f5": ["task::Spawn", { "task_name": "Run File" }]
  }
}
```

## 🐛 Troubleshooting

### The key does nothing

1. Run it from the command palette: `Ctrl/Cmd+Shift+P` → "task: spawn" → "Run File". If that works, the keybinding is the problem; otherwise, the task is.
2. Check `~/.config/zed/tasks.json` and `keymap.json` for invalid JSON
3. Look for conflicts in the keymap editor (`Ctrl+K Ctrl+S`, or `Cmd+K Cmd+S` on Mac), or try another key such as `F5`
4. Restart Zed once

### Command not found

Make sure the runtime is installed and on your `PATH`:

```bash
which python3
which node
```

### Test without Zed

```bash
python3 ~/.config/zed/run_code.py test.py
```

## 🔄 Updating

Run the installer again. Your `runner.custom.sh` and your other tasks and keybindings are kept.

```bash
curl -fsSL https://raw.githubusercontent.com/Sothcheat/zed-code-runner/main/install.sh | bash
```

## 🗑️ Uninstalling

```bash
rm ~/.config/zed/runner.sh ~/.config/zed/run_code.py ~/.config/zed/runner.custom.sh
```

Then remove the "Run File" entry from `~/.config/zed/tasks.json` and the `ctrl-r` / `cmd-r` "Run File" binding from `~/.config/zed/keymap.json`. Leave the rest of both files as they are.

## ❓ Why Not a Zed Extension?

Zed extensions can't change your user configuration (tasks and keybindings), so a small installer does it instead:

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

Inspired by VS Code's [Code Runner](https://marketplace.visualstudio.com/items?itemName=formulahendry.code-runner) extension.

## 📧 Support

- **Issues**: [GitHub Issues](https://github.com/Sothcheat/zed-code-runner/issues)

---

**Made with ❤️ for Zed users who want a simple, fast code runner**
