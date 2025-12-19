; ════════════════════════════════════════════════════════════════════════════
; INPUT_SVC.ASM - Input Service Implementation (SOLID)
; ════════════════════════════════════════════════════════════════════════════
; Wraps keyboard/mouse state as a service for the registry
; All input queries go through this service - no direct variable access
; ════════════════════════════════════════════════════════════════════════════

; ════════════════════════════════════════════════════════════════════════════
; INPUT SERVICE V-TABLE
; ════════════════════════════════════════════════════════════════════════════
input_svc_vtable:
    dq input_poll           ; Offset 0:  poll() -> has_input (1/0)
    dq input_get_key        ; Offset 8:  get_key() -> scancode
    dq input_get_mouse_x    ; Offset 16: mouse_x() -> x
    dq input_get_mouse_y    ; Offset 24: mouse_y() -> y
    dq input_get_mouse_btn  ; Offset 32: mouse_btn() -> buttons

; ════════════════════════════════════════════════════════════════════════════
; INPUT_SVC_INIT - Register input service
; Call this after registry_init
; ════════════════════════════════════════════════════════════════════════════
input_svc_init:
    push rdi
    push rsi

    mov edi, SVC_INPUT
    lea rsi, [input_svc_vtable]
    call register_service

    pop rsi
    pop rdi
    ret

; ════════════════════════════════════════════════════════════════════════════
; INPUT_POLL - Check if input is available
; Output: EAX = 1 if key pressed, 0 otherwise
; ════════════════════════════════════════════════════════════════════════════
input_poll:
    xor eax, eax
    cmp byte [key_pressed], 0
    je .done
    mov eax, 1
.done:
    ret

; ════════════════════════════════════════════════════════════════════════════
; INPUT_GET_KEY - Get last pressed key and clear it
; Output: EAX = scancode (0 if none)
; ════════════════════════════════════════════════════════════════════════════
input_get_key:
    xor eax, eax
    mov al, [key_pressed]
    mov byte [key_pressed], 0       ; Clear after read (consume)
    ret

; ════════════════════════════════════════════════════════════════════════════
; INPUT_GET_MOUSE_X - Get mouse X position
; Output: EAX = x coordinate
; ════════════════════════════════════════════════════════════════════════════
input_get_mouse_x:
    xor eax, eax
    mov ax, [mouse_x]
    ret

; ════════════════════════════════════════════════════════════════════════════
; INPUT_GET_MOUSE_Y - Get mouse Y position
; Output: EAX = y coordinate
; ════════════════════════════════════════════════════════════════════════════
input_get_mouse_y:
    xor eax, eax
    mov ax, [mouse_y]
    ret

; ════════════════════════════════════════════════════════════════════════════
; INPUT_GET_MOUSE_BTN - Get mouse button state
; Output: EAX = buttons (bit 0 = left, bit 1 = right)
; ════════════════════════════════════════════════════════════════════════════
input_get_mouse_btn:
    xor eax, eax
    mov al, [mouse_buttons]
    ret
