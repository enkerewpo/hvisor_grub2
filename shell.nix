let
  pkgs = import <nixpkgs> {};
  cross_loongarch64 = import <nixpkgs> {
    crossSystem = { config = "loongarch64-unknown-linux-gnu"; };
  };
  cross_aarch64 = import <nixpkgs> {
    crossSystem = { config = "aarch64-unknown-linux-gnu"; };
  };
  cross_riscv64 = import <nixpkgs> {
    crossSystem = { config = "riscv64-unknown-linux-gnu"; };
  };
in
# configure: error: Building GCC requires GMP 4.2+, MPFR 3.1.0+ and MPC 0.8.0+.
pkgs.mkShell {
  buildInputs = [
    # LoongArch64 cross-compilation toolchain
    cross_loongarch64.buildPackages.gcc
    cross_loongarch64.buildPackages.binutils
    cross_loongarch64.buildPackages.libgcc
    cross_loongarch64.buildPackages.libelf
    cross_loongarch64.buildPackages.elfutils
    cross_loongarch64.buildPackages.libffi
    cross_loongarch64.buildPackages.zlib
    cross_loongarch64.buildPackages.zstd
    cross_loongarch64.buildPackages.libmpc
    cross_loongarch64.buildPackages.mpfr
    
    # GRUB2 build dependencies
    pkgs.autoconf
    pkgs.automake
    pkgs.automake115x  # Specific version needed by GRUB2
    pkgs.libtool
    pkgs.m4
    pkgs.perl
    pkgs.flex
    pkgs.bison
    pkgs.gettext
    pkgs.freetype
    pkgs.fontconfig
    pkgs.libpng
    pkgs.libjpeg
    pkgs.libtiff
    pkgs.unifont
    pkgs.dejavu_fonts
    pkgs.lvm2
    pkgs.zfs
    pkgs.xz
    pkgs.fuse3
    
    cross_aarch64.buildPackages.gcc
    cross_aarch64.buildPackages.binutils
    cross_aarch64.buildPackages.libgcc
    cross_aarch64.buildPackages.libelf
    cross_aarch64.buildPackages.elfutils
    cross_aarch64.buildPackages.libffi
    cross_aarch64.buildPackages.zlib
    cross_aarch64.buildPackages.zstd

    cross_riscv64.buildPackages.gcc
    cross_riscv64.buildPackages.binutils
    cross_riscv64.buildPackages.libgcc
    cross_riscv64.buildPackages.libelf
    cross_riscv64.buildPackages.elfutils
    cross_riscv64.buildPackages.libffi
    cross_riscv64.buildPackages.zlib

    pkgs.llvmPackages.llvm
    pkgs.llvmPackages.libclang
    pkgs.llvmPackages.clang-unwrapped
    pkgs.llvmPackages.clang-unwrapped.dev
    pkgs.llvmPackages.clang-unwrapped.lib
    pkgs.llvmPackages.clang-unwrapped.lib.dev
    
    pkgs.gnumake
    pkgs.cmake
    pkgs.ninja
    pkgs.pkg-config
    pkgs.libffi
    pkgs.zlib
    pkgs.libedit
    pkgs.libz
    pkgs.bpftools
    pkgs.bear
    pkgs.clang
    pkgs.llvm
    pkgs.qemu
    pkgs.gdb
  ];
  shellHook = ''
    COLOR_YELLOW='\033[1;33m'
    COLOR_RESET='\033[0m'
    echo -e "\n$COLOR_YELLOW This is a dev shell environment for wheatfox $COLOR_RESET"
  '';
}

# ./bootstrap.sh ebpf-samples