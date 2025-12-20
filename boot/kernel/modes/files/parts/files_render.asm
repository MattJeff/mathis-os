; ════════════════════════════════════════════════════════════════════════════
; FILES_RENDER.ASM - Drawing functions for Files App
; ════════════════════════════════════════════════════════════════════════════

[BITS 64]

; ════════════════════════════════════════════════════════════════════════════
; FILES_APP_DRAW - Draw all widgets
; ════════════════════════════════════════════════════════════════════════════
files_app_draw:
    push rbx

    ; Clear screen with dark background
    mov edi, 0x00202020
    call video_clear

    ; Check current state
    mov eax, [fa_state]

    cmp eax, FA_STATE_EDITOR
    je .draw_editor

    cmp eax, FA_STATE_DIALOG_NEW
    je .draw_with_dialog
    cmp eax, FA_STATE_DIALOG_DEL
    je .draw_with_dialog
    cmp eax, FA_STATE_DIALOG_REN
    je .draw_with_dialog

    ; Default: draw file list view
.draw_list:
    mov rdi, [fa_header]
    call widget_draw

    mov rdi, [fa_pathbar]
    call widget_draw

    mov rdi, [fa_file_list]
    call widget_draw

    mov rdi, [fa_statusbar]
    call widget_draw

    jmp .done

.draw_editor:
    ; Draw editor (full screen except header)
    mov rdi, [fa_header]
    call widget_draw

    mov rdi, [fa_editor]
    test rdi, rdi
    jz .done
    call widget_draw
    jmp .done

.draw_with_dialog:
    ; Draw list view first (dimmed background)
    mov rdi, [fa_header]
    call widget_draw
    mov rdi, [fa_pathbar]
    call widget_draw
    mov rdi, [fa_file_list]
    call widget_draw
    mov rdi, [fa_statusbar]
    call widget_draw

    ; Draw dialog on top
    mov rdi, [fa_dialog]
    test rdi, rdi
    jz .done
    call widget_draw

.done:
    pop rbx
    ret
