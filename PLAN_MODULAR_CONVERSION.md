# Plan de Conversion Modulaire Complète

## Conventions de Code

```
SOLID, modulaire, 1 fichier 1 tâche, max 100 lignes.
Convention System V : RDI, RSI, RDX, RCX, R8, R9.
Preserved : R12-R15, RBX, RBP.
Stack aligné 16 bytes avant call.
Commentaires en anglais.
Snake_case pour les noms.
Max 50 lignes par fonction.
Pas de magic numbers.
```

---

## Phase 1: Memory Management (mm/)

### 1.1 mm/const.asm (Constants only)
```nasm
; Constants shared across all mm modules
PAGE_SIZE           equ 0x1000
PAGE_SHIFT          equ 12
HEAP_START          equ 0x400000
HEAP_SIZE           equ 0x1000000
PMM_BITMAP_ADDR     equ 0x200000
```

### 1.2 mm/heap.asm ✓ (Already done)
- Exports: `heap_init`, `malloc`, `free`, `realloc`, `calloc`
- Imports: None

### 1.3 mm/pmm.asm (~80 lines)
```nasm
; Physical Memory Manager - Page allocator
; Exports:
global pmm_init              ; Initialize from E820 map
global pmm_alloc_page        ; Returns physical page address
global pmm_free_page         ; Frees a physical page
global pmm_get_free_count    ; Returns free page count

; Imports:
extern e820_entries          ; From e820.asm
extern e820_count
```

### 1.4 mm/vmm.asm (~90 lines)
```nasm
; Virtual Memory Manager - Page table operations
; Exports:
global vmm_init              ; Setup page tables
global vmm_map_page          ; Map virtual to physical
global vmm_unmap_page        ; Unmap virtual address
global vmm_get_phys          ; Get physical from virtual

; Imports:
extern pmm_alloc_page
extern pmm_free_page
```

### 1.5 mm/slab.asm (~80 lines)
```nasm
; Slab Allocator - Fixed-size object pools
; Exports:
global slab_init
global slab_alloc            ; Allocate from cache
global slab_free             ; Return to cache

; Imports:
extern pmm_alloc_page
```

---

## Phase 2: Filesystem (fs/)

### 2.1 fs/ata.asm (~60 lines)
```nasm
; ATA PIO Driver - Sector read/write
; Exports:
global ata_read_sector       ; RDI=lba, RSI=buffer
global ata_write_sector      ; RDI=lba, RSI=buffer
global ata_identify          ; Identify drive

; Imports: None (hardware I/O only)
```

### 2.2 fs/fat32.asm (~100 lines, split if needed)
```nasm
; FAT32 Filesystem Driver
; Exports:
global fat32_init            ; Initialize filesystem
global fat32_read_file       ; Read file to buffer
global fat32_list_dir        ; List directory entries
global fat32_get_cluster     ; Get cluster chain

; Imports:
extern ata_read_sector
extern malloc
extern free
```

### 2.3 fs/path.asm (~50 lines)
```nasm
; Path utilities
; Exports:
global path_parse            ; Parse path components
global path_join             ; Join path parts
global path_get_parent       ; Get parent directory
```

---

## Phase 3: Input (input/)

### 3.1 input/keyboard.asm (~60 lines)
```nasm
; PS/2 Keyboard Driver
; Exports:
global keyboard_isr          ; IRQ1 handler
global keyboard_get_key      ; Get last key pressed
global keyboard_clear        ; Clear key buffer

; Imports:
extern key_buffer            ; From input/state.asm
extern key_pressed
```

### 3.2 input/mouse.asm (~70 lines)
```nasm
; PS/2 Mouse Driver
; Exports:
global mouse_init            ; Initialize PS/2 mouse
global mouse_isr             ; IRQ12 handler
global mouse_get_pos         ; Get X, Y position
global mouse_get_buttons     ; Get button state

; Imports:
extern mouse_x, mouse_y      ; From input/state.asm
extern mouse_buttons
extern screen_width, screen_height
```

### 3.3 input/state.asm (~30 lines, data only)
```nasm
; Input state variables
; Exports:
global key_buffer
global key_pressed
global mouse_x, mouse_y
global mouse_buttons
global mouse_clicked
```

---

## Phase 4: Graphics (ui/)

### 4.1 ui/video.asm (~80 lines)
```nasm
; Video primitives
; Exports:
global video_clear           ; Clear screen with color
global video_put_pixel       ; Draw single pixel
global video_draw_rect       ; Draw filled rectangle
global video_draw_line       ; Draw line

; Imports:
extern screen_fb, screen_width, screen_height, screen_pitch
```

### 4.2 ui/text.asm (~70 lines)
```nasm
; Text rendering
; Exports:
global text_draw_char        ; Draw single character
global text_draw_string      ; Draw null-terminated string
global text_draw_number      ; Draw integer

; Imports:
extern video_put_pixel
extern font_8x8              ; From ui/font.asm
```

### 4.3 ui/font.asm (~50 lines)
```nasm
; Font data
; Exports:
global font_8x8              ; 8x8 bitmap font (256 chars)

; Data section only - no code
```

