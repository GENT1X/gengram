#!/usr/bin/env bash
set -euo pipefail

ABI=arm64-v8a
API=24
NDK="${ANDROID_NDK_LATEST_HOME:-${ANDROID_NDK_HOME:?}}"
ROOT="$(pwd)"
OUT="$ROOT/android/app/src/main/jniLibs/$ABI"
TOOLCHAIN="$NDK/toolchains/llvm/prebuilt/linux-x86_64"

mkdir -p "$ROOT/_tdbuild" "$OUT"
cd "$ROOT/_tdbuild"

curl -fsSL https://www.openssl.org/source/openssl-3.0.15.tar.gz -o openssl.tar.gz
tar xf openssl.tar.gz
(
  cd openssl-3.0.15
  export ANDROID_NDK_ROOT="$NDK"
  export PATH="$TOOLCHAIN/bin:$PATH"
  ./Configure android-arm64 -D__ANDROID_API__=$API no-shared no-tests no-ui-console --prefix="$ROOT/_tdbuild/openssl"
  make -j"$(nproc)" build_libs
  make install_dir=. install_dev >/dev/null 2>&1 || make install_sw
)
SSL="$ROOT/_tdbuild/openssl"

git clone --depth 1 https://github.com/tdlib/td.git
cd td
mkdir host
(cd host && cmake -DCMAKE_BUILD_TYPE=Release .. && cmake --build . --target prepare_cross_compiling -j"$(nproc)")

mkdir build-android
cd build-android
cmake .. \
  -DCMAKE_TOOLCHAIN_FILE="$NDK/build/cmake/android.toolchain.cmake" \
  -DANDROID_ABI=$ABI -DANDROID_PLATFORM=android-$API \
  -DCMAKE_BUILD_TYPE=Release \
  -DOPENSSL_ROOT_DIR="$SSL" \
  -DOPENSSL_INCLUDE_DIR="$SSL/include" \
  -DOPENSSL_CRYPTO_LIBRARY="$SSL/lib/libcrypto.a" \
  -DOPENSSL_SSL_LIBRARY="$SSL/lib/libssl.a" \
  -DOPENSSL_USE_STATIC_LIBS=TRUE
cmake --build . --target tdjson -j3

"$TOOLCHAIN/bin/llvm-strip" libtdjson.so
cp libtdjson.so "$OUT/libtdjson.so"
ls -la "$OUT"
