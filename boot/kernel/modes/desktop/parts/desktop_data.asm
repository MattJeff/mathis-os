; ════════════════════════════════════════════════════════════════════════════
; DESKTOP_DATA.ASM - Desktop state and constants
; ════════════════════════════════════════════════════════════════════════════

[BITS 64]

; ════════════════════════════════════════════════════════════════════════════
; CONSTANTS
; ════════════════════════════════════════════════════════════════════════════
DESKTOP_BG_COLOR        equ 0x00205080      ; Teal/cyan (RGB)
DESKTOP_TASKBAR_H       equ 28
DESKTOP_TASKBAR_COLOR   equ 0x00303030      ; Dark gray
DESKTOP_ICON_SIZE       equ 48

; ════════════════════════════════════════════════════════════════════════════
; STATE
; ════════════════════════════════════════════════════════════════════════════
desktop_initialized:    db 0
desktop_menu_open:      db 0

; Strings
desktop_str_terminal:   db "Terminal", 0
desktop_str_files:      db "Files", 0
desktop_str_start:      db "Start", 0
desktop_str_clock:      db "00:00", 0
