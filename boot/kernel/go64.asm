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

%include "modes/desktop.asm"

%include "core/isr.asm"

; ════════════════════════════════════════════════════════════════════════════
; INCLUDE SCHEDULER MODULE
; ════════════════════════════════════════════════════════════════════════════
%include "scheduler.asm"

; ════════════════════════════════════════════════════════════════════════════
; INCLUDE E1000 NETWORK DRIVER
; ════════════════════════════════════════════════════════════════════════════
%include "e1000/e1000.asm"

; ════════════════════════════════════════════════════════════════════════════
; INCLUDE SYSCALLS MODULE (48 system calls)
; ════════════════════════════════════════════════════════════════════════════
%include "syscalls.asm"

; ════════════════════════════════════════════════════════════════════════════
; INCLUDE USB UHCI DRIVER
; ════════════════════════════════════════════════════════════════════════════
%include "usb/uhci.asm"

; ════════════════════════════════════════════════════════════════════════════
; INCLUDE ACPI POWER MANAGEMENT
; ════════════════════════════════════════════════════════════════════════════
%include "acpi.asm"

; ════════════════════════════════════════════════════════════════════════════
; INCLUDE HEAP ALLOCATOR
; ════════════════════════════════════════════════════════════════════════════
%include "mm/heap.asm"

; ════════════════════════════════════════════════════════════════════════════
; INCLUDE FAT32 FILESYSTEM
; ════════════════════════════════════════════════════════════════════════════
%include "fs/fat32.asm"

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
mode_flag:      db 2                ; 0=graphics, 1=shell, 2=GUI, 3=3D GUI
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

