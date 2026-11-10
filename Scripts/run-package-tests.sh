#!/bin/bash
# Runs the package suite with a hang watchdog. A starved Swift concurrency pool stalls every test
# without output, so after the deadline this samples the test process, prints only frames from our
# modules and the kernel calls they block in, then stops the run with a failure.
set -u
deadline="${MACKOPIA_TEST_DEADLINE_SECONDS:-900}"
swift test --package-path MacKopiaKit "$@" &
tests=$!
(
    sleep "$deadline"
    echo "::error::Package tests still running after ${deadline}s; sampling for blocked threads"
    for pid in $(pgrep -f swiftpm-testing-helper) $(pgrep -f 'MacKopiaKitPackageTests'); do
        report="${RUNNER_TEMP:-/tmp}/mackopia-hang-$pid.txt"
        sample "$pid" 3 -file "$report" > /dev/null 2>&1 || continue
        awk '/Call graph:/,/Total number in stack/' "$report" \
            | grep -E 'Thread_|\(in (FoundationTests|BackupEngine|BackupDomain|KopiaCLI|KopiaServer|Persistence|Secrets|SystemIntegration|AgentProtocol)\)|\(in libsystem_kernel\.dylib\)|\(in Foundation\) ' \
            | cut -c1-240 | head -400
    done
    pkill -f swiftpm-testing-helper
    kill "$tests" 2> /dev/null
) &
watchdog=$!
wait "$tests"
status=$?
kill "$watchdog" 2> /dev/null
wait "$watchdog" 2> /dev/null
exit "$status"
