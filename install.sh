#!/usr/bin/env bash
set -euo pipefail
mode=${1:-panel}
case "$mode" in panel|agent) ;; *) echo 'Usage: bash bootstrap.sh panel|agent' >&2; exit 2;; esac
[[ $EUID == 0 ]] || { echo 'Run as root.' >&2; exit 1; }
[[ $(uname -s) == Linux ]] || { echo 'Linux required.' >&2; exit 1; }
command -v systemctl >/dev/null || { echo 'systemd required.' >&2; exit 1; }
case $(uname -m) in x86_64) arch=amd64;; aarch64|arm64) arch=arm64;; *) echo 'Unsupported CPU architecture.' >&2; exit 1;; esac
base=https://raw.githubusercontent.com/alirezachatgpt97-coder/ALIREZA-TUUNEL/main
asset=ALIREZATUNEL-linux-$arch.tar.gz
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
if ! command -v curl >/dev/null || ! command -v python3 >/dev/null; then
 command -v apt-get >/dev/null || { echo 'Install curl, ca-certificates and python3, then retry.' >&2; exit 1; }
 apt-get update
 DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends curl ca-certificates python3
fi
fetch() { curl --fail --location --retry 3 --connect-timeout 20 --output "$2" "$1"; }
echo "Downloading prebuilt ALIREZATUNEL ($arch); no compilation required."
fetch "$base/SHA256SUMS" "$work/SHA256SUMS"
fetch "$base/$asset" "$work/$asset"
python3 - "$work" "$asset" <<'PY'
import hashlib,pathlib,sys,tarfile
root=pathlib.Path(sys.argv[1]); name=sys.argv[2]
entries=[line.split() for line in (root/'SHA256SUMS').read_text().splitlines() if line.strip()]
match=[e[0] for e in entries if len(e)==2 and e[1].lstrip('*')==name]
if len(match)!=1 or hashlib.sha256((root/name).read_bytes()).hexdigest()!=match[0]:
 raise SystemExit('Package checksum failed; installation stopped.')
out=root/'runtime'; out.mkdir()
with tarfile.open(root/name,'r:gz') as tar:
 for m in tar.getmembers():
  p=pathlib.PurePosixPath(m.name)
  if p.is_absolute() or '..' in p.parts or not (m.isfile() or m.isdir()):
   raise SystemExit('Unsafe package entry; installation stopped.')
 tar.extractall(out,filter='data') if sys.version_info >= (3,12) else tar.extractall(out)
PY
missing=()
command -v ip >/dev/null || missing+=(iproute2)
command -v iptables >/dev/null || missing+=(iptables)
command -v ping >/dev/null || missing+=(iputils-ping)
command -v modprobe >/dev/null || missing+=(kmod)
command -v sysctl >/dev/null || missing+=(procps)
if (( ${#missing[@]} )); then
 command -v apt-get >/dev/null || { echo "Install runtime dependencies: ${missing[*]}" >&2; exit 1; }
 apt-get update
 DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends "${missing[@]}"
fi
bash "$work/runtime/install.sh" "$mode" --no-build
