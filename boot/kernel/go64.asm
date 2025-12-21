; ════════════════════════════════════════════════════════════════════════════
; GO64.ASM - MATHIS OS 64-bit with Full GUI Desktop + MULTITASKING
; Features:
; - Timer IRQ0 (system tick + clock + SCHEDULER)
; - Keyboard IRQ1 (full input)
; - PS/2 Mouse IRQ12 (cursor + clicks)
; - GUI Desktop with icons
; - Window system (drag, close, minimize)
; - Terminal app, Files app, 3D Demo, Settings
; - Taskbar with Start menu and clock
; - PREEMPTIVE MULTITASKING with round-robin scheduler
; ════════════════════════════════════════════════════════════════════════════

; Screen constants (compile-time defaults for backward compatibility)
; Runtime code should use screen_width, screen_height, screen_fb variables
GFX_FB      equ 0xA0000
GFX_W       equ 640             ; Max supported width (VESA 640x480)
GFX_H       equ 480             ; Max supported height
CENTER_X    equ 320             ; Will be recalculated at runtime
CENTER_Y    equ 240

; Old compatibility aliases
GFX_FB_DEFAULT  equ 0xA0000
GFX_W_DEFAULT   equ 640
GFX_H_DEFAULT   equ 480

; Memory locations where stage2 stores video info
VIDEO_INFO_FB     equ 0x500    ; Framebuffer address (4 bytes)
VIDEO_INFO_W      equ 0x504    ; Screen width (4 bytes)
VIDEO_INFO_H      equ 0x508    ; Screen height (4 bytes)
VIDEO_INFO_VESA   equ 0x50C    ; VESA mode flag (4 bytes)
VIDEO_INFO_PITCH  equ 0x510    ; Screen pitch/bytes per line (4 bytes)
VIDEO_INFO_BPP    equ 0x514    ; Bits per pixel (4 bytes) - 8, 24, or 32

; GUI Constants
TASKBAR_H   equ 14
TITLEBAR_H  equ 12
MAX_WINDOWS equ 4

; Colors (VGA 256 palette)
COL_DESKTOP     equ 1         ; Blue
COL_TASKBAR     equ 8         ; Dark gray
COL_TASKBAR_LT  equ 7         ; Light gray
COL_TITLEBAR    equ 9         ; Light blue
COL_TITLE_INACT equ 8         ; Gray
COL_WINDOW      equ 15        ; White
COL_BORDER      equ 0         ; Black
COL_TEXT        equ 0         ; Black
COL_TEXT_WHITE  equ 15        ; White
COL_CLOSE_BTN   equ 4         ; Red
COL_CURSOR      equ 15        ; White
COL_SHADOW      equ 0         ; Black
COL_SELECTED    equ 11        ; Light cyan
COL_GREEN       equ 10        ; Bright green
COL_YELLOW      equ 14        ; Yellow
COL_CYAN        equ 3         ; Cyan

; PS/2 Mouse ports
MOUSE_DATA   equ 0x60
MOUSE_CMD    equ 0x64
MOUSE_STATUS equ 0x64

; ════════════════════════════════════════════════════════════════════════════
; CORE MODULES (entry, main loop, ISRs)
; ════════════════════════════════════════════════════════════════════════════
%include "core/entry64.asm"
%include "core/main_loop.asm"

; %include "modes/desktop.asm"   ; DEPRECATED - focus on files_mode

%include "core/isr.asm"

; ════════════════════════════════════════════════════════════════════════════
; INCLUDE SCHEDULER MODULE
; ════════════════════════════════════════════════════════════════════════════
%include "scheduler.asm"

; ════════════════════════════════════════════════════════════════════════════
; PRIORITY SCHEDULER EXTENSION
; ════════════════════════════════════════════════════════════════════════════
%include "sched/priority_const.asm"
%include "sched/priority.asm"
%include "sched/setpriority.asm"

; ════════════════════════════════════════════════════════════════════════════
; SIGNAL SUBSYSTEM - ALL DISABLED
; ════════════════════════════════════════════════════════════════════════════
%include "signal/const.asm"
; %include "signal/table.asm"
; %include "signal/init.asm"
; %include "signal/entry.asm"
; %include "signal/send.asm"
; %include "signal/handler.asm"
; %include "signal/check.asm"
; %include "signal/deliver.asm"

