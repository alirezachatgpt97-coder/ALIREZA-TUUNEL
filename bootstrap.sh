#!/usr/bin/env bash
# ALIREZATUNEL one-command installer for alirezachatgpt97-coder/ALIREZA-TUUNEL.
set -Eeuo pipefail
REPOSITORY=alirezachatgpt97-coder/ALIREZA-TUUNEL
REF=main
MODE=panel
CHECK_SOURCE=0
PUBLIC_HOST=""
JOIN_CODE=""
usage() {
  cat <<'HELP'
ALIREZATUNEL — Ubuntu/Debian with systemd
  bash bootstrap.sh [panel|agent] [--host IP_OR_DOMAIN] [--join JOIN_CODE]
  bash bootstrap.sh --check-source

Upload ALIREZATUNEL-GITHUB.zip and bootstrap.sh to the repository root on main.
Alternatively, upload the extracted project files to the repository root.
--check-source downloads and validates the source layout without installing it.
HELP
}
die() { echo "ERROR: $*" >&2; exit 1; }
while (($#)); do
  case "$1" in
    panel|agent) MODE="$1"; shift ;;
    --host) (($# >= 2)) || die '--host needs an IP or domain'; PUBLIC_HOST="$2"; shift 2 ;;
    --join) (($# >= 2)) || die '--join needs a code'; JOIN_CODE="$2"; MODE=agent; shift 2 ;;
    --check-source) CHECK_SOURCE=1; shift ;;
    --help|-h) usage; exit 0 ;;
    *) die "Unknown argument: $1" ;;
  esac
done
if (( ! CHECK_SOURCE )); then
  [[ $EUID -eq 0 ]] || die 'Run as root, or use sudo bash bootstrap.sh.'
  [[ $(uname -s) == Linux ]] || die 'Linux is required.'
  [[ -r /etc/os-release ]] || die 'Cannot detect this distribution.'
  . /etc/os-release
  case "$ID" in ubuntu|debian) ;; *) die 'Automatic installation supports Ubuntu/Debian only.' ;; esac
  command -v systemctl >/dev/null || die 'systemd is required.'
  export DEBIAN_FRONTEND=noninteractive
  apt-get update
  apt-get install -y --no-install-recommends ca-certificates curl python3 unzip xz-utils \
    build-essential pkg-config git iproute2 iptables iputils-ping
fi
for tool in curl python3; do command -v "$tool" >/dev/null || die "Missing download dependency: $tool"; done
stage=$(mktemp -d "${TMPDIR:-/tmp}/alirezatunel-install.XXXXXXXX")
trap 'rm -rf -- "$stage"' EXIT
trap 'echo "Installation stopped at line $LINENO. Existing settings were not intentionally deleted." >&2' ERR
download() { curl --fail --location --show-error --silent --retry 3 --connect-timeout 20 --max-time 1200 "$1" -o "$2"; }
echo "Downloading $REPOSITORY ($REF)..."
download "https://codeload.github.com/$REPOSITORY/zip/refs/heads/$REF" "$stage/repository.zip"
python3 - "$stage" <<'PY'
import pathlib, sys, zipfile
stage = pathlib.Path(sys.argv[1])
def extract(source, destination):
    destination.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(source) as archive:
        for item in archive.infolist():
            path = pathlib.PurePosixPath(item.filename)
            if path.is_absolute() or '..' in path.parts or '\\' in item.filename:
                raise SystemExit('Unsafe path in project archive')
            if (item.external_attr >> 16) & 0o170000 == 0o120000:
                raise SystemExit('Symbolic links in project archive are not supported')
        archive.extractall(destination)
extract(stage/'repository.zip', stage/'repository')
candidates = list((stage/'repository').glob('*/Cargo.toml'))
if not candidates:
    bundles = list((stage/'repository').glob('*/ALIREZATUNEL*.zip'))
    if len(bundles) != 1:
        raise SystemExit('Upload one ALIREZATUNEL ZIP next to bootstrap.sh in the GitHub repository root, or upload the extracted project files there.')
    extract(bundles[0], stage/'package')
    candidates = ([stage/'package'/'Cargo.toml'] if (stage/'package'/'Cargo.toml').is_file() else list((stage/'package').glob('*/Cargo.toml')))
if len(candidates) != 1:
    raise SystemExit('The archive must contain exactly one ALIREZATUNEL project root')
root = candidates[0].parent
required = ['install.sh', 'scripts/build-alirezatunel.sh', 'scripts/alirezatunel-join',
            'panel/src/backpack.rs', 'engines/backpack/go.mod', 'engines/backpack/main.go',
            'systemd/alirezatunel-backpack@.service']
for name in required:
    if not (root/name).is_file():
        raise SystemExit('Incomplete project: missing '+name)
(stage/'source-path').write_text(str(root))
print('ALIREZATUNEL source layout validated.')
PY
source_root=$(cat "$stage/source-path")
if (( CHECK_SOURCE )); then echo 'Source check passed. No installation was performed.'; exit 0; fi

