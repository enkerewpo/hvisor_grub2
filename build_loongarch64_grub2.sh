#!/bin/bash

# LoongArch64 GRUB2 Build Script
# Using cross-compilation toolchain: loongarch64-unknown-linux-gnu-gcc

set -e  # Exit immediately on error

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check dependencies
check_dependencies() {
    log_info "Checking build dependencies..."
    
    # Check cross-compilation toolchain
    if ! command -v loongarch64-unknown-linux-gnu-gcc &> /dev/null; then
        log_error "loongarch64-unknown-linux-gnu-gcc not found, please install LoongArch64 cross-compilation toolchain"
        exit 1
    fi
    
    # Check required tools
    local tools=("autoconf" "automake" "make" "pkg-config" "flex" "bison")
    for tool in "${tools[@]}"; do
        if ! command -v "$tool" &> /dev/null; then
            log_error "$tool not found, please install required build tools"
            exit 1
        fi
    done
    
    log_success "Dependency check passed"
}

# Configure build parameters
configure_build() {
    log_info "Configuring build parameters..."
    
    # Set environment variables
    export TARGET_CC="loongarch64-unknown-linux-gnu-gcc"
    export TARGET_CFLAGS="-Os -fno-common"
    export TARGET_LDFLAGS=""
    export HOST_CC="gcc"
    export HOST_CFLAGS="-g -O2"
    
    # Configure options
    local configure_opts=(
        "--target=loongarch64-unknown-linux-gnu"
        "--host=x86_64-linux-gnu"  # Assuming compilation on x86_64 system
        "--build=x86_64-linux-gnu"
        "--with-platform=efi"
        "--disable-werror"
        "--disable-nls"  # Optional: disable internationalization to simplify build
        "--disable-grub-emu-usb"
        "--disable-grub-emu-sdl"
        "--disable-grub-emu-pci"
        "--disable-grub-mkfont"  # Disable grub-mkfont due to freetype2 issues
        "--disable-device-mapper"  # Disable device-mapper to avoid dependency issues
        "--disable-libzfs"  # Disable libzfs to avoid dependency issues
        "--disable-grub-mount"  # Disable grub-mount to avoid fuse3 dependency issues
    )
    
    echo "Configure options: ${configure_opts[*]}"
    
    # Run configure
    ./configure "${configure_opts[@]}"
    
    log_success "Configuration completed"
}

# Build
build_grub2() {
    log_info "Starting GRUB2 compilation..."
    
    # Set number of build threads
    local jobs=$(nproc)
    log_info "Using $jobs threads for compilation"
    
    # Build
    make -j"$jobs"
    
    log_success "Build completed"
}

# Install
install_grub2() {
    log_info "Installing GRUB2..."
    
    # Create install directory
    local install_dir="./install"
    mkdir -p "$install_dir"
    
    # Install to specified directory
    make DESTDIR="$install_dir" install
    
    log_success "Installation completed, install directory: $install_dir"
}

# Generate EFI image
generate_efi_image() {
    log_info "Generating LoongArch64 EFI image..."
    
    local efi_dir="./efi_output"
    mkdir -p "$efi_dir"
    
    # Use grub-mkimage to generate EFI image
    if [ -f "./grub-core/grub-mkimage" ]; then
        ./grub-core/grub-mkimage \
            --format=loongarch64-efi \
            --output="$efi_dir/grub.efi" \
            --prefix='(hd0,gpt1)/boot/grub' \
            --compression=xz \
            part_gpt part_msdos \
            fat exfat ext2 \
            hfsplus ntfs \
            linux \
            configfile \
            boot \
            btrfs \
            zfs \
            lvm \
            luks \
            search \
            search_label \
            search_fs_uuid \
            search_fs_file \
            normal \
            echo \
            all_video \
            test \
            sleep \
            font \
            gfxterm \
            gfxmenu \
            gfxpayload \
            terminal \
            serial \
            usb \
            keyboard \
            acpi \
            halt \
            reboot \
            memdisk \
            tar \
            ls \
            cat \
            cpuid \
            rdrand \
            relocator
    
        log_success "EFI image generation completed: $efi_dir/grub.efi"
    else
        log_warning "grub-mkimage not found, skipping EFI image generation"
    fi
}