; ════════════════════════════════════════════════════════════════════════════
; DEPRECATED MODULES - Moved to deprecated/ for later reintegration
; Focus: files_mode only for now
; ════════════════════════════════════════════════════════════════════════════
; %include "e1000/e1000.asm"      ; Network driver - deprecated/e1000/
; %include "syscalls.asm"         ; 48 syscalls - not needed for files_mode
; %include "usb/uhci.asm"         ; USB driver - deprecated/usb/
; %include "acpi.asm"             ; ACPI power - not critical

; STUB: net_init (called by entry64.asm)
net_init:
    ret

; STUB: usb_init (called by entry64.asm)
usb_init:
    ret

; STUB: acpi_init (called by entry64.asm)
acpi_init:
    ret

; ════════════════════════════════════════════════════════════════════════════
; INCLUDE HEAP ALLOCATOR
; ════════════════════════════════════════════════════════════════════════════
%include "mm/heap.asm"

; ════════════════════════════════════════════════════════════════════════════
; E820 MEMORY MAP DETECTION
; ════════════════════════════════════════════════════════════════════════════
%include "mm/e820.asm"

; ════════════════════════════════════════════════════════════════════════════
; PMM - PHYSICAL MEMORY MANAGER
; ════════════════════════════════════════════════════════════════════════════
%include "mm/pmm_const.asm"
%include "mm/pmm_bitmap.asm"
%include "mm/pmm_init.asm"
%include "mm/pmm_alloc.asm"
%include "mm/pmm_free.asm"

; ════════════════════════════════════════════════════════════════════════════
; VMM - VIRTUAL MEMORY MANAGER
; ════════════════════════════════════════════════════════════════════════════
%include "mm/vmm_const.asm"
%include "mm/vmm.asm"
%include "mm/vmm_helpers.asm"

; ════════════════════════════════════════════════════════════════════════════
; SLAB - SLAB ALLOCATOR
; ════════════════════════════════════════════════════════════════════════════
%include "mm/slab_const.asm"
%include "mm/slab.asm"
%include "mm/slab_create.asm"

; ════════════════════════════════════════════════════════════════════════════
; MEMORY PROTECTION
; ════════════════════════════════════════════════════════════════════════════
%include "mm/protection.asm"

; ════════════════════════════════════════════════════════════════════════════
; INCLUDE ATA64 DRIVER (64-bit disk I/O)
; ════════════════════════════════════════════════════════════════════════════
%include "fs/ata64.asm"

; ════════════════════════════════════════════════════════════════════════════
; INCLUDE FAT32 FILESYSTEM
; ════════════════════════════════════════════════════════════════════════════
%include "fs/fat32.asm"

; ════════════════════════════════════════════════════════════════════════════
; INCLUDE PATH PARSING (depends on fat32)
; ════════════════════════════════════════════════════════════════════════════
%include "fs/path/path.asm"

; ════════════════════════════════════════════════════════════════════════════
; INCLUDE ELF LOADER
; ════════════════════════════════════════════════════════════════════════════
%include "exec/elf.asm"

; ════════════════════════════════════════════════════════════════════════════
; DATA SECTION
; ════════════════════════════════════════════════════════════════════════════
align 8

; Screen variables (initialized from stage2 video info)
screen_fb:      dq GFX_FB_DEFAULT   ; Framebuffer address
screen_width:   dd GFX_W_DEFAULT    ; Screen width
screen_height:  dd GFX_H_DEFAULT    ; Screen height
screen_pitch:   dd GFX_W_DEFAULT    ; Bytes per line (= width for 8bpp)
screen_bpp:     dd 8                ; Bits per pixel (8, 24, or 32)
screen_centerx: dd 320              ; Center X
screen_centery: dd 240              ; Center Y

