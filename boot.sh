#!/bin/sh

# QEMU Boot Script - Boot LoongArch64 with GRUB EFI
# Author: Created for hvisor_grub2 project

set -e

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

# Check required files
check_files() {
    log_info "Checking required files..."
    
    if [ ! -f "./firmware/QEMU_EFI_LOONGARCH64.fd" ]; then
        log_error "QEMU EFI firmware file not found: ./firmware/QEMU_EFI_LOONGARCH64.fd"
        exit 1
    fi
    
    if [ ! -f "./grub2/efi_output/grub.efi" ]; then
        log_error "GRUB EFI file not found: ./grub2/efi_output/grub.efi"
        log_info "Please run first: ./build_loongarch64_grub2.sh --efi"
        exit 1
    fi
    
    log_success "All required files check passed"
}

# Create virtual disk
create_disk() {
    log_info "Creating virtual disk..."
    
    if [ ! -f "./disk.img" ]; then
        # Create 1GB virtual disk
        qemu-img create -f qcow2 ./disk.img 1G
        log_success "Virtual disk created: ./disk.img"
    else
        log_info "Virtual disk already exists: ./disk.img"
    fi
}

# Create EFI boot partition
setup_efi_partition() {
    log_info "Setting up EFI boot partition..."
    
    # Create a simple FAT32 image for EFI boot
    if [ ! -f "./efi_boot.img" ]; then
        # Create 100MB FAT32 image
        dd if=/dev/zero of=./efi_boot.img bs=1M count=100 2>/dev/null
        
        # Format as FAT32
        /sbin/mkfs.fat -F32 ./efi_boot.img >/dev/null 2>&1
        
        # Create temporary mount point
        mkdir -p ./temp_esp
        
        # Mount the FAT32 image with sudo
        log_info "Mounting EFI boot image with sudo..."
        if sudo mount -o loop ./efi_boot.img ./temp_esp; then
            # Create EFI boot directory structure
            sudo mkdir -p ./temp_esp/EFI/BOOT
            
            # Copy GRUB EFI file
            sudo cp ./grub2/efi_output/grub.efi ./temp_esp/EFI/BOOT/BOOTLOONGARCH64.EFI
            
            # Copy GRUB configuration
            sudo mkdir -p ./temp_esp/boot/grub
            sudo cp ./grub.cfg ./temp_esp/boot/grub/grub.cfg
            
            # Unmount
            sudo umount ./temp_esp
            
            # Cleanup
            rm -rf ./temp_esp
            
            log_success "EFI boot image created with GRUB files: ./efi_boot.img"
        else
            log_error "Cannot mount EFI boot image with sudo"
            rm -rf ./temp_esp
            exit 1
        fi
    else
        log_info "EFI boot image already exists: ./efi_boot.img"
    fi
}


# Start QEMU
start_qemu() {
    log_info "Starting QEMU virtual machine..."
    
    # Determine which disk image to use
    if [ -f "./efi_boot.img" ]; then
        # Use alternative EFI boot image
        DISK_IMAGE="./efi_boot.img"
        DISK_FORMAT="raw"
        log_info "Using alternative EFI boot image: $DISK_IMAGE"
    else
        # Use main disk image
        DISK_IMAGE="./disk.img"
        DISK_FORMAT="qcow2"
        log_info "Using main disk image: $DISK_IMAGE"
    fi
    
    # QEMU parameters
    QEMU_OPTS="
        -machine virt
        -cpu la464
        -smp 4
        -m 2G
        -bios ./firmware/QEMU_EFI_LOONGARCH64.fd
        -drive file=$DISK_IMAGE,format=$DISK_FORMAT,if=virtio
        -netdev user,id=net0,hostfwd=tcp::2222-:22
        -device virtio-net-pci,netdev=net0
        -nographic
        -serial mon:stdio
    "
    
    log_info "QEMU startup parameters:"
    echo "$QEMU_OPTS" | sed 's/^/  /'
    
    log_success "Starting QEMU virtual machine (Press Ctrl+A then X to exit)"
    
    # Start QEMU
    qemu-system-loongarch64 $QEMU_OPTS
}

# Show help information
show_help() {
    echo "LoongArch64 GRUB EFI QEMU Boot Script"
    echo ""
    echo "Usage: $0 [options]"
    echo ""
    echo "Options:"
    echo "  -h, --help     Show this help message"
    echo "  -c, --clean    Clean virtual disk"
    echo "  -s, --setup    Setup EFI partition only"
    echo "  -q, --qemu     Start QEMU only (skip partition setup)"
    echo ""
    echo "Examples:"
    echo "  $0              # Full boot process"
    echo "  $0 --clean      # Clean and start fresh"
    echo "  $0 --qemu       # Start QEMU only"
}

# Cleanup function
cleanup() {
    log_info "Cleaning virtual disk..."
    if [ -f "./disk.img" ]; then
        rm -f ./disk.img
        log_success "Virtual disk cleaned"
    fi
    if [ -f "./efi_boot.img" ]; then
        rm -f ./efi_boot.img
        log_success "EFI boot image cleaned"
    fi
    rm -rf ./temp_esp
}

# Main function
main() {
    case "${1:-}" in
        -h|--help)
            show_help
            exit 0
            ;;
        -c|--clean)
            cleanup
            exit 0
            ;;
        -s|--setup)
            check_files
            create_disk
            setup_efi_partition
            log_success "EFI partition setup completed"
            exit 0
            ;;
        -q|--qemu)
            check_files
            if [ ! -f "./disk.img" ] && [ ! -f "./efi_boot.img" ]; then
                log_error "No virtual disk found, please run first: $0 --setup"
                exit 1
            fi
            start_qemu
            ;;
        "")
            # Default full process
            check_files
            create_disk
            setup_efi_partition
            start_qemu
            ;;
        *)
            log_error "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
}

# Run main function
main "$@"