# Cleanup function
cleanup() {
    log_info "Cleaning build files..."
    make clean 2>/dev/null || true
    rm -rf autom4te.cache 2>/dev/null || true
    log_success "Cleanup completed"
}

# Show help information
show_help() {
    echo "LoongArch64 GRUB2 Build Script"
    echo ""
    echo "Usage: $0 [options]"
    echo ""
    echo "Options:"
    echo "  -h, --help     Show this help message"
    echo "  -c, --clean    Clean build files"
    echo "  -i, --install  Build and install"
    echo "  -e, --efi      Generate EFI image"
    echo "  --clean-build  Clean and rebuild"
    echo ""
    echo "Examples:"
    echo "  $0                # Build only"
    echo "  $0 --install      # Build and install"
    echo "  $0 --efi          # Build and generate EFI image"
    echo "  $0 --clean-build  # Clean and rebuild"
}

# Main function
main() {
    local install_flag=false
    local efi_flag=false
    local clean_flag=false
    local clean_build_flag=false
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -c|--clean)
                clean_flag=true
                shift
                ;;
            -i|--install)
                install_flag=true
                shift
                ;;
            -e|--efi)
                efi_flag=true
                shift
                ;;
            --clean-build)
                clean_build_flag=true
                shift
                ;;
            *)
                log_error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
    
    # Enter GRUB2 source directory
    cd "$(dirname "$0")/grub2"
    
    # Check source directory
    if [ ! -f "configure.ac" ]; then
        log_error "GRUB2 source code not found, please ensure you are running this script in the correct directory"
        exit 1
    fi
    
    log_info "Starting LoongArch64 GRUB2 build process..."
    log_info "Source directory: $(pwd)"
    
    # Cleanup operations
    if [ "$clean_flag" = true ] || [ "$clean_build_flag" = true ]; then
        cleanup
        if [ "$clean_flag" = true ]; then
            log_success "Cleanup completed"
            exit 0
        fi
    fi
    
    # Always clean auxiliary files to ensure fresh build
    log_info "Cleaning auxiliary files for fresh build..."
    rm -f config.status config.log
    rm -rf autom4te.cache
    rm -f aclocal.m4
    rm -f configure
    log_success "Auxiliary files cleaned"
    
    # Check dependencies
    check_dependencies
    
    # Run autogen.sh if needed
    if [ ! -f "configure" ] || [ "configure.ac" -nt "configure" ]; then
        log_info "Running autogen.sh to generate configure script..."
        ./autogen.sh
        log_success "Autogen completed"
    fi
    
    # Ensure all auxiliary files are present
    if [ ! -f "build-aux/compile" ]; then
        log_info "Running autoreconf to generate missing auxiliary files..."
        autoreconf -fiv
        log_success "Autoreconf completed"
    fi
    
    # Create missing extra_deps.lst file if needed
    if [ ! -f "grub-core/extra_deps.lst" ]; then
        log_info "Creating missing extra_deps.lst file..."
        touch grub-core/extra_deps.lst
        log_success "extra_deps.lst created"
    fi
    
    # Configure and build
    configure_build
    build_grub2
    
    # Install
    if [ "$install_flag" = true ]; then
        install_grub2
    fi
    
    # Generate EFI image
    if [ "$efi_flag" = true ]; then
        generate_efi_image
    fi
    
    log_success "LoongArch64 GRUB2 build completed!"
    
    # Show output information
    echo ""
    log_info "Build output:"
    echo "  - Executables: ./grub-core/"
    if [ "$install_flag" = true ]; then
        echo "  - Install directory: ./install"
    fi
    if [ "$efi_flag" = true ]; then
        echo "  - EFI image: ./efi_output/grub.efi"
    fi
}

# Run main function
main "$@"
