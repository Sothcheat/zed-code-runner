# Code Runner for Zed

⚡ Run the file you're editing with one key, like VS Code's Code Runner.

```bash
curl -fsSL https://raw.githubusercontent.com/Sothcheat/zed-code-runner/main/install.sh | bash
```

Then press `Ctrl+R` (`Cmd+R` on Mac) in any code file.

## ✨ Features

- **One key to run**: `Ctrl+R` / `Cmd+R` runs the current file; Zed's Rerun key (`Ctrl+Shift+R` / `Cmd+Alt+R`) runs it again from any file
- **▶ next to `main()`**: click the run button Zed shows next to `main()` in C, C++, Rust and Go, and next to `if __name__ == "__main__":` in Python
- **20 languages**: Python, JavaScript, TypeScript, Dart, Java, Kotlin, Go, Ruby, C, C++, C#, PHP, Shell, Perl, Lua, R, Swift, Rust and Zig
- **Knows your project**: uses the project's `.venv` or uv for Python, `cargo run` in a Cargo crate, `go run .` in a Go module, and `dotnet run --project` for C# projects
- **Input files**: put `calculator.in` next to `calculator.cpp` and it's used as the program's input, so you don't retype test input on every run
- **Clear results**: a warning count after compiling, then ✅ with the run time, or ❌ with the exit code
- **Debug builds**: Run File (debug) compiles C and C++ with sanitizers that catch out-of-bounds access, use-after-free and undefined behaviour
- **Run Selection**: run just the selected lines (Python, JavaScript, TypeScript, Ruby, Perl, Lua, Shell, PHP, R)
- **Your own commands**: add or change languages in `custom.sh`, which updates never touch
- **Clean**: compiled programs are built in a temporary folder and removed afterwards; programs run from their own folder, so relative paths like `data.txt` work

## 📋 Languages