### 4.4 ui/cursor.asm (~40 lines)
```nasm
; Mouse cursor rendering
; Exports:
global cursor_draw           ; Draw cursor at position
global cursor_hide           ; Hide cursor (restore background)

; Imports:
extern mouse_x, mouse_y
extern video_put_pixel
```

---

## Phase 5: Core Handlers (handlers/)

### 5.1 handlers/global.asm (~50 lines)
```nasm
; Global key handlers (TAB, ESC, etc.)
; Exports:
global handle_global_keys

; Imports:
extern key_pressed
extern mode_flag
```

### 5.2 handlers/desktop.asm (~60 lines)
```nasm
; Desktop mode input handlers
; Exports:
global handle_desktop_input
global handle_desktop_click

; Imports:
extern mouse_x, mouse_y, mouse_clicked
extern active_window
```

---

## Phase 6: Modes (modes/)

### 6.1 modes/desktop.asm (~80 lines)
```nasm
; Desktop mode - main GUI
; Exports:
global desktop_init
global desktop_draw
global desktop_update

; Imports:
extern video_clear, video_draw_rect
extern cursor_draw
extern handle_desktop_input
```

---

## Structure des Fichiers Finale

```
boot/kernel/
├── core_entry.asm          ; Entry point (exists)
├── core/
│   └── tables.asm          ; IDT, TSS, PIC, PIT (exists)
├── mm/
│   ├── const.asm           ; Memory constants
│   ├── heap.asm            ; Heap allocator (exists)
│   ├── pmm.asm             ; Physical page manager
│   ├── vmm.asm             ; Virtual memory manager
│   └── slab.asm            ; Slab allocator
├── fs/
│   ├── ata.asm             ; ATA PIO driver
│   ├── fat32.asm           ; FAT32 filesystem
│   └── path.asm            ; Path utilities
├── input/
│   ├── state.asm           ; Input state variables
│   ├── keyboard.asm        ; Keyboard driver
│   └── mouse.asm           ; Mouse driver
├── ui/
│   ├── video.asm           ; Video primitives
│   ├── text.asm            ; Text rendering
│   ├── font.asm            ; Font data
│   └── cursor.asm          ; Cursor rendering
├── handlers/
│   ├── global.asm          ; Global key handlers
│   └── desktop.asm         ; Desktop handlers
├── modes/
│   └── desktop.asm         ; Desktop mode
└── kernel.ld               ; Linker script (exists)
```

---

## Ordre d'Implémentation

| # | Module | Dépendances | Priorité |
|---|--------|-------------|----------|
| 1 | mm/const.asm | None | HIGH |
| 2 | mm/pmm.asm | mm/const | HIGH |
| 3 | mm/vmm.asm | mm/pmm | HIGH |
| 4 | mm/slab.asm | mm/pmm | MEDIUM |
| 5 | fs/ata.asm | None | HIGH |
| 6 | fs/fat32.asm | fs/ata, mm/heap | HIGH |
| 7 | input/state.asm | None | HIGH |
| 8 | input/keyboard.asm | input/state | HIGH |
| 9 | input/mouse.asm | input/state | HIGH |
| 10 | ui/font.asm | None | MEDIUM |
| 11 | ui/video.asm | None | HIGH |
| 12 | ui/text.asm | ui/video, ui/font | MEDIUM |
| 13 | ui/cursor.asm | input/mouse, ui/video | MEDIUM |
| 14 | handlers/global.asm | input/state | MEDIUM |
| 15 | modes/desktop.asm | ui/*, input/* | LOW |

---

## Template de Module

```nasm
; ============================================================================
; MODULE_NAME.ASM - Brief description
; ============================================================================

[BITS 64]
[DEFAULT REL]

; ============================================================================
; CONSTANTS
; ============================================================================
CONST_NAME          equ 0x1234

; ============================================================================
; IMPORTS
; ============================================================================
extern some_function
extern some_variable

; ============================================================================
; EXPORTS
; ============================================================================
global my_function

; ============================================================================
; CODE
; ============================================================================
section .text

; ----------------------------------------------------------------------------
; my_function - Brief description
; Input:  RDI = param1, RSI = param2
; Output: RAX = result
; ----------------------------------------------------------------------------
my_function:
    push rbx                    ; Preserve callee-saved
    push r12

    ; Function body (max 50 lines)

    pop r12
    pop rbx
    ret

; ============================================================================
; DATA
; ============================================================================
section .data

my_variable:    dq 0

; ============================================================================
; BSS
; ============================================================================
section .bss

my_buffer:      resb 256
```

---

## Build Command

```bash
#!/bin/bash
OBJS=""
for f in core_entry core/tables mm/heap mm/pmm mm/vmm \
         fs/ata fs/fat32 input/state input/keyboard input/mouse \
         ui/video ui/text ui/font ui/cursor; do
    nasm -f elf64 boot/kernel/${f}.asm -o build/${f##*/}.o
    OBJS="$OBJS build/${f##*/}.o"
done
x86_64-elf-ld -T boot/kernel/kernel.ld -o build/kernel.elf $OBJS
x86_64-elf-objcopy -O binary build/kernel.elf build/kernel.bin
```

---

*Plan créé pour MathisOS - Décembre 2024*
