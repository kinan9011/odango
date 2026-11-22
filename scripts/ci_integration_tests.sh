#!/usr/bin/env bash

# SPDX-FileCopyrightText: 2019-Present Christian Kußowski
# SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
#
# SPDX-License-Identifier: AGPL-3.0-or-later

# CI only: runs the integration flows on the emulator the workflow started.
#
# ponytail: the emulator process crashes in about half the CI runs, with any
# build, and takes adb with it. When the device is gone after a run, start a
# fresh emulator and homeserver and run again. A run that fails with the device
# still there is a real failure and ends the job at once. Every flow has to
# pass in one run: a device that drops mid-run still prints the flows it did
# run as passed, hence the flow count.

set -u

attempts=4
expected=$(grep -c '^    flow(' integration_test/mobile_test.dart)

device_ready() {
    [ "$(timeout 20 adb shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')" = 1 ]
}

restart_emulator() {
    timeout 20 adb emu kill >/dev/null 2>&1
    pkill -f qemu-system >/dev/null 2>&1
    adb kill-server >/dev/null 2>&1
    adb start-server >/dev/null 2>&1
    nohup "$ANDROID_HOME/emulator/emulator" -avd test -no-snapshot-save -no-window \
        -wipe-data -accel on -gpu swiftshader_indirect -noaudio -no-boot-anim \
        -camera-back none >emulator.log 2>&1 &
    timeout 300 adb wait-for-device || return 1
    for _ in $(seq 60); do
        device_ready && return 0
        sleep 5
    done
    return 1
}

: > integration_test.log
for attempt in $(seq "$attempts"); do
    timeout 35m flutter test integration_test/mobile_test.dart 2>&1 | tee attempt.log
    cat attempt.log >> integration_test.log
    grep -qE "^🎉 $expected tests passed" attempt.log && exit 0

    adb devices
    free -m
    sudo dmesg | grep -iE 'oom|killed process' | tail -n 20
    pgrep -l qemu
    if device_ready; then
        echo "::error::A flow failed with the emulator still running."
        break
    fi
    echo "::warning::The emulator was gone after attempt $attempt of $attempts."
    [ "$attempt" = "$attempts" ] && break
    restart_emulator || break
    ./scripts/prepare_integration_test.sh || break
done

timeout 30s adb logcat -d > logcat.txt
exit 1
