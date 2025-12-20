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
    push r9
    push r12
    push r13
    push r14

    ; Check visibility
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

    ; Draw locations
    mov r12d, 0                     ; Index
    mov r13d, [sidebar_loc_count]
    mov r14d, [sidebar_y]
    add r14d, SIDEBAR_PADDING       ; Y position

.draw_loop:
    cmp r12d, r13d
    jge .done

    ; Get location entry address
    call sidebar_get_loc_addr       ; r12 = index, returns rax = addr

    ; Get location type
    movzx ebx, byte [rax + SB_LOC_TYPE_OFF]

    ; Check if header
    cmp ebx, SB_LOC_HEADER
    je .draw_header

    ; Draw normal item
    call .draw_item
    jmp .next_item

.draw_header:
    call .draw_section_header

.next_item:
    add r14d, SIDEBAR_ITEM_H
    inc r12d
    jmp .draw_loop

.done:
    pop r14
    pop r13
    pop r12
    pop r9
    pop r8
    pop rdi
    pop rsi
    pop rdx
    pop rcx
    pop rbx
    pop rax
    ret

; ────────────────────────────────────────────────────────────────────────────
; .draw_section_header - Draw a section header (gray text, no bg)
; Input: RAX = location addr, R14 = y position
; ────────────────────────────────────────────────────────────────────────────
.draw_section_header:
    push rax
    push rdi
    push rsi
    push rdx

    ; Draw text
    mov edi, [sidebar_x]
    add edi, SIDEBAR_PADDING
    mov esi, r14d
    add esi, 4                      ; Center text vertically
    lea rdx, [rax + SB_LOC_NAME_OFF]
    mov r8d, SIDEBAR_TEXT_DIM
    call draw_text

    pop rdx
    pop rsi
    pop rdi
    pop rax
    ret

; ────────────────────────────────────────────────────────────────────────────
; .draw_item - Draw a normal location item
; Input: RAX = location addr, R12 = index, R14 = y position
; ────────────────────────────────────────────────────────────────────────────
.draw_item:
    push rax
    push rbx
    push rdi
    push rsi
    push rdx
    push rcx
    push r8

    mov rbx, rax                    ; Save location addr

    ; Check if selected
    cmp r12d, [sidebar_selected]
    jne .check_hover

    ; Draw selection background
    mov edi, [sidebar_x]
    add edi, 4
    mov esi, r14d
    mov edx, [sidebar_w]
    sub edx, 8
    mov ecx, SIDEBAR_ITEM_H
    mov r8d, SIDEBAR_SELECTED
    call fill_rect
    jmp .draw_text

.check_hover:
    ; Check if hovered
    cmp r12d, [sidebar_hover]
    jne .draw_text

    ; Draw hover background
    mov edi, [sidebar_x]
    add edi, 4
    mov esi, r14d
    mov edx, [sidebar_w]
    sub edx, 8
    mov ecx, SIDEBAR_ITEM_H
    mov r8d, SIDEBAR_HOVER
    call fill_rect

.draw_text:
    ; Draw location name
    mov edi, [sidebar_x]
    add edi, SIDEBAR_PADDING
    add edi, 20                     ; Space for icon
    mov esi, r14d
    add esi, 5                      ; Center text
    lea rdx, [rbx + SB_LOC_NAME_OFF]
    mov r8d, SIDEBAR_TEXT
    call draw_text

    ; Draw icon (simple folder/disk shape)
    mov edi, [sidebar_x]
    add edi, SIDEBAR_PADDING
    mov esi, r14d
    add esi, 4
    movzx eax, byte [rbx + SB_LOC_TYPE_OFF]
    call sidebar_draw_icon

    pop r8
    pop rcx
    pop rdx
    pop rsi
    pop rdi
    pop rbx
    pop rax
    ret

; ════════════════════════════════════════════════════════════════════════════
; SIDEBAR_DRAW_ICON - Draw location icon
; Input: EDI = x, ESI = y, EAX = location type
; ════════════════════════════════════════════════════════════════════════════
sidebar_draw_icon:
    push rdi
    push rsi
    push rdx
    push rcx
    push r8

    ; Choose color based on type
    cmp eax, SB_LOC_DESKTOP
    je .icon_desktop
    cmp eax, SB_LOC_ROOT
    je .icon_root
    cmp eax, SB_LOC_DOWNLOADS
    je .icon_downloads
    cmp eax, SB_LOC_DOCUMENTS
    je .icon_documents
    jmp .icon_folder

.icon_desktop:
    mov r8d, 0x0055AAFF             ; Light blue
    jmp .draw_icon_rect

.icon_root:
    mov r8d, 0x00888888             ; Gray
    jmp .draw_icon_rect

.icon_downloads:
    mov r8d, 0x0000CC66             ; Green
    jmp .draw_icon_rect

.icon_documents:
    mov r8d, 0x00FFAA00             ; Orange
    jmp .draw_icon_rect

.icon_folder:
    mov r8d, 0x00FFCC00             ; Yellow

.draw_icon_rect:
    ; Draw simple folder icon (12x12)
    mov edx, 12
    mov ecx, 12
    call fill_rect

    pop r8
    pop rcx
    pop rdx
    pop rsi
    pop rdi
    ret

; ════════════════════════════════════════════════════════════════════════════
; SIDEBAR_GET_LOC_ADDR - Get address of location entry
; Input:  R12 = index
; Output: RAX = address of location entry
; ════════════════════════════════════════════════════════════════════════════
sidebar_get_loc_addr:
    push rbx

    ; Each location is 32 bytes
    ; Locations are: sb_loc_0_type, sb_loc_1_type, etc.
    lea rax, [sb_loc_0_type]
    mov ebx, r12d
    imul ebx, SB_LOC_SIZE
    add rax, rbx

    pop rbx
    ret
