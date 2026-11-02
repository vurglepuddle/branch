#!/usr/bin/env bash
# Runs the headless checks from the project root and fails on test failures or engine errors.
# Usage: tests/run_tests.sh [boards per difficulty]
# Set GODOT to your Godot 4.3 binary if "godot" is not on PATH.

cd "$(dirname "$0")/.." || exit 1
GODOT="${GODOT:-godot}"
BOARDS="${1:-200}"
status=0

run() {
	local script="$1"; shift
	local output
	output="$("$GODOT" --headless --path . --script "res://tests/$script" -- "$@" 2>&1)"
	local code=$?
	printf '%s\n' "$output" | grep -v '^Godot Engine\|^$'
	if [ "$code" -ne 0 ]; then
		echo "==> $script exited with $code"
		status=1
	fi
	# Quitting always reports the title music still in use, even from an empty script. It's harmless.
	if printf '%s\n' "$output" | grep -v 'resources still in use at exit' | grep -q 'SCRIPT ERROR\|^ERROR:\|^USER ERROR:'; then
		echo "==> $script logged engine errors"
		status=1
	fi
}

run test_generator.gd "$BOARDS"
run test_scenes.gd
run test_audio.gd
exit "$status"
