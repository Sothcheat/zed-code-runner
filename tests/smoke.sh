#!/bin/bash
# Smoke tests: install into a throwaway config folder, run a small program in
# every language whose runtime is installed, and check the installer's edits
# to tasks.json and keymap.json. Languages without a runtime are skipped.
#
#   bash tests/smoke.sh

REPO=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
WORK=$(mktemp -d "${TMPDIR:-/tmp}/zed-code-runner-test.XXXXXX")
trap 'rm -rf "$WORK"' EXIT
export TERM=dumb

# Install into $WORK, never into the real Zed config
if [[ "$OSTYPE" == "darwin"* ]]; then
    export HOME="$WORK/home"
    CONFIG="$HOME/.config/zed"
else
    export XDG_CONFIG_HOME="$WORK/config"
    CONFIG="$XDG_CONFIG_HOME/zed"
fi
mkdir -p "$CONFIG"
RUNNER="$CONFIG/code-runner/runner.sh"
SRC="$WORK/src dir (1)"   # spaces and parentheses on purpose
mkdir -p "$SRC"

PASS=0
FAIL=0
SKIP=0
ok() { PASS=$((PASS + 1)); echo "  ✅ $1"; }
bad() { FAIL=$((FAIL + 1)); echo "  ❌ $1"; [ -n "${2:-}" ] && echo "$2" | sed 's/^/       │ /'; }
skip() { SKIP=$((SKIP + 1)); echo "  ⏭️  $1"; }
have() { command -v "$1" > /dev/null 2>&1; }

# expect NAME CODE PATTERN ARGS...: run the runner, check exit code and output
expect() {
    local name="$1" code="$2" pattern="$3" out got
    shift 3
    out=$("$BASH" "$RUNNER" "$@" 2>&1)
    got=$?
    if [ "$got" -eq "$code" ] && echo "$out" | grep -qE "$pattern"; then
        ok "$name"
    else
        bad "$name (exit $got, wanted $code and /$pattern/)" "$(echo "$out" | tail -n 15)"
    fi
}

# lang NAME TOOL FILE CONTENT: write FILE and expect it to print "hello NAME"
lang() {
    local name="$1" tool="$2" file="$SRC/$3"
    if ! have "$tool"; then
        skip "$name ($tool not installed)"
        return
    fi
    printf '%s\n' "$4" > "$file"
    expect "$name" 0 "hello $name" "$file"
}

json_ok() {
    python3 -I - "$1" << 'EOF'
import json, re, sys
s = open(sys.argv[1]).read()
s = re.sub(r"//[^\n]*", "", s)
s = re.sub(r",(\s*[\]}])", r"\1", s)
json.loads(s)
EOF
}

echo "== Installer"
cat > "$CONFIG/keymap.json" << 'EOF'
// my keymap
[
  {
    "context": "Workspace",
    "bindings": {
      "ctrl-shift-t": "workspace::NewTerminal", // keep me
    },
  },
]
EOF
cat > "$CONFIG/tasks.json" << 'EOF'
[
  // my task
  { "label": "lint", "command": "npm run lint" },
]
EOF
# A v1 install: old scripts and a custom file to migrate
echo '"""Wrapper script to run code files in Zed editor."""' > "$CONFIG/run_code.py"
echo 'filename_ext=x' > "$CONFIG/runner.sh"
printf 'case "$FILE" in\n  *.v1) run echo "v1 custom works" ;;\nesac\n' > "$CONFIG/runner.custom.sh"

out=$("$BASH" "$REPO/install.sh" 2>&1) || bad "install exit code" "$out"
[ -x "$RUNNER" ] && ok "runner installed" || bad "runner installed" "$out"
[ ! -e "$CONFIG/run_code.py" ] && [ ! -e "$CONFIG/runner.sh" ] && ok "v1 scripts removed" || bad "v1 scripts removed"
grep -q 'v1 custom works' "$CONFIG/code-runner/custom.sh" 2> /dev/null && ok "v1 custom file moved to custom.sh" || bad "v1 custom file moved"
grep -q '// keep me' "$CONFIG/keymap.json" && grep -q '// my task' "$CONFIG/tasks.json" && ok "comments kept" || bad "comments kept"
grep -q 'ctrl-shift-t' "$CONFIG/keymap.json" && grep -q '"lint"' "$CONFIG/tasks.json" && ok "existing entries kept" || bad "existing entries kept"
json_ok "$CONFIG/tasks.json" && json_ok "$CONFIG/keymap.json" && ok "files still valid" || bad "files still valid" "$(cat "$CONFIG/tasks.json" "$CONFIG/keymap.json")"
[ "$(grep -c '"label": "Run File"' "$CONFIG/tasks.json")" -eq 1 ] && grep -q '"Run Selection"' "$CONFIG/tasks.json" && grep -q 'cpp-main' "$CONFIG/tasks.json" && ok "tasks added" || bad "tasks added" "$(cat "$CONFIG/tasks.json")"

