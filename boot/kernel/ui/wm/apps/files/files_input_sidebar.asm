; ============================================================================
; FILES_INPUT_SIDEBAR.ASM - Sidebar click handling
; ============================================================================
; Single Responsibility: Handle sidebar navigation clicks
; Preserves: R12-R15
; ============================================================================

[BITS 64]

; ============================================================================
; WMF_HANDLE_SIDEBAR_CLICK - Handle sidebar click
; Uses: r13d = abs_y from wmf_on_click
; ============================================================================
wmf_handle_sidebar_click:
    mov eax, r13d
    sub eax, [wmf_win_y]
    sub eax, 12
    cmp eax, 0
    jl .done

    xor edx, edx
    mov ecx, 28
    div ecx

    cmp eax, 0
    je .root
    cmp eax, 1
    je .desktop
    cmp eax, 2
    je .documents
    cmp eax, 3
    je .downloads
    jmp .done

.root:
    mov edi, VFS_LOC_ROOT
    jmp .navigate
.desktop:
    mov edi, VFS_LOC_DESKTOP
    jmp .navigate
.documents:
    mov edi, VFS_LOC_DOCUMENTS
    jmp .navigate
.downloads:
    mov edi, VFS_LOC_DOWNLOADS

.navigate:
    push rdi
    call wmf_history_push
    pop rdi
    call vfs_goto_loc
    mov dword [wmf_selected], 0
    mov dword [wmf_scroll_pos], 0

.done:
    ret