case "$(uname -m)" in
  x86_64) go_arch=amd64; node_arch=x64 ;;
  aarch64|arm64) go_arch=arm64; node_arch=arm64 ;;
  *) die 'This installer supports x86_64 and aarch64/arm64.' ;;
esac
toolchain_dir=/opt/alirezatunel/toolchains
mkdir -p "$toolchain_dir"
go_version=$(python3 - "$source_root/engines/backpack/go.mod" <<'PY'
import re,sys
match=re.search(r'^go (\d+\.\d+(?:\.\d+)?)$',open(sys.argv[1]).read(),re.M)
if not match:raise SystemExit('Cannot determine the required Go version')
print(match.group(1))
PY
)
go_root="$toolchain_dir/go-$go_version"
if [[ ! -x "$go_root/go/bin/go" ]]; then
  echo "Installing verified Go $go_version for $go_arch..."
  download 'https://go.dev/dl/?mode=json&include=all' "$stage/go-downloads.json"
  go_file="go$go_version.linux-$go_arch.tar.gz"
  go_checksum=$(python3 - "$stage/go-downloads.json" "$go_file" <<'PY'
import json,re,sys
for release in json.load(open(sys.argv[1])):
    for file in release['files']:
        if file['filename']==sys.argv[2]:
            sha=file['sha256']
            if not re.fullmatch('[a-f0-9]{64}',sha):raise SystemExit('Invalid checksum')
            print(sha);raise SystemExit(0)
raise SystemExit('Required Go release is not listed by go.dev')
PY
)
  download "https://go.dev/dl/$go_file" "$stage/$go_file"
  printf '%s  %s\n' "$go_checksum" "$stage/$go_file" | sha256sum -c -
  mkdir -p "$stage/go-unpack"
  tar -xzf "$stage/$go_file" -C "$stage/go-unpack"
  mv "$stage/go-unpack" "$go_root"
fi
echo 'Installing a verified Node.js 22 toolchain...'
download 'https://nodejs.org/dist/latest-v22.x/SHASUMS256.txt' "$stage/node-checksums"
read -r node_checksum node_file < <(python3 - "$stage/node-checksums" "$node_arch" <<'PY'
import re,sys
pattern=re.compile(r'([a-f0-9]{64})\s+(node-v22\.\d+\.\d+-linux-'+re.escape(sys.argv[2])+r'\.tar\.xz)$')
for line in open(sys.argv[1]):
    match=pattern.fullmatch(line.strip())
    if match:print(match.group(1),match.group(2));break
else:raise SystemExit('Node.js 22 archive not found')
PY
)
[[ -n ${node_file:-} && -n ${node_checksum:-} ]] || die 'Invalid Node.js checksum manifest.'
node_folder=${node_file%.tar.xz}
if [[ ! -x "$toolchain_dir/$node_folder/bin/node" ]]; then
  download "https://nodejs.org/dist/latest-v22.x/$node_file" "$stage/$node_file"
  printf '%s  %s\n' "$node_checksum" "$stage/$node_file" | sha256sum -c -
  tar -xJf "$stage/$node_file" -C "$toolchain_dir"
fi
export CARGO_HOME="$toolchain_dir/cargo"
export RUSTUP_HOME="$toolchain_dir/rustup"
export GOROOT="$go_root/go"
export PATH="$CARGO_HOME/bin:$GOROOT/bin:$toolchain_dir/$node_folder/bin:$PATH"
if [[ ! -x "$CARGO_HOME/bin/rustup" ]]; then
  download https://sh.rustup.rs "$stage/rustup-init.sh"
  sh "$stage/rustup-init.sh" -y --profile minimal --no-modify-path --default-toolchain stable
else
  rustup toolchain install stable --profile minimal
  rustup default stable
fi
install_id=$(date -u +%Y%m%dT%H%M%SZ)-$$
project_dir="/opt/alirezatunel/sources/$install_id"
mkdir -p "$project_dir"
cp -a "$source_root/." "$project_dir/"
echo "Building and installing ALIREZATUNEL ($MODE). The first build can take several minutes..."
bash "$project_dir/install.sh" "$MODE"
if [[ $MODE == panel ]]; then
  if [[ -z $PUBLIC_HOST && -t 0 ]]; then read -r -p 'Public IP or domain for the panel login link: ' PUBLIC_HOST; fi
  if [[ -n $PUBLIC_HOST ]]; then
    /usr/local/bin/kariz-panel login-link --host "$PUBLIC_HOST"
  else
    echo 'Get your login link: sudo kariz-panel login-link --host YOUR_PUBLIC_IP'
  fi
else
  if [[ -z $JOIN_CODE && -t 0 ]]; then read -r -p 'Join code from the panel (Enter to connect later): ' JOIN_CODE; fi
  if [[ -n $JOIN_CODE ]]; then /usr/local/bin/alirezatunel-join "$JOIN_CODE"; fi
fi
echo "ALIREZATUNEL installed. Source: $project_dir"
