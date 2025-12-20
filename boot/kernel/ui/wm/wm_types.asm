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

; Default window sizes
WM_DEF_W            equ 400
WM_DEF_H            equ 300
WM_TITLE_H          equ 24
WM_MIN_W            equ 200
WM_MIN_H            equ 150
