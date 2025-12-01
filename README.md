# MATHIS OS

**AI-First Operating System** - 100% Assembly, 0 dependencies

## What is this?

A bare-metal operating system built from scratch with:

- **24KB Kernel** with 60+ VM opcodes
- **JARVIS AI Assistant** with 15+ commands
- **Self-hosted compiler** (MathisC) that compiles MathisScript to bytecode
- **In-kernel compilation**: write, compile, and run code inside the OS
- **Interactive shell** with command history

## Quick Start

```bash
# Boot in QEMU
qemu-system-i386 -fda boot/mathis.img -boot a -m 32M

# With JARVIS bridge (optional)
./run_with_jarvis.sh
```

## Shell Commands

```
help          - Show available commands
clear         - Clear screen
jarvis <cmd>  - AI assistant (jarvis help for list)
mathisc       - Show compiler info
compile <f>   - Compile .mhs file to .mbc
runmbc <f>    - Execute bytecode
fs <cmd>      - Filesystem commands (ls, cat, write, mkdir)
run <file>    - Run a program
```

## Project Structure

```
mathis-os/
├── boot/
│   ├── boot.asm          # Boot sector (512 bytes)
│   ├── stage2.asm        # Stage 2 loader (16→32 bit)
│   ├── kernel.asm        # Main kernel (50KB source)
│   └── mathis.img        # Bootable disk image
├── mathisc/
│   ├── mathisc_v7.masm   # Self-hosted compiler
│   ├── lexer.masm        # Tokenizer
│   ├── parser.masm       # Parser
│   ├── codegen.masm      # Code generator
│   └── mathisc.mhs       # Compiler in MathisScript
├── examples/             # Demo programs (.masm)
├── programs/             # Test programs
├── jarvis/               # Python bridge for development
└── llml-mathis/          # Future: AI/stdlib foundation
```

## Build from Source

```bash
cd boot
nasm -f bin boot.asm -o boot.bin
nasm -f bin stage2.asm -o stage2.bin
nasm -f bin kernel.asm -o kernel.bin
cat boot.bin stage2.bin kernel.bin > mathis.img
```

## Technical Specs

- **Architecture**: x86 (i386), 32-bit protected mode
- **Kernel size**: 24KB binary
- **RAM disk**: 64KB at 0x30000
- **VM**: Stack-based with 60+ opcodes
- **Display**: VGA text mode (80x25)

See `00-OVERVIEW.md` through `08-IMPLEMENTATION-GUIDE.md` for complete specs.

## Author

**Mathis Higuinen**

## License

MIT
