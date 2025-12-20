; ════════════════════════════════════════════════════════════════════════════
; INPUT_MANAGER.ASM - Centralized Input Management (SOLID)
; ════════════════════════════════════════════════════════════════════════════
; Single Responsibility: Centralize all input handling for the kernel
; Open/Closed: Modes register handlers, don't implement input logic
;
; Architecture:
;   - Called from main_loop ONCE per frame
;   - Manages keyboard state, mouse state, cursor rendering
;   - Modes register click/key handlers via callbacks
;   - Provides unified API for all input queries
;
; Usage:
;   1. Call input_manager_init() at kernel startup
;   2. Each mode calls input_manager_set_handlers() on activation
;   3. Main loop calls input_manager_update() then input_manager_draw_cursor()
;   4. Modes query state via input_manager_get_* functions
; ════════════════════════════════════════════════════════════════════════════

[BITS 64]

; ════════════════════════════════════════════════════════════════════════════
; CONSTANTS
; ════════════════════════════════════════════════════════════════════════════
INPUT_CLICK_COOLDOWN    equ 10          ; Frames between clicks

; ════════════════════════════════════════════════════════════════════════════
; STATE
; ════════════════════════════════════════════════════════════════════════════
section .data

im_initialized:         db 0
im_cursor_visible:      db 1            ; 1 = draw cursor, 0 = hide
im_last_mouse_btn:      db 0            ; For click edge detection
im_click_cooldown:      db 0            ; Cooldown counter

; Handler callbacks (set by current mode)
im_key_handler:         dq 0            ; void handler(scancode)
im_click_handler:       dq 0            ; void handler(x, y, button)
im_mouse_move_handler:  dq 0            ; void handler(x, y) - optional

; Cached state (updated each frame)
im_mouse_x:             dw 0
im_mouse_y:             dw 0
im_mouse_btn:           db 0
im_key_scancode:        db 0
im_key_ready:           db 0            ; 1 if new key this frame

section .text

; ════════════════════════════════════════════════════════════════════════════
; INPUT_MANAGER_INIT - Initialize input manager
; ════════════════════════════════════════════════════════════════════════════
; Call once at kernel startup, after mouse_init
; ════════════════════════════════════════════════════════════════════════════
input_manager_init:
    ; Only init once
    cmp byte [im_initialized], 1
    je .done

    push rax

    ; DON'T reset mouse position - ISR already handles it
    ; Just sync our cached values
    mov ax, [mouse_x]
    mov [im_mouse_x], ax
    mov ax, [mouse_y]
    mov [im_mouse_y], ax

    ; Clear handlers
    mov qword [im_key_handler], 0
    mov qword [im_click_handler], 0
    mov qword [im_mouse_move_handler], 0

    ; Set initialized flag
    mov byte [im_initialized], 1
    mov byte [im_cursor_visible], 1

    pop rax
.done:
    ret

; ════════════════════════════════════════════════════════════════════════════
; INPUT_MANAGER_SET_HANDLERS - Set handlers for current mode
; ════════════════════════════════════════════════════════════════════════════
; Input: RDI = key_handler (or 0), RSI = click_handler (or 0), RDX = move_handler (or 0)
; Handler signatures:
;   key_handler:   void(scancode in EDI)
;   click_handler: void(x in EDI, y in ESI, button in EDX)
;   move_handler:  void(x in EDI, y in ESI)
; ════════════════════════════════════════════════════════════════════════════
input_manager_set_handlers:
    mov [im_key_handler], rdi
    mov [im_click_handler], rsi
    mov [im_mouse_move_handler], rdx
    ret

; ════════════════════════════════════════════════════════════════════════════
; INPUT_MANAGER_SET_KEY_HANDLER - Set only key handler
; Input: RDI = handler
; ════════════════════════════════════════════════════════════════════════════
input_manager_set_key_handler:
    mov [im_key_handler], rdi
    ret

; ════════════════════════════════════════════════════════════════════════════
; INPUT_MANAGER_SET_CLICK_HANDLER - Set only click handler
; Input: RDI = handler
; ════════════════════════════════════════════════════════════════════════════
input_manager_set_click_handler:
    mov [im_click_handler], rdi
    ret

; ════════════════════════════════════════════════════════════════════════════
; INPUT_MANAGER_SHOW_CURSOR / HIDE_CURSOR
; ════════════════════════════════════════════════════════════════════════════
input_manager_show_cursor:
    mov byte [im_cursor_visible], 1
    ret

input_manager_hide_cursor:
    mov byte [im_cursor_visible], 0
    ret

; ════════════════════════════════════════════════════════════════════════════
; INPUT_MANAGER_UPDATE - Process input events (call once per frame)
; ════════════════════════════════════════════════════════════════════════════
; Called from main_loop before mode drawing
; Reads hardware state, dispatches to handlers
; ════════════════════════════════════════════════════════════════════════════
input_manager_update:
    push rax
    push rbx
    push rcx
    push rdx
    push rdi
    push rsi

    ; ══════════════════════════════════════════════════════════════════════
    ; Update cached mouse position
    ; ══════════════════════════════════════════════════════════════════════
    mov ax, [mouse_x]
    mov [im_mouse_x], ax
    mov ax, [mouse_y]
    mov [im_mouse_y], ax
    mov al, [mouse_buttons]
    mov [im_mouse_btn], al

    ; ══════════════════════════════════════════════════════════════════════
    ; Process keyboard input
    ; ══════════════════════════════════════════════════════════════════════
    mov byte [im_key_ready], 0
    mov al, [key_pressed]
    test al, al
    jz .no_key

    ; New key pressed
    mov [im_key_scancode], al
    mov byte [im_key_ready], 1

    ; Clear key_pressed to consume it
    mov byte [key_pressed], 0

    ; Dispatch to handler if registered
    mov rax, [im_key_handler]
    test rax, rax
    jz .no_key

    movzx edi, byte [im_key_scancode]
    call rax

