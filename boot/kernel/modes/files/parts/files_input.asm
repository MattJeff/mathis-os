; ════════════════════════════════════════════════════════════════════════════
; FILES_INPUT.ASM - Keyboard input handling for Files App
; ════════════════════════════════════════════════════════════════════════════

[BITS 64]

; ════════════════════════════════════════════════════════════════════════════
; FILES_APP_ON_KEY - Handle keyboard input
; Input:  AL = scancode
; Output: AL = 1 if handled
; ════════════════════════════════════════════════════════════════════════════
files_app_on_key:
    push rbx
    push r12
    movzx r12d, al                  ; Save scancode

    mov eax, [fa_state]

    ; Dialog state - forward to dialog
    cmp eax, FA_STATE_DIALOG_NEW
    je .handle_dialog
    cmp eax, FA_STATE_DIALOG_DEL
    je .handle_dialog
    cmp eax, FA_STATE_DIALOG_REN
    je .handle_dialog

    ; Editor state
    cmp eax, FA_STATE_EDITOR
    je .handle_editor

    ; List state
.handle_list:
    ; ESC - do nothing in list (global handler will switch mode)
    cmp r12d, 0x01
    je .not_handled

    ; N - New file dialog (0x31)
    cmp r12d, 0x31
    je .show_new_dialog

    ; D - Delete dialog (0x20)
    cmp r12d, 0x20
    je .show_delete_dialog

    ; R - Rename dialog (0x13)
    cmp r12d, 0x13
    je .show_rename_dialog

    ; Forward to file list widget
    mov rdi, [fa_file_list]
    mov esi, r12d
    call widget_on_key
    test eax, eax
    jnz .handled_redraw

    jmp .not_handled

.handle_editor:
    ; ESC in editor - close and return to list
    cmp r12d, 0x01
    je .close_editor

    ; Ctrl+S (0x1F) - Save file
    cmp r12d, 0x1F
    jne .check_ctrl_s_done
    cmp byte [ctrl_state], 1
    jne .check_ctrl_s_done
    call fa_save_file
    jmp .handled_redraw
.check_ctrl_s_done:

    ; Forward to editor widget
    mov rdi, [fa_editor]
    test rdi, rdi
    jz .not_handled
    mov esi, r12d
    call widget_on_key
    test eax, eax
    jnz .handled_redraw
    jmp .not_handled

.handle_dialog:
    ; ESC in dialog - close dialog and return to list
    cmp r12d, 0x01
    je .close_dialog_esc

    ; Forward to dialog widget
    mov rdi, [fa_dialog]
    test rdi, rdi
    jz .not_handled
    mov esi, r12d
    call widget_on_key
    test eax, eax
    jnz .handled_redraw
    jmp .not_handled

.close_dialog_esc:
    call fa_close_dialog
    jmp .handled_redraw

.show_new_dialog:
    call dialog_new_create
    mov [fa_dialog], rax
    test rax, rax
    jz .not_handled
    ; Set callbacks
    mov rdi, rax
    mov rsi, fa_on_new_confirm
    mov rdx, fa_on_dialog_cancel
    call dialog_set_callbacks
    mov dword [fa_state], FA_STATE_DIALOG_NEW
    jmp .handled_redraw

.show_delete_dialog:
    ; Get selected entry name from fa_entries
    mov rdi, [fa_file_list]
    call file_list_get_selected
    ; Get filename pointer from entry
    imul eax, 32                    ; FILE_ENTRY_SIZE = 32
    lea rbx, [fa_entries + rax]
    mov rsi, [rbx + FE_NAME]        ; Get name pointer
    ; Check if directory
    mov edx, [rbx + FE_FLAGS]
    and edx, FEF_DIRECTORY          ; is_folder flag
    call dialog_delete_create
    mov [fa_dialog], rax
    test rax, rax
    jz .not_handled
    mov rdi, rax
    mov rsi, fa_on_delete_confirm
    mov rdx, fa_on_dialog_cancel
    call dialog_set_callbacks
    mov dword [fa_state], FA_STATE_DIALOG_DEL
    jmp .handled_redraw

.show_rename_dialog:
    ; Get selected entry name from fa_entries
    mov rdi, [fa_file_list]
    call file_list_get_selected
    imul eax, 32
    lea rbx, [fa_entries + rax]
    mov rsi, [rbx + FE_NAME]        ; Get current filename
    call dialog_rename_create
    mov [fa_dialog], rax
    test rax, rax
    jz .not_handled
    mov rdi, rax
    mov rsi, fa_on_rename_confirm
    mov rdx, fa_on_dialog_cancel
    call dialog_set_callbacks
    mov dword [fa_state], FA_STATE_DIALOG_REN
    jmp .handled_redraw

.close_editor:
    ; Destroy editor widget
    mov rdi, [fa_editor]
    test rdi, rdi
    jz .back_to_list
    call widget_destroy
    mov qword [fa_editor], 0
.back_to_list:
    mov dword [fa_state], FA_STATE_LIST
    ; Update header title
    mov rdi, [fa_header]
    mov rsi, fa_title_files
    call header_set_title
    jmp .handled_redraw

.handled_redraw:
    mov byte [files_dirty], 1
    mov al, 1
    jmp .done

.not_handled:
    xor al, al

.done:
    pop r12
    pop rbx
    ret

; ════════════════════════════════════════════════════════════════════════════
; FA_ON_LOCATION_CHANGE - DEPRECATED (replaced by VFS notify system)
; Now uses fa_on_vfs_change in files_init.asm
; ════════════════════════════════════════════════════════════════════════════
