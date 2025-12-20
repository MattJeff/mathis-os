; ════════════════════════════════════════════════════════════════════════════
; SIDEBAR_DRAW.ASM - Sidebar rendering
; ════════════════════════════════════════════════════════════════════════════

[BITS 64]

; ════════════════════════════════════════════════════════════════════════════
; SIDEBAR_DRAW - Draw the sidebar
; ════════════════════════════════════════════════════════════════════════════
sidebar_draw:
    push rax
    push rbx
    push rcx
    push rdx
    push rsi
    push rdi
    push r8
    push r12
    push r13
    push r14

    cmp byte [sidebar_visible], 0
    je .done

    ; Draw background
    mov edi, [sidebar_x]
    mov esi, [sidebar_y]
    mov edx, [sidebar_w]
    mov ecx, [sidebar_h]
    mov r8d, SIDEBAR_BG
    call fill_rect

    ; Draw right border
    mov edi, [sidebar_x]
    add edi, [sidebar_w]
    dec edi
    mov esi, [sidebar_y]
    mov edx, 1
    mov ecx, [sidebar_h]
    mov r8d, SIDEBAR_BORDER
    call fill_rect

    ; Draw items
    xor r12d, r12d                  ; Index
    mov r13d, [sidebar_item_count]
    mov r14d, [sidebar_y]
    add r14d, 8                     ; Top padding

.draw_loop:
    cmp r12d, r13d
    jge .done

    ; Get item address
    call sidebar_get_item           ; r12 = index, returns rax

    ; Get item type
    movzx ebx, byte [rax + SB_ITEM_TYPE]
    cmp ebx, SB_ITEM_HEADER
    je .draw_header

    ; Draw location item
    call sidebar_draw_location
    jmp .next

.draw_header:
    call sidebar_draw_header

.next:
    add r14d, SIDEBAR_ITEM_H
    inc r12d
    jmp .draw_loop

.done:
    pop r14
    pop r13
    pop r12
    pop r8
    pop rdi
    pop rsi
    pop rdx
    pop rcx
    pop rbx
    pop rax
    ret

; ════════════════════════════════════════════════════════════════════════════
; SIDEBAR_DRAW_HEADER - Draw section header
; Input: RAX = item addr, R14 = y
; ════════════════════════════════════════════════════════════════════════════
sidebar_draw_header:
    push rdx
    push rcx

    mov edi, [sidebar_x]
    add edi, 4
    mov esi, r14d
    add esi, 5
    mov rdx, [rax + SB_ITEM_NAME]
    mov ecx, SIDEBAR_TEXT_DIM
    call video_text

    pop rcx
    pop rdx
    ret

; ════════════════════════════════════════════════════════════════════════════
; SIDEBAR_DRAW_LOCATION - Draw location item
; Input: RAX = item addr, R12 = index, R14 = y
; ════════════════════════════════════════════════════════════════════════════
sidebar_draw_location:
    push rbx
    push rdx
    push rcx
    push r8

    mov rbx, rax

    ; Check if selected
    cmp r12d, [sidebar_selected]
    jne .check_hover

    ; Draw selection bg
    mov edi, [sidebar_x]
    add edi, 2
    mov esi, r14d
    mov edx, [sidebar_w]
    sub edx, 4
    mov ecx, SIDEBAR_ITEM_H
    mov r8d, SIDEBAR_SELECTED
    call fill_rect
    jmp .draw_content

.check_hover:
    cmp r12d, [sidebar_hover]
    jne .draw_content

    ; Draw hover bg
    mov edi, [sidebar_x]
    add edi, 2
    mov esi, r14d
    mov edx, [sidebar_w]
    sub edx, 4
    mov ecx, SIDEBAR_ITEM_H
    mov r8d, SIDEBAR_HOVER
    call fill_rect

.draw_content:
    ; Draw icon
    mov edi, [sidebar_x]
    add edi, 4
    mov esi, r14d
    add esi, 6
    movzx eax, byte [rbx + SB_ITEM_LOC]
    call sidebar_draw_icon

    ; Draw text
    mov edi, [sidebar_x]
    add edi, 20                     ; After icon
    mov esi, r14d
    add esi, 5
    mov rdx, [rbx + SB_ITEM_NAME]
    mov ecx, SIDEBAR_TEXT
    call video_text

    pop r8
    pop rcx
    pop rdx
    pop rbx
    ret

; ════════════════════════════════════════════════════════════════════════════
; SIDEBAR_DRAW_ICON - Draw location icon
; Input: EDI = x, ESI = y, EAX = VFS location type
; ════════════════════════════════════════════════════════════════════════════
sidebar_draw_icon:
    push rdx
    push rcx
    push r8

    ; Choose color
    cmp eax, VFS_LOC_ROOT
    je .root
    cmp eax, VFS_LOC_DESKTOP
    je .desktop
    cmp eax, VFS_LOC_DOWNLOADS
    je .downloads
    cmp eax, VFS_LOC_DOCUMENTS
    je .documents
    mov r8d, 0x00FFCC00             ; Default yellow
    jmp .draw

.root:
    mov r8d, 0x00888888             ; Gray
    jmp .draw
.desktop:
    mov r8d, 0x0055AAFF             ; Blue
    jmp .draw
.downloads:
    mov r8d, 0x0000CC66             ; Green
    jmp .draw
.documents:
    mov r8d, 0x00FFAA00             ; Orange

.draw:
    mov edx, SIDEBAR_ICON_SIZE
    mov ecx, SIDEBAR_ICON_SIZE
    call fill_rect

    pop r8
    pop rcx
    pop rdx
    ret

; ════════════════════════════════════════════════════════════════════════════
; SIDEBAR_GET_ITEM - Get item address by index
; Input: R12 = index
; Output: RAX = item address
; ════════════════════════════════════════════════════════════════════════════
sidebar_get_item:
    lea rax, [sb_item_0]
    mov ebx, r12d
    imul ebx, SB_ITEM_SIZE
    add rax, rbx
    ret