.no_key:

    ; ══════════════════════════════════════════════════════════════════════
    ; Process mouse click (edge detection)
    ; ══════════════════════════════════════════════════════════════════════
    ; Decrement cooldown
    cmp byte [im_click_cooldown], 0
    je .cooldown_ok
    dec byte [im_click_cooldown]
    jmp .no_click

.cooldown_ok:
    mov al, [im_mouse_btn]
    and al, 1                           ; Left button only
    mov bl, [im_last_mouse_btn]
    mov [im_last_mouse_btn], al

    ; Edge detection: was 0, now 1 = click
    test bl, bl
    jnz .no_click                       ; Was pressed = not a new click
    test al, al
    jz .no_click                        ; Not pressed now = no click

    ; Click detected - set cooldown
    mov byte [im_click_cooldown], INPUT_CLICK_COOLDOWN

    ; Dispatch to handler if registered
    mov rax, [im_click_handler]
    test rax, rax
    jz .no_click

    movzx edi, word [im_mouse_x]
    movzx esi, word [im_mouse_y]
    mov edx, 1                          ; Left button
    call rax

.no_click:

    pop rsi
    pop rdi
    pop rdx
    pop rcx
    pop rbx
    pop rax
    ret

; ════════════════════════════════════════════════════════════════════════════
; INPUT_MANAGER_DRAW_CURSOR - Draw cursor (call AFTER mode drawing)
; ════════════════════════════════════════════════════════════════════════════
input_manager_draw_cursor:
    cmp byte [im_cursor_visible], 0
    je .done
    call cursor_draw
.done:
    ret

; ════════════════════════════════════════════════════════════════════════════
; GETTER FUNCTIONS - For modes to query state
; ════════════════════════════════════════════════════════════════════════════

; ────────────────────────────────────────────────────────────────────────────
; INPUT_MANAGER_GET_MOUSE_X - Get mouse X position
; Output: EAX = x
; ────────────────────────────────────────────────────────────────────────────
input_manager_get_mouse_x:
    movzx eax, word [im_mouse_x]
    ret

; ────────────────────────────────────────────────────────────────────────────
; INPUT_MANAGER_GET_MOUSE_Y - Get mouse Y position
; Output: EAX = y
; ────────────────────────────────────────────────────────────────────────────
input_manager_get_mouse_y:
    movzx eax, word [im_mouse_y]
    ret

; ────────────────────────────────────────────────────────────────────────────
; INPUT_MANAGER_GET_MOUSE_POS - Get mouse position
; Output: EAX = x, EDX = y
; ────────────────────────────────────────────────────────────────────────────
input_manager_get_mouse_pos:
    movzx eax, word [im_mouse_x]
    movzx edx, word [im_mouse_y]
    ret

; ────────────────────────────────────────────────────────────────────────────
; INPUT_MANAGER_GET_MOUSE_BTN - Get mouse button state
; Output: EAX = buttons (bit 0 = left, bit 1 = right)
; ────────────────────────────────────────────────────────────────────────────
input_manager_get_mouse_btn:
    movzx eax, byte [im_mouse_btn]
    ret

; ────────────────────────────────────────────────────────────────────────────
; INPUT_MANAGER_HAS_KEY - Check if key was pressed this frame
; Output: EAX = 1 if key ready, 0 otherwise
; ────────────────────────────────────────────────────────────────────────────
input_manager_has_key:
    movzx eax, byte [im_key_ready]
    ret

; ────────────────────────────────────────────────────────────────────────────
; INPUT_MANAGER_GET_KEY - Get last key scancode
; Output: EAX = scancode
; ────────────────────────────────────────────────────────────────────────────
input_manager_get_key:
    movzx eax, byte [im_key_scancode]
    ret

; ────────────────────────────────────────────────────────────────────────────
; INPUT_MANAGER_IS_SHIFT - Check if shift is pressed
; Output: EAX = 1 if shift, 0 otherwise
; ────────────────────────────────────────────────────────────────────────────
input_manager_is_shift:
    movzx eax, byte [shift_state]
    ret

; ────────────────────────────────────────────────────────────────────────────
; INPUT_MANAGER_IS_CTRL - Check if ctrl is pressed
; Output: EAX = 1 if ctrl, 0 otherwise
; ────────────────────────────────────────────────────────────────────────────
input_manager_is_ctrl:
    movzx eax, byte [ctrl_state]
    ret

; ────────────────────────────────────────────────────────────────────────────
; INPUT_MANAGER_IS_ALT - Check if alt is pressed
; Output: EAX = 1 if alt, 0 otherwise
; ────────────────────────────────────────────────────────────────────────────
input_manager_is_alt:
    movzx eax, byte [alt_state]
    ret
