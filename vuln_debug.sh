#!/usr/bin/env bash

set -euo pipefail

SRC="vuln.c"
BIN_SSP="vuln_ssp" # w stack protector
BIN_NOSSP="vuln_nossp"

# 1. compile both ssp and nossp
echo "[*] Compiling $SRC -> $BIN_SSP (stack protector)"
cc -g -O0 "$SRC" -o "$BIN_SSP"

echo "[*] Compiling $SRC -> $BIN_NOSSP (NO stack protector)"
cc -g -O0 -fno-stack-protector "$SRC" -o "$BIN_NOSSP"

# 2. Prepare payloads
SMALL_PAYLOAD="payload_small.txt"
OVERFLOW_PAYLOAD="payload_overflow.txt"

printf "small\n" > "$SMALL_PAYLOAD"

python3 - <<'PY' > "$OVERFLOW_PAYLOAD"
payload = b"A"*128 + b"\n" # 128 bytes of A

import sys
sys.stdout.buffer.write(payload)
PY

# absolute paths to avoid errors
# ABS_OVERFLOW="$(pwd)/$OVERFLOW_PAYLOAD"
# ABS_SRC="$(pwd)/$SRC"

ABS_OVERFLOW="$(pwd)/payload_overflow.txt"
ABS_SRC="$(pwd)/vuln.c"

perl -0777 -pe "s|breakpoint set --file .* --line (\\d+)|breakpoint set --file \"$ABS_SRC\" --line \$1|s; s|process lauch|process launch|g" -i.bak lldb_commands.txt
perl -0777 -pe "s|process launch .*|process launch --stdin \"$ABS_OVERFLOW\"|s" -i lldb_commands.txt


echo "[*] Payloads written: $SMALL_PAYLOAD (short), $OVERFLOW_PAYLOAD (overflow)"
echo "[*] ABS_OVERFLOW = $ABS_OVERFLOW"
echo "[*] ABS_SRC = $ABS_SRC"


# 3. compute source line number to stop after input
LINE_AFTER_INPUT=$(grep -n "You entered:" "$SRC" | head -n1 | cut -d: -f1 || true)
if [[ -z "$LINE_AFTER_INPUT" ]]; then
  echo "[-] Could not find 'You entered:' in $SRC. Please check the source file."
  exit 1
fi 
echo "[*] Found 'You entered:' at $SRC:$LINE_AFTER_INPUT -- will set breakpoint there."

# 4. Create lldb command script to automate debugging
LLDB_CMDS="lldb_commands.txt"
cat > "$LLDB_CMDS" << EOF
breakpoint set --name vuln
breakpoint set --file "$ABS_SRC" --line $LINE_AFTER_INPUT
process launch --stdin "$ABS_OVERFLOW"
frame info
frame variable p.buff p.target
expr (void*)p.buff
expr (void*)&p.target
expr (long)((char*)&p.target - (char*)p.buff)
expr/x (long)((char*)&p.target - (char*)p.buff)
expr/x p.target
memory read --format byte --size 1 --count 64 (void*)p.buff
memory read --format hex --size 4 --count 8 (void*)p.buff
continue
quit
EOF

echo "[*] LLDB script written to $LLDB_CMDS"

# 5. run script lldb session with no ssp
echo "[*] Starting lldb automated session (NO STACK PROTECTION):"
echo "      -> binary: ./$BIN_NOSSP"
echo "      -> lldb script: ./$LLDB_CMDS"
echo

# NO_SSP run
lldb -s "$LLDB_CMDS" -- "./$BIN_NOSSP"

echo
echo "[*] Automated NO Stack Protection lldb finished"

echo
echo
echo "[*] Starting lldb automated session (STACK PROTECTION):"
echo "      -> binary: ./$BIN_SSP"
echo "      -> lldb script: ./$LLDB_CMDS"
echo

# SSP run
lldb -s "$LLDB_CMDS" -- "./$BIN_SSP"

echo
echo "[*] Automated STACK PROTECTION lldb finished"