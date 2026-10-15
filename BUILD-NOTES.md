# Build scope

The application and vendored BackPack source remain unchanged by this installer update. The default Rust features (QUIC, KCP and mimalloc), embedded UI and complete Go engine are included. Rust uses release opt-level 3, ThinLTO and eight codegen units. Executables target Linux musl with crt-static; Go uses CGO_ENABLED=0. The x86_64 musl static PIE suppresses a redundant PT_INTERP entry (after verifying there are no DT_NEEDED libraries), matching the linker option --no-dynamic-linker. Static executables eliminate a requirement to install Rust/Go/Node or a matching libc on the VPS.

This packaging change does not claim faster traffic throughput or a fixed installation time. Installation time depends on downloads and any missing OS runtime packages. A 1 GiB VPS installation/performance benchmark has not been performed in this environment.

The x86_64 executables are smoke tested on the build host. ARM64 binaries are cross compiled and checked for architecture, static linkage and checksum; this host cannot execute ARM64 binaries. Full systemd installation and privileged L3/raw packet operation require validation on the target VPS.

Corresponding source and upstream licenses are included in ALIREZATUNEL-SOURCE.zip; source licenses and notices also accompany each runtime bundle.
