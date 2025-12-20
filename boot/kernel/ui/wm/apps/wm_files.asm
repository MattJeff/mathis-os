; ============================================================================
; WM_FILES.ASM - Finder-style Files app for window manager
; ============================================================================

[BITS 64]

; Layout constants
WMF_SIDEBAR_W       equ 90          ; Sidebar width
WMF_TOOLBAR_H       equ 28          ; Toolbar height
WMF_ROW_H           equ 20          ; File row height
WMF_PADDING         equ 4
WMF_MAX_VISIBLE     equ 10

; Colors
WMF_COL_SIDEBAR     equ 0x002D2D3A  ; Dark sidebar
WMF_COL_TOOLBAR     equ 0x003A3A4A  ; Toolbar background
WMF_COL_CONTENT     equ 0x00252530  ; Content background
WMF_COL_SEL         equ 0x00404060  ; Selection
WMF_COL_HOVER       equ 0x00505070  ; Hover
WMF_COL_BTN         equ 0x00505060  ; Button
WMF_COL_BTN_HOV     equ 0x00606080  ; Button hover
WMF_COL_TEXT        equ 0x00FFFFFF  ; Text
WMF_COL_TEXT_DIM    equ 0x00888888  ; Dimmed text
WMF_COL_FOLDER      equ 0x0066AAFF  ; Folder icon (blue)
WMF_COL_FILE        equ 0x00AAAAAA  ; File icon

; State
wmf_scroll_pos:     dd 0
wmf_selected:       dd 0
wmf_entry_count:    dd 0
wmf_sidebar_hover:  dd -1           ; Hovered sidebar item (-1 = none)
wmf_btn_hover:      dd 0            ; 1=back, 2=fwd, 3=new

; Window geometry (set by wmf_draw_content)
wmf_win_x:          dd 0
wmf_win_y:          dd 0
wmf_win_w:          dd 0
wmf_win_h:          dd 0

; ============================================================================
; WMF_DRAW_CONTENT - Draw Finder-style UI
; Input: EDI = x, ESI = y, EDX = w, ECX = h
; ============================================================================
wmf_draw_content:
    push rbx
    push r12
    push r13
    push r14
    push r15

    ; Save geometry
    mov [wmf_win_x], edi
    mov [wmf_win_y], esi
    mov [wmf_win_w], edx
    mov [wmf_win_h], ecx

    mov r12d, edi               ; r12 = x
    mov r13d, esi               ; r13 = y
    mov r14d, edx               ; r14 = w
    mov r15d, ecx               ; r15 = h

    ; --- Draw Sidebar ---
    mov edi, r12d
    mov esi, r13d
    mov edx, WMF_SIDEBAR_W
    mov ecx, r15d
    mov r8d, WMF_COL_SIDEBAR
    call fill_rect

    ; Draw sidebar items
    call wmf_draw_sidebar

    ; --- Draw Toolbar ---
    mov edi, r12d
    add edi, WMF_SIDEBAR_W
    mov esi, r13d
    mov edx, r14d
    sub edx, WMF_SIDEBAR_W
    mov ecx, WMF_TOOLBAR_H
    mov r8d, WMF_COL_TOOLBAR
    call fill_rect

    ; Draw toolbar content
    call wmf_draw_toolbar

    ; --- Draw Content Area ---
    mov edi, r12d
    add edi, WMF_SIDEBAR_W
    mov esi, r13d
    add esi, WMF_TOOLBAR_H
    mov edx, r14d
    sub edx, WMF_SIDEBAR_W
    mov ecx, r15d
    sub ecx, WMF_TOOLBAR_H
    mov r8d, WMF_COL_CONTENT
    call fill_rect

    ; Draw file list
    call wmf_draw_files

    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; ============================================================================
; WMF_DRAW_SIDEBAR - Draw sidebar with locations
; ============================================================================
wmf_draw_sidebar:
    push rbx
    push r12

    mov r12d, [wmf_win_x]
    mov ebx, [wmf_win_y]
    add ebx, 8                  ; Start Y

    ; Get current location
    mov eax, [vfs_current_loc]
    mov [wmf_temp_loc], eax

    ; ROOT
    mov edi, r12d
    add edi, 8
    mov esi, ebx
    mov edx, VFS_LOC_ROOT
    lea rcx, [.str_root]
    call wmf_draw_sidebar_item
    add ebx, 24

    ; DESKTOP
    mov edi, r12d
    add edi, 8
    mov esi, ebx
    mov edx, VFS_LOC_DESKTOP
    lea rcx, [.str_desktop]
    call wmf_draw_sidebar_item
    add ebx, 24

    ; DOCUMENTS
    mov edi, r12d
    add edi, 8
    mov esi, ebx
    mov edx, VFS_LOC_DOCUMENTS
    lea rcx, [.str_documents]
    call wmf_draw_sidebar_item
    add ebx, 24

    ; DOWNLOADS
    mov edi, r12d
    add edi, 8
    mov esi, ebx
    mov edx, VFS_LOC_DOWNLOADS
    lea rcx, [.str_downloads]
    call wmf_draw_sidebar_item

    pop r12
    pop rbx
    ret

