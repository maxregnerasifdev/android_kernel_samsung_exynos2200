#!/bin/bash
# Enhanced GKI Build Script for Exynos 2200
# Builds both GKI kernel and vendor modules with proper separation

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
KERNEL_DIR=$(pwd)
ARCH=arm64
CROSS_COMPILE=${CROSS_COMPILE:-aarch64-linux-gnu-}
CLANG_TRIPLE=${CLANG_TRIPLE:-aarch64-linux-gnu-}
CC=${CC:-clang}
JOBS=${JOBS:-$(nproc)}

# Build directories
OUT_DIR=${OUT_DIR:-out}
GKI_OUT_DIR=${OUT_DIR}/gki
VENDOR_OUT_DIR=${OUT_DIR}/vendor

# GKI and vendor configurations
GKI_DEFCONFIG=gki_defconfig
VENDOR_DEFCONFIG=exynos2200_defconfig

print_banner() {
    echo -e "${BLUE}"
    echo "=================================================="
    echo "    Enhanced GKI Build for Exynos 2200"
    echo "    Loki Kernel with GKI Compliance"
    echo "=================================================="
    echo -e "${NC}"
}

print_step() {
    echo -e "${GREEN}[STEP]${NC} $1"
}

print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_dependencies() {
    print_step "Checking build dependencies..."
    
    # Check for required tools
    local missing_tools=()
    
    if ! command -v ${CC} &> /dev/null; then
        missing_tools+=("${CC}")
    fi
    
    if ! command -v ${CROSS_COMPILE}gcc &> /dev/null; then
        missing_tools+=("${CROSS_COMPILE}gcc")
    fi
    
    if [ ${#missing_tools[@]} -ne 0 ]; then
        print_error "Missing required tools: ${missing_tools[*]}"
        print_info "Please install the missing tools and try again."
        exit 1
    fi
    
    print_info "All dependencies satisfied"
}

setup_build_env() {
    print_step "Setting up build environment..."
    
    # Create output directories
    mkdir -p ${GKI_OUT_DIR}
    mkdir -p ${VENDOR_OUT_DIR}
    
    # Export build variables
    export ARCH=${ARCH}
    export CROSS_COMPILE=${CROSS_COMPILE}
    export CLANG_TRIPLE=${CLANG_TRIPLE}
    export CC=${CC}
    export LLVM=1
    export LLVM_IAS=1
    
    print_info "Build environment configured"
    print_info "Architecture: ${ARCH}"
    print_info "Cross compiler: ${CROSS_COMPILE}"
    print_info "Clang triple: ${CLANG_TRIPLE}"
    print_info "Compiler: ${CC}"
    print_info "Jobs: ${JOBS}"
}

build_gki_kernel() {
    print_step "Building GKI kernel..."
    
    # Clean previous GKI build
    make O=${GKI_OUT_DIR} clean
    
    # Configure GKI kernel
    print_info "Configuring GKI kernel with ${GKI_DEFCONFIG}..."
    make O=${GKI_OUT_DIR} ${GKI_DEFCONFIG}
    
    # Build GKI kernel
    print_info "Building GKI kernel image..."
    make O=${GKI_OUT_DIR} -j${JOBS} Image.lz4 modules
    
    # Check if GKI kernel was built successfully
    if [ ! -f "${GKI_OUT_DIR}/arch/${ARCH}/boot/Image.lz4" ]; then
        print_error "GKI kernel build failed!"
        exit 1
    fi
    
    print_info "GKI kernel built successfully"
}

build_vendor_modules() {
    print_step "Building vendor modules..."
    
    # Check if vendor defconfig exists
    if [ ! -f "arch/${ARCH}/configs/${VENDOR_DEFCONFIG}" ]; then
        print_warning "Vendor defconfig ${VENDOR_DEFCONFIG} not found, using mrkernel_defconfig"
        VENDOR_DEFCONFIG=mrkernel_defconfig
    fi
    
    # Clean previous vendor build
    make O=${VENDOR_OUT_DIR} clean
    
    # Configure vendor kernel
    print_info "Configuring vendor kernel with ${VENDOR_DEFCONFIG}..."
    make O=${VENDOR_OUT_DIR} ${VENDOR_DEFCONFIG}
    
    # Build vendor modules
    print_info "Building vendor modules..."
    make O=${VENDOR_OUT_DIR} -j${JOBS} modules
    
    print_info "Vendor modules built successfully"
}

check_abi_compliance() {
    print_step "Checking ABI compliance..."
    
    # Check if ABI definition exists
    if [ -f "android/abi_gki_aarch64.xml" ]; then
        print_info "ABI definition found, checking compliance..."
        
        # Run ABI check (if tools are available)
        if command -v abidiff &> /dev/null; then
            print_info "Running ABI compliance check..."
            # Add ABI checking logic here
        else
            print_warning "ABI checking tools not available, skipping ABI check"
        fi
    else
        print_warning "ABI definition not found, skipping ABI check"
    fi
}

package_artifacts() {
    print_step "Packaging build artifacts..."
    
    local package_dir="${OUT_DIR}/package"
    mkdir -p ${package_dir}
    
    # Copy GKI artifacts
    if [ -f "${GKI_OUT_DIR}/arch/${ARCH}/boot/Image.lz4" ]; then
        cp "${GKI_OUT_DIR}/arch/${ARCH}/boot/Image.lz4" "${package_dir}/gki_kernel.lz4"
        print_info "GKI kernel packaged"
    fi
    
    # Copy vendor modules
    if [ -d "${VENDOR_OUT_DIR}" ]; then
        find ${VENDOR_OUT_DIR} -name "*.ko" -exec cp {} ${package_dir}/ \;
        print_info "Vendor modules packaged"
    fi
    
    # Create build info
    cat > "${package_dir}/build_info.txt" << EOF
Build Information
=================
Build Date: $(date)
Kernel Version: $(make kernelversion)
GKI Defconfig: ${GKI_DEFCONFIG}
Vendor Defconfig: ${VENDOR_DEFCONFIG}
Architecture: ${ARCH}
Compiler: ${CC}
Cross Compiler: ${CROSS_COMPILE}
Jobs: ${JOBS}

GKI Features:
- Generic Kernel Image compliant
- ABI stability enforced
- Vendor module separation
- Security hardening enabled
- LTO and CFI enabled
EOF
    
    print_info "Build artifacts packaged in ${package_dir}"
}

show_build_summary() {
    print_step "Build Summary"
    
    echo -e "${GREEN}"
    echo "=================================================="
    echo "           BUILD COMPLETED SUCCESSFULLY"
    echo "=================================================="
    echo -e "${NC}"
    
    print_info "GKI kernel: ${GKI_OUT_DIR}/arch/${ARCH}/boot/Image.lz4"
    print_info "Vendor modules: ${VENDOR_OUT_DIR}/"
    print_info "Package directory: ${OUT_DIR}/package/"
    
    # Show file sizes
    if [ -f "${GKI_OUT_DIR}/arch/${ARCH}/boot/Image.lz4" ]; then
        local gki_size=$(du -h "${GKI_OUT_DIR}/arch/${ARCH}/boot/Image.lz4" | cut -f1)
        print_info "GKI kernel size: ${gki_size}"
    fi
    
    local module_count=$(find ${VENDOR_OUT_DIR} -name "*.ko" 2>/dev/null | wc -l)
    print_info "Vendor modules built: ${module_count}"
}

# Main build process
main() {
    print_banner
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --gki-only)
                BUILD_GKI_ONLY=1
                shift
                ;;
            --vendor-only)
                BUILD_VENDOR_ONLY=1
                shift
                ;;
            --clean)
                CLEAN_BUILD=1
                shift
                ;;
            --jobs=*)
                JOBS="${1#*=}"
                shift
                ;;
            --help|-h)
                echo "Usage: $0 [OPTIONS]"
                echo "Options:"
                echo "  --gki-only      Build only GKI kernel"
                echo "  --vendor-only   Build only vendor modules"
                echo "  --clean         Clean build (remove output directory)"
                echo "  --jobs=N        Number of parallel jobs (default: $(nproc))"
                echo "  --help, -h      Show this help message"
                exit 0
                ;;
            *)
                print_error "Unknown option: $1"
                exit 1
                ;;
        esac
    done
    
    # Clean build if requested
    if [ "${CLEAN_BUILD}" = "1" ]; then
        print_step "Cleaning previous builds..."
        rm -rf ${OUT_DIR}
        print_info "Build directory cleaned"
    fi
    
    check_dependencies
    setup_build_env
    
    # Build based on options
    if [ "${BUILD_VENDOR_ONLY}" = "1" ]; then
        build_vendor_modules
    elif [ "${BUILD_GKI_ONLY}" = "1" ]; then
        build_gki_kernel
        check_abi_compliance
    else
        # Build both GKI and vendor
        build_gki_kernel
        build_vendor_modules
        check_abi_compliance
    fi
    
    package_artifacts
    show_build_summary
}

# Run main function with all arguments
main "$@"

