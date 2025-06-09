#!/bin/bash
# GKI ABI Compliance Checker for Exynos 2200
# Validates kernel ABI against GKI requirements

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
KERNEL_DIR=$(pwd)
ABI_DIR="${KERNEL_DIR}/android"
GKI_ABI_FILE="${ABI_DIR}/abi_gki_aarch64"
ABI_XML_FILE="${ABI_DIR}/abi_gki_aarch64.xml"
OUT_DIR=${OUT_DIR:-out/gki}

print_info() {
    echo -e "${BLUE}[ABI-CHECK]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[ABI-CHECK]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[ABI-CHECK]${NC} $1"
}

print_error() {
    echo -e "${RED}[ABI-CHECK]${NC} $1"
}

check_abi_files() {
    print_info "Checking ABI definition files..."
    
    if [ ! -f "${GKI_ABI_FILE}" ]; then
        print_error "GKI ABI symbol list not found: ${GKI_ABI_FILE}"
        return 1
    fi
    
    if [ ! -f "${ABI_XML_FILE}" ]; then
        print_warning "ABI XML definition not found: ${ABI_XML_FILE}"
        print_info "This is optional but recommended for comprehensive ABI checking"
    fi
    
    print_success "ABI files validated"
    return 0
}

extract_kernel_symbols() {
    print_info "Extracting kernel symbols from built kernel..."
    
    local vmlinux="${OUT_DIR}/vmlinux"
    local symbol_file="${OUT_DIR}/kernel_symbols.txt"
    
    if [ ! -f "${vmlinux}" ]; then
        print_error "Built kernel not found: ${vmlinux}"
        print_info "Please build the kernel first using build_gki.sh"
        return 1
    fi
    
    # Extract symbols using nm
    nm "${vmlinux}" | grep -E '^[0-9a-fA-F]+ [ABCDGRSTUVW] ' | \
        awk '{print $3}' | sort > "${symbol_file}"
    
    print_info "Extracted $(wc -l < ${symbol_file}) symbols from kernel"
    return 0
}

