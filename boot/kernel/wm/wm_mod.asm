; ============================================================================
; WM_MOD.ASM - Window Manager Entry Point
; ============================================================================
; Main WM initialization and update
; ============================================================================

[BITS 64]
[DEFAULT REL]

; ============================================================================
; EXPORTS
; ============================================================================
global wm_init
global wm_update
global wm_has_windows
global wm_get_active

; ============================================================================
; IMPORTS
; ============================================================================
extern wm_window_count
extern wm_active_index
extern wm_draw_all
extern wm_on_click
extern mouse_clicked
extern mouse_x
extern mouse_y

; ============================================================================
; CODE
; ============================================================================
section .text

; ----------------------------------------------------------------------------
; wm_init - Initialize window manager
; ----------------------------------------------------------------------------
wm_init:
    mov dword [wm_window_count], 0
    mov dword [wm_active_index], -1
    mov byte [wm_initialized], 1
    ret

; ----------------------------------------------------------------------------
; wm_update - Update window manager (called each frame)
; ----------------------------------------------------------------------------
wm_update:
    push rax

    ; Check for click
    cmp byte [mouse_clicked], 0
    je .no_click

    movzx edi, word [mouse_x]
    movzx esi, word [mouse_y]
    call wm_on_click

    mov byte [mouse_clicked], 0

.no_click:
    ; Draw all windows
    call wm_draw_all

    pop rax
    ret

; ----------------------------------------------------------------------------
; wm_has_windows - Check if any windows are open
; Output: AL = 1 if windows exist
; ----------------------------------------------------------------------------
wm_has_windows:
    cmp dword [wm_window_count], 0
    setg al
    ret

; ----------------------------------------------------------------------------
; wm_get_active - Get active window pointer
; Output: RAX = active window pointer (0 if none)
; ----------------------------------------------------------------------------
wm_get_active:
    xor eax, eax
    ret

; ============================================================================
; DATA
; ============================================================================
section .data

wm_initialized:         db 0
