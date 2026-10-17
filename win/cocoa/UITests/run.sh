#!/bin/bash
# Runs UI test scripts against build/NetHackUITest.app (make -C win/cocoa uitest).
#
#   UITests/run.sh                      # every UITests/*.nhtest
#   UITests/run.sh UITests/status.nhtest
#
# Each script runs in a fresh game. Directives at the top of a script:
#   @options <NETHACKOPTIONS>   added to name:uitest,!legacy,!tutorial
#   @wizard                     start in wizard mode
#   @tutorial                   let the game offer its tutorial
#   @config <line>              a line of the game's configuration file
#   @appearance light|dark      force the window appearance
#   @relaunch                   quit here and start the same game again
# The steps themselves are documented in UITests/README.md.
#
# The app takes the keyboard focus while it runs, so leave the Mac alone.

# A locked screen can't give the app the focus, and the driver's events don't count as
# activity, so keep the display awake for as long as the tests run
if [ -z "$UITEST_AWAKE" ]; then
	UITEST_AWAKE=1 exec caffeinate -d "$0" "$@"
fi

# test paths are relative to where the script was run from
tests=()
for test in "$@"; do
	tests+=("$(cd "$(dirname "$test")" && pwd)/$(basename "$test")")
done
set -- "${tests[@]}"

cd "$(dirname "$0")/.." || exit 1
app=${UITEST_APP:-build/NetHackUITest.app}/Contents/MacOS/NetHack
timeout=${UITEST_TIMEOUT:-180}
logs=${UITEST_LOGS:-build/uitest-logs}
mkdir -p "$logs"

if [ $# -eq 0 ]; then set -- UITests/*.nhtest; fi

failed=()
for test in "$@"; do
	name=$(basename "$test" .nhtest)
	options=$(sed -n 's/^@options *//p' "$test" | head -1)
	args=()
	grep -q '^@wizard' "$test" && args+=(-D)
	tutorial=,!tutorial
	grep -q '^@tutorial' "$test" && tutorial=
	case $(sed -n 's/^@appearance *//p' "$test" | head -1) in
		light) args+=(-NSRequiresAquaSystemAppearance YES) ;;
		dark) args+=(-AppleInterfaceStyle Dark) ;;
	esac

	parts=$(mktemp -d)
	awk -v dir="$parts" '/^@relaunch/ { n++; next } { print > (dir "/" n+0) }' "$test"

	echo "# $name"
	result=pass
	launch=0
	while [ -f "$parts/$launch" ]; do
		log="$logs/$name.$launch.log"
		NETHACKOPTIONS="name:uitest,!legacy${tutorial}${options:+,$options}" \
		NETHACK_TEST_SCRIPT="$(cat "$parts/$launch")" \
		NETHACK_TEST_DIR="$name" \
		NETHACK_TEST_CONFIG="$(sed -n 's/^@config *//p' "$test")" \
		NETHACK_TEST_FRESH=$([ "$launch" -eq 0 ] && echo 1 || echo 0) \
			perl -e 'alarm shift; exec @ARGV' "$timeout" "$app" "${args[@]}" > "$log" 2> "$log.stderr"
		code=$?
		grep -E '^(ok|not ok|Bail out|#)' "$log" | sed 's/^/    /'
		if [ $code -ne 0 ] || grep -q '^not ok' "$log"; then
			[ $code -eq 142 ] && echo "    timed out after ${timeout}s"
			echo "    exit code $code; stderr in $log.stderr"
			result=fail
			break
		fi
		launch=$((launch + 1))
	done
	rm -rf "$parts"
	[ $result = fail ] && failed+=("$name")
done

if [ ${#failed[@]} -gt 0 ]; then
	echo "FAILED: ${failed[*]}"
	exit 1
fi
echo "All UI tests passed."