.str_root:      db "Root", 0
.str_desktop:   db "Desktop", 0
.str_documents: db "Documents", 0
.str_downloads: db "Downloads", 0

; ============================================================================
; WMF_DRAW_SIDEBAR_ITEM - Draw one sidebar item
; Input: EDI=x, ESI=y, EDX=loc_id, RCX=name
; ============================================================================
wmf_draw_sidebar_item:
    push rbx
    push r12
    push r13
    push r14

    mov r12d, edi               ; x
    mov r13d, esi               ; y
    mov r14d, edx               ; loc_id
    mov rbx, rcx                ; name

    ; Check if selected (current location)
    mov eax, [wmf_temp_loc]
    cmp eax, r14d
    jne .not_selected

    ; Draw selection background
    mov edi, r12d
    sub edi, 4
    mov esi, r13d
    sub esi, 2
    mov edx, WMF_SIDEBAR_W - 8
    mov ecx, 20
    mov r8d, WMF_COL_SEL
    call fill_rect

.not_selected:
    ; Draw folder icon
    mov edi, r12d
    mov esi, r13d
    add esi, 2
    mov edx, 12
    mov ecx, 10
    mov r8d, WMF_COL_FOLDER
    call fill_rect

    ; Draw name
    mov edi, r12d
    add edi, 18
    mov esi, r13d
    add esi, 3
    mov rdx, rbx
    mov ecx, WMF_COL_TEXT
    call video_text

    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; ============================================================================
; WMF_DRAW_TOOLBAR - Draw toolbar with buttons and path
; ============================================================================
wmf_draw_toolbar:
    push rbx
    push r12
    push r13

    mov r12d, [wmf_win_x]
    add r12d, WMF_SIDEBAR_W
    mov r13d, [wmf_win_y]

    ; --- Back button < ---
    mov edi, r12d
    add edi, 8
    mov esi, r13d
    add esi, 4
    mov edx, 24
    mov ecx, 20
    mov r8d, WMF_COL_BTN
    call fill_rect

    ; Draw <
    mov edi, r12d
    add edi, 16
    mov esi, r13d
    add esi, 7
    lea rdx, [.str_back]
    mov ecx, WMF_COL_TEXT
    call video_text

    ; --- Forward button > ---
    mov edi, r12d
    add edi, 36
    mov esi, r13d
    add esi, 4
    mov edx, 24
    mov ecx, 20
    mov r8d, WMF_COL_BTN
    call fill_rect

    ; Draw >
    mov edi, r12d
    add edi, 44
    mov esi, r13d
    add esi, 7
    lea rdx, [.str_fwd]
    mov ecx, WMF_COL_TEXT
    call video_text

    ; --- Path ---
    mov edi, r12d
    add edi, 70
    mov esi, r13d
    add esi, 9
    call vfs_get_path           ; RAX = path string
    mov rdx, rax
    mov ecx, WMF_COL_TEXT
    call video_text

    ; --- NEW button ---
    mov eax, [wmf_win_w]
    sub eax, WMF_SIDEBAR_W
    sub eax, 50                 ; Right margin

    mov edi, r12d
    add edi, eax
    mov esi, r13d
    add esi, 4
    mov edx, 40
    mov ecx, 20
    mov r8d, WMF_COL_BTN
    call fill_rect

    ; Draw NEW text
    mov edi, r12d
    add edi, eax
    add edi, 8
    mov esi, r13d
    add esi, 7
    lea rdx, [.str_new]
    mov ecx, WMF_COL_TEXT
    call video_text

    pop r13
    pop r12
    pop rbx
    ret

.str_back:  db "<", 0
.str_fwd:   db ">", 0
.str_new:   db "NEW", 0

