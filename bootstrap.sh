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
import pathlib, sys, zipfile, hashlib
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
known_bundle = False
candidates = list((stage/'repository').glob('*/Cargo.toml'))
if not candidates:
    bundles = list((stage/'repository').glob('*/ALIREZATUNEL*.zip'))
    if len(bundles) != 1:
        raise SystemExit('Upload one ALIREZATUNEL ZIP next to bootstrap.sh in the GitHub repository root, or upload the extracted project files there.')
    known_bundle = hashlib.sha256(bundles[0].read_bytes()).hexdigest() == 'efe9eff8db2ad313a3950c0d7f4d715af974c0cd93bbae90e09c7efa13064196'
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
# The recognized ZIP is the previously validated source + production web bundle.
# Unknown/edited bundles must rebuild the web UI rather than assume it is current.
if known_bundle:
    web = root/'panel/web'
    files = [p for folder in ['src', 'dist'] for p in (web/folder).rglob('*')
             if p.is_file() and p != web/'dist/source.sha256']
    files += [web/p for p in ['index.html','package.json','package-lock.json','vite.config.ts','tsconfig.json']]
    manifest = ''.join(hashlib.sha256(p.read_bytes()).hexdigest()+'  '+p.relative_to(web).as_posix()+'\n'
                       for p in sorted(files,key=lambda p:p.relative_to(web).as_posix()))
    (web/'dist/source.sha256').write_text(manifest)
(stage/'source-path').write_text(str(root))
print('ALIREZATUNEL source layout validated.')
PY
source_root=$(cat "$stage/source-path")
legacy_build_sum=$(sha256sum "$source_root/scripts/build-alirezatunel.sh")
legacy_build_sha=${legacy_build_sum%% *}
if [[ $legacy_build_sha == 6b0cd81f029482e85040ca869c460318b5a87979118e8b2278e4763b7941d57b ]]; then
  cat > "$source_root/scripts/build-alirezatunel.sh" <<'ALIREZATUNEL_BUILD_SCRIPT'
#!/usr/bin/env bash
set -euo pipefail
project_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$project_root"
for tool in cargo go; do
  command -v "$tool" >/dev/null || { echo "Missing build dependency: $tool" >&2; exit 1; }
done
if [[ -s panel/web/dist/index.html && -s panel/web/dist/source.sha256 ]] && \
    (cd panel/web && sha256sum -c dist/source.sha256 --status); then
  echo 'Using the verified, prebuilt web interface.'
else
  for tool in node npm; do
    command -v "$tool" >/dev/null || { echo "Missing web-build dependency: $tool" >&2; exit 1; }
  done
  npm --prefix panel/web ci --no-audit --no-fund
  npm --prefix panel/web run build
  (
    cd panel/web
    { find src dist -type f ! -path dist/source.sha256 -print0 | LC_ALL=C sort -z | xargs -0 sha256sum;
      sha256sum index.html package.json package-lock.json vite.config.ts tsconfig.json;
    } > dist/source.sha256
  )
fi
jobs="${ALIREZATUNEL_BUILD_JOBS:-}"
if [[ -z $jobs ]]; then
  cpus=$(getconf _NPROCESSORS_ONLN 2>/dev/null || echo 1)
  [[ $cpus =~ ^[1-9][0-9]*$ ]] || cpus=1
  available_kb=$(awk '/MemAvailable:/ {print $2; exit}' /proc/meminfo 2>/dev/null || true)
  [[ $available_kb =~ ^[0-9]+$ ]] || available_kb=1048576
  if [[ -r /sys/fs/cgroup/memory.max && -r /sys/fs/cgroup/memory.current ]]; then
    limit=$(cat /sys/fs/cgroup/memory.max)
    used=$(cat /sys/fs/cgroup/memory.current)
    if [[ $limit =~ ^[0-9]+$ && $used =~ ^[0-9]+$ ]] && (( limit > used )); then
      remaining_kb=$(( (limit - used) / 1024 ))
      (( available_kb <= remaining_kb )) || available_kb=$remaining_kb
    fi
  fi
  jobs=$(( available_kb / 786432 ))
  (( jobs >= 1 )) || jobs=1
  (( jobs <= cpus )) || jobs=$cpus
  (( jobs <= 4 )) || jobs=4
fi
[[ $jobs =~ ^[1-9][0-9]*$ ]] && (( jobs <= 64 )) || { echo 'ALIREZATUNEL_BUILD_JOBS must be 1..64.' >&2; exit 1; }
export CARGO_TARGET_DIR="${CARGO_TARGET_DIR:-$project_root/target}"
mkdir -p "$CARGO_TARGET_DIR"
CARGO_TARGET_DIR="$(cd "$CARGO_TARGET_DIR" && pwd)"
echo "Building optimized native programs with $jobs parallel job(s); cache: $CARGO_TARGET_DIR"
echo 'The final link can take several minutes without changing the progress counter.'
KARIZ_BUILD_VERSION=2.5.1-alirezatunel.1 cargo build --release --locked --workspace --jobs "$jobs"
mkdir -p build
cp "$CARGO_TARGET_DIR/release/kariz" build/kariz
cp "$CARGO_TARGET_DIR/release/kariz-panel" build/kariz-panel
(
  cd engines/backpack
  GOMAXPROCS="$jobs" go build -p "$jobs" -trimpath -buildvcs=false -o "$project_root/build/alirezatunel-backpack" .
)
cd build
sha256sum kariz kariz-panel alirezatunel-backpack > SHA256SUMS
echo "ALIREZATUNEL built successfully. Run: sudo bash install.sh panel (from the project root)."
ALIREZATUNEL_BUILD_SCRIPT
fi
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
node_bin=""
if [[ -s "$source_root/panel/web/dist/index.html" && -s "$source_root/panel/web/dist/source.sha256" ]] && \
    (cd "$source_root/panel/web" && sha256sum -c dist/source.sha256 --status); then
  echo 'Verified web bundle is included; Node.js download and web compilation are unnecessary.'
else
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
  node_bin="$toolchain_dir/$node_folder/bin"
fi
export CARGO_HOME="$toolchain_dir/cargo"
export RUSTUP_HOME="$toolchain_dir/rustup"
export GOROOT="$go_root/go"
export PATH="$CARGO_HOME/bin:$GOROOT/bin${node_bin:+:$node_bin}:$PATH"
export CARGO_PROFILE_RELEASE_LTO=thin
export CARGO_PROFILE_RELEASE_CODEGEN_UNITS=8
export CARGO_TARGET_DIR=/opt/alirezatunel/cache/rust-target
export GOCACHE=/opt/alirezatunel/cache/go-build
export GOPATH=/opt/alirezatunel/cache/go-modules
mkdir -p "$CARGO_TARGET_DIR" "$GOCACHE" "$GOPATH"
if [[ ! -x "$CARGO_HOME/bin/rustup" ]]; then
  download https://sh.rustup.rs "$stage/rustup-init.sh"
  sh "$stage/rustup-init.sh" -y --profile minimal --no-modify-path --default-toolchain stable
elif ! rustup run stable rustc --version >/dev/null 2>&1; then
  rustup toolchain install stable --profile minimal
  rustup default stable
else
  echo 'Using the existing stable Rust toolchain.'
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
