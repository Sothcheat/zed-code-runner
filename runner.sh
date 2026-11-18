#!/bin/bash
# Code Runner for Zed: runs one file, picking the command from its extension.
# https://github.com/Sothcheat/zed-code-runner
#
#   runner.sh FILE                    run a file
#   runner.sh --debug FILE            C/C++ with -g and sanitizers, others as usual
#   runner.sh --selection FILE TEXT   run TEXT as code in FILE's language
#   runner.sh --doctor                show which language runtimes are installed
#   runner.sh --version
#
# This file is replaced on every update. Put your own commands in custom.sh
# next to it; that file is never overwritten.
#
# Written for bash 3.2 too (macOS /bin/bash): no associative arrays, no ${x,,}.

VERSION="2.0.0"
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

have() {
    command -v "$1" > /dev/null 2>&1
}

# Node 22.18+ / 23.6+ runs TypeScript itself by stripping the types
node_runs_ts() {
    have node && node -e 'process.exit(process.features.typescript ? 0 : 1)' 2> /dev/null
}

# ---------------------------------------------------------------- doctor ---

doctor_line() {
    # doctor_line LABEL TOOL VERSION_CMD...
    local label="$1" tool="$2" version
    shift 2
    if have "$tool"; then
        version=$("$@" 2>&1 | grep -v '^[[:space:]]*$' | head -n 1)
        printf '  ✅ %-12s %s\n' "$label" "$version"
    else
        printf '  ❌ %-12s %s not found\n' "$label" "$tool"
    fi
}

doctor() {
    echo "Code Runner for Zed $VERSION"
    echo "Script: $SCRIPT_DIR/runner.sh"
    if [ -f "$SCRIPT_DIR/custom.sh" ]; then
        echo "Your commands: $SCRIPT_DIR/custom.sh"
    fi
    echo ""
    echo "Language runtimes:"
    doctor_line "Python" python3 python3 --version
    doctor_line "uv" uv uv --version
    doctor_line "JavaScript" node node --version
    if have tsx; then
        doctor_line "TypeScript" tsx tsx --version
    elif have bun; then
        doctor_line "TypeScript" bun echo "bun $(bun --version)"
    elif node_runs_ts; then
        doctor_line "TypeScript" node echo "node $(node --version) (built-in type stripping)"
    elif have deno; then
        doctor_line "TypeScript" deno deno --version
    else
        doctor_line "TypeScript" ts-node ts-node --version
    fi
    doctor_line "Dart" dart dart --version
    doctor_line "Java" java java --version
    doctor_line "Maven" mvn mvn -v
    doctor_line "Gradle" gradle sh -c 'gradle -v | grep -m 1 Gradle'
    doctor_line "Kotlin" kotlinc kotlinc -version
    doctor_line "Go" go go version
    doctor_line "Ruby" ruby ruby --version
    doctor_line "C" gcc gcc --version
    doctor_line "C++" g++ g++ --version
    if have dotnet && [ -n "$(dotnet --list-sdks 2> /dev/null)" ]; then
        doctor_line "C#" dotnet echo ".NET SDK $(dotnet --version)"
    elif have dotnet; then
        printf '  ❌ %-12s %s\n' "C#" "dotnet found, but no .NET SDK is installed"
    else
        doctor_line "C#" dotnet true
    fi
    doctor_line "PHP" php php --version
    doctor_line "Shell" bash echo "bash $BASH_VERSION"
    doctor_line "Perl" perl perl -e 'print "perl $^V\n"'
    doctor_line "Lua" lua lua -v
    doctor_line "R" Rscript Rscript --version
    doctor_line "Swift" swift swift --version
    doctor_line "Rust" rustc rustc --version
    doctor_line "Cargo" cargo cargo --version
    doctor_line "Zig" zig echo "zig $(zig version 2> /dev/null)"
}

# ------------------------------------------------------------- arguments ---

MODE="run"
case "${1:-}" in
    --doctor)
        doctor
        exit 0
        ;;
    --version)
        echo "Code Runner for Zed $VERSION"
        exit 0
        ;;
    --debug)
        MODE="debug"
        shift
        ;;
    --selection)
        MODE="selection"
        shift
        ;;
esac

FILE="${1:-}"
SELECTION="${2-}"

if [ -z "$FILE" ]; then
    echo "❌ Error: No file provided"
    exit 1
fi

if [ ! -f "$FILE" ]; then
    echo "❌ Error: File not found: $FILE"
    exit 1
fi