; ============================================================================
; WMF_DRAW_FILES - Draw file list in content area
; ============================================================================
wmf_draw_files:
    push rbx
    push r12
    push r13
    push r14
    push r15

    ; Content area starts after sidebar and toolbar
    mov r12d, [wmf_win_x]
    add r12d, WMF_SIDEBAR_W
    add r12d, WMF_PADDING

    mov r13d, [wmf_win_y]
    add r13d, WMF_TOOLBAR_H
    add r13d, WMF_PADDING

    mov r14d, [wmf_win_w]
    sub r14d, WMF_SIDEBAR_W
    sub r14d, WMF_PADDING * 2

    ; Get VFS entries
    call vfs_get_entries
    mov [wmf_vfs_ptr], rax
    mov [wmf_entry_count], edx

    ; Loop through entries
    mov dword [wmf_loop_idx], 0

.loop:
    mov eax, [wmf_loop_idx]
    cmp eax, [wmf_entry_count]
    jge .done

    mov ecx, eax
    sub ecx, [wmf_scroll_pos]
    cmp ecx, WMF_MAX_VISIBLE
    jge .done
    cmp ecx, 0
    jl .next

    ; Calculate Y
    imul ecx, WMF_ROW_H
    add ecx, r13d
    mov [wmf_cur_y], ecx

    ; Get entry
    mov eax, [wmf_loop_idx]
    imul eax, VFS_ENTRY_SIZE
    mov rbx, [wmf_vfs_ptr]
    add rbx, rax

    ; Selection highlight
    mov eax, [wmf_loop_idx]
    cmp eax, [wmf_selected]
    jne .no_sel

    mov edi, r12d
    mov esi, [wmf_cur_y]
    mov edx, r14d
    mov ecx, WMF_ROW_H
    mov r8d, WMF_COL_SEL
    call fill_rect

.no_sel:
    ; Icon
    mov edi, r12d
    add edi, 4
    mov esi, [wmf_cur_y]
    add esi, 3

    mov eax, [rbx + VFS_E_FLAGS]
    test eax, VFS_FLAG_DIR
    jz .file_icon

    ; Folder icon
    mov edx, 14
    mov ecx, 12
    mov r8d, WMF_COL_FOLDER
    call fill_rect
    jmp .draw_name

.file_icon:
    mov edx, 12
    mov ecx, 14
    mov r8d, WMF_COL_FILE
    call fill_rect

.draw_name:
    mov edi, r12d
    add edi, 24
    mov esi, [wmf_cur_y]
    add esi, 4
    lea rdx, [rbx + VFS_E_NAME]
    mov ecx, WMF_COL_TEXT
    call video_text

.next:
    inc dword [wmf_loop_idx]
    jmp .loop

.done:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; ============================================================================
; WMF_ON_CLICK - Handle click
; Input: EDI = x, ESI = y (relative to content area)
; ============================================================================
wmf_on_click:
    push rbx
    push r12
    push r13

    ; Convert to absolute coords
    add edi, [wmf_win_x]
    add esi, [wmf_win_y]
    mov r12d, edi               ; r12 = abs x
    mov r13d, esi               ; r13 = abs y

    ; Check sidebar click
    mov eax, [wmf_win_x]
    add eax, WMF_SIDEBAR_W
    cmp r12d, eax
    jge .check_toolbar

    ; Sidebar click - determine which item
    mov eax, r13d
    sub eax, [wmf_win_y]
    sub eax, 8                  ; First item y offset
    cmp eax, 0
    jl .not_handled

    xor edx, edx
    mov ecx, 24                 ; Item height
    div ecx                     ; eax = item index

    cmp eax, 0
    je .goto_root
    cmp eax, 1
    je .goto_desktop
    cmp eax, 2
    je .goto_documents
    cmp eax, 3
    je .goto_downloads
    jmp .not_handled

.goto_root:
    mov edi, VFS_LOC_ROOT
    jmp .do_goto
.goto_desktop:
    mov edi, VFS_LOC_DESKTOP
    jmp .do_goto
.goto_documents:
    mov edi, VFS_LOC_DOCUMENTS
    jmp .do_goto
.goto_downloads:
    mov edi, VFS_LOC_DOWNLOADS

.do_goto:
    call vfs_goto_loc
    mov dword [wmf_selected], 0
    mov dword [wmf_scroll_pos], 0
    jmp .handled

.check_toolbar:
    ; Check if in toolbar area
    mov eax, [wmf_win_y]
    add eax, WMF_TOOLBAR_H
    cmp r13d, eax
    jge .check_content

    ; Toolbar click
    mov eax, r12d
    sub eax, [wmf_win_x]
    sub eax, WMF_SIDEBAR_W

    ; Back button (8-32)
    cmp eax, 8
    jl .not_handled
    cmp eax, 32
    jle .click_back

    ; Forward button (36-60)
    cmp eax, 36
    jl .not_handled
    cmp eax, 60
    jle .click_fwd

    ; NEW button (right side)
    mov ecx, [wmf_win_w]
    sub ecx, WMF_SIDEBAR_W
    sub ecx, 50
    cmp eax, ecx
    jl .not_handled
    add ecx, 40
    cmp eax, ecx
    jg .not_handled
    jmp .click_new

