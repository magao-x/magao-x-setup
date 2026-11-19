#!/bin/bash
# Rust toolchain with the wasm32-unknown-unknown target, plus wasm-pack and
# the helpers it would otherwise download per-user into ~/.cache/.wasm-pack.
# Uses the official standalone installers (not rustup) so the toolchain lands
# in /usr/local for every user, including root under sudo, with no env vars.
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source $DIR/../_common.sh
set -uo pipefail

RUST_VERSION=1.100.0
WASM_PACK_VERSION=0.15.1
# must exactly match the wasm-bindgen crate version in sup's Cargo.lock files,
# or wasm-pack ignores this one and downloads its own
WASM_BINDGEN_VERSION=0.2.108
BINARYEN_VERSION=133

arch=$(uname -m)
RUST_PREFIX=/usr/local

mkdir -p /opt/MagAOX/vendor/rust || exit 1
cd /opt/MagAOX/vendor/rust || exit 1

# The combined rust-* installer has rustc, cargo, clippy, rustfmt, and the
# native (host) std, so the x86_64/aarch64 toolchain comes along; rust-std-*
# adds the wasm32 target on top
if [[ "$($RUST_PREFIX/bin/rustc --version 2>/dev/null)" != "rustc $RUST_VERSION "* ]]; then
    if [[ -x $RUST_PREFIX/lib/rustlib/uninstall.sh ]]; then
        $SUDO $RUST_PREFIX/lib/rustlib/uninstall.sh || exit 1
    fi
    for component in rust-$RUST_VERSION-$arch-unknown-linux-gnu rust-std-$RUST_VERSION-wasm32-unknown-unknown; do
        _cached_fetch https://static.rust-lang.org/dist/$component.tar.xz $component.tar.xz || exit 1
        rm -rf $component || exit 1
        tar xf $component.tar.xz || exit 1
    done
    $SUDO ./rust-$RUST_VERSION-$arch-unknown-linux-gnu/install.sh \
        --prefix=$RUST_PREFIX --without=rust-docs --disable-ldconfig || exit 1
    $SUDO ./rust-std-$RUST_VERSION-wasm32-unknown-unknown/install.sh \
        --prefix=$RUST_PREFIX --disable-ldconfig || exit 1
fi

# wasm-pack
if [[ "$($RUST_PREFIX/bin/wasm-pack --version 2>/dev/null)" != "wasm-pack $WASM_PACK_VERSION" ]]; then
    name=wasm-pack-v$WASM_PACK_VERSION-$arch-unknown-linux-musl
    _cached_fetch https://github.com/rustwasm/wasm-pack/releases/download/v$WASM_PACK_VERSION/$name.tar.gz $name.tar.gz || exit 1
    tar xf $name.tar.gz || exit 1
    $SUDO install -m 755 $name/wasm-pack $RUST_PREFIX/bin/wasm-pack || exit 1
fi

# wasm-bindgen CLI
if [[ "$($RUST_PREFIX/bin/wasm-bindgen --version 2>/dev/null)" != "wasm-bindgen $WASM_BINDGEN_VERSION"* ]]; then
    name=wasm-bindgen-$WASM_BINDGEN_VERSION-$arch-unknown-linux-musl
    _cached_fetch https://github.com/wasm-bindgen/wasm-bindgen/releases/download/$WASM_BINDGEN_VERSION/$name.tar.gz $name.tar.gz || exit 1
    tar xf $name.tar.gz || exit 1
    for tool in wasm-bindgen wasm-bindgen-test-runner wasm2es6js; do
        $SUDO install -m 755 $name/$tool $RUST_PREFIX/bin/$tool || exit 1
    done
fi

# wasm-opt from binaryen, kept in its own folder because it ships a shared lib
name=binaryen-version_$BINARYEN_VERSION
if [[ ! -x $name/bin/wasm-opt ]]; then
    _cached_fetch https://github.com/WebAssembly/binaryen/releases/download/version_$BINARYEN_VERSION/$name-$arch-linux.tar.gz $name-$arch-linux.tar.gz || exit 1
    tar xf $name-$arch-linux.tar.gz || exit 1
fi
$SUDO ln -sfv $(realpath ./$name/bin/wasm-opt) $RUST_PREFIX/bin/wasm-opt || exit 1

$RUST_PREFIX/bin/rustc --print target-libdir --target wasm32-unknown-unknown | xargs test -d || exit_with_error "wasm32 target missing"
log_success "Installed $($RUST_PREFIX/bin/rustc --version), $($RUST_PREFIX/bin/wasm-pack --version), $($RUST_PREFIX/bin/wasm-bindgen --version), $($RUST_PREFIX/bin/wasm-opt --version)"
