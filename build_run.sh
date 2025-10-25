#!/usr/bin/env bash

set -u # do not set -e because we want to catch non-zero exits

SRC="vuln.c"
BIN_CANARY="vuln_canary"
BIN_ASAN="vuln_asan"
PAYLOAD="payload_overflow.txt"
LOG_CANARY="vuln_canary.log"
LOG_ASAN="vuln_asan.log"

hdr() { printf "\n================= %s =================\n" "$1"; }

# Sanity
if [[ ! -f "$SRC" ]]; then
    echo "Error: $SRC not found in $(pwd)"
    exit 1
fi

echo "[*] Using source: $(pwd)/$SRC"
echo "[*] GCC version:"
gcc --version | sed -n '1p'

# 1. Create payload (128 bytes of A + newline)
printf 'A%.0s' $(seq 1 128) > "$PAYLOAD"
printf '\n' >> "$PAYLOAD"
echo "[*] Wrote payload to $(pwd)/$PAYLOAD (length: $(wc -c < "$PAYLOAD") bytes)"

# 2. Compile with stack protector (canary)
hdr "Compiling with stack protector -> $BIN_CANARY"
gcc -std=c11 -g -O0 -fstack-protector-all "$SRC" -o "$BIN_CANARY" 2>&1 | tee compile_canary.txt

if [[ -x "$BIN_CANARY" ]]; then
    echo "[*] Built $BIN_CANARY"
else
    echo "[-] Failed to build $BIN_CANARY; see compile_canary.txt"
fi

# 3. Compile with ASan
hdr "Compiling with AddressSanitizer -> $BIN_ASAN"
gcc -std=c11 -g -O1 -fsanitize=address -fno-omit-frame-pointer "$SRC" -o "$BIN_ASAN" 2>&1 | tee compile_asan.txt

if [[ -x "$BIN_ASAN" ]]; then
  echo "[*] Built $BIN_ASAN"
else
  echo "[-] Failed to build $BIN_ASAN; see compile_asan.txt"
fi

run_with_payload() {
    local bin="$1"
    local log="$2"

    hdr "Running $bin (stdout+stderr -> $log)"
    if [[ ! -x "$bin" ]]; then
        echo "[-] Binary $bin not found or not executable"
        return 1
    fi

    # run and catch stdout and stderr
    rm -f "$log"
    ( "./$bin" < "$PAYLOAD" ) > "$log" 2>&1 &
    pid=$!

    # wait up to 10s
    # secs_wait=0
    max_ticks=50
    ticks=0
    while kill -0 "$pid" 2>/dev/null; do
        sleep 0.2
        ticks=$((ticks + 1))

        if (( ticks > max_ticks )); then
            echo "[-] Process $pid still running after $((max_ticks * 2 / 10))s; killing it."
            kill -9 "$pid" 2>/dev/null || true
            break
        fi
    done

    # get exit code
    wait_status=0
    if wait "$pid" 2>/dev/null; then
        wait_status=$?
    else
        # if wait failed, try to read exit status from ps or set to 1
        wait_status=1
    fi

    echo "[*] $bin finished with exit code: $wait_status"
    echo "[*] Log saved to: $(pwd)/$log"
    return 0
}

# 4. Run canary build
run_with_payload "$BIN_CANARY" "$LOG_CANARY" || true

# 5. Run ASan build
run_with_payload "$BIN_ASAN" "$LOG_ASAN" || true

# 6) Brief summaries (tail logs)
hdr "Summary: last 40 lines of $LOG_CANARY"
if [[ -f "$LOG_CANARY" ]]; then
  tail -n 40 "$LOG_CANARY" || true
else
  echo "(no $LOG_CANARY)"
fi

hdr "Summary: last 80 lines of $LOG_ASAN"
if [[ -f "$LOG_ASAN" ]]; then
  tail -n 80 "$LOG_ASAN" || true
else
  echo "(no $LOG_ASAN)"
fi

echo
echo "[*] Done. Logs:"
echo "    $(pwd)/$LOG_CANARY"
echo "    $(pwd)/$LOG_ASAN"