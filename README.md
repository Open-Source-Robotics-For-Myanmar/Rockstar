# Rock 5B Cross-SDK Setup Repository

## Structure
```
rock5b-cross-sdk/
└── 01_setup_crossCompiler/
    ├── install_debian_stable.md       # Install Debian 13 (Trixie) on Rock 5B
    ├── extract_rootfs_for_builder_amd64.md  # Create sysroot for cross-compilation
    └── compiler_test_deploy.md        # Build, deploy, debug workflow
```

## Quick Start

1. **Install Debian on Rock 5B** → Follow `install_debian_stable.md`
2. **Extract sysroot** → Follow `extract_rootfs_for_builder_amd64.md`
3. **Build & debug** → Follow `compiler_test_deploy.md`

## Prerequisites
- Rock 5B with Debian 13 (Trixie) + vendor kernel 6.1
- amd64 host (Debian/Ubuntu) with SSH access to Rock 5B
- Basic CMake/C++ knowledge

## Result
- Working cross-compilation toolchain (aarch64-linux-gnu-gcc)
- Sysroot with target libraries/headers
- VS Code live debugging via gdbserver
- Deploy-and-test automation
