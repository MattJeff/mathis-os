; ============================================================================
; DESKTOP_DLG_STATE.ASM - Desktop dialog constants and state
; ============================================================================
; Single Responsibility: Dialog state management
; ============================================================================

[BITS 64]

; Dialog mode constants
DESKTOP_DLG_NONE    equ 0
DESKTOP_DLG_NEW     equ 1       ; Choose file or folder

; Dialog state
desktop_dlg_mode:   db 0
desktop_dlg_select: db 0        ; 0=folder, 1=file
desktop_dlg_cursor: dd 0
desktop_dlg_input:  times 32 db 0
desktop_dlg_path:   times 64 db 0

; ============================================================================
; DESKTOP_DLG_OPEN_NEW - Open new dialog (N key pressed)
; ============================================================================
desktop_dlg_open_new:
    mov byte [desktop_dlg_mode], DESKTOP_DLG_NEW
    mov byte [desktop_dlg_select], 0
    mov dword [desktop_dlg_cursor], 0
    lea rdi, [desktop_dlg_input]
    mov ecx, 32
    xor eax, eax
    rep stosb
    ret

; ============================================================================
; DESKTOP_DLG_CLOSE - Close dialog
; ============================================================================
desktop_dlg_close:
    mov byte [desktop_dlg_mode], DESKTOP_DLG_NONE
    ret

