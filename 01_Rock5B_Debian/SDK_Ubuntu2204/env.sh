export RK3588_SDK="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
export CC=/usr/bin/aarch64-linux-gnu-gcc
export CXX=/usr/bin/aarch64-linux-gnu-g++
export AR=/usr/bin/aarch64-linux-gnu-ar
export RANLIB=/usr/bin/aarch64-linux-gnu-ranlib
export STRIP=/usr/bin/aarch64-linux-gnu-strip
export PKG_CONFIG="$RK3588_SDK/bin/rk3588-pkg-config"
unset CPATH C_INCLUDE_PATH CPLUS_INCLUDE_PATH LIBRARY_PATH LD_LIBRARY_PATH
unset CFLAGS CXXFLAGS CPPFLAGS LDFLAGS CMAKE_PREFIX_PATH
unset PKG_CONFIG_PATH PKG_CONFIG_LIBDIR PKG_CONFIG_SYSROOT_DIR
