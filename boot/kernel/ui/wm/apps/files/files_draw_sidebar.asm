; FILES_DRAW_SIDEBAR.ASM - Finder-style sidebar
[BITS 64]

; Section headers
wmf_str_favorites: db "Favorites", 0
wmf_str_locations: db "Locations", 0

; Sidebar items
wmf_str_desktop:   db "Desktop", 0
wmf_str_documents: db "Documents", 0
wmf_str_downloads: db "Downloads", 0
wmf_str_root:      db "Macintosh HD", 0

; WMF_DRAW_SIDEBAR - Draw Finder-style sidebar
wmf_draw_sidebar:
    push r12
    push r13
    push r14
    push r15

    mov r12d, [wmf_win_x]
    add r12d, 12
    mov r13d, [wmf_win_y]
    add r13d, 16
    mov eax, [vfs_current_loc]
    mov [wmf_temp_loc], eax

    ; Section: Favorites
    mov edi, r12d
    mov esi, r13d
    lea rdx, [wmf_str_favorites]
    mov ecx, WMF_COL_TEXT_HEADER
    call video_text
    add r13d, 24

    ; Desktop
    mov edi, r12d
    mov esi, r13d
    mov edx, VFS_LOC_DESKTOP
    lea rcx, [wmf_str_desktop]
    call wmf_draw_sidebar_item
    add r13d, 26

    ; Documents
    mov edi, r12d
    mov esi, r13d
    mov edx, VFS_LOC_DOCUMENTS
    lea rcx, [wmf_str_documents]
    call wmf_draw_sidebar_item
    add r13d, 26

    ; Downloads
    mov edi, r12d
    mov esi, r13d
    mov edx, VFS_LOC_DOWNLOADS
    lea rcx, [wmf_str_downloads]
    call wmf_draw_sidebar_item
    add r13d, 36

    ; Section: Locations
    mov edi, r12d
    mov esi, r13d
    lea rdx, [wmf_str_locations]
    mov ecx, WMF_COL_TEXT_HEADER
    call video_text
    add r13d, 24

    ; Root (Macintosh HD)
    mov edi, r12d
    mov esi, r13d
    mov edx, VFS_LOC_ROOT
    lea rcx, [wmf_str_root]
    call wmf_draw_sidebar_item

    pop r15
    pop r14
    pop r13
    pop r12
    ret

; WMF_DRAW_SIDEBAR_ITEM - Draw one item with folder icon
; EDI=x, ESI=y, EDX=loc_id, RCX=name
wmf_draw_sidebar_item:
    push rbx
    push r12
    push r13
    push r14

    mov r12d, edi
    mov r13d, esi
    mov r14d, edx
    mov rbx, rcx

    ; Selection background if current
    cmp [wmf_temp_loc], r14d
    jne .not_sel
    mov edi, r12d
    sub edi, 8
    mov esi, r13d
    sub esi, 2
    mov edx, WMF_SIDEBAR_W - 20
    mov ecx, 22
    mov r8d, WMF_COL_SEL_BLUE
    call fill_rect
.not_sel:

    ; Folder icon (small blue square)
    mov edi, r12d
    mov esi, r13d
    add esi, 2
    mov edx, 16
    mov ecx, 14
    mov r8d, WMF_COL_FOLDER
    call fill_rect

    ; Label
    mov edi, r12d
    add edi, 22
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
