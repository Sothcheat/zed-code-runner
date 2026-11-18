# shellcheck shell=bash
# custom.sh: your own commands for Code Runner for Zed.
#
# The installer creates this file once and never overwrites it, so changes
# here survive updates. It is read before the built-in languages: a pattern
# that matches here wins, and any other file falls through to the defaults.
#
# Helpers:
#   run CMD...            run the program (gets NAME.in as input if it exists)
#   build_and_run CMD...  compile with CMD (output to "$BIN"), then run "$BIN"
#   compile CMD...        compile only, with a warning count; stops on errors
#   need CMD "hint"       stop with a hint when CMD is not installed
#   say "text"            print a ">>> text" line
# Variables:
#   $FILE (absolute path)  $DIR (its folder, also the working directory)
#   $FILENAME  $STEM  $BIN  $MODE (run, debug or selection)
#
# Uncomment or add lines:

case "$FILE" in
    # *.py)  run python "$FILE" ;;
    # *.c)   build_and_run clang "$FILE" -o "$BIN" -O2 ;;
    # *.hs)  run runghc "$FILE" ;;
    *) ;;
esac