; 8x8 Bitmap Font (ASCII 32-127)
align 8
font8x8:
    ; Space (32)
    db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
    ; ! (33)
    db 0x18, 0x18, 0x18, 0x18, 0x18, 0x00, 0x18, 0x00
    ; " (34)
    db 0x6C, 0x6C, 0x24, 0x00, 0x00, 0x00, 0x00, 0x00
    ; # (35)
    db 0x6C, 0xFE, 0x6C, 0x6C, 0xFE, 0x6C, 0x00, 0x00
    ; $ (36)
    db 0x18, 0x7E, 0xC0, 0x7C, 0x06, 0xFC, 0x18, 0x00
    ; % (37)
    db 0xC6, 0xCC, 0x18, 0x30, 0x66, 0xC6, 0x00, 0x00
    ; & (38)
    db 0x38, 0x6C, 0x38, 0x76, 0xDC, 0xCC, 0x76, 0x00
    ; ' (39)
    db 0x18, 0x18, 0x30, 0x00, 0x00, 0x00, 0x00, 0x00
    ; ( (40)
    db 0x0C, 0x18, 0x30, 0x30, 0x30, 0x18, 0x0C, 0x00
    ; ) (41)
    db 0x30, 0x18, 0x0C, 0x0C, 0x0C, 0x18, 0x30, 0x00
    ; * (42)
    db 0x00, 0x66, 0x3C, 0xFF, 0x3C, 0x66, 0x00, 0x00
    ; + (43)
    db 0x00, 0x18, 0x18, 0x7E, 0x18, 0x18, 0x00, 0x00
    ; , (44)
    db 0x00, 0x00, 0x00, 0x00, 0x00, 0x18, 0x18, 0x30
    ; - (45)
    db 0x00, 0x00, 0x00, 0x7E, 0x00, 0x00, 0x00, 0x00
    ; . (46)
    db 0x00, 0x00, 0x00, 0x00, 0x00, 0x18, 0x18, 0x00
    ; / (47)
    db 0x06, 0x0C, 0x18, 0x30, 0x60, 0xC0, 0x00, 0x00
    ; 0 (48)
    db 0x7C, 0xCE, 0xDE, 0xF6, 0xE6, 0xC6, 0x7C, 0x00
    ; 1 (49)
    db 0x18, 0x38, 0x18, 0x18, 0x18, 0x18, 0x7E, 0x00
    ; 2 (50)
    db 0x7C, 0xC6, 0x0E, 0x3C, 0x78, 0xE0, 0xFE, 0x00
    ; 3 (51)
    db 0x7C, 0xC6, 0x06, 0x3C, 0x06, 0xC6, 0x7C, 0x00
    ; 4 (52)
    db 0x1C, 0x3C, 0x6C, 0xCC, 0xFE, 0x0C, 0x0C, 0x00
    ; 5 (53)
    db 0xFE, 0xC0, 0xFC, 0x06, 0x06, 0xC6, 0x7C, 0x00
    ; 6 (54)
    db 0x7C, 0xC0, 0xFC, 0xC6, 0xC6, 0xC6, 0x7C, 0x00
    ; 7 (55)
    db 0xFE, 0x06, 0x0C, 0x18, 0x30, 0x30, 0x30, 0x00
    ; 8 (56)
    db 0x7C, 0xC6, 0xC6, 0x7C, 0xC6, 0xC6, 0x7C, 0x00
    ; 9 (57)
    db 0x7C, 0xC6, 0xC6, 0x7E, 0x06, 0x06, 0x7C, 0x00
    ; : (58)
    db 0x00, 0x18, 0x18, 0x00, 0x00, 0x18, 0x18, 0x00
    ; ; (59)
    db 0x00, 0x18, 0x18, 0x00, 0x00, 0x18, 0x18, 0x30
    ; < (60)
    db 0x0C, 0x18, 0x30, 0x60, 0x30, 0x18, 0x0C, 0x00
    ; = (61)
    db 0x00, 0x00, 0x7E, 0x00, 0x7E, 0x00, 0x00, 0x00
    ; > (62)
    db 0x30, 0x18, 0x0C, 0x06, 0x0C, 0x18, 0x30, 0x00
    ; ? (63)
    db 0x7C, 0xC6, 0x0C, 0x18, 0x18, 0x00, 0x18, 0x00
    ; @ (64)
    db 0x7C, 0xC6, 0xDE, 0xDE, 0xDE, 0xC0, 0x7C, 0x00
    ; A (65)
    db 0x38, 0x6C, 0xC6, 0xC6, 0xFE, 0xC6, 0xC6, 0x00
    ; B (66)
    db 0xFC, 0xC6, 0xC6, 0xFC, 0xC6, 0xC6, 0xFC, 0x00
    ; C (67)
    db 0x7C, 0xC6, 0xC0, 0xC0, 0xC0, 0xC6, 0x7C, 0x00
    ; D (68)
    db 0xF8, 0xCC, 0xC6, 0xC6, 0xC6, 0xCC, 0xF8, 0x00
    ; E (69)
    db 0xFE, 0xC0, 0xC0, 0xF8, 0xC0, 0xC0, 0xFE, 0x00
    ; F (70)
    db 0xFE, 0xC0, 0xC0, 0xF8, 0xC0, 0xC0, 0xC0, 0x00
    ; G (71)
    db 0x7C, 0xC6, 0xC0, 0xCE, 0xC6, 0xC6, 0x7C, 0x00
    ; H (72)
    db 0xC6, 0xC6, 0xC6, 0xFE, 0xC6, 0xC6, 0xC6, 0x00
    ; I (73)
    db 0x7E, 0x18, 0x18, 0x18, 0x18, 0x18, 0x7E, 0x00
    ; J (74)
    db 0x1E, 0x06, 0x06, 0x06, 0xC6, 0xC6, 0x7C, 0x00
    ; K (75)
    db 0xC6, 0xCC, 0xD8, 0xF0, 0xD8, 0xCC, 0xC6, 0x00
    ; L (76)
    db 0xC0, 0xC0, 0xC0, 0xC0, 0xC0, 0xC0, 0xFE, 0x00
    ; M (77)
    db 0xC6, 0xEE, 0xFE, 0xD6, 0xC6, 0xC6, 0xC6, 0x00
    ; N (78)
    db 0xC6, 0xE6, 0xF6, 0xDE, 0xCE, 0xC6, 0xC6, 0x00
    ; O (79)
    db 0x7C, 0xC6, 0xC6, 0xC6, 0xC6, 0xC6, 0x7C, 0x00
    ; P (80)
    db 0xFC, 0xC6, 0xC6, 0xFC, 0xC0, 0xC0, 0xC0, 0x00
    ; Q (81)
    db 0x7C, 0xC6, 0xC6, 0xC6, 0xD6, 0xDE, 0x7C, 0x06
    ; R (82)
    db 0xFC, 0xC6, 0xC6, 0xFC, 0xD8, 0xCC, 0xC6, 0x00
    ; S (83)
    db 0x7C, 0xC6, 0xC0, 0x7C, 0x06, 0xC6, 0x7C, 0x00
    ; T (84)
    db 0xFE, 0x18, 0x18, 0x18, 0x18, 0x18, 0x18, 0x00
    ; U (85)
    db 0xC6, 0xC6, 0xC6, 0xC6, 0xC6, 0xC6, 0x7C, 0x00
    ; V (86)
    db 0xC6, 0xC6, 0xC6, 0xC6, 0x6C, 0x38, 0x10, 0x00
    ; W (87)
    db 0xC6, 0xC6, 0xC6, 0xD6, 0xFE, 0xEE, 0xC6, 0x00
    ; X (88)
    db 0xC6, 0xC6, 0x6C, 0x38, 0x6C, 0xC6, 0xC6, 0x00
    ; Y (89)
    db 0xC6, 0xC6, 0x6C, 0x38, 0x18, 0x18, 0x18, 0x00
    ; Z (90)
    db 0xFE, 0x06, 0x0C, 0x18, 0x30, 0x60, 0xFE, 0x00
    ; [ (91)
    db 0x3C, 0x30, 0x30, 0x30, 0x30, 0x30, 0x3C, 0x00
    ; \ (92)
    db 0xC0, 0x60, 0x30, 0x18, 0x0C, 0x06, 0x00, 0x00
    ; ] (93)
    db 0x3C, 0x0C, 0x0C, 0x0C, 0x0C, 0x0C, 0x3C, 0x00
    ; ^ (94)
    db 0x10, 0x38, 0x6C, 0xC6, 0x00, 0x00, 0x00, 0x00
    ; _ (95)
    db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xFE
    ; ` (96)
    db 0x18, 0x18, 0x0C, 0x00, 0x00, 0x00, 0x00, 0x00
    ; a (97)
    db 0x00, 0x00, 0x7C, 0x06, 0x7E, 0xC6, 0x7E, 0x00
    ; b (98)
    db 0xC0, 0xC0, 0xFC, 0xC6, 0xC6, 0xC6, 0xFC, 0x00
    ; c (99)
    db 0x00, 0x00, 0x7C, 0xC6, 0xC0, 0xC6, 0x7C, 0x00
    ; d (100)
    db 0x06, 0x06, 0x7E, 0xC6, 0xC6, 0xC6, 0x7E, 0x00
    ; e (101)
    db 0x00, 0x00, 0x7C, 0xC6, 0xFE, 0xC0, 0x7C, 0x00
    ; f (102)
    db 0x1C, 0x36, 0x30, 0x78, 0x30, 0x30, 0x30, 0x00
    ; g (103)
    db 0x00, 0x00, 0x7E, 0xC6, 0xC6, 0x7E, 0x06, 0x7C
    ; h (104)
    db 0xC0, 0xC0, 0xFC, 0xC6, 0xC6, 0xC6, 0xC6, 0x00
    ; i (105)
    db 0x18, 0x00, 0x38, 0x18, 0x18, 0x18, 0x3C, 0x00
    ; j (106)
    db 0x06, 0x00, 0x0E, 0x06, 0x06, 0x06, 0xC6, 0x7C
    ; k (107)
    db 0xC0, 0xC0, 0xCC, 0xD8, 0xF0, 0xD8, 0xCC, 0x00
    ; l (108)
    db 0x38, 0x18, 0x18, 0x18, 0x18, 0x18, 0x3C, 0x00
    ; m (109)
    db 0x00, 0x00, 0xEC, 0xFE, 0xD6, 0xC6, 0xC6, 0x00
    ; n (110)
    db 0x00, 0x00, 0xFC, 0xC6, 0xC6, 0xC6, 0xC6, 0x00
    ; o (111)
    db 0x00, 0x00, 0x7C, 0xC6, 0xC6, 0xC6, 0x7C, 0x00
    ; p (112)
    db 0x00, 0x00, 0xFC, 0xC6, 0xC6, 0xFC, 0xC0, 0xC0
    ; q (113)
    db 0x00, 0x00, 0x7E, 0xC6, 0xC6, 0x7E, 0x06, 0x06
    ; r (114)
    db 0x00, 0x00, 0xDC, 0xE6, 0xC0, 0xC0, 0xC0, 0x00
    ; s (115)
    db 0x00, 0x00, 0x7E, 0xC0, 0x7C, 0x06, 0xFC, 0x00
    ; t (116)
    db 0x30, 0x30, 0x7C, 0x30, 0x30, 0x36, 0x1C, 0x00
    ; u (117)
    db 0x00, 0x00, 0xC6, 0xC6, 0xC6, 0xC6, 0x7E, 0x00
    ; v (118)
    db 0x00, 0x00, 0xC6, 0xC6, 0xC6, 0x6C, 0x38, 0x00
    ; w (119)
    db 0x00, 0x00, 0xC6, 0xC6, 0xD6, 0xFE, 0x6C, 0x00
    ; x (120)
    db 0x00, 0x00, 0xC6, 0x6C, 0x38, 0x6C, 0xC6, 0x00
    ; y (121)
    db 0x00, 0x00, 0xC6, 0xC6, 0xC6, 0x7E, 0x06, 0x7C
    ; z (122)
    db 0x00, 0x00, 0xFE, 0x0C, 0x38, 0x60, 0xFE, 0x00
    ; { (123)
    db 0x0E, 0x18, 0x18, 0x70, 0x18, 0x18, 0x0E, 0x00
    ; | (124)
    db 0x18, 0x18, 0x18, 0x18, 0x18, 0x18, 0x18, 0x00
    ; } (125)
    db 0x70, 0x18, 0x18, 0x0E, 0x18, 0x18, 0x70, 0x00
    ; ~ (126)
    db 0x76, 0xDC, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
    ; DEL (127) - empty
    db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00

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
align 16
tss64:
    dd 0                            ; Reserved
    dq 0x90000                      ; RSP0 - Kernel stack for interrupts
    dq 0                            ; RSP1
    dq 0                            ; RSP2
    dq 0                            ; Reserved
    dq 0                            ; IST1
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
; 3D ENGINE INCLUDES (DEPRECATED - will be moved to deprecated/3d/)
; Keep for now until 2D UI is fully stable
; ════════════════════════════════════════════════════════════════════════════
%include "gfx3d/math3d.asm"
%include "gfx3d/camera3d.asm"
%include "gfx3d/render3d.asm"
%include "gfx3d/world3d.asm"
%include "gfx3d/ui3d.asm"
%include "gfx3d/effects3d.asm"

; UI MODULES (new modular structure)
%include "ui/draw.asm"
%include "ui/dialog.asm"
%include "ui/files.asm"
%include "ui/input.asm"
%include "ui/window.asm"
%include "ui/terminal.asm"
%include "ui/desktop.asm"
%include "ui/taskbar.asm"

; INPUT MODULES (keyboard/mouse)
%include "input/state.asm"
%include "input/scancode.asm"
%include "input/mouse.asm"
%include "input/keyboard.asm"
%include "input/dispatcher.asm"

; INPUT HANDLERS (event-driven)
%include "handlers/global_keys.asm"
%include "handlers/gui_keys.asm"
%include "handlers/files_keys.asm"
%include "handlers/terminal_keys.asm"
%include "handlers/shell_keys.asm"
%include "handlers/3d_keys.asm"

; MODES
%include "modes/graphics.asm"
%include "modes/shell.asm"
%include "modes/files/files_main.asm"

; SYSTEM (ISRs, setup)
%include "sys/timer.asm"
%include "sys/setup.asm"
%include "sys/ring3.asm"

; SERVICES (SOLID Phase 2)
%include "services/registry.asm"
%include "services/alloc_svc.asm"