# Absolute path, so a compiled program is never looked up in PATH by name
# (a relative "test.c" would otherwise run the shell's built-in `test`)
DIR=$(cd "$(dirname "$FILE")" && pwd)
FILENAME=$(basename "$FILE")
FILE="$DIR/$FILENAME"
STEM="${FILENAME%.*}"

# Programs run from their own folder, so relative paths like "data.txt" work
# (Cargo, Maven and Gradle projects run from the project folder instead)
cd "$DIR" || exit 1

# Compiled programs are built in a private temporary directory that is always
# removed, so nothing next to the source file is created, overwritten or deleted
TMP_ROOT="${TMPDIR:-/tmp}"
BUILD_DIR=$(mktemp -d "${TMP_ROOT%/}/zed-code-runner.XXXXXX") || exit 1
BIN="$BUILD_DIR/$STEM"
trap 'rm -rf "$BUILD_DIR"' EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

# ---------------------------------------------------------------- helpers ---

ESC=$(printf '\033')
START=""

rule() {
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

now() {
    if [ -n "${EPOCHREALTIME:-}" ]; then
        echo "${EPOCHREALTIME/,/.}"
    else
        date +%s
    fi
}

# say TEXT: announce what is about to run
say() {
    echo ">>> $1"
    echo ""
}

# finish CODE: report the result and exit with the program's exit code
finish() {
    local code="$1" took=""
    if [ -n "$START" ]; then
        took=$(awk -v a="$START" -v b="$(now)" 'BEGIN { printf "%.2fs", b - a }')
    fi
    echo ""
    rule
    if [ "$code" -eq 0 ]; then
        echo "✅ Finished${took:+ in $took}"
    elif [ -n "$took" ]; then
        echo "❌ Exited with code $code after $took"
    else
        echo "❌ Failed with code $code"
    fi
    rule
    exit "$code"
}

# run CMD...: run the program (with NAME.in as its input when that file
# exists), then finish with its exit code
run() {
    START=$(now)
    if [ -n "$INPUT" ]; then
        "$@" < "$INPUT"
    else
        "$@"
    fi
    finish $?
}

# compile CMD...: run a compiler, show its messages and a warning count, and
# stop here if it fails
compile() {
    local log="$BUILD_DIR/compile.log" code warnings
    "$@" 2> "$log"
    code=$?
    cat "$log" >&2
    [ "$code" -ne 0 ] && finish "$code"
    warnings=$(sed "s/$ESC\[[0-9;]*[mK]//g" "$log" \
        | grep 'warning:' | grep -cv 'warnings* emitted')
    if [ "$warnings" -gt 0 ]; then
        echo ""
        if [ "$warnings" -eq 1 ]; then
            echo "⚠️  Compiled with 1 warning (shown above)"
        else
            echo "⚠️  Compiled with $warnings warnings (shown above)"
        fi
        rule
        echo ""
    fi
}

# build_and_run CMD...: compile with CMD, which must write "$BIN", then run it
build_and_run() {
    compile "$@"
    run "$BIN"
}

# need CMD HINT: stop with a hint when CMD is not installed
need() {
    if ! have "$1"; then
        echo "❌ $1 not found. $2"
        finish 127
    fi
}

# find_up PATH: print the nearest directory, from the file's own upwards,
# that contains PATH (a name, a relative path or a glob like "*.csproj")
find_up() {
    local d="$DIR" f
    while :; do
        for f in "$d"/$1; do
            if [ -e "$f" ]; then
                echo "$d"
                return 0
            fi
        done
        [ "$d" = "/" ] && return 1
        d=$(dirname "$d")
    done
}

# ------------------------------------------------------------- selection ---

if [ "$MODE" = "selection" ]; then
    EXT="${FILENAME##*.}"
    case "$EXT" in
        py|js|mjs|cjs|ts|mts|cts|rb|pl|lua|sh|php|r|R|kts) ;;
        *)
            echo "❌ Run Selection works with Python, JavaScript, TypeScript, Ruby,"
            echo "   Perl, Lua, Shell, PHP, R and Kotlin script files."
            echo "   For $FILENAME, use Run File instead."
            exit 1
            ;;
    esac
    if [ -z "$SELECTION" ]; then
        echo "❌ Nothing is selected"
        exit 1
    fi
    # The snippet goes in a file with the same extension and runs from the
    # original file's folder
    SNIPPET="$BUILD_DIR/selection.$EXT"
    if [ "$EXT" = "php" ] && [ "${SELECTION#<?php}" = "$SELECTION" ]; then
        printf '<?php\n%s\n' "$SELECTION" > "$SNIPPET"
    else
        printf '%s\n' "$SELECTION" > "$SNIPPET"
    fi
    LABEL="selection from $FILENAME"
    FILE="$SNIPPET"
