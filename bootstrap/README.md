# MATHIS Bootstrap Package

This directory contains pre-compiled .mbc bytecode files that allow MATHIS OS to be self-sufficient without Rust.

## Files

| File | Description |
|------|-------------|
| `mathisc_v1.mbc` | Self-hosted Mathis compiler |
| `vm.mbc` | Mathis Virtual Machine |
| `loader.mbc` | MBC file loader |
| `paging.mbc` | Memory paging |
| `x86asm.mbc` | x86 assembler |
| `kernel_100_final.mbc` | Kernel generator |

## Usage

These .mbc files can be executed by the Mini VM embedded in the kernel.

```
MATHIS OS > run mathisc_v1.mbc
```

## Bootstrap Process

1. Boot MATHIS OS (kernel with Mini VM)
2. Mini VM executes mathisc.mbc to compile new code
3. No Rust needed!

## Generated with

```bash
cargo run -p masm -- assemble <file>.masm -o <file>.mbc
```

This was the LAST use of Rust. From now on, MATHIS is self-sufficient.