cp "$CONFIG/tasks.json" "$WORK/tasks.before"
cp "$CONFIG/keymap.json" "$WORK/keymap.before"
out=$("$BASH" "$REPO/install.sh" 2>&1)
cmp -s "$CONFIG/tasks.json" "$WORK/tasks.before" && cmp -s "$CONFIG/keymap.json" "$WORK/keymap.before" && ok "re-install changes nothing" || bad "re-install changes nothing" "$out"

out=$("$BASH" "$REPO/install.sh" --key f9 2>&1)
grep -q '"f9"' "$CONFIG/keymap.json" && ! grep -q '"ctrl-r"\|"cmd-r"' "$CONFIG/keymap.json" && ok "--key replaces the binding" || bad "--key replaces the binding" "$(cat "$CONFIG/keymap.json")"

echo '[{"context": "Editor", "bindings": {"f8": "editor::Rename"}}]' > "$WORK/k.json"
cp "$WORK/k.json" "$CONFIG/keymap.json"
out=$("$BASH" "$REPO/install.sh" --key f8 2>&1)
cmp -s "$CONFIG/keymap.json" "$WORK/k.json" && echo "$out" | grep -q 'already bound' && ok "taken key is not stolen" || bad "taken key is not stolen" "$out"

echo '[{"context": "Editor",' > "$CONFIG/keymap.json"
out=$("$BASH" "$REPO/install.sh" 2>&1)
[ "$(cat "$CONFIG/keymap.json")" = '[{"context": "Editor",' ] && echo "$out" | grep -q 'could not parse' && ok "broken file left alone" || bad "broken file left alone" "$out"
rm "$CONFIG/keymap.json"
"$BASH" "$REPO/install.sh" > /dev/null 2>&1

echo ""
echo "== Languages"
lang "python" python3 "hello.py" 'print("hello python")'
lang "javascript" node "hello.js" 'console.log("hello javascript")'
if have tsx || have bun || have deno || have ts-node \
    || (have node && node -e 'process.exit(process.features.typescript ? 0 : 1)' 2> /dev/null); then
    lang "typescript" bash "hello.ts" 'const who: string = "typescript"; console.log(`hello ${who}`)'
else
    skip "typescript (no TypeScript runner installed)"
fi
lang "ruby" ruby "hello.rb" 'puts "hello ruby"'
lang "perl" perl "hello.pl" 'print "hello perl\n";'
lang "lua" lua "hello.lua" 'print("hello lua")'
lang "shell" bash "hello.sh" 'echo "hello shell"'
lang "php" php "hello.php" '<?php echo "hello php\n";'
lang "c" gcc "hello.c" '#include <stdio.h>
int main(void) { puts("hello c"); return 0; }'
lang "cpp" g++ "hello.cpp" '#include <iostream>
int main() { std::cout << "hello cpp\n"; }'
lang "rust" rustc "hello.rs" 'fn main() { println!("hello rust"); }'
lang "go" go "hello.go" 'package main
import "fmt"
func main() { fmt.Println("hello go") }'
lang "java" java "Hello.java" 'class Hello { public static void main(String[] a) { System.out.println("hello java"); } }'
lang "dart" dart "hello.dart" 'void main() { print("hello dart"); }'
lang "swift" swift "hello.swift" 'print("hello swift")'
lang "r" Rscript "hello.R" 'cat("hello r\n")'
lang "zig" zig "hello.zig" 'const std = @import("std");
pub fn main() void { std.debug.print("hello zig\n", .{}); }'