; System variables
tick_count:     dq 0
mode_flag:      db 2                ; 0=graphics, 1=shell, 2=GUI/Desktop, 3=3D, 4=files
key3d_scancode: db 0                ; Last scancode for 3D mode
align 4
tab_debounce:   dd 0                ; Tab key debounce counter (unused)
last_tab_tick:  dd 0                ; Tick count of last Tab press (32-bit)
ui3d_initialized: db 0              ; 1 if 3D engine was initialized
active_window:  db 0xFF
start_menu_open: db 0
dragging:       db 0
drag_window:    db 0
drag_offset_x:  dw 0
drag_offset_y:  dw 0

; Mouse state moved to input/state.asm

; Terminal state
cmd_buf:        times 64 db 0
cmd_pos:        db 0
show_result:    db 0
result_buf:     times 64 db 0

; Demo process counters (to show multitasking is working)
demo1_counter:  dq 0
demo2_counter:  dq 0

; Clock buffer for time display
clock_buf:      times 8 db 0

; Process indicator buffer
proc_ind_buf:   times 8 db 0

; Temp variables for 3D
temp_x1:        dd 0
temp_y1:        dd 0
temp_x2:        dd 0
temp_y2:        dd 0
temp_x3:        dd 0
temp_y3:        dd 0
temp_x4:        dd 0
temp_y4:        dd 0

; Windows array (4 windows * 32 bytes each)
; Format: flags(1), type(1), x(2), y(2), w(2), h(2), reserved(6), title_ptr(8), extra(8)
align 8
windows:        times MAX_WINDOWS * 32 db 0

; Strings
str_banner:     db "MATHIS OS 64-BIT", 0
str_start:      db "Start", 0
str_terminal:   db "Terminal", 0
str_files:      db "Files", 0
str_3ddemo:     db "3D Demo", 0
str_x:          db "X", 0

str_win_terminal: db "Terminal", 0
str_win_files:    db "Files", 0
str_win_3d:       db "3D Demo", 0

str_term_header:  db "MATHIS OS Terminal", 0
str_term_help:    db "Cmds: help,ps,kill <pid>", 0
str_prompt:       db "mathis>", 0

str_file1:        db "[DIR] boot/", 0
str_file2:        db "[DIR] system/", 0
str_file3:        db "readme.txt", 0

str_menu_term:    db "Terminal", 0
str_menu_files:   db "Files", 0
str_menu_3d:      db "3D Demo", 0
str_menu_about:   db "About", 0
str_menu_reboot:  db "Reboot", 0

str_help_result:  db "help,clear,ls,ps", 0
str_ls_result:    db "boot/ readme.txt", 0

str_3d_mode:      db "3D MODE", 0
str_help_gfx:     db "TAB=next mode", 0
str_help_shell:   db "TAB=next mode ESC=reboot", 0

; Process names for demos
str_proc_demo1:   db "worker1", 0
str_proc_demo2:   db "worker2", 0
str_ps_header:    db "PID STATE NAME", 0
str_proc_run:     db "RUN ", 0
str_proc_rdy:     db "RDY ", 0
str_proc_blk:     db "BLK ", 0

; Scancode to ASCII (lowercase/unshifted)
scancode_ascii:
    db 0, 0, '1', '2', '3', '4', '5', '6', '7', '8', '9', '0', '-', '=', 0, 0
    db 'q', 'w', 'e', 'r', 't', 'y', 'u', 'i', 'o', 'p', '[', ']', 0, 0
    db 'a', 's', 'd', 'f', 'g', 'h', 'j', 'k', 'l', ';', "'", '`', 0, '\'
    db 'z', 'x', 'c', 'v', 'b', 'n', 'm', ',', '.', '/', 0, 0, 0, ' '

; Sin table for 3D
sin_table:
    db  0,  3,  6,  9, 12, 15, 18, 21
    db 24, 26, 28, 30, 31, 32, 32, 32
    db 32, 32, 32, 31, 30, 28, 26, 24
    db 21, 18, 15, 12,  9,  6,  3,  0
    db  0, -3, -6, -9,-12,-15,-18,-21
    db -24,-26,-28,-30,-31,-32,-32,-32
    db -32,-32,-32,-31,-30,-28,-26,-24
    db -21,-18,-15,-12, -9, -6, -3,  0

