# MATHIS OS - Kernel Architecture Map

## Overview

MathisOS is a 64-bit operating system written in x86-64 assembly. The kernel provides a graphical desktop environment, multitasking, networking, and file system support.

## Boot Sequence

```
boot.bin → stage2.bin → core.asm → go64.asm
                                      ↓
                              core/entry64.asm (do_go64 → long_mode_entry)
                                      ↓
                              core/main_loop.asm (main_loop dispatcher)
```

## Directory Structure

```
kernel/
├── go64.asm              # Main kernel entry point (constants + includes)
├── core.asm              # 32-bit kernel entry (calls do_go64)
├── CONVENTIONS.md        # Calling conventions documentation
├── KERNEL_MAP.md         # This file
│
├── core/                 # Core kernel modules
│   ├── entry64.asm       # 32→64 bit transition + initialization
│   ├── main_loop.asm     # Main dispatch loop for all modes
│   └── isr.asm           # Interrupt service routines (syscall, mouse)
│
├── modes/                # Application modes
│   ├── desktop.asm       # GUI desktop (mode_flag=2)
│   ├── graphics.asm      # Legacy graphics mode (mode_flag=0)
│   ├── shell.asm         # Text shell mode (mode_flag=1)
│   └── files/            # File manager (mode_flag=4)
│       ├── files_main.asm
│       ├── files_draw.asm
│       ├── files_view.asm
│       └── files_data.asm
│
├── ui/                   # UI components
│   ├── draw.asm          # Drawing primitives (fill_rect, draw_text, etc.)
│   ├── desktop.asm       # Desktop icons, mouse cursor, start menu
│   ├── taskbar.asm       # Clock, process indicator
│   ├── window.asm        # Window management
│   ├── terminal.asm      # Terminal window
│   ├── dialog.asm        # Dialog boxes
│   ├── files.asm         # Files window (legacy)
│   └── input.asm         # UI input helpers
│
├── input/                # Input handling
│   ├── state.asm         # Input state variables
│   ├── scancode.asm      # Scancode tables
│   ├── keyboard.asm      # Keyboard ISR + handler
│   ├── mouse.asm         # Mouse initialization + handler
│   └── dispatcher.asm    # Input event dispatcher
│
├── handlers/             # Mode-specific key handlers
│   ├── global_keys.asm   # Global hotkeys (Tab, Esc, etc.)
│   ├── gui_keys.asm      # GUI mode keys
│   ├── files_keys.asm    # File manager keys
│   ├── terminal_keys.asm # Terminal keys
│   ├── shell_keys.asm    # Shell mode keys
│   └── 3d_keys.asm       # 3D mode keys
│
├── sys/                  # System services
│   ├── setup.asm         # IDT, TSS, PIC, PIT setup
│   ├── timer.asm         # Timer ISR (IRQ0)
│   └── ring3.asm         # Ring 3 support (user mode)
│
├── gfx3d/                # 3D graphics engine
│   ├── math3d.asm        # 3D math (fixed-point)
│   ├── camera3d.asm      # Camera/projection
│   ├── render3d.asm      # 3D rendering
│   ├── world3d.asm       # World/scene
│   ├── ui3d.asm          # 3D UI interface
│   └── effects3d.asm     # Visual effects
│
├── fs/                   # File systems
│   └── fat32.asm         # FAT32 driver
│
├── mm/                   # Memory management
│   └── heap.asm          # Heap allocator
│
├── e1000/                # Network (Intel E1000)
│   ├── e1000.asm         # Main driver
│   ├── e1000_init.asm    # Initialization
│   ├── e1000_regs.asm    # Register definitions
│   ├── e1000_rx.asm      # Receive
│   └── e1000_tx.asm      # Transmit
│
├── net/                  # Network stack
│   ├── arp.asm           # ARP
│   ├── dhcp.asm          # DHCP
│   ├── dns.asm           # DNS
│   ├── icmp.asm          # ICMP/ping
│   ├── ip.asm            # IPv4
│   ├── tcp.asm           # TCP
│   └── udp.asm           # UDP
│
├── usb/                  # USB (UHCI)
│   ├── uhci.asm          # Main driver
│   ├── uhci_init.asm     # Initialization
│   ├── uhci_hub.asm      # Hub support
│   └── uhci_transfer.asm # Transfers
│
├── exec/                 # Program execution
│   └── elf.asm           # ELF loader
│
├── vm/                   # Virtual machine (bytecode)
│   ├── core.asm          # VM core
│   ├── stack.asm         # Stack operations
│   ├── math.asm          # Math ops
│   ├── bitwise.asm       # Bitwise ops
│   ├── control.asm       # Control flow
│   ├── memory.asm        # Memory ops
│   ├── io.asm            # I/O ops
│   └── float.asm         # Float ops
│
└── deprecated/           # Deprecated code (backup)
    └── 3d/               # Old 3D code
```

## Mode System

The kernel uses `mode_flag` to dispatch to different application modes:

| mode_flag | Mode | Description |
|-----------|------|-------------|
| 0 | graphics_mode | Legacy graphics mode |
| 1 | shell_mode | Text shell |
| 2 | gui_mode | Desktop GUI |
| 3 | gui3d_mode | 3D interface |
| 4 | files_mode | File manager |

Mode switching is done via the TAB key (handled in handlers/global_keys.asm).

## Key Functions

### Core
- `do_go64` - Setup paging, switch to long mode
- `long_mode_entry` - 64-bit initialization
- `main_loop` - Main dispatch loop
- `process_input` - Input event processor