echo ""
echo "== Behaviour"
if have gcc; then
    printf '#include <stdio.h>\nint main(void){puts("exiting 3");return 3;}\n' > "$SRC/fail.c"
    echo "KEEP" > "$SRC/fail"
    expect "exit code reported" 3 "Exited with code 3 after" "$SRC/fail.c"
    [ "$(cat "$SRC/fail")" = "KEEP" ] && ok "file named like the binary untouched" || bad "file named like the binary untouched"

    printf 'int main(void){ return syntax error }\n' > "$SRC/broken.c"
    expect "compile error reported" 1 "Failed with code 1" "$SRC/broken.c"

    printf '#include <stdio.h>\nint main(void){int x; switch(1){case 1: x=1; case 2: x=2;} printf("%%d\\n", x); return 0;}\n' > "$SRC/warn.c"
    expect "warning count shown" 0 "Compiled with [0-9]+ warnings?" "$SRC/warn.c"

    printf '#include <stdio.h>\nint main(void){int a,b; scanf("%%d %%d",&a,&b); printf("sum %%d\\n",a+b); return 0;}\n' > "$SRC/sum.c"
    echo "2 40" > "$SRC/sum.in"
    expect "NAME.in used as input" 0 "sum 42" "$SRC/sum.c"

    printf '#include <stdio.h>\nint main(void){FILE*f=fopen("data.txt","r"); char s[32]; fgets(s,32,f); printf("read %%s",s); return 0;}\n' > "$SRC/reads.c"
    echo "from its folder" > "$SRC/data.txt"
    (cd / && expect "runs from the file's folder" 0 "read from its folder" "$SRC/reads.c")

    if echo 'int main(void){return 0;}' | gcc -x c - -o "$WORK/asan" -fsanitize=address,undefined 2> /dev/null; then
        printf '#include <stdlib.h>\nint main(void){int *a = malloc(4 * sizeof(int)); a[4] = 1; free(a); return 0;}\n' > "$SRC/oob.c"
        expect "debug build catches out-of-bounds" 1 "heap-buffer-overflow" --debug "$SRC/oob.c"
    else
        skip "debug build (no sanitizer support)"
    fi
fi

expect "selection runs" 0 "selected 6" --selection "$SRC/hello.py" 'print("selected", 2 * 3)'
expect "selection refused for C" 1 "Run Selection works with" --selection "$SRC/hello.c" 'puts("x");'

mkdir -p "$SRC/venvproj/.venv/bin" "$SRC/venvproj/pkg"
printf '#!/bin/sh\necho "venv python ran $1"\n' > "$SRC/venvproj/.venv/bin/python"
chmod +x "$SRC/venvproj/.venv/bin/python"
echo 'print(1)' > "$SRC/venvproj/pkg/app.py"
expect "project .venv is used" 0 "venv python ran" "$SRC/venvproj/pkg/app.py"

if have cargo; then
    mkdir -p "$SRC/crate/src/bin"
    printf '[package]\nname = "crate"\nversion = "0.1.0"\nedition = "2021"\n' > "$SRC/crate/Cargo.toml"
    echo 'fn main() { println!("hello crate main"); }' > "$SRC/crate/src/main.rs"
    echo 'fn main() { println!("hello extra bin"); }' > "$SRC/crate/src/bin/extra.rs"
    expect "cargo project" 0 "hello crate main" "$SRC/crate/src/main.rs"
    expect "cargo src/bin target" 0 "hello extra bin" "$SRC/crate/src/bin/extra.rs"
    mkdir -p "$SRC/crate/src/bin/tool"
    echo 'fn main() { println!("hello tool bin"); }' > "$SRC/crate/src/bin/tool/main.rs"
    expect "cargo src/bin/NAME/main.rs target" 0 "hello tool bin" "$SRC/crate/src/bin/tool/main.rs"
else
    skip "cargo project (cargo not installed)"
fi

expect "custom.sh override" 0 "v1 custom works" "$(touch "$SRC/x.v1"; echo "$SRC/x.v1")"
echo 'x' > "$SRC/file.unknown"
expect "unsupported type" 1 "Unsupported file type" "$SRC/file.unknown"
expect "doctor" 0 "Language runtimes" --doctor

left=$(find "${TMPDIR:-/tmp}" -maxdepth 1 -name 'zed-code-runner.*' -newer "$REPO/runner.sh" 2> /dev/null | wc -l | tr -d ' ')
[ "$left" -eq 0 ] && ok "no temp folders left behind" || bad "no temp folders left behind ($left found)"

echo ""
echo "== Uninstall"
out=$("$BASH" "$CONFIG/code-runner/install.sh" --uninstall 2>&1)
! grep -q 'Run File\|Run Selection\|Code Runner' "$CONFIG/tasks.json" && grep -q '"lint"' "$CONFIG/tasks.json" && ok "tasks removed, others kept" || bad "tasks removed, others kept" "$(cat "$CONFIG/tasks.json")"
! grep -q 'Run File' "$CONFIG/keymap.json" && ok "keybinding removed" || bad "keybinding removed" "$(cat "$CONFIG/keymap.json")"
[ ! -e "$RUNNER" ] && [ -f "$CONFIG/code-runner/custom.sh" ] && ok "runner removed, custom.sh kept" || bad "runner removed, custom.sh kept" "$out"
json_ok "$CONFIG/tasks.json" && json_ok "$CONFIG/keymap.json" && ok "files still valid" || bad "files still valid"

echo ""
echo "Passed: $PASS  Failed: $FAIL  Skipped: $SKIP"
[ "$FAIL" -eq 0 ]