else
    LABEL="$FILENAME"
fi

# Feed NAME.in to the program as input, if it exists next to NAME.ext
INPUT=""
if [ "$MODE" != "selection" ] && [ -f "$DIR/$STEM.in" ]; then
    INPUT="$DIR/$STEM.in"
fi

clear
rule
echo "🚀 Running: $LABEL"
echo "📁 Path: $DIR/$FILENAME"
[ "$MODE" = "debug" ] && echo "🐞 Debug build"
[ -n "$INPUT" ] && echo "📥 Input: $STEM.in"
rule
echo ""

if [ "$MODE" = "debug" ]; then
    case "$FILE" in
        *.c|*.cpp|*.cc|*.cxx|*.java) ;;
        *)
            echo "ℹ️  Debug builds are for C, C++ and Java; running $FILENAME as usual."
            echo ""
            ;;
    esac
fi

# Your own commands win over the built-in ones below
if [ -f "$SCRIPT_DIR/custom.sh" ]; then
    # shellcheck source=/dev/null
    . "$SCRIPT_DIR/custom.sh"
fi

# -------------------------------------------------------------- languages ---

DEBUG_FLAGS="-g -O0 -fsanitize=address,undefined -fno-omit-frame-pointer"
# On macOS the sanitizer aborts the program (exit 134 and an "Abort trap"
# line); exit with code 1 instead, the same as on Linux
if [ "$MODE" = "debug" ] && [ -z "${ASAN_OPTIONS:-}" ]; then
    export ASAN_OPTIONS="abort_on_error=0"
fi

