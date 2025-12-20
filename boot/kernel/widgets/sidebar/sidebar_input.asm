; ════════════════════════════════════════════════════════════════════════════
; SIDEBAR_INPUT.ASM - Sidebar input handling
; ════════════════════════════════════════════════════════════════════════════

[BITS 64]

; ════════════════════════════════════════════════════════════════════════════
; SIDEBAR_ON_CLICK - Handle mouse click
; Input: EDI = x, ESI = y
; Output: EAX = 1 if handled
; ════════════════════════════════════════════════════════════════════════════
sidebar_on_click:
    push rbx
    push rcx
    push rdx
    push r12

    cmp byte [sidebar_visible], 0
    je .not_handled

    ; Check bounds
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

    ; Calculate item index
    mov eax, esi
    sub eax, [sidebar_y]
    sub eax, 8                      ; Top padding
    xor edx, edx
    mov ecx, SIDEBAR_ITEM_H
    div ecx

    ; Validate
    cmp eax, [sidebar_item_count]
    jge .not_handled

    mov r12d, eax

    ; Get item
    call sidebar_get_item

    ; Check if header
    movzx ecx, byte [rax + SB_ITEM_TYPE]
    cmp ecx, SB_ITEM_HEADER
    je .not_handled

    ; Set selection
    mov [sidebar_selected], r12d

    ; Navigate via VFS
    movzx edi, byte [rax + SB_ITEM_LOC]
    call vfs_goto_loc

    ; Call callback if set
    mov rcx, [sidebar_on_select]
    test rcx, rcx
    jz .handled
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
; SIDEBAR_ON_KEY - Handle keyboard
; Input: EDI = scancode
; Output: EAX = 1 if handled
; ════════════════════════════════════════════════════════════════════════════
sidebar_on_key:
    push rbx
    push rcx
    push r12

    cmp byte [sidebar_visible], 0
    je .not_handled

    ; W/Up = move up
    cmp edi, 0x11
    je .up
    cmp edi, 0x48
    je .up

    ; S/Down = move down
    cmp edi, 0x1F
    je .down
    cmp edi, 0x50
    je .down

    ; Enter = activate
    cmp edi, 0x1C
    je .activate

    jmp .not_handled

.up:
    mov eax, [sidebar_selected]
    test eax, eax
    jz .not_handled
    dec eax
    ; Skip headers
.skip_up:
    test eax, eax
    jz .set
    mov r12d, eax
    call sidebar_get_item
    movzx ecx, byte [rax + SB_ITEM_TYPE]
    cmp ecx, SB_ITEM_HEADER
    jne .set
    dec eax
    jmp .skip_up

.down:
    mov eax, [sidebar_selected]
    inc eax
    cmp eax, [sidebar_item_count]
    jge .not_handled
    ; Skip headers
.skip_down:
    cmp eax, [sidebar_item_count]
    jge .not_handled
    mov r12d, eax
    call sidebar_get_item
    movzx ecx, byte [rax + SB_ITEM_TYPE]
    cmp ecx, SB_ITEM_HEADER
    jne .set
    inc eax
    jmp .skip_down

.set:
    mov [sidebar_selected], eax
    jmp .handled

.activate:
    mov r12d, [sidebar_selected]
    call sidebar_get_item
    movzx edi, byte [rax + SB_ITEM_LOC]
    call vfs_goto_loc

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
