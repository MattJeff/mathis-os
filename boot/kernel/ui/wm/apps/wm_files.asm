; ============================================================================
; WM_FILES.ASM - Files app for window manager
; ============================================================================

[BITS 64]

; Constants
WMF_PADDING         equ 4
WMF_ROW_H           equ 20
WMF_MAX_VISIBLE     equ 12

; State
wmf_scroll_pos:     dd 0
wmf_selected:       dd 0
wmf_entry_count:    dd 0

; ============================================================================
; WMF_DRAW_CONTENT - Draw file list in window content area
; Input: EDI = x, ESI = y, EDX = w, ECX = h
; ============================================================================
wmf_draw_content:
    push rbx
    push r12
    push r13
    push r14
    push r15

    mov r12d, edi               ; r12 = content x
    mov r13d, esi               ; r13 = content y
    mov r14d, edx               ; r14 = content w
    mov r15d, ecx               ; r15 = content h

    ; Get VFS entries
    call vfs_get_entries        ; RAX = entries, EDX = count
    mov [wmf_vfs_ptr], rax
    mov [wmf_entry_count], edx

    ; Loop through visible entries
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

    ; Calculate Y = content_y + padding + (visible_idx * row_h)
    imul ecx, WMF_ROW_H
    add ecx, r13d
    add ecx, WMF_PADDING
    mov [wmf_cur_y], ecx

    ; Get entry pointer
    mov eax, [wmf_loop_idx]
    imul eax, VFS_ENTRY_SIZE
    mov rbx, [wmf_vfs_ptr]
    add rbx, rax                ; rbx = entry

    ; Draw selection highlight if selected
    mov eax, [wmf_loop_idx]
    cmp eax, [wmf_selected]
    jne .no_sel

    mov edi, r12d
    add edi, WMF_PADDING
    mov esi, [wmf_cur_y]
    mov edx, r14d
    sub edx, WMF_PADDING * 2
    mov ecx, WMF_ROW_H
    mov r8d, 0x00404060
    call fill_rect
.no_sel:

    ; Draw icon
    mov edi, r12d
    add edi, WMF_PADDING + 4
    mov esi, [wmf_cur_y]
    add esi, 3

    mov eax, [rbx + VFS_E_FLAGS]
    test eax, VFS_FLAG_DIR
    jz .file_icon

    ; Folder icon (yellow square)
    mov edx, 12
    mov ecx, 10
    mov r8d, 0x00FFCC00
    call fill_rect
    jmp .draw_name

.file_icon:
    ; File icon (white square)
    mov edx, 10
    mov ecx, 12
    mov r8d, 0x00AAAAAA
    call fill_rect

.draw_name:
    ; Draw name
    mov edi, r12d
    add edi, WMF_PADDING + 22
    mov esi, [wmf_cur_y]
    add esi, 5
    lea rdx, [rbx + VFS_E_NAME]
    mov ecx, 0x00FFFFFF
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

; Temp variables
wmf_vfs_ptr:    dq 0
wmf_loop_idx:   dd 0
wmf_cur_y:      dd 0

; ============================================================================
; WMF_ON_CLICK - Handle click in files window content
; Input: EDI = x, ESI = y (relative to content area)
; Output: EAX = 1 if handled
; ============================================================================
wmf_on_click:
    push rbx

    ; Calculate which row was clicked
    sub esi, WMF_PADDING
    cmp esi, 0
    jl .not_handled

    mov eax, esi
    xor edx, edx
    mov ecx, WMF_ROW_H
    div ecx

    ; Add scroll offset
    add eax, [wmf_scroll_pos]

    ; Validate
    cmp eax, [wmf_entry_count]
    jge .not_handled

    ; Check for double-click
    cmp eax, [wmf_selected]
    jne .single_click
    call wmf_open_selected
    jmp .handled

.single_click:
    mov [wmf_selected], eax

.handled:
    mov eax, 1
    jmp .done

.not_handled:
    xor eax, eax

.done:
    pop rbx
    ret

; ============================================================================
; WMF_OPEN_SELECTED - Open selected entry
; ============================================================================
wmf_open_selected:
    push rbx
    push r12

    call vfs_get_entries
    mov rbx, rax

    mov eax, [wmf_selected]
    imul eax, VFS_ENTRY_SIZE
    add rbx, rax

    ; Check if directory
    mov eax, [rbx + VFS_E_FLAGS]
    test eax, VFS_FLAG_DIR
    jz .done

    ; Navigate into directory (don't notify - window manages its own state)
    lea rdi, [rbx + VFS_E_NAME]
    call vfs_goto

    mov dword [wmf_selected], 0
    mov dword [wmf_scroll_pos], 0

.done:
    pop r12
    pop rbx
    ret

; ============================================================================
; WMF_ON_KEY - Handle keyboard in files window
; Input: EDI = scancode
; Output: EAX = 1 if handled
; ============================================================================
wmf_on_key:
    cmp edi, 0x11               ; W
    je .up
    cmp edi, 0x48               ; Up arrow
    je .up
    cmp edi, 0x1F               ; S
    je .down
    cmp edi, 0x50               ; Down arrow
    je .down
    cmp edi, 0x1C               ; Enter
    je .enter
    cmp edi, 0x0E               ; Backspace
    je .back

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

.handled:
    mov eax, 1
    ret
