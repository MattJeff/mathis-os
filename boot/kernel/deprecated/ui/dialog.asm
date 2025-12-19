; ============================================================================
; MathisOS - Dialog popups
; ============================================================================
; Popups et dialogues (sera rempli progressivement)
; - draw_dialog_new
; - dialog create/delete/rename
; - dialog strings
; ============================================================================

; Dialog strings
str_dlg_new:     db "CREATE NEW", 0
str_dlg_cancel:  db "[ESC] Cancel", 0
str_dlg_create:  db "[ENTER] Create", 0

; DRAW_DIALOG_NEW - Draw dialog box overlay
draw_dialog_new:
    push rax
    push rbx
    push rcx
    pop rcx
    pop rbx
    pop rax
    ret
