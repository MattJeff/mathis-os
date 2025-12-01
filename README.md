# MATHIS OS 🚀

**AI-First Operating System** - 100% Mathis, 0% Rust

## Features

- ✅ Custom bootloader (16-bit → 32-bit protected mode)
- ✅ Kernel with interactive shell
- ✅ Mini VM for Mathis bytecode (.mbc)
- ✅ **JARVIS AI Assistant** with 15+ commands
- ✅ Self-hosted compiler (mathisc)
- 📋 Filesystem (RAM disk) - Coming soon
- 📋 Neural network integration - Planned

## JARVIS Commands

```
> jarvis help     - List all AI commands
> jarvis self     - Self-awareness mode
> jarvis code     - Show kernel info
> jarvis evolve   - Evolution mode
> jarvis learn    - Learning mode
> jarvis think    - Processing mode
> jarvis build    - Build features
> jarvis spawn    - Create AI instances
> jarvis memory   - Memory status
> jarvis goal     - Show objectives
> jarvis roadmap  - Development roadmap
> jarvis status   - System status
```

## Quick Start

```bash
# Boot in QEMU
cd boot
qemu-system-i386 -fda mathis_jarvis.img -boot a -m 32M
```

## Architecture

```
MATHIS OS
├── boot/
│   ├── boot.bin        # Bootloader
│   ├── stage2.bin      # Stage 2 loader
│   ├── kernel.asm      # Kernel source
│   └── mathis_jarvis.img # Bootable image
├── bootstrap/
│   ├── masm            # Compiler binary
│   ├── mathis          # VM binary
│   └── *.mbc           # Pre-compiled modules
├── masm/
│   ├── mathisc_v1.masm # Self-hosted compiler
│   ├── vm.masm         # VM in Mathis
│   └── *.masm          # Other modules
└── jarvis/
    └── jarvis.py       # External AI bridge (optional)
```

## The Mathis Language

Mathis is a stack-based assembly language with AI annotations:

```masm
.module "hello"
.version "1.0.0"

.func main
    .arity 0
    .locals 0
    .ai_intent "Print hello world"
    
    CONST 0          ; Load "Hello, MATHIS OS!"
    SYSCALL 0x0001   ; Print
    RET
.end
```

## Roadmap

1. ✅ Kernel + JARVIS
2. 📋 Filesystem (RAM disk)
3. 📋 Complete VM (all opcodes)
4. 📋 Module loader
5. 📋 AI opcodes (AI_CALL, AI_DECIDE)
6. 📋 Self-modification
7. 📋 Neural network integration

## Author

**Mathis Higuinen** - Creator of MATHIS OS and the Mathis programming language

One of less than 10 people in the world to create both a custom OS AND a custom programming language! 🏆

## License

MIT