| Language   | Extensions              | Runs with                                                                  |
| ---------- | ----------------------- | -------------------------------------------------------------------------- |
| Python     | `.py`                   | project `.venv`, else `uv run` in a uv project, else `python3`; `uv run --script` for [inline dependencies](https://docs.astral.sh/uv/guides/scripts/) |
| JavaScript | `.js`, `.mjs`, `.cjs`   | `node`                                                                     |
| TypeScript | `.ts`, `.mts`, `.cts`   | the first found of `tsx`, `bun`, Node.js 22.18+, `deno`, `ts-node`         |
| Dart       | `.dart`                 | `dart run`                                                                 |
| Java       | `.java`                 | `java` (single-file source launcher, JDK 11+)                              |
| Kotlin     | `.kt`, `.kts`           | `kotlinc` then `java -jar`; `kotlinc -script` for `.kts`                   |
| Go         | `.go`                   | `go run .` in a module, else `go run file.go`                              |
| Ruby       | `.rb`                   | `ruby`                                                                     |
| C          | `.c`                    | `gcc -Wall -Wextra -O2 -std=c17`                                           |
| C++        | `.cpp`, `.cc`, `.cxx`   | `g++ -Wall -Wextra -O2 -std=c++20`                                         |
| C#         | `.cs`                   | `dotnet run --project` in a project, else `dotnet run file.cs` (.NET 10+)  |
| PHP        | `.php`                  | `php`                                                                      |
| Shell      | `.sh`                   | `bash`                                                                     |
| Perl       | `.pl`                   | `perl`                                                                     |
| Lua        | `.lua`                  | `lua`                                                                      |
| R          | `.r`, `.R`              | `Rscript`                                                                  |
| Swift      | `.swift`                | `swift`                                                                    |
| Rust       | `.rs`                   | `cargo run` (right `--bin` / `--example`) in a crate, else `rustc --edition 2021` |
| Zig        | `.zig`                  | `zig run`                                                                  |

Run **Code Runner: Doctor** from the task list to see which of these are installed.

## 🎯 Usage

| What                     | How                                                                                     |
| ------------------------ | --------------------------------------------------------------------------------------- |
| Run the current file     | `Ctrl+R` / `Cmd+R`, or ▶ next to `main()`                                               |
| Run it again             | `Ctrl+Shift+R` / `Cmd+Alt+R`, from any file (Zed's built-in Rerun)                     |
| Debug build (C/C++)      | task list (`Alt+Shift+T` on Linux, `Cmd+Shift+R` on Mac) → **Run File (debug)**        |
| Run selected lines       | select them → task list → **Run Selection** (only listed while text is selected)       |
| Check installed runtimes | task list → **Code Runner: Doctor**                                                     |

The program runs in Zed's terminal, so you can type input when it asks for it.

### Input files

Put a file named like your program with `.in` next to it, and the runner uses it as the program's input:

```
calculator.cpp
calculator.in     ← "2\n16\n6\n2\nn\n0\n" is typed in for you
```

The header shows `📥 Input: calculator.in` when this happens. Rename or delete the file to type input yourself again.

### Debug builds

**Run File (debug)** compiles C and C++ with `-g -O0 -fsanitize=address,undefined`. Instead of a random crash or a wrong answer, you get a report naming the line that read past the end of an array, used freed memory, or overflowed an `int`.

## 📦 Installation

Linux and macOS. The installer uses `python3` to edit Zed's JSON files; the runner itself only needs `bash`.

```bash
curl -fsSL https://raw.githubusercontent.com/Sothcheat/zed-code-runner/main/install.sh | bash
```

To read it first:

```bash
curl -fsSLO https://raw.githubusercontent.com/Sothcheat/zed-code-runner/main/install.sh
less install.sh
bash install.sh
```

Options (from the web, put them after `bash -s --`, for example `curl ... | bash -s -- --key f9`):

| Option        | Does                                                                |
| ------------- | ------------------------------------------------------------------- |
| `--key KEY`   | use another key for Run File, for example `--key f9`               |
| `--update`    | download the latest version and install it                          |
| `--uninstall` | remove what the installer added                                     |
| `--doctor`    | show which language runtimes are installed                          |

### What the installer changes

In `~/.config/zed/` (`$XDG_CONFIG_HOME/zed/` on Linux):

- `code-runner/runner.sh` and `code-runner/install.sh`: replaced on every update
- `code-runner/custom.sh`: your own commands, created once and never overwritten
- `tasks.json`: adds four tasks (Run File, Run File (debug), Run Selection, Code Runner: Doctor) and updates them on later installs
- `keymap.json`: adds `ctrl-r` / `cmd-r` → Run File in the editor

Everything else in `tasks.json` and `keymap.json` stays as it is, comments included, and a backup (`*.backup.<timestamp>`) is saved before either file changes. If the key is already bound in your keymap, your binding is kept and the installer suggests `--key`. If a file can't be read (invalid JSON), it's left alone and the installer prints what to add.

Version 1 installs (`runner.sh`, `run_code.py` and `runner.custom.sh` directly in `~/.config/zed/`) are moved over automatically, including your custom commands.

`Ctrl+R` replaces Zed's Open Recent shortcut inside the editor; Open Recent is still on `Ctrl+Alt+O`. On Mac, `Cmd+R` replaces Toggle Right Dock in the editor.

## 🎨 Customization

### Your own commands

Edit `~/.config/zed/code-runner/custom.sh`. It's read before the built-in languages, so it can add new languages or change existing ones:

```bash
case "$FILE" in
    *.py)  run python "$FILE" ;;                         # change a built-in
    *.hs)  run runghc "$FILE" ;;                         # add a language
    *.c)   build_and_run clang "$FILE" -o "$BIN" -O2 ;;  # compile to $BIN, then run it
    *) ;;
esac
```

| Helper                | Does                                                              |
| --------------------- | ----------------------------------------------------------------- |
| `run CMD...`          | runs the program (with `NAME.in` as input when it exists)        |
| `build_and_run CMD...`| compiles with `CMD`, which must write `"$BIN"`, then runs `"$BIN"` |
| `compile CMD...`      | compiles only, with the warning count; stops on errors            |
| `need CMD "hint"`     | stops with the hint when `CMD` isn't installed                    |
| `say "text"`          | prints `>>> text`                                                 |

Variables: `$FILE` (absolute path), `$DIR` (its folder, also the working directory), `$FILENAME`, `$STEM`, `$BIN` (where to put a compiled program) and `$MODE` (`run`, `debug` or `selection`).

### Another key

```bash
bash ~/.config/zed/code-runner/install.sh --key f9
```

## 🐛 Troubleshooting

**The key does nothing.** Open the task list and pick Run File. If that works, the key is the problem: look for conflicts in the keymap editor (`Ctrl+K Ctrl+S` / `Cmd+K Cmd+S`) or pick another key with `--key`. If it doesn't, check `tasks.json` for invalid JSON. Restarting Zed once can help after the first install.

**Command not found.** Run **Code Runner: Doctor** to see what's installed and on your `PATH`.

**Too many compiler warnings.** They often point at real bugs, which is why they stay on. To turn them off for C++, override it in `custom.sh`:

```bash
*.cpp) build_and_run g++ "$FILE" -o "$BIN" -O2 -std=c++20 ;;
```

**Test without Zed:**

```bash
bash ~/.config/zed/code-runner/runner.sh path/to/file.py
```

## 🔄 Updating

```bash
bash ~/.config/zed/code-runner/install.sh --update
```

Your `custom.sh`, other tasks and keybindings are kept.

## 🗑️ Uninstalling

```bash
bash ~/.config/zed/code-runner/install.sh --uninstall
```

This removes the tasks, the keybinding and the runner. Your `custom.sh` stays in `~/.config/zed/code-runner/`; delete it if you don't need it.

## ❓ Why not a Zed extension?

Zed extensions can add languages, themes, snippets, debuggers, language servers and MCP servers, but not tasks or keybindings for the languages Zed already ships, and they can't change your settings. Running files is done with Zed's own [tasks](https://zed.dev/docs/tasks), and this project installs and maintains them for you. If Zed's extension API gains tasks, this can become an extension.

## 🧪 Development

```bash
bash tests/smoke.sh
```

installs into a temporary folder, runs a small program in every installed language, and checks the installer's edits. CI runs it on Linux and macOS (bash 3.2) together with ShellCheck.

## 🤝 Contributing

Contributions welcome: more languages, better messages, bug fixes. Please run `bash tests/smoke.sh` before opening a pull request.

## 📄 License

MIT License, see [LICENSE](LICENSE).

## 🙏 Acknowledgments

Inspired by VS Code's [Code Runner](https://marketplace.visualstudio.com/items?itemName=formulahendry.code-runner) extension.

## 📧 Support

[GitHub Issues](https://github.com/Sothcheat/zed-code-runner/issues)
