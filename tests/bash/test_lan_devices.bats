#!/usr/bin/env bats
# ------------------------------------------
# Bats: net-lan-devices in .bash.d/02-utilities/40-lan-devices.sh
# ------------------------------------------
# arp.exe, arp, ip, powershell.exe, wslpath and python3 are stubs on PATH that
# serve fixture output and log their argv.

setup() {
  repo_root="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  HOME="$BATS_TEST_TMPDIR/home"
  mkdir -p "$HOME/.bash.d" "$BATS_TEST_TMPDIR/bin"
  ln -s "$repo_root/.bash.d/lib" "$HOME/.bash.d/lib"
  CALLS="$BATS_TEST_TMPDIR/calls"
  export CALLS
  bin="$BATS_TEST_TMPDIR/bin"
  tools="$BATS_TEST_TMPDIR/tools"
  mkdir -p "$tools"
  local tool
  for tool in awk sort uniq tr sed cat basename wc grep head cut mktemp rm bash env dirname chmod perl; do
    ln -s "$(command -v "$tool")" "$tools/$tool"
  done
  PATH="$bin:$tools"

  cat > "$bin/arp.exe" << 'STUB'
#!/usr/bin/env bash
echo "arp.exe $*" >> "$CALLS"
printf '\r\nInterface: 192.168.1.5 --- 0x8\r\n  Internet Address      Physical Address      Type\r\n'
printf '  192.168.1.20          AA-BB-CC-DD-EE-02     dynamic\r\n'
printf '  192.168.1.1           aa-bb-cc-dd-ee-01     dynamic\r\n'
printf '  192.168.1.9           00-00-00-00-00-00     invalid\r\n'
printf '  192.168.1.255         ff-ff-ff-ff-ff-ff     static\r\n'
printf '  224.0.0.22            01-00-5e-00-00-16     static\r\n'
printf '  239.255.255.250       01-00-5e-7f-ff-fa     static\r\n'
STUB
  cat > "$bin/arp" << 'STUB'
#!/usr/bin/env bash
echo "arp $*" >> "$CALLS"
echo '? (192.168.1.20) at AA:BB:CC:DD:EE:2 on en0 ifscope [ethernet]'
echo '? (192.168.1.1) at aa:bb:cc:dd:ee:1 on en0 ifscope [ethernet]'
echo '? (192.168.1.30) at a:b:c:d:e:f on en0 ifscope [ethernet]'
echo '? (192.168.1.9) at (incomplete) on en0 ifscope [ethernet]'
echo '? (192.168.1.255) at ff:ff:ff:ff:ff:ff on en0 ifscope [ethernet]'
echo '? (224.0.0.251) at 1:0:5e:0:0:fb on en0 ifscope permanent [ethernet]'
STUB
  cat > "$bin/ip" << 'STUB'
#!/usr/bin/env bash
echo "ip $*" >> "$CALLS"
echo '192.168.1.20 dev eth0 lladdr aa:bb:cc:dd:ee:02 REACHABLE'
echo '192.168.1.1 dev eth0 lladdr aa:bb:cc:dd:ee:01 STALE'
echo '192.168.1.9 dev eth0  FAILED'
echo '192.168.1.8 dev eth0  INCOMPLETE'
echo '192.168.1.255 dev eth0 lladdr ff:ff:ff:ff:ff:ff PERMANENT'
echo '224.0.0.1 dev eth0 lladdr 01:00:5e:00:00:01 PERMANENT'
STUB
  cat > "$bin/powershell.exe" << 'STUB'
#!/usr/bin/env bash
echo "powershell.exe $*" >> "$CALLS"
printf '192.168.1.20\tTvOS/1.0\tupnp:rootdevice\thttp://192.168.1.20:8080/d.xml\r\n'
printf '192.168.1.20\tTvOS/1.0\tssdp:all\thttp://192.168.1.20:8080/e.xml\r\n'
printf '192.168.1.3\t-\tupnp:rootdevice\thttp://192.168.1.3/d.xml\r\n'
printf '192.168.1.3\t-\tupnp:rootdevice\thttp://192.168.1.3/d.xml\r\n'
STUB
  cat > "$bin/wslpath" << 'STUB'
#!/usr/bin/env bash
echo "C:\\win\\$(basename "$2")"
STUB
  cat > "$bin/python3" << 'STUB'
#!/usr/bin/env bash
echo "python3 $*" >> "$CALLS"
printf '192.168.1.7\tSrv/1\tupnp:rootdevice\thttp://192.168.1.7/d.xml\n'
printf '192.168.1.7\tSrv/1\tupnp:rootdevice\thttp://192.168.1.7/\033]0;pwned\007x.xml\n'
STUB
  chmod +x "$bin"/*
  # shellcheck disable=SC1091
  source "$repo_root/.bash.d/02-utilities/39-http-client.sh"
  # shellcheck disable=SC1091
  source "$repo_root/.bash.d/02-utilities/40-lan-devices.sh"
  # shellcheck disable=SC2034
  CB_RED="" CB_BLUE="" C_RESET=""
  # shellcheck disable=SC2317
  mt-help() { echo "help called"; }
  expected_rows=$'192.168.1.1\taa:bb:cc:dd:ee:01\tneighbour\n192.168.1.20\taa:bb:cc:dd:ee:02\tneighbour'
}

@test "WSL reads the Windows host's table and normalises it" {
  OS_FAMILY=wsl run net-lan-devices
  [ "$status" -eq 0 ]
  grep -q 'arp.exe -a' "$CALLS"
  [[ "$output" == *"📡 Neighbours"* ]]
  [[ "$output" == *"$expected_rows"* ]]
  [[ "$output" != *$'\r'* ]]
}

@test "macOS output normalises to the same rows, padding short MAC octets" {
  OS_FAMILY=macos run net-lan-devices
  [ "$status" -eq 0 ]
  grep -q 'arp -an' "$CALLS"
  [[ "$output" == *"$expected_rows"* ]]
}

@test "macOS pads short MAC octets" {
  OS_FAMILY=macos run net-lan-devices
  [[ "$output" == *$'192.168.1.30\t0a:0b:0c:0d:0e:0f\tneighbour'* ]]
}

@test "Linux output normalises to the same rows" {
  OS_FAMILY=linux run net-lan-devices
  [ "$status" -eq 0 ]
  grep -q 'ip -4 neigh show' "$CALLS"
  [[ "$output" == *"$expected_rows"* ]]
}

@test "multicast, broadcast and incomplete entries are dropped on every platform" {
  local family
  for family in wsl macos linux; do
    OS_FAMILY=$family run net-lan-devices
    [[ "$output" != *"224."* && "$output" != *"239."* && "$output" != *".255"* ]]
    [[ "$output" != *"192.168.1.9"* && "$output" != *"192.168.1.8"* ]]
  done
}

@test "rows are sorted numerically by IP" {
  OS_FAMILY=linux run net-lan-devices
  [ "$(grep -n '192.168.1.1\b' <<< "$output" | head -1 | cut -d: -f1)" -lt "$(grep -n '192.168.1.20' <<< "$output" | head -1 | cut -d: -f1)" ]
}

@test "--ssdp on WSL runs the PowerShell script with the timeout and keeps every distinct reply" {
  OS_FAMILY=wsl run net-lan-devices --ssdp
  [ "$status" -eq 0 ]
  grep -qF -- '-TimeoutSeconds 3' "$CALLS"
  grep -qF -- '-Address 239.255.255.250 -Port 1900' "$CALLS"
  grep -qF -- 'win_ssdp_discover.ps1' "$CALLS"
  [[ "$output" == *"🔊 SSDP replies"* ]]
  [[ "$output" == *$'192.168.1.20\tTvOS/1.0\tssdp:all\thttp://192.168.1.20:8080/e.xml'* ]]
  [[ "$output" == *$'192.168.1.20\tTvOS/1.0\tupnp:rootdevice\thttp://192.168.1.20:8080/d.xml'* ]]
  [ "$(grep -c '192.168.1.3' <<< "$output")" -eq 1 ]
  ! grep -q 'python3' "$CALLS"
}

@test "--ssdp on Linux runs the Python script, honours --timeout and strips control characters" {
  OS_FAMILY=linux run net-lan-devices --ssdp --timeout 5
  [ "$status" -eq 0 ]
  grep -qF -- 'ssdp_discover.py --address 239.255.255.250 --port 1900 --timeout 5' "$CALLS"
  [[ "$output" != *$'\033'* ]]
  ! grep -q 'powershell.exe' "$CALLS"
}

@test "an empty section prints a none line" {
  printf '#!/usr/bin/env bash\nexit 0\n' > "$bin/ip"
  OS_FAMILY=linux run net-lan-devices
  [ "$status" -eq 0 ]
  [[ "$output" == *"ℹ️  none"* ]]
}

@test "missing tools exit 1 with the platform's message" {
  rm "$bin/arp.exe"
  OS_FAMILY=wsl run net-lan-devices
  [ "$status" -eq 1 ]
  [[ "$output" == *"arp.exe not found: the LAN neighbour list on WSL comes from the Windows host."* ]]
  rm "$bin/powershell.exe"
  OS_FAMILY=wsl run net-lan-devices --ssdp
  [ "$status" -eq 1 ]
  rm "$bin/ip"
  OS_FAMILY=linux run net-lan-devices
  [ "$status" -eq 1 ]
  [[ "$output" == *"ip not found."* ]]
  rm "$bin/arp"
  OS_FAMILY=macos run net-lan-devices
  [ "$status" -eq 1 ]
  [[ "$output" == *"arp not found."* ]]
}

@test "powershell.exe missing on WSL names the Windows host" {
  rm "$bin/powershell.exe"
  OS_FAMILY=wsl run net-lan-devices --ssdp
  [[ "$output" == *"powershell.exe not found: SSDP discovery from WSL runs through the Windows host."* ]]
}

@test "a failing discovery script exits 1" {
  printf '#!/usr/bin/env bash\nexit 3\n' > "$bin/python3"
  OS_FAMILY=linux run net-lan-devices --ssdp
  [ "$status" -eq 1 ]
  [[ "$output" == *"SSDP discovery failed"* ]]
}

@test "--timeout 0, a non-number and unknown options exit 1 without any call" {
  OS_FAMILY=linux run net-lan-devices --timeout 0
  [ "$status" -eq 1 ]
  OS_FAMILY=linux run net-lan-devices --timeout abc
  [ "$status" -eq 1 ]
  OS_FAMILY=linux run net-lan-devices --bogus
  [ "$status" -eq 1 ]
  [ ! -f "$CALLS" ]
}

@test "-h shows help" {
  run net-lan-devices -h
  [ "$output" = "help called" ]
}