; 8x8 Bitmap Font - Extracted to ui/font8x8_data.asm
%include "ui/font8x8_data.asm"

; IDT
align 16
idt64:          times 256 dq 0, 0

idt64_ptr:
    dw 256*16 - 1
    dq idt64

idt64_null:
    dw 0
    dq 0

; GDT with Ring 3 support
[BITS 32]
align 16
gdt64:
    dq 0                            ; 0x00: Null descriptor
    dq 0x00209A0000000000           ; 0x08: Kernel Code (Ring 0, DPL=0)
    dq 0x0000920000000000           ; 0x10: Kernel Data (Ring 0, DPL=0)
    dq 0x0020FA0000000000           ; 0x18: User Code (Ring 3, DPL=3)
    dq 0x0000F20000000000           ; 0x20: User Data (Ring 3, DPL=3)
    ; 0x28: TSS descriptor (16 bytes in 64-bit mode)
    dw 104                          ; Limit (size of TSS - 1)
    dw 0                            ; Base 15:0 (patched at runtime)
    db 0                            ; Base 23:16
    db 0x89                         ; Type: 64-bit TSS Available, DPL=0
    db 0x00                         ; Limit 19:16, flags
    db 0                            ; Base 31:24
    dd 0                            ; Base 63:32
    dd 0                            ; Reserved
gdt64_end:

gdt64_ptr:
    dw gdt64_end - gdt64 - 1
    dd gdt64

; Selectors for easy reference
KERNEL_CODE_SEL equ 0x08
KERNEL_DATA_SEL equ 0x10
USER_CODE_SEL   equ 0x18 | 3       ; 0x1B (Ring 3)
USER_DATA_SEL   equ 0x20 | 3       ; 0x23 (Ring 3)
TSS_SEL         equ 0x28

; ════════════════════════════════════════════════════════════════════════════
; TSS (Task State Segment) - Required for Ring 3 → Ring 0 transitions
; ════════════════════════════════════════════════════════════════════════════
; IST1 used for Double Fault handler (separate stack prevents triple fault)
; ════════════════════════════════════════════════════════════════════════════

; IST1 stack location (4KB below kernel stack)
IST1_STACK_TOP      equ 0x8F000     ; 4KB stack at 0x8E000-0x8F000

align 16
tss64:
    dd 0                            ; Reserved
    dq 0x90000                      ; RSP0 - Kernel stack for interrupts
    dq 0                            ; RSP1
    dq 0                            ; RSP2
    dq 0                            ; Reserved
    dq IST1_STACK_TOP               ; IST1 - Double fault stack
    dq 0                            ; IST2
    dq 0                            ; IST3
    dq 0                            ; IST4
    dq 0                            ; IST5
    dq 0                            ; IST6
    dq 0                            ; IST7
    dq 0                            ; Reserved
    dw 0                            ; Reserved
    dw 104                          ; IOPB offset (no IOPB)
tss64_end:

; ════════════════════════════════════════════════════════════════════════════
; BACK TO 64-BIT MODE FOR REMAINING INCLUDES
; ════════════════════════════════════════════════════════════════════════════
[BITS 64]

; ════════════════════════════════════════════════════════════════════════════
; 3D ENGINE - DEPRECATED (moved to deprecated/gfx3d/)
; ════════════════════════════════════════════════════════════════════════════
; %include "gfx3d/math3d.asm"
; %include "gfx3d/camera3d.asm"
; %include "gfx3d/render3d.asm"
; %include "gfx3d/world3d.asm"
; %include "gfx3d/ui3d.asm"
; %include "gfx3d/effects3d.asm"

; ════════════════════════════════════════════════════════════════════════════
; STUBS FOR DEPRECATED 3D/SYSCALL MODULES
; ════════════════════════════════════════════════════════════════════════════
%include "deprecated/stubs.asm"

