# mrkernel Exynos2200

Custom kernel for Samsung Galaxy S22+ (Exynos2200) with enhanced GKI (Generic Kernel Image) support.

## 🚀 Features

### Core Features
- **GKI Compliance**: Full Android GKI support with ABI stability
- **Size-optimized build**: LTO, -Os, strip & lzma compression
- **Custom scheduler and memory tweaks**: Performance optimizations
- **Security hardening**: CFI, stack protection, memory hardening
- **Integrated CI/CD**: Automated compliance checks and testing

### GKI Enhancements
- ✅ **Full ABI Compatibility**: Stable kernel interface for vendor modules
- 🔒 **Enhanced Security**: CFI, LTO, and comprehensive hardening
- 🏗️ **Modular Architecture**: Clean GKI/vendor separation
- 🧪 **Automated Testing**: Continuous compliance validation
- 📊 **ABI Monitoring**: Real-time compatibility checking

## 🛠️ Quick Start

### Prerequisites
```bash
sudo apt-get install -y build-essential bc bison flex libssl-dev libelf-dev \
    clang lld llvm gcc-aarch64-linux-gnu python3 git
```

### Standard Build
```bash
make mrkernel_defconfig ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu-
make -j$(nproc) ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu-
make post-build
```

### GKI Build (Recommended)
```bash
# Build both GKI kernel and vendor modules
./build_gki.sh

# Build options
./build_gki.sh --gki-only      # GKI kernel only
./build_gki.sh --vendor-only   # Vendor modules only
./build_gki.sh --clean         # Clean build
```

### ABI Compliance Check
```bash
./scripts/gki-abi-check.sh check    # Full compliance check
./scripts/gki-abi-check.sh report   # Generate report
```

## 📋 Supported Devices

| Device | Model | Codename | Status |
|--------|-------|----------|--------|
| Galaxy S22 | SM-S901B | b0s | ✅ Fully Supported |
| Galaxy S22+ | SM-S906B | g0s | ✅ Fully Supported |
| Galaxy S22 Ultra | SM-S908B | r0s | ✅ Fully Supported |

## 🏗️ Architecture

```
Loki Kernel (Exynos 2200)
├── GKI Core
│   ├── Generic ARM64 kernel
│   ├── Android framework support
│   └── ABI-stable interfaces
├── Vendor Extensions
│   ├── Samsung-specific drivers
│   ├── Exynos 2200 SoC support
│   └── Performance optimizations
└── Security Layer
    ├── CFI protection
    ├── Stack protection
    └── Memory hardening
```

## 📚 Documentation

- **[GKI Guide](docs/GKI.md)** - Comprehensive GKI implementation guide
- **[Build System](build_gki.sh)** - Enhanced build script with GKI support
- **[ABI Checking](scripts/gki-abi-check.sh)** - ABI compliance validation
- **[CI/CD](.github/workflows/gki-compliance.yml)** - Automated testing workflow

## 🔧 Configuration Files

- `arch/arm64/configs/gki_defconfig` - GKI kernel configuration
- `arch/arm64/configs/mrkernel_defconfig` - Original Loki configuration
- `build.config.gki*` - GKI build configurations
- `android/abi_gki_aarch64*` - ABI symbol definitions

## 🧪 Testing & Validation

The kernel includes comprehensive testing:

- **Build Validation**: Automated build testing for all configurations
- **ABI Compliance**: Continuous ABI compatibility checking
- **Security Scanning**: Security configuration validation
- **Performance Testing**: Benchmark validation

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Follow the [development guidelines](docs/GKI.md#development-guidelines)
4. Run compliance checks: `./scripts/gki-abi-check.sh check`
5. Submit a pull request

## 📞 Support

- **Issues**: [GitHub Issues](https://github.com/maxregnerasifdev/android_kernel_samsung_exynos2200/issues)
- **Chat**: [Telegram](https://t.me/+Ehf3IgzJw0k0NmE8)
- **Documentation**: [GKI Guide](docs/GKI.md)

## 📄 License

This project is licensed under the GPL v2 License - see the [LICENSE](LICENSE) file for details.

---

**Note**: This kernel provides enhanced GKI support while maintaining all the performance optimizations and features of the original Loki Kernel. For detailed GKI information, see the [GKI documentation](docs/GKI.md).