.click_back:
    ; Go back to root
    mov edi, VFS_LOC_ROOT
    call vfs_goto_loc
    mov dword [wmf_selected], 0
    jmp .handled

.click_fwd:
    ; Forward (no-op for now)
    jmp .handled

.click_new:
    ; Create new folder dialog
    call wmf_show_new_dialog
    jmp .handled

.check_content:
    ; Content area click
    mov eax, r13d
    sub eax, [wmf_win_y]
    sub eax, WMF_TOOLBAR_H
    sub eax, WMF_PADDING
    cmp eax, 0
    jl .not_handled

    xor edx, edx
    mov ecx, WMF_ROW_H
    div ecx

    add eax, [wmf_scroll_pos]
    cmp eax, [wmf_entry_count]
    jge .not_handled

    ; Double-click?
    cmp eax, [wmf_selected]
    jne .single_click
    call wmf_open_selected
    jmp .handled

.single_click:
    mov [wmf_selected], eax
    jmp .handled

.handled:
    mov eax, 1
    jmp .done

.not_handled:
    xor eax, eax

.done:
    pop r13
    pop r12
    pop rbx
    ret

; ============================================================================
; WMF_OPEN_SELECTED - Open selected entry
; ============================================================================
wmf_open_selected:
    push rbx

    call vfs_get_entries
    mov rbx, rax

    mov eax, [wmf_selected]
    imul eax, VFS_ENTRY_SIZE
    add rbx, rax

    mov eax, [rbx + VFS_E_FLAGS]
    test eax, VFS_FLAG_DIR
    jz .done

    lea rdi, [rbx + VFS_E_NAME]
    call vfs_goto

    mov dword [wmf_selected], 0
    mov dword [wmf_scroll_pos], 0

.done:
    pop rbx
    ret

; ============================================================================
; WMF_SHOW_NEW_DIALOG - Show create folder dialog
; ============================================================================
wmf_show_new_dialog:
    ; For now, create a default folder
    ; TODO: proper dialog
    call vfs_get_path
    mov rdi, rax

    ; Build path: current + /newfolder
    lea rdi, [wmf_new_path]

    ; Copy current path
    call vfs_get_path
    mov rsi, rax
.copy:
    lodsb
    stosb
    test al, al
    jnz .copy
    dec rdi

    ; Add /NEWFOLDER
    mov byte [rdi], '/'
    inc rdi
    lea rsi, [.default_name]
.copy2:
    lodsb
    stosb
    test al, al
    jnz .copy2

    ; Create folder
    lea rdi, [wmf_new_path]
    call fs_mkdir

    ; Refresh
    call vfs_reload
    ret

.default_name: db "NEWFOLDER", 0

wmf_new_path: times 128 db 0

; ============================================================================
; WMF_ON_KEY - Handle keyboard
; ============================================================================
wmf_on_key:
    cmp edi, 0x11               ; W
    je .up
    cmp edi, 0x48               ; Up
    je .up
    cmp edi, 0x1F               ; S
    je .down
    cmp edi, 0x50               ; Down
    je .down
    cmp edi, 0x1C               ; Enter
    je .enter
    cmp edi, 0x0E               ; Backspace
    je .back
    cmp edi, 0x31               ; N
    je .new

    xor eax, eax
    ret

.up:
    mov eax, [wmf_selected]
    test eax, eax
    jz .handled
    dec eax
    mov [wmf_selected], eax
    jmp .handled

.down:
    mov eax, [wmf_selected]
    inc eax
    cmp eax, [wmf_entry_count]
    jge .handled
    mov [wmf_selected], eax
    jmp .handled

.enter:
    call wmf_open_selected
    jmp .handled

.back:
    mov edi, VFS_LOC_ROOT
    call vfs_goto_loc
    mov dword [wmf_selected], 0
    mov dword [wmf_scroll_pos], 0
    jmp .handled

.new:
    call wmf_show_new_dialog
    jmp .handled

.handled:
    mov eax, 1
    ret

; ============================================================================
; DATA
; ============================================================================
wmf_vfs_ptr:    dq 0
wmf_loop_idx:   dd 0
wmf_cur_y:      dd 0
wmf_temp_loc:   dd 0
