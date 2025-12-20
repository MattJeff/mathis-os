; FILES_DRAW_SIDEBAR.ASM - Sidebar drawing
[BITS 64]

wmf_str_root:      db "Root", 0
wmf_str_desktop:   db "Desktop", 0
wmf_str_documents: db "Documents", 0
wmf_str_downloads: db "Downloads", 0

wmf_sidebar_items:
    dd VFS_LOC_ROOT,      0, 0, 0
    dq wmf_str_root
    dd VFS_LOC_DESKTOP,   0, 0, 0
    dq wmf_str_desktop
    dd VFS_LOC_DOCUMENTS, 0, 0, 0
    dq wmf_str_documents
    dd VFS_LOC_DOWNLOADS, 0, 0, 0
    dq wmf_str_downloads
WMF_SIDEBAR_COUNT equ 4

; WMF_DRAW_SIDEBAR - Draw sidebar items
wmf_draw_sidebar:
    push r12
    push r13
    push r14
    push r15

    mov r12d, [wmf_win_x]
    add r12d, 10
    mov r13d, [wmf_win_y]
    add r13d, 12
    mov eax, [vfs_current_loc]
    mov [wmf_temp_loc], eax
    lea r15, [wmf_sidebar_items]
    xor r14d, r14d

.loop:
    cmp r14d, WMF_SIDEBAR_COUNT
    jge .done
    mov edi, r12d
    mov esi, r13d
    mov edx, [r15]
    mov rcx, [r15 + 16]
    call wmf_draw_sidebar_item
    add r13d, 28
    add r15, 24
    inc r14d
    jmp .loop

.done:
    pop r15
    pop r14
    pop r13
    pop r12
    ret

; WMF_DRAW_SIDEBAR_ITEM - Draw one item. EDI=x, ESI=y, EDX=loc_id, RCX=name
wmf_draw_sidebar_item:
    push rbx
    push r12
    push r13
    push r14

    mov r12d, edi
    mov r13d, esi
    mov r14d, edx
    mov rbx, rcx

    cmp [wmf_temp_loc], r14d
    jne .not_sel
    mov edi, r12d
    sub edi, 6
    mov esi, r13d
    sub esi, 3
    mov edx, WMF_SIDEBAR_W - 12
    mov ecx, 24
    mov r8d, WMF_COL_SEL
    call fill_rect
.not_sel:
    mov edi, r12d
    mov esi, r13d
    add esi, 2
    mov edx, 14
    mov ecx, 12
    mov r8d, WMF_COL_FOLDER
    call fill_rect

    mov edi, r12d
    add edi, 20
    mov esi, r13d
    add esi, 4
    mov rdx, rbx
    mov ecx, WMF_COL_TEXT
    call video_text

    pop r14
    pop r13
    pop r12
    pop rbx
    ret
