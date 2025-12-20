; ============================================================================
; WM_TYPES.ASM - Window Manager types and constants
; ============================================================================

[BITS 64]

; Window manager limits
WM_MAX_WINDOWS      equ 8

; Window state flags
WM_WIN_VISIBLE      equ 0x01
WM_WIN_FOCUSED      equ 0x02
WM_WIN_DRAGGING     equ 0x04
WM_WIN_MINIMIZED    equ 0x08

; Window types
WM_TYPE_FILES       equ 1
WM_TYPE_TERMINAL    equ 2
WM_TYPE_SETTINGS    equ 3
WM_TYPE_EDITOR      equ 4
WM_TYPE_CALC        equ 5
WM_TYPE_CLOCK       equ 6

; Default window sizes (Finder-style, large)
WM_DEF_W            equ 700
WM_DEF_H            equ 500
WM_TITLE_H          equ 24
WM_MIN_W            equ 400
WM_MIN_H            equ 300

; Window control buttons (macOS style - left side)
WM_BTN_SIZE         equ 12          ; Button diameter
WM_BTN_SPACING      equ 8           ; Space between buttons
WM_BTN_MARGIN_X     equ 10          ; Left margin
WM_BTN_MARGIN_Y     equ 6           ; Top margin

; Resize handle size
WM_RESIZE_HANDLE    equ 10          ; Pixels for resize corner
