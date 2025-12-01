# MATHIS OS - Quick Start

## Boot the OS

```bash
# Option 1: QEMU direct
qemu-system-i386 -fda boot/mathis.img -boot a -m 32M

# Option 2: With JARVIS AI bridge
./run_with_jarvis.sh
```

## Build from Source

```bash
cd boot
nasm -f bin boot.asm -o boot.bin
nasm -f bin stage2.asm -o stage2.bin
nasm -f bin kernel.asm -o kernel.bin
cat boot.bin stage2.bin kernel.bin > mathis.img
```

## Using the Shell

Once booted, you'll see the MATHIS banner and prompt:

```
> help              # List commands
> jarvis help       # AI assistant commands
> jarvis self       # Self-awareness mode
> fs ls             # List filesystem
> compile test.mhs  # Compile MathisScript
> runmbc test.mbc   # Run bytecode
```

## Write a Program

Create a file in the filesystem:

```
> fs write hello.mhs
func main() {
    print("Hello from MATHIS!")
}

> compile hello.mhs
Compiled: hello.mbc

> runmbc hello.mbc
Hello from MATHIS!
```

## Architecture

```
Boot: 512B → Stage2: 4KB → Kernel: 24KB
     16-bit      16→32-bit      32-bit PM

Memory Map:
0x00000 - 0x07BFF : Free
0x07C00 - 0x07DFF : Boot sector
0x07E00 - 0x0FFFF : Stage 2
0x10000 - 0x1FFFF : Kernel
0x20000 - 0x2FFFF : Bytecode
0x30000 - 0x3FFFF : RAM disk (64KB)
0xB8000 - 0xB8FA0 : VGA text buffer
```

## Technical Specs

| Component | Details |
|-----------|---------|
| Kernel size | 24KB (50KB source) |
| VM opcodes | 60+ |
| RAM disk | 64KB |
| Display | VGA 80x25 |
| Architecture | x86 32-bit |

## Documentation

See numbered spec files `00-OVERVIEW.md` through `08-IMPLEMENTATION-GUIDE.md` for complete technical documentation.
