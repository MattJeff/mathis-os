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

    ; Initialize state from current mouse position
    mov ax, [mouse_x]
    mov [ms_last_x], ax
    mov ax, [mouse_y]
    mov [ms_last_y], ax

    mov byte [ms_initialized], 1

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
; MOUSE_SVC_POLL_CLICK - Check for click and dispatch to handler (call from main loop)
; Output: EAX = 1 if click was processed
; ════════════════════════════════════════════════════════════════════════════
mouse_svc_poll_click:
    ; Check if click flag is set
    cmp byte [mouse_clicked], 0
    je .no_click

    ; Clear flag
    mov byte [mouse_clicked], 0

    ; Get handler
    mov rax, [ms_click_handler]
    test rax, rax
    jz .no_click

    ; Call handler(x, y, button)
    push rax
    movzx edi, word [mouse_x]
    movzx esi, word [mouse_y]
    mov edx, 1                      ; Left button
    pop rax
    call rax

    mov eax, 1
    ret

.no_click:
    xor eax, eax
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
