; ════════════════════════════════════════════════════════════════════════════
; MOUSE_SVC.ASM - Centralized Mouse Service (SOLID Phase 6)
; ════════════════════════════════════════════════════════════════════════════
; Single Responsibility: Manages cursor rendering and click distribution
; Open/Closed: Modes register handlers, don't implement mouse logic
;
; Architecture:
;   - Cursor drawing is centralized (one place)
;   - Click events go through event system
;   - Each mode registers its click handler
;   - Widgets can be hit-tested for clicks
;
; ════════════════════════════════════════════════════════════════════════════

[BITS 64]

; ════════════════════════════════════════════════════════════════════════════
; CONSTANTS
; ════════════════════════════════════════════════════════════════════════════
MOUSE_CURSOR_W      equ 10
MOUSE_CURSOR_H      equ 10
MOUSE_CURSOR_COLOR  equ 0x00FFFFFF      ; White

; ════════════════════════════════════════════════════════════════════════════
; STATE
; ════════════════════════════════════════════════════════════════════════════
ms_initialized:     db 0
ms_cursor_visible:  db 1
ms_last_x:          dw 0
ms_last_y:          dw 0
ms_click_handler:   dq 0                ; Current mode's click handler

; ════════════════════════════════════════════════════════════════════════════
; MOUSE_SVC_INIT - Initialize mouse service
; ════════════════════════════════════════════════════════════════════════════
mouse_svc_init:
    push rax
    push rdi
    push rsi

    ; Register for mouse events
    mov edi, EVT_MOUSE_MOVE
    lea rsi, [ms_on_mouse_move]
    call evt_register_handler

    mov edi, EVT_MOUSE_DOWN
    lea rsi, [ms_on_mouse_down]
    call evt_register_handler

    mov edi, EVT_MOUSE_UP
    lea rsi, [ms_on_mouse_up]
    call evt_register_handler

    ; Initialize state
    mov ax, [mouse_x]
    mov [ms_last_x], ax
    mov ax, [mouse_y]
    mov [ms_last_y], ax

    mov byte [ms_initialized], 1

    pop rsi
    pop rdi
    pop rax
    ret

; ════════════════════════════════════════════════════════════════════════════
; MOUSE_SVC_SET_HANDLER - Set click handler for current mode
; Input: RDI = handler function (or 0 to clear)
; Handler signature: void handler(x, y, button) - EDI=x, ESI=y, DL=button
; ════════════════════════════════════════════════════════════════════════════
mouse_svc_set_handler:
    mov [ms_click_handler], rdi
    ret

; ════════════════════════════════════════════════════════════════════════════
; MOUSE_SVC_SHOW_CURSOR / HIDE_CURSOR
; ════════════════════════════════════════════════════════════════════════════
mouse_svc_show_cursor:
    mov byte [ms_cursor_visible], 1
    ret

mouse_svc_hide_cursor:
    mov byte [ms_cursor_visible], 0
    ret

; ════════════════════════════════════════════════════════════════════════════
; MOUSE_SVC_DRAW_CURSOR - Draw cursor at current position
; Called from main loop after mode drawing
; ════════════════════════════════════════════════════════════════════════════
mouse_svc_draw_cursor:
    cmp byte [ms_cursor_visible], 0
    je .done

    push rbx

    ; Draw cursor (simple square for now)
    movzx edi, word [mouse_x]
    movzx esi, word [mouse_y]
    mov edx, MOUSE_CURSOR_W
    mov ecx, MOUSE_CURSOR_H
    mov r8d, MOUSE_CURSOR_COLOR
    call fill_rect

    ; Save position for next erase
    mov ax, [mouse_x]
    mov [ms_last_x], ax
    mov ax, [mouse_y]
    mov [ms_last_y], ax

    pop rbx
.done:
    ret

; ════════════════════════════════════════════════════════════════════════════
; MOUSE_SVC_NEEDS_REDRAW - Check if cursor moved (for dirty tracking)
; Output: EAX = 1 if moved, 0 if not
; ════════════════════════════════════════════════════════════════════════════
mouse_svc_needs_redraw:
    mov ax, [mouse_x]
    cmp ax, [ms_last_x]
    jne .moved
    mov ax, [mouse_y]
    cmp ax, [ms_last_y]
    jne .moved
    xor eax, eax
    ret
.moved:
    mov eax, 1
    ret

; ════════════════════════════════════════════════════════════════════════════
; EVENT HANDLERS (called by dispatcher)
; ════════════════════════════════════════════════════════════════════════════

; Mouse move event - mark screen dirty for cursor redraw
ms_on_mouse_move:
    ; Just mark that we need to redraw cursor
    ; The main loop will handle the actual drawing
    ret

; Mouse down event - dispatch to current handler
ms_on_mouse_down:
    push rbx
    push rcx
    push rdx

    ; Get click position from event
    call event_get_mouse_pos          ; AX = x, DX = y
    movzx ebx, ax                     ; ebx = x
    movzx ecx, dx                     ; ecx = y

    ; Get button
    call event_get_mouse_button       ; AL = button

    ; Call current mode's handler if set
    mov rsi, [ms_click_handler]
    test rsi, rsi
    jz .no_handler

    ; Call handler(x, y, button)
    mov edi, ebx                      ; x
    mov esi, ecx                      ; y (reuse esi)
    movzx edx, al                     ; button
    call rsi

.no_handler:
    pop rdx
    pop rcx
    pop rbx
    ret

ms_on_mouse_up:
    ; Could be used for drag-end, etc.
    ret

; ════════════════════════════════════════════════════════════════════════════
; WIDGET HIT TESTING
; ════════════════════════════════════════════════════════════════════════════

; ────────────────────────────────────────────────────────────────────────────
; MOUSE_SVC_HIT_TEST - Check if point is inside widget
; Input:  RDI = widget pointer, ESI = x, EDX = y
; Output: EAX = 1 if hit, 0 if miss
; ────────────────────────────────────────────────────────────────────────────
mouse_svc_hit_test:
    test rdi, rdi
    jz .miss

    ; Get widget bounds
    mov eax, [rdi + W_X]
    cmp esi, eax
    jl .miss                          ; x < widget.x

    add eax, [rdi + W_W]
    cmp esi, eax
    jge .miss                         ; x >= widget.x + widget.w

    mov eax, [rdi + W_Y]
    cmp edx, eax
    jl .miss                          ; y < widget.y

    add eax, [rdi + W_H]
    cmp edx, eax
    jge .miss                         ; y >= widget.y + widget.h

    mov eax, 1
    ret

.miss:
    xor eax, eax
    ret

; ────────────────────────────────────────────────────────────────────────────
; MOUSE_SVC_HIT_TEST_RECT - Check if point is inside rectangle
; Input:  EDI = x, ESI = y, EDX = rect_x, ECX = rect_y, R8D = rect_w, R9D = rect_h
; Output: EAX = 1 if hit, 0 if miss
; ────────────────────────────────────────────────────────────────────────────
mouse_svc_hit_test_rect:
    ; Check x bounds
    cmp edi, edx
    jl .miss                          ; x < rect_x

    mov eax, edx
    add eax, r8d
    cmp edi, eax
    jge .miss                         ; x >= rect_x + rect_w

    ; Check y bounds
    cmp esi, ecx
    jl .miss                          ; y < rect_y

    mov eax, ecx
    add eax, r9d
    cmp esi, eax
    jge .miss                         ; y >= rect_y + rect_h

    mov eax, 1
    ret

.miss:
    xor eax, eax
    ret