check_required_symbols() {
    print_info "Checking required GKI symbols..."
    
    local symbol_file="${OUT_DIR}/kernel_symbols.txt"
    local missing_symbols=()
    local found_symbols=0
    local total_symbols=0
    
    if [ ! -f "${symbol_file}" ]; then
        print_error "Kernel symbols not extracted. Run extract_kernel_symbols first."
        return 1
    fi
    
    # Check each required symbol
    while IFS= read -r symbol; do
        # Skip empty lines and comments
        [[ -z "$symbol" || "$symbol" =~ ^[[:space:]]*# ]] && continue
        
        total_symbols=$((total_symbols + 1))
        
        if grep -q "^${symbol}$" "${symbol_file}"; then
            found_symbols=$((found_symbols + 1))
        else
            missing_symbols+=("$symbol")
        fi
    done < "${GKI_ABI_FILE}"
    
    print_info "Symbol check results:"
    print_info "  Total required symbols: ${total_symbols}"
    print_info "  Found symbols: ${found_symbols}"
    print_info "  Missing symbols: ${#missing_symbols[@]}"
    
    if [ ${#missing_symbols[@]} -eq 0 ]; then
        print_success "All required GKI symbols are present!"
        return 0
    else
        print_error "Missing required GKI symbols:"
        for symbol in "${missing_symbols[@]}"; do
            echo "    - ${symbol}"
        done
        return 1
    fi
}

check_extra_symbols() {
    print_info "Checking for extra exported symbols..."
    
    local symbol_file="${OUT_DIR}/kernel_symbols.txt"
    local extra_symbols=()
    local exported_count=0
    
    if [ ! -f "${symbol_file}" ]; then
        print_error "Kernel symbols not extracted."
        return 1
    fi
    
    # Find symbols that are exported but not in GKI list
    while IFS= read -r symbol; do
        exported_count=$((exported_count + 1))
        
        if ! grep -q "^${symbol}$" "${GKI_ABI_FILE}"; then
            extra_symbols+=("$symbol")
        fi
    done < "${symbol_file}"
    
    print_info "Extra symbol check results:"
    print_info "  Total exported symbols: ${exported_count}"
    print_info "  Extra symbols (not in GKI): ${#extra_symbols[@]}"
    
    if [ ${#extra_symbols[@]} -gt 0 ]; then
        print_warning "Extra exported symbols found (may break ABI compatibility):"
        for symbol in "${extra_symbols[@]:0:10}"; do  # Show first 10
            echo "    - ${symbol}"
        done
        
        if [ ${#extra_symbols[@]} -gt 10 ]; then
            echo "    ... and $((${#extra_symbols[@]} - 10)) more"
        fi
        
        print_info "Consider removing these exports or adding them to vendor-specific ABI"
    else
        print_success "No extra symbols found - good ABI compliance!"
    fi
    
    return 0
}

generate_abi_report() {
    print_info "Generating ABI compliance report..."
    
    local report_file="${OUT_DIR}/abi_compliance_report.txt"
    local timestamp=$(date)
    
    cat > "${report_file}" << EOF
GKI ABI Compliance Report
========================
Generated: ${timestamp}
Kernel: $(make kernelversion 2>/dev/null || echo "Unknown")
Architecture: arm64
Target: Samsung Exynos 2200

ABI Files Checked:
- GKI Symbol List: ${GKI_ABI_FILE}
- ABI XML Definition: ${ABI_XML_FILE}

Symbol Analysis:
EOF
    
    # Add symbol statistics
    if [ -f "${OUT_DIR}/kernel_symbols.txt" ]; then
        local total_exported=$(wc -l < "${OUT_DIR}/kernel_symbols.txt")
        local total_required=$(grep -v '^[[:space:]]*#' "${GKI_ABI_FILE}" | grep -v '^[[:space:]]*$' | wc -l)
        
        echo "- Total exported symbols: ${total_exported}" >> "${report_file}"
        echo "- Total required GKI symbols: ${total_required}" >> "${report_file}"
    fi
    
    echo "" >> "${report_file}"
    echo "Compliance Status:" >> "${report_file}"
    
    # Run checks and capture results
    local compliance_status="UNKNOWN"
    
    if check_required_symbols >/dev/null 2>&1; then
        echo "- Required symbols: PASS" >> "${report_file}"
        compliance_status="PASS"
    else
        echo "- Required symbols: FAIL" >> "${report_file}"
        compliance_status="FAIL"
    fi
    
    check_extra_symbols >/dev/null 2>&1
    echo "- Extra symbols check: See details above" >> "${report_file}"
    
    echo "" >> "${report_file}"
    echo "Overall Compliance: ${compliance_status}" >> "${report_file}"
    
    print_success "ABI compliance report generated: ${report_file}"
}

update_abi_definition() {
    print_info "Updating ABI definition with current kernel..."
    
    local symbol_file="${OUT_DIR}/kernel_symbols.txt"
    local backup_file="${GKI_ABI_FILE}.backup.$(date +%Y%m%d_%H%M%S)"
    
    if [ ! -f "${symbol_file}" ]; then
        print_error "Kernel symbols not extracted."
        return 1
    fi
    
    # Backup current ABI file
    cp "${GKI_ABI_FILE}" "${backup_file}"
    print_info "Backed up current ABI file to: ${backup_file}"
    
    # Create new ABI file header
    cat > "${GKI_ABI_FILE}" << EOF
# GKI ABI Symbol List for ARM64
# Generated: $(date)
# Kernel: $(make kernelversion 2>/dev/null || echo "Unknown")
# Target: Samsung Exynos 2200
#
# This file contains the list of kernel symbols that must be
# exported for GKI compliance on ARM64 architecture.
#

EOF
    
    # Add sorted symbols
    sort "${symbol_file}" >> "${GKI_ABI_FILE}"
    
    print_success "ABI definition updated with current kernel symbols"
    print_info "Previous version backed up to: ${backup_file}"
}

show_help() {
    echo "GKI ABI Compliance Checker"
    echo ""
    echo "Usage: $0 [COMMAND]"
    echo ""
    echo "Commands:"
    echo "  check       - Run full ABI compliance check"
    echo "  extract     - Extract symbols from built kernel"
    echo "  symbols     - Check required GKI symbols"
    echo "  extra       - Check for extra exported symbols"
    echo "  report      - Generate ABI compliance report"
    echo "  update      - Update ABI definition with current kernel"
    echo "  help        - Show this help message"
    echo ""
    echo "Environment Variables:"
    echo "  OUT_DIR     - Kernel build output directory (default: out/gki)"
    echo ""
    echo "Examples:"
    echo "  $0 check                    # Run full compliance check"
    echo "  OUT_DIR=build $0 extract    # Extract symbols from custom build dir"
}

main() {
    local command=${1:-check}
    
    case "$command" in
        check)
            print_info "Running full GKI ABI compliance check..."
            check_abi_files && \
            extract_kernel_symbols && \
            check_required_symbols && \
            check_extra_symbols && \
            generate_abi_report
            ;;
        extract)
            extract_kernel_symbols
            ;;
        symbols)
            check_abi_files && extract_kernel_symbols && check_required_symbols
            ;;
        extra)
            extract_kernel_symbols && check_extra_symbols
            ;;
        report)
            generate_abi_report
            ;;
        update)
            extract_kernel_symbols && update_abi_definition
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            print_error "Unknown command: $command"
            show_help
            exit 1
            ;;
    esac
}

main "$@"

