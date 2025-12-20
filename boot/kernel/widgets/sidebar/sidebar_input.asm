; ════════════════════════════════════════════════════════════════════════════
; SIDEBAR_INPUT.ASM - Sidebar mouse/keyboard input handling
; ════════════════════════════════════════════════════════════════════════════

[BITS 64]

; ════════════════════════════════════════════════════════════════════════════
; SIDEBAR_ON_MOUSE_MOVE - Update hover state
; Input: EDI = mouse_x, ESI = mouse_y
; ════════════════════════════════════════════════════════════════════════════
sidebar_on_mouse_move:
    push rax
    push rbx
    push rcx
    push rdx

    ; Check visibility
    cmp byte [sidebar_visible], 0
    je .no_hover

    ; Check if mouse is in sidebar bounds
    mov eax, [sidebar_x]
    cmp edi, eax
    jl .no_hover

    add eax, [sidebar_w]
    cmp edi, eax
    jge .no_hover

    mov eax, [sidebar_y]
    cmp esi, eax
    jl .no_hover

    add eax, [sidebar_h]
    cmp esi, eax
    jge .no_hover

    ; Calculate which item is hovered
    mov eax, esi
    sub eax, [sidebar_y]
    sub eax, SIDEBAR_PADDING

    ; Divide by item height
    xor edx, edx
    mov ecx, SIDEBAR_ITEM_H
    div ecx                         ; EAX = item index

    ; Validate index
    cmp eax, [sidebar_loc_count]
    jge .no_hover

    ; Check if it's a header (not hoverable)
    mov ebx, eax
    mov r12d, eax
    call sidebar_get_loc_addr
    movzx ecx, byte [rax + SB_LOC_TYPE_OFF]
    cmp ecx, SB_LOC_HEADER
    je .no_hover

    ; Set hover
    mov [sidebar_hover], ebx
    jmp .done

.no_hover:
    mov dword [sidebar_hover], -1

.done:
    pop rdx
    pop rcx
    pop rbx
    pop rax
    ret

; ════════════════════════════════════════════════════════════════════════════
; SIDEBAR_ON_CLICK - Handle mouse click
; Input: EDI = mouse_x, ESI = mouse_y
; Output: EAX = 1 if handled, 0 otherwise
; ════════════════════════════════════════════════════════════════════════════
sidebar_on_click:
    push rbx
    push rcx
    push rdx
    push r12

    ; Check visibility
    cmp byte [sidebar_visible], 0
    je .not_handled

    ; Check if mouse is in sidebar bounds
    mov eax, [sidebar_x]
    cmp edi, eax
    jl .not_handled

    add eax, [sidebar_w]
    cmp edi, eax
    jge .not_handled

    mov eax, [sidebar_y]
    cmp esi, eax
    jl .not_handled

    add eax, [sidebar_h]
    cmp esi, eax
    jge .not_handled

    ; Calculate which item was clicked
    mov eax, esi
    sub eax, [sidebar_y]
    sub eax, SIDEBAR_PADDING

    xor edx, edx
    mov ecx, SIDEBAR_ITEM_H
    div ecx                         ; EAX = item index

    ; Validate index
    cmp eax, [sidebar_loc_count]
    jge .not_handled

    ; Check if it's a header (not clickable)
    mov ebx, eax
    mov r12d, eax
    call sidebar_get_loc_addr
    movzx ecx, byte [rax + SB_LOC_TYPE_OFF]
    cmp ecx, SB_LOC_HEADER
    je .not_handled

    ; Set selection
    mov [sidebar_selected], ebx

    ; Call callback if set
    mov rcx, [sidebar_on_select]
    test rcx, rcx
    jz .handled

    ; Prepare callback: rdi = index, rsi = path ptr
    mov edi, ebx
    lea rsi, [rax + SB_LOC_PATH_OFF]
    call rcx

.handled:
    mov eax, 1
    jmp .done

.not_handled:
    xor eax, eax

.done:
    pop r12
    pop rdx
    pop rcx
    pop rbx
    ret

; ════════════════════════════════════════════════════════════════════════════
; SIDEBAR_ON_KEY - Handle keyboard input
; Input: EDI = scancode
; Output: EAX = 1 if handled, 0 otherwise
; ════════════════════════════════════════════════════════════════════════════
sidebar_on_key:
    push rbx
    push rcx
    push r12

    ; Check visibility
    cmp byte [sidebar_visible], 0
    je .not_handled

    ; W or Up arrow (0x11 / 0x48) - move selection up
    cmp edi, 0x11
    je .move_up
    cmp edi, 0x48
    je .move_up

    ; S or Down arrow (0x1F / 0x50) - move selection down
    cmp edi, 0x1F
    je .move_down
    cmp edi, 0x50
    je .move_down

    ; Enter (0x1C) - activate selection
    cmp edi, 0x1C
    je .activate

    jmp .not_handled

.move_up:
    mov eax, [sidebar_selected]
    test eax, eax
    jz .not_handled
    dec eax

    ; Skip headers
.skip_header_up:
    test eax, eax
    jz .set_selection
    mov r12d, eax
    call sidebar_get_loc_addr
    movzx ecx, byte [rax + SB_LOC_TYPE_OFF]
    cmp ecx, SB_LOC_HEADER
    jne .set_selection
    dec eax
    jmp .skip_header_up

.move_down:
    mov eax, [sidebar_selected]
    inc eax
    cmp eax, [sidebar_loc_count]
    jge .not_handled

    ; Skip headers
.skip_header_down:
    cmp eax, [sidebar_loc_count]
    jge .not_handled
    mov r12d, eax
    call sidebar_get_loc_addr
    movzx ecx, byte [rax + SB_LOC_TYPE_OFF]
    cmp ecx, SB_LOC_HEADER
    jne .set_selection
    inc eax
    jmp .skip_header_down

.set_selection:
    mov [sidebar_selected], eax
    jmp .handled

.activate:
    ; Call callback with current selection
    mov rcx, [sidebar_on_select]
    test rcx, rcx
    jz .handled

    mov eax, [sidebar_selected]
    mov r12d, eax
    call sidebar_get_loc_addr

    mov edi, [sidebar_selected]
    lea rsi, [rax + SB_LOC_PATH_OFF]
    call rcx
    jmp .handled

.handled:
    mov eax, 1
    jmp .done

.not_handled:
    xor eax, eax

.done:
    pop r12
    pop rcx
    pop rbx
    ret