### ISRs
- `timer_isr64` - Timer (IRQ0, 100Hz)
- `keyboard_isr64` - Keyboard (IRQ1)
- `mouse_isr64` - Mouse (IRQ12)
- `syscall_isr64` - System calls (INT 0x80)

### Drawing
- `fill_rect` - Fill rectangle (edi=x, esi=y, edx=w, ecx=h, r8d=color)
- `draw_rect` - Draw outline
- `draw_text` - Draw text (rdi=pos, rsi=string, r8d=color)
- `draw_line` - Bresenham line (edi=x1, esi=y1, edx=x2, ecx=y2, r8d=color)

### System
- `setup_idt64` - Setup Interrupt Descriptor Table
- `setup_tss64` - Setup Task State Segment
- `setup_pic64` - Setup Programmable Interrupt Controller
- `setup_pit64` - Setup Programmable Interval Timer

## Memory Map

```
0x00000000 - 0x00001000  Page tables
0x00010000 - 0x00090000  Kernel code/data
0x00090000              Kernel stack
0x00400000 - 0x01400000  Heap (4-20MB)
0xFD000000+             VESA framebuffer (mapped via PDPT[3])
```

## Data Locations

Key variables in go64.asm DATA section:
- `screen_fb` - Framebuffer address (qword)
- `screen_width/height` - Screen dimensions (dword)
- `screen_pitch` - Bytes per line (dword)
- `tick_count` - System tick counter (qword)
- `mode_flag` - Current mode (byte)
- `mouse_x/y` - Mouse position (word)

## Calling Convention

See CONVENTIONS.md for full details. Summary:
- Arguments: RDI, RSI, RDX, RCX, R8, R9
- Preserved: RBX, RBP, R12-R15
- Scratch: RAX, RCX, RDX, RSI, RDI, R8-R11

## Build System

```bash
./build.sh
# Outputs:
#   boot.bin    - Boot sector (512B)
#   stage2.bin  - Stage 2 loader (4KB)
#   kernel.bin  - Kernel (512KB)
#   mathis.img  - Complete disk image (10MB)
```

## Testing

```bash
qemu-system-x86_64 -hda boot/mathis.img -m 128M
```

---

## SOLID Architecture (En cours)

Voir **SOLID_PLAN.md** pour le plan détaillé.

### Principes

| Principe | Application |
|----------|-------------|
| **S**ingle Responsibility | 1 fichier = 1 responsabilité |
| **O**pen/Closed | V-Tables pour extension sans modification |
| **L**iskov Substitution | Widgets interchangeables |
| **I**nterface Segregation | Services avec API minimale |
| **D**ependency Inversion | Service registry, pas de dépendances directes |

### Structure Cible

```
kernel/
├── core/           # Boot + Main loop (fait)
├── mm/             # Memory (heap allocator)
├── services/       # Abstractions (registry, interfaces)
├── drivers/        # Implementations (vesa, ps2, fat32)
├── widgets/        # UI components (button, window, etc.)
├── events/         # Event system (queue, dispatch)
├── apps/           # Applications (desktop, terminal, files)
└── sys/            # System services (fait)
```

### V-Table Widget System

```
┌─────────────────────────────────────────────────────────────┐
│                    WIDGET INHERITANCE                        │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│    Widget (base)                                             │
│      │                                                       │
│      ├── Container                                           │
│      │     ├── Window                                        │
│      │     └── Panel                                         │
│      │                                                       │
│      ├── Button                                              │
│      ├── Label                                               │
│      ├── TextBox                                             │
│      ├── List                                                │
│      └── Icon                                                │
│                                                              │
└─────────────────────────────────────────────────────────────┘

Widget V-Table:
  [0]  draw(self)
  [8]  on_click(self, x, y)
  [16] on_key(self, scancode)
  [24] on_focus(self, focused)
  [32] destroy(self)
  [40] get_size(self)
```

### Service Registry

```
┌─────────────────────────────────────────────────────────────┐
│                    SERVICE ARCHITECTURE                      │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│   ┌─────────────┐                                           │
│   │   Kernel    │                                           │
│   │  main_loop  │                                           │
│   └──────┬──────┘                                           │
│          │                                                   │
│          ▼                                                   │
│   ┌─────────────────────────────────────────┐               │
│   │          SERVICE REGISTRY               │               │
│   │  ┌─────┬─────┬─────┬─────┬─────┬─────┐  │               │
│   │  │VIDEO│INPUT│ALLOC│ FS  │ NET │TIMER│  │               │
│   │  └──┬──┴──┬──┴──┬──┴──┬──┴──┬──┴──┬──┘  │               │
│   └─────┼─────┼─────┼─────┼─────┼─────┼─────┘               │
│         │     │     │     │     │     │                     │
│         ▼     ▼     ▼     ▼     ▼     ▼                     │
│       VESA   PS2   HEAP  FAT32 E1000  PIT                   │
│      Driver Driver Alloc Driver Driver Timer                │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

### Phases d'Implémentation

| Phase | Description | Statut |
|-------|-------------|--------|
| 0 | Cleanup + Modularisation | ✅ Fait |
| 1 | Heap Allocator (kmalloc/kfree) | ⏳ À faire |
| 2 | Service Registry | ⏳ À faire |
| 3 | Widget System (V-Tables) | ⏳ À faire |
| 4 | Desktop Refactor | ⏳ À faire |
| 5 | Event System | ⏳ À faire |
