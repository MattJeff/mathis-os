; ============================================================================
; WM_STATE.ASM - Window Manager state
; ============================================================================

[BITS 64]

; Window entry: 64 bytes
; 0:  flags (4)
; 4:  type (4)
; 8:  x (4)
; 12: y (4)
; 16: w (4)
; 20: h (4)
; 24: widget_ptr (8)
; 32: title_ptr (8)
; 40: on_close (8)
; 48: reserved (16)
WM_ENT_SIZE         equ 64
WM_ENT_FLAGS        equ 0
WM_ENT_TYPE         equ 4
WM_ENT_X            equ 8
WM_ENT_Y            equ 12
WM_ENT_W            equ 16
WM_ENT_H            equ 20
WM_ENT_WIDGET       equ 24
WM_ENT_TITLE        equ 32
WM_ENT_CLOSE        equ 40

; Window array
wm_windows:         times (WM_ENT_SIZE * WM_MAX_WINDOWS) db 0
wm_window_count:    dd 0
wm_focused_idx:     dd -1
wm_drag_idx:        dd -1
wm_drag_off_x:      dd 0
wm_drag_off_y:      dd 0
wm_initialized:     db 0
wm_dirty:           db 1
wm_close_grace:     db 0            ; Grace frames before ESC can close (prevents accidental close)