# Java: CLASS is the class to run (package + file name); JAVA_EA turns on
# `assert` statements in debug runs
java_setup() {
    local pkg
    pkg=$(sed -n 's/^[[:space:]]*package[[:space:]]\{1,\}\([A-Za-z0-9_.]\{1,\}\)[[:space:]]*;.*/\1/p' \
        "$FILE" | head -n 1)
    CLASS="${pkg:+$pkg.}$STEM"
    PKG_PATH=$(echo "$pkg" | tr . /)
    JAVA_EA=""
    [ "$MODE" = "debug" ] && JAVA_EA="-ea"
    SOURCE_SET="main"
    case "$FILE" in */src/test/*) SOURCE_SET="test" ;; esac
}

# Plain Java: javac compiles the file plus any classes it uses from the same
# source tree (-sourcepath), on every JDK version, into the temp folder
java_plain() {
    local root="$DIR"
    if [ -n "$PKG_PATH" ] && [ "${DIR%/"$PKG_PATH"}" != "$DIR" ]; then
        root="${DIR%/"$PKG_PATH"}"
    fi
    say "Compiling and running Java ($CLASS)..."
    need javac "Please install a JDK (not just a Java runtime)."
    compile javac -d "$BUILD_DIR/classes" -sourcepath "$root" "$FILE"
    # shellcheck disable=SC2086
    run java $JAVA_EA -cp "$BUILD_DIR/classes" "$CLASS"
}

# Maven and Gradle only build the code and write its classpath to a file;
# the program then runs with plain `java`, so it reads input straight from the
# terminal (or NAME.in) and starts without the build tool in between.

# Maven: compile and write the classpath in one go. In a multi-module build,
# the module is built from the top-level pom.xml together with the modules it
# depends on (-pl MODULE -am), which come last-to-first so the module's own
# classpath is what ends up in the file.
java_maven() {
    local module="$1" root="$1" d mvn goal="compile" scope="runtime"
    local cp_file="$BUILD_DIR/classpath.txt" classes
    d=$(dirname "$module")
    while [ "$d" != "/" ] && [ -f "$d/pom.xml" ]; do
        root="$d"
        d=$(dirname "$d")
    done
    if [ -x "$root/mvnw" ]; then
        mvn="$root/mvnw"
    else
        need mvn "Please install Maven, or add the Maven wrapper (mvnw) to the project."
        mvn="mvn"
    fi
    classes="$module/target/classes"
    if [ "$SOURCE_SET" = "test" ]; then
        goal="test-compile"
        scope="test"
        classes="$module/target/test-classes:$classes"
    fi
    say "Building with Maven (project in $module)..."
    set -- -q "$goal" dependency:build-classpath \
        "-Dmdep.outputFile=$cp_file" "-Dmdep.includeScope=$scope"
    if [ "$module" != "$root" ]; then
        set -- "$@" -pl "${module#"$root"/}" -am
    fi
    (cd "$root" && "$mvn" "$@") || finish $?
    say "Running $CLASS..."
    cd "$module" || finish 1
    # shellcheck disable=SC2086
    run java $JAVA_EA -cp "$classes:$(cat "$cp_file")" "$CLASS"
}

# Gradle: an init script adds a codeRunnerClasspath task to the module the
# file is in; it builds the module (and the modules it uses) and writes the
# runtime classpath, so any class with a main() runs, not just the one the
# build names
java_gradle() {
    local module="$1" gradle wrapper
    local init="$BUILD_DIR/code-runner.init.gradle" cp_file="$BUILD_DIR/classpath.txt"
    if wrapper=$(find_up "gradlew") && [ -x "$wrapper/gradlew" ]; then
        gradle="$wrapper/gradlew"
    else
        need gradle "Please install Gradle, or add the Gradle wrapper (gradlew) to the project."
        gradle="gradle"
    fi
    cat > "$init" << 'GRADLE'
allprojects { p ->
    p.afterEvaluate {
        def wanted = new File(p.findProperty('codeRunnerDir') ?: '.').canonicalPath
        if (p.projectDir.canonicalPath == wanted && p.plugins.hasPlugin('java')) {
            def set = p.sourceSets.getByName(p.findProperty('codeRunnerSourceSet') ?: 'main')
            def cp = set.runtimeClasspath
            def out = new File(p.findProperty('codeRunnerOut'))
            p.tasks.register('codeRunnerClasspath') {
                dependsOn cp
                doLast { out.text = cp.asPath }
            }
        }
    }
}
GRADLE
    say "Building with Gradle (project in $module)..."
    (cd "$module" && "$gradle" -q --console=plain -I "$init" codeRunnerClasspath \
        "-PcodeRunnerDir=$module" "-PcodeRunnerSourceSet=$SOURCE_SET" \
        "-PcodeRunnerOut=$cp_file") || finish $?
    say "Running $CLASS..."
    cd "$module" || finish 1
    # shellcheck disable=SC2086
    run java $JAVA_EA -cp "$(cat "$cp_file")" "$CLASS"
}

case "$FILE" in
    *.py)
        if grep -q '^# /// script' "$FILE" && have uv; then
            say "Running Python with uv (inline script dependencies)..."
            run uv run --script "$FILE"
        elif PROJECT_DIR=$(find_up ".venv/bin/python"); then
            say "Running Python from $PROJECT_DIR/.venv..."
            run "$PROJECT_DIR/.venv/bin/python" "$FILE"
        elif PROJECT_DIR=$(find_up "uv.lock") && have uv; then
            say "Running Python with uv (project in $PROJECT_DIR)..."
            run uv run python "$FILE"
        else
            say "Running Python..."
            need python3 "Please install Python 3."
            run python3 "$FILE"
        fi
        ;;
    *.js|*.mjs|*.cjs)
        say "Running JavaScript (Node.js)..."
        need node "Please install Node.js."
        run node "$FILE"
        ;;
    *.ts|*.mts|*.cts)
        if have tsx; then
            say "Running TypeScript (tsx)..."
            run tsx "$FILE"
        elif have bun; then
            say "Running TypeScript (Bun)..."
            run bun "$FILE"
        elif node_runs_ts; then
            say "Running TypeScript (Node.js type stripping)..."
            run node "$FILE"
        elif have deno; then
            say "Running TypeScript (Deno)..."
            run deno run "$FILE"
        elif have ts-node; then
            say "Running TypeScript (ts-node)..."
            run ts-node "$FILE"
        else
            echo "❌ No TypeScript runner found. Install one of: tsx (npm i -g tsx),"
            echo "   Bun, Deno, or Node.js 22.18 or newer."
            finish 127
        fi
        ;;
    *.dart)
        say "Running Dart..."
        need dart "Please install the Dart SDK."
        run dart run "$FILE"
        ;;
    *.java)
        need java "Please install a JDK."
        java_setup
        if PROJECT_DIR=$(find_up "pom.xml"); then
            java_maven "$PROJECT_DIR"
        elif PROJECT_DIR=$(find_up "build.gradle*"); then
            java_gradle "$PROJECT_DIR"
        else
            java_plain
        fi
        ;;
    *.kt)
        say "Compiling and running Kotlin..."
        need kotlinc "Please install Kotlin."
        compile kotlinc "$FILE" -include-runtime -d "$BIN.jar"
        run java -jar "$BIN.jar"
        ;;
    *.kts)
        say "Running Kotlin script..."
        need kotlinc "Please install Kotlin."
        run kotlinc -script "$FILE"
        ;;
    *.go)
        need go "Please install Go."
        if PROJECT_DIR=$(find_up "go.mod"); then
            say "Running Go package in $DIR (module in $PROJECT_DIR)..."
            run go run .
        else
            say "Running Go..."
            run go run "$FILE"
        fi
        ;;
    *.rb)
        say "Running Ruby..."
        need ruby "Please install Ruby."
        run ruby "$FILE"
        ;;
    *.cpp|*.cc|*.cxx)
        need g++ "Please install g++."
        if [ "$MODE" = "debug" ]; then
            say "Compiling C++ with debug info and sanitizers..."
            # shellcheck disable=SC2086
            build_and_run g++ "$FILE" -o "$BIN" -Wall -Wextra -std=c++20 \
                -fdiagnostics-color=always $DEBUG_FLAGS
        else
            say "Compiling and running C++..."
            build_and_run g++ "$FILE" -o "$BIN" -Wall -Wextra -O2 -std=c++20 \
                -fdiagnostics-color=always
        fi
        ;;
    *.c)
        need gcc "Please install gcc."
        if [ "$MODE" = "debug" ]; then
            say "Compiling C with debug info and sanitizers..."
            # shellcheck disable=SC2086
            build_and_run gcc "$FILE" -o "$BIN" -Wall -Wextra -std=c17 \
                -fdiagnostics-color=always $DEBUG_FLAGS
        else
            say "Compiling and running C..."
            build_and_run gcc "$FILE" -o "$BIN" -Wall -Wextra -O2 -std=c17 \
                -fdiagnostics-color=always
        fi
        ;;
    *.cs)
        need dotnet "Please install the .NET SDK."
        if PROJECT_DIR=$(find_up "*.csproj"); then
            say "Running C# project in $PROJECT_DIR..."
            run dotnet run --project "$PROJECT_DIR"
        else
            say "Running C# file (needs .NET 10 or newer)..."
            run dotnet run "$FILE"
        fi
        ;;
    *.php)
        say "Running PHP..."
        need php "Please install PHP."
        run php "$FILE"
        ;;
    *.sh)
        say "Running Shell Script..."
        run bash "$FILE"
        ;;
    *.pl)
        say "Running Perl..."
        need perl "Please install Perl."
        run perl "$FILE"
        ;;
    *.lua)
        say "Running Lua..."
        need lua "Please install Lua."
        run lua "$FILE"
        ;;
    *.r|*.R)
        say "Running R..."
        need Rscript "Please install R."
        run Rscript "$FILE"
        ;;
    *.swift)
        say "Running Swift..."
        need swift "Please install Swift."
        run swift "$FILE"
        ;;
    *.rs)
        if PROJECT_DIR=$(find_up "Cargo.toml") && have cargo; then
            # Pick the Cargo target the file belongs to; src/main.rs needs
            # --bin PACKAGE once src/bin/ adds more binaries
            REL="${FILE#"$PROJECT_DIR"/}"
            case "$REL" in
                src/bin/*/main.rs) TARGET="--bin $(basename "$(dirname "$REL")")" ;;
                src/bin/*.rs) TARGET="--bin $STEM" ;;
                examples/*.rs) TARGET="--example $STEM" ;;
                src/main.rs)
                    PACKAGE=$(sed -n 's/^[[:space:]]*name[[:space:]]*=[[:space:]]*"\([^"]*\)".*/\1/p' \
                        "$PROJECT_DIR/Cargo.toml" | head -n 1)
                    TARGET="${PACKAGE:+--bin $PACKAGE}"
                    ;;
                *) TARGET="" ;;
            esac
            say "Running Cargo project in $PROJECT_DIR..."
            cd "$PROJECT_DIR" || finish 1
            # shellcheck disable=SC2086
            run cargo run $TARGET
        else
            say "Compiling and running Rust..."
            need rustc "Please install Rust (https://rustup.rs)."
            build_and_run rustc "$FILE" -o "$BIN" --edition 2021 --color always
        fi
        ;;
    *.zig)
        say "Running Zig..."
        need zig "Please install Zig."
        run zig run "$FILE"
        ;;
    *)
        echo "❌ Unsupported file type: $FILENAME"
        echo ""
        echo "Supported: Python, JavaScript, TypeScript, Dart, Java, Kotlin, Go, Ruby,"
        echo "C, C++, C#, PHP, Shell, Perl, Lua, R, Swift, Rust and Zig."
        echo ""
        echo "Add your own in $SCRIPT_DIR/custom.sh"
        exit 1
        ;;
esac
