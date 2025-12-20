; ============================================================================
; DESKTOP_ICONS_DRAG.ASM - Icon drag and drop handling
; ============================================================================
; Single Responsibility: Handle dragging icons on desktop
; ============================================================================

[BITS 64]

; Drag state
dicon_drag_idx:     dd -1           ; Index of icon being dragged (-1 = none)
dicon_drag_off_x:   dd 0            ; Offset from icon origin to mouse
dicon_drag_off_y:   dd 0

; ============================================================================
; DICON_START_DRAG - Start dragging an icon
; Input: EDI = icon index, ESI = mouse_x, EDX = mouse_y
; ============================================================================
dicon_start_drag:
    push rbx

    mov [dicon_drag_idx], edi

    ; Get icon entry
    mov eax, edi
    imul eax, DICON_ENT_SIZE
    lea rbx, [dicon_entries + rax]

    ; Calculate offset from icon origin
    mov eax, esi
    sub eax, [rbx + DICON_ENT_X]
    mov [dicon_drag_off_x], eax

    mov eax, edx
    sub eax, [rbx + DICON_ENT_Y]
    mov [dicon_drag_off_y], eax

    pop rbx
    ret

; ============================================================================
; DICON_UPDATE_DRAG - Update dragged icon position
; Input: EDI = mouse_x, ESI = mouse_y
; ============================================================================
dicon_update_drag:
    push rbx

    mov eax, [dicon_drag_idx]
    cmp eax, -1
    je .done

    ; Get icon entry
    imul eax, DICON_ENT_SIZE
    lea rbx, [dicon_entries + rax]

    ; Update X position
    mov eax, edi
    sub eax, [dicon_drag_off_x]
    ; Clamp to screen bounds
    cmp eax, 0
    jge .x_min_ok
    xor eax, eax
.x_min_ok:
    mov ecx, [screen_width]
    sub ecx, DESKTOP_ICON_SIZE
    cmp eax, ecx
    jle .x_max_ok
    mov eax, ecx
.x_max_ok:
    mov [rbx + DICON_ENT_X], eax

    ; Update Y position
    mov eax, esi
    sub eax, [dicon_drag_off_y]
    ; Clamp to screen bounds (above taskbar)
    cmp eax, 0
    jge .y_min_ok
    xor eax, eax
.y_min_ok:
    mov ecx, [screen_height]
    sub ecx, DESKTOP_TASKBAR_H
    sub ecx, DESKTOP_ICON_SIZE
    sub ecx, 20                     ; Extra margin
    cmp eax, ecx
    jle .y_max_ok
    mov eax, ecx
.y_max_ok:
    mov [rbx + DICON_ENT_Y], eax

    mov byte [desktop_needs_redraw], 1

.done:
    pop rbx
    ret

; ============================================================================
; DICON_END_DRAG - Stop dragging
; ============================================================================
dicon_end_drag:
    mov dword [dicon_drag_idx], -1
    ret

; ============================================================================
; DICON_IS_DRAGGING - Check if currently dragging
; Output: EAX = 1 if dragging
; ============================================================================
dicon_is_dragging:
    xor eax, eax
    cmp dword [dicon_drag_idx], -1
    je .done
    mov eax, 1
.done:
    ret

; ============================================================================
; DICON_FIND_FREE_POS - Find free position for new icon
; Output: EDI = x, ESI = y
; ============================================================================
dicon_find_free_pos:
    push rbx
    push r12
    push r13
    push r14

    ; Start scanning from top-left, below static icons
    mov r12d, DICON_START_X         ; Current test X
    mov r13d, DICON_START_Y         ; Current test Y

.test_pos:
    ; Check if position collides with any existing icon
    mov r14d, 0                     ; Collision flag

    xor ecx, ecx
.check_loop:
    cmp ecx, [dicon_count]
    jge .no_collision

    mov eax, ecx
    imul eax, DICON_ENT_SIZE
    lea rbx, [dicon_entries + rax]

    ; Check X overlap
    mov eax, [rbx + DICON_ENT_X]
    add eax, DESKTOP_ICON_SIZE + 8  ; Add spacing
    cmp r12d, eax
    jge .next_icon
    mov eax, r12d
    add eax, DESKTOP_ICON_SIZE + 8
    cmp eax, [rbx + DICON_ENT_X]
    jle .next_icon

    ; Check Y overlap
    mov eax, [rbx + DICON_ENT_Y]
    add eax, DESKTOP_ICON_SIZE + 20 ; Add spacing for label
    cmp r13d, eax
    jge .next_icon
    mov eax, r13d
    add eax, DESKTOP_ICON_SIZE + 20
    cmp eax, [rbx + DICON_ENT_Y]
    jle .next_icon

    ; Collision detected
    mov r14d, 1
    jmp .try_next_pos

.next_icon:
    inc ecx
    jmp .check_loop

.no_collision:
    ; No collision, use this position
    mov edi, r12d
    mov esi, r13d
    jmp .done

.try_next_pos:
    ; Move to next grid position
    add r12d, DICON_SPACING_X
    mov eax, [screen_width]
    sub eax, DESKTOP_ICON_SIZE
    cmp r12d, eax
    jl .test_pos

    ; Next row
    mov r12d, DICON_START_X
    add r13d, DICON_SPACING_Y
    mov eax, [screen_height]
    sub eax, DESKTOP_TASKBAR_H
    sub eax, DESKTOP_ICON_SIZE
    cmp r13d, eax
    jl .test_pos

    ; No free position found, use default
    mov edi, DICON_START_X
    mov esi, DICON_START_Y

.done:
    pop r14
    pop r13
    pop r12
    pop rbx
    ret
