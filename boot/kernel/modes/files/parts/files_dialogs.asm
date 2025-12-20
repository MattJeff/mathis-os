; ════════════════════════════════════════════════════════════════════════════
; FILES_DIALOGS.ASM - Dialog callbacks for Files App
; ════════════════════════════════════════════════════════════════════════════

[BITS 64]

; ════════════════════════════════════════════════════════════════════════════
; FA_ON_NEW_CONFIRM - Called when "Create" button is clicked
; ════════════════════════════════════════════════════════════════════════════
fa_on_new_confirm:
    push rbx
    push r12
    push r13

    ; Get filename from dialog input
    mov rdi, [fa_dialog]
    test rdi, rdi
    jz .new_done

    ; Check if folder was selected
    call dialog_new_is_folder
    mov r13d, eax                   ; r13 = is_folder flag

    ; Get input text from dialog
    mov rdi, [fa_dialog]
    call dialog_new_get_name
    test rax, rax
    jz .new_done
    mov r12, rax                    ; r12 = new filename

    ; Check if creating folder or file
    test r13d, r13d
    jnz .create_folder

    ; Create FILE using CRUD
    mov rdi, r12
    mov esi, FS_O_CREATE            ; Create flag
    call crud_create_file
    cmp eax, -1
    je .new_done                    ; Creation failed

    ; Close the fd
    mov edi, eax
    call fs_close
    jmp .new_refresh

.create_folder:
    ; Create FOLDER using fs_mkdir
    mov rdi, r12
    call fs_mkdir
    test eax, eax
    jz .new_done                    ; Creation failed

.new_refresh:
    ; Refresh VFS and notify listeners
    call vfs_reload
    call vfs_notify_change

.new_done:
    call fa_close_dialog
    pop r13
    pop r12
    pop rbx
    ret

; ════════════════════════════════════════════════════════════════════════════
; FA_ON_DELETE_CONFIRM - Called when "Delete" button is clicked
; ════════════════════════════════════════════════════════════════════════════
fa_on_delete_confirm:
    push rbx
    push r12

    ; Get selected entry name
    mov rdi, [fa_file_list]
    call file_list_get_selected
    imul eax, 32
    lea rbx, [fa_entries + rax]
    mov r12, [rbx + FE_NAME]        ; r12 = filename to delete

    ; Delete using fs_delete
    mov rdi, r12
    call fs_delete
    test eax, eax
    jz .delete_done                 ; Deletion failed

    ; Refresh VFS and notify listeners
    call vfs_reload
    call vfs_notify_change

.delete_done:
    call fa_close_dialog
    pop r12
    pop rbx
    ret

; ════════════════════════════════════════════════════════════════════════════
; FA_ON_RENAME_CONFIRM - Called when "Rename" button is clicked
; ════════════════════════════════════════════════════════════════════════════
fa_on_rename_confirm:
    push rbx
    push r12
    push r13

    ; Get old filename (selected entry)
    mov rdi, [fa_file_list]
    call file_list_get_selected
    imul eax, 32
    lea rbx, [fa_entries + rax]
    mov r12, [rbx + FE_NAME]        ; r12 = old filename

    ; Get new filename from dialog input
    mov rdi, [fa_dialog]
    test rdi, rdi
    jz .rename_done

    call dialog_get_input
    test rax, rax
    jz .rename_done
    mov r13, rax                    ; r13 = new filename

    ; Rename using CRUD
    mov rdi, r12                    ; old path
    mov rsi, r13                    ; new path
    call crud_rename
    test eax, eax
    jz .rename_done                 ; Rename failed

    ; Refresh VFS and notify listeners
    call vfs_reload
    call vfs_notify_change

.rename_done:
    call fa_close_dialog
    pop r13
    pop r12
    pop rbx
    ret

; ════════════════════════════════════════════════════════════════════════════
; FA_ON_DIALOG_CANCEL - Called when dialog is cancelled
; ════════════════════════════════════════════════════════════════════════════
fa_on_dialog_cancel:
    call fa_close_dialog
    ret

; ════════════════════════════════════════════════════════════════════════════
; FA_CLOSE_DIALOG - Close current dialog and return to list
; ════════════════════════════════════════════════════════════════════════════
fa_close_dialog:
    mov rdi, [fa_dialog]
    test rdi, rdi
    jz .done
    call widget_destroy
    mov qword [fa_dialog], 0
    mov dword [fa_state], FA_STATE_LIST
    mov byte [files_dirty], 1
.done:
    ret