; ════════════════════════════════════════════════════════════════════════════
; UI MODULES - MINIMAL SET FOR FILES_MODE
; ════════════════════════════════════════════════════════════════════════════
%include "ui/draw.asm"              ; CORE: Drawing primitives
; %include "ui/dialog.asm"          ; DEPRECATED
%include "ui/files.asm"             ; CORE: File list widget
%include "ui/input.asm"             ; CORE: Input helpers
; %include "ui/window.asm"          ; DEPRECATED (window management)
; %include "ui/terminal.asm"        ; DEPRECATED
%include "ui/desktop.asm"             ; Icons & mouse cursor (used by desktop_app)
; %include "ui/taskbar.asm"         ; DEPRECATED

; ════════════════════════════════════════════════════════════════════════════
; INPUT MODULES - CORE (keyboard/mouse)
; ════════════════════════════════════════════════════════════════════════════
%include "input/state.asm"
%include "input/scancode.asm"
%include "input/mouse.asm"
%include "input/keyboard.asm"
%include "input/dispatcher.asm"
%include "input/cursor.asm"            ; Unified cursor rendering
%include "input/input_manager.asm"     ; Centralized input management

; ════════════════════════════════════════════════════════════════════════════
; INPUT HANDLERS - MINIMAL
; ════════════════════════════════════════════════════════════════════════════
%include "handlers/global_keys.asm"  ; CORE: TAB mode switch, ESC
; %include "handlers/gui_keys.asm"   ; DEPRECATED
%include "handlers/files_keys.asm"   ; CORE: Files mode keys
; %include "handlers/terminal_keys.asm" ; DEPRECATED
; %include "handlers/shell_keys.asm" ; DEPRECATED
; %include "handlers/3d_keys.asm"    ; DEPRECATED

; ════════════════════════════════════════════════════════════════════════════
; MODES
; ════════════════════════════════════════════════════════════════════════════
%include "modes/graphics.asm"           ; mode_flag=0
%include "modes/shell.asm"              ; mode_flag=1
%include "modes/desktop/desktop_simple.asm" ; mode_flag=2
%include "modes/files/files_main.asm"   ; mode_flag=4
%include "modes/gui/gui_mode.asm"       ; mode_flag=2 (legacy desktop)

; SYSTEM (ISRs, setup)
%include "sys/timer.asm"
%include "sys/setup.asm"
%include "sys/ring3.asm"
%include "drivers/rtc.asm"

; EXCEPTION HANDLERS (BSOD)
%include "sys/exc_data.asm"
%include "sys/exc_bsod.asm"
%include "sys/exc_handlers.asm"

; SERVICES (SOLID Phase 2+3+4)
%include "services/registry.asm"
%include "services/alloc_svc.asm"
%include "services/video_svc.asm"
%include "services/input_svc.asm"
%include "services/fs_svc.asm"

; CRUD MODULES (SOLID - Single Responsibility)
%include "fs/crud/create.asm"
%include "fs/crud/read.asm"
%include "fs/crud/update.asm"
%include "fs/crud/delete.asm"

; EVENTS (SOLID Phase 5)
%include "events/events.asm"

; MOUSE SERVICE (SOLID Phase 6) - Centralized cursor + click handling
%include "services/mouse_svc.asm"

; WIDGETS (SOLID Phase 5)
%include "widgets/widget.asm"
%include "widgets/label.asm"
%include "widgets/button.asm"
%include "widgets/container.asm"
%include "widgets/window.asm"
%include "widgets/header.asm"
%include "widgets/pathbar.asm"
%include "widgets/file_list.asm"
%include "widgets/statusbar.asm"
%include "widgets/text_editor.asm"
%include "widgets/desktop_icon.asm"
%include "widgets/taskbar.asm"
%include "widgets/dialogs/dialog_base.asm"
%include "widgets/dialogs/dialog_new.asm"
%include "widgets/dialogs/dialog_delete.asm"
%include "widgets/dialogs/dialog_rename.asm"
%include "widgets/sidebar/sidebar.asm"

; FS EVENTS (SOLID Phase 7)
%include "fs/events/fs_events.asm"

; VFS - Shared Virtual Filesystem (SOLID Phase 8)
%include "fs/vfs/vfs.asm"

; WINDOW MANAGER - Floating windows on desktop (SOLID Phase 9)
%include "ui/wm/wm.asm"
