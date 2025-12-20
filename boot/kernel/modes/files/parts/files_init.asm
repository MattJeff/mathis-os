; ════════════════════════════════════════════════════════════════════════════
; FILES_INIT.ASM - Files App initialization
; ════════════════════════════════════════════════════════════════════════════

[BITS 64]

; ════════════════════════════════════════════════════════════════════════════
; FILES_APP_INIT - Initialize all widgets
; ════════════════════════════════════════════════════════════════════════════
files_app_init:
    cmp byte [fa_initialized], 1
    je .done

    push rbx
    push r12
    push r13

    ; Initialize VFS
    call vfs_init

    ; Register for VFS changes
    mov rdi, fa_on_vfs_change
    call vfs_register

    ; Get screen dimensions
    mov r12d, [screen_width]
    mov r13d, [screen_height]

    ; Create header
    xor esi, esi
    xor edx, edx
    mov ecx, r12d
    mov r8d, 24
    mov r9, fa_title_files
    call header_create
    mov [fa_header], rax

    ; Create pathbar (after sidebar)
    mov esi, SIDEBAR_WIDTH
    mov edx, 24
    mov ecx, r12d
    sub ecx, SIDEBAR_WIDTH
    mov r8d, 20
    call vfs_get_path
    mov r9, rax
    call pathbar_create
    mov [fa_pathbar], rax

    ; Initialize sidebar
    xor edi, edi
    mov esi, 24
    mov edx, r13d
    sub edx, 70
    call sidebar_init

    ; Set sidebar callback
    mov rdi, fa_on_sidebar_select
    call sidebar_set_callback

    ; Create file list (right of sidebar)
    mov esi, SIDEBAR_WIDTH
    add esi, 10
    mov edx, 54
    mov ecx, r12d
    sub ecx, SIDEBAR_WIDTH
    sub ecx, 20
    mov r8d, r13d
    sub r8d, 110
    call file_list_create
    mov [fa_file_list], rax

    ; Load entries from VFS
    call fa_refresh_from_vfs

    ; Create statusbar
    xor esi, esi
    mov edx, r13d
    sub edx, 46
    mov ecx, r12d
    mov r8d, 46
    call statusbar_create
    mov [fa_statusbar], rax

    mov byte [fa_initialized], 1
    mov dword [fa_state], FA_STATE_LIST

    pop r13
    pop r12
    pop rbx

.done:
    ret

; ════════════════════════════════════════════════════════════════════════════
; FA_REFRESH_FROM_VFS - Refresh file list from VFS
; ════════════════════════════════════════════════════════════════════════════
fa_refresh_from_vfs:
    push rax
    push rbx
    push rcx
    push rdx
    push rsi
    push rdi

    ; Get entries from VFS
    call vfs_get_entries            ; RAX = entries, EDX = count

    ; Convert VFS entries to FILE_ENTRY format
    mov rbx, rax                    ; rbx = vfs entries
    mov ecx, edx                    ; ecx = count
    mov [fa_entry_count], ecx

    xor esi, esi                    ; Index
.convert_loop:
    cmp esi, ecx
    jge .update_widget

    ; Source: vfs_entries + i * VFS_ENTRY_SIZE
    mov eax, esi
    imul eax, VFS_ENTRY_SIZE
    lea rdi, [rbx + rax]            ; rdi = vfs entry

    ; Dest: fa_entries + i * FILE_ENTRY_SIZE (32)
    mov eax, esi
    imul eax, 32
    lea r8, [fa_entries + rax]      ; r8 = fa entry

    ; Copy name pointer (point to vfs entry name)
    lea rax, [rdi + VFS_E_NAME]
    mov [r8 + FE_NAME], rax

    ; Copy size
    mov eax, [rdi + VFS_E_SIZE]
    mov [r8 + FE_SIZE], eax

    ; Convert flags
    mov eax, [rdi + VFS_E_FLAGS]
    xor edx, edx
    test eax, VFS_FLAG_DIR
    jz .not_dir
    or edx, FEF_DIRECTORY
.not_dir:
    mov [r8 + FE_FLAGS], edx

    ; Set mod date (placeholder)
    lea rax, [fa_mock_mod]
    mov [r8 + FE_MOD_DATE], rax

    inc esi
    mov ecx, [fa_entry_count]
    jmp .convert_loop

.update_widget:
    ; Update file list widget
    mov rdi, [fa_file_list]
    test rdi, rdi
    jz .done
    mov rsi, fa_entries
    mov edx, [fa_entry_count]
    call file_list_set_entries

    ; Update pathbar
    mov rdi, [fa_pathbar]
    test rdi, rdi
    jz .done
    call vfs_get_path
    mov rsi, rax
    call pathbar_set_path

.done:
    pop rdi
    pop rsi
    pop rdx
    pop rcx
    pop rbx
    pop rax
    ret

; ════════════════════════════════════════════════════════════════════════════
; FA_ON_VFS_CHANGE - Called when VFS directory changes
; ════════════════════════════════════════════════════════════════════════════
fa_on_vfs_change:
    call fa_refresh_from_vfs
    mov byte [files_dirty], 1
    ret

; ════════════════════════════════════════════════════════════════════════════
; FA_ON_SIDEBAR_SELECT - Called when sidebar selection changes
; ════════════════════════════════════════════════════════════════════════════
fa_on_sidebar_select:
    ; VFS already navigated by sidebar, just refresh
    call fa_refresh_from_vfs
    mov byte [files_dirty], 1
    ret
