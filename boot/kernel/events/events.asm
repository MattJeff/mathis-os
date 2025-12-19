; ════════════════════════════════════════════════════════════════════════════
; EVENTS.ASM - Event System Main Module
; ════════════════════════════════════════════════════════════════════════════
; SOLID Phase 5: Complete event-driven architecture
;
; This is the main entry point for the event system.
; Include this file to get access to all event functionality.
;
; Architecture:
;   ┌─────────────┐     ┌─────────────┐     ┌─────────────┐
;   │   ISR       │────▶│   Queue     │────▶│  Dispatch   │────▶ Handlers
;   │ (producer)  │     │ (ring buf)  │     │  (router)   │
;   └─────────────┘     └─────────────┘     └─────────────┘
;
; Usage:
;   1. Call evt_system_init() at startup
;   2. Register handlers with evt_register_handler(type, handler_fn)
;   3. ISRs call evt_post_*() to queue events
;   4. Main loop calls evt_process() to dispatch events
;
; ════════════════════════════════════════════════════════════════════════════

[BITS 64]

; Include sub-modules
%include "events/event.asm"
%include "events/queue.asm"
%include "events/dispatch.asm"

; ════════════════════════════════════════════════════════════════════════════
; EVT_SYSTEM_INIT - Initialize the complete event system
; ════════════════════════════════════════════════════════════════════════════
evt_system_init:
    push rax

    ; Initialize queue
    call evt_queue_init

    ; Initialize dispatcher
    call evt_dispatch_init

    ; Mark system as ready
    mov byte [evt_system_ready], 1

    pop rax
    ret

; ════════════════════════════════════════════════════════════════════════════
; EVT_PROCESS - Process all pending events (call from main loop)
; Output: EAX = number of events processed
; ════════════════════════════════════════════════════════════════════════════
evt_process:
    cmp byte [evt_system_ready], 1
    jne .not_ready

    call evt_dispatch_all
    ret

.not_ready:
    xor eax, eax
    ret

; ════════════════════════════════════════════════════════════════════════════
; EVT_PROCESS_ONE - Process one event if available (for cooperative dispatch)
; Output: EAX = 1 if event processed, 0 if none
; ════════════════════════════════════════════════════════════════════════════
evt_process_one:
    cmp byte [evt_system_ready], 1
    jne .not_ready

    call evt_dispatch_one
    ret

.not_ready:
    xor eax, eax
    ret

; ════════════════════════════════════════════════════════════════════════════
; HIGH-LEVEL EVENT POSTING FUNCTIONS
; These create and queue events from ISRs
; ════════════════════════════════════════════════════════════════════════════

; ────────────────────────────────────────────────────────────────────────────
; EVT_POST_KEY_DOWN - Post a key down event
; Input:  DIL = scancode, SIL = ASCII char, DL = modifiers
; Output: EAX = 1 if queued, 0 if failed
; ────────────────────────────────────────────────────────────────────────────
evt_post_key_down:
    push rbx
    push rcx
    push rdi
    push rsi
    push rdx

    ; Save parameters
    movzx ebx, dil              ; scancode
    movzx ecx, sil              ; ASCII
    movzx eax, dl               ; modifiers
    push rax                    ; save modifiers

    ; Allocate event on stack
    sub rsp, EVENT_SIZE

    ; Initialize event
    mov rdi, rsp
    mov esi, EVT_KEY_DOWN
    call event_init

    ; Fill key data
    mov byte [rsp + EVT_DATA + KEVT_SCANCODE], bl
    mov byte [rsp + EVT_DATA + KEVT_ASCII], cl
    pop rax                     ; restore modifiers
    mov byte [rsp + EVT_DATA + KEVT_MODIFIERS], al

    ; Queue event
    mov rdi, rsp
    call evt_queue_push

    ; Clean up
    add rsp, EVENT_SIZE

    pop rdx
    pop rsi
    pop rdi
    pop rcx
    pop rbx
    ret

; ────────────────────────────────────────────────────────────────────────────
; EVT_POST_KEY_UP - Post a key up event
; Input:  DIL = scancode
; Output: EAX = 1 if queued, 0 if failed
; ────────────────────────────────────────────────────────────────────────────
evt_post_key_up:
    push rbx
    push rdi

    movzx ebx, dil              ; scancode

    ; Allocate event on stack
    sub rsp, EVENT_SIZE

    ; Initialize event
    mov rdi, rsp
    mov esi, EVT_KEY_UP
    call event_init

    ; Fill key data
    mov byte [rsp + EVT_DATA + KEVT_SCANCODE], bl

    ; Queue event
    mov rdi, rsp
    call evt_queue_push

    ; Clean up
    add rsp, EVENT_SIZE

    pop rdi
    pop rbx
    ret

; ────────────────────────────────────────────────────────────────────────────
; EVT_POST_MOUSE_MOVE - Post a mouse move event
; Input:  DI = X position, SI = Y position, DX = delta_x, CX = delta_y
; Output: EAX = 1 if queued, 0 if failed
; ────────────────────────────────────────────────────────────────────────────
evt_post_mouse_move:
    push rbx
    push r8
    push r9
    push r10
    push r11
    push rdi

    ; Save parameters
    mov r8w, di                 ; X
    mov r9w, si                 ; Y
    mov r10w, dx                ; delta_x
    mov r11w, cx                ; delta_y

    ; Allocate event on stack
    sub rsp, EVENT_SIZE

    ; Initialize event
    mov rdi, rsp
    mov esi, EVT_MOUSE_MOVE
    call event_init

    ; Fill mouse data
    mov word [rsp + EVT_DATA + MEVT_X], r8w
    mov word [rsp + EVT_DATA + MEVT_Y], r9w
    mov word [rsp + EVT_DATA + MEVT_DELTA_X], r10w
    mov word [rsp + EVT_DATA + MEVT_DELTA_Y], r11w

    ; Queue event
    mov rdi, rsp
    call evt_queue_push

    ; Clean up
    add rsp, EVENT_SIZE

    pop rdi
    pop r11
    pop r10
    pop r9
    pop r8
    pop rbx
    ret

; ────────────────────────────────────────────────────────────────────────────
; EVT_POST_MOUSE_DOWN - Post a mouse button down event
; Input:  DI = X position, SI = Y position, DL = button (MBTN_*)
; Output: EAX = 1 if queued, 0 if failed
; ────────────────────────────────────────────────────────────────────────────
evt_post_mouse_down:
    push rbx
    push r8
    push r9
    push rdi

    ; Save parameters
    mov r8w, di                 ; X
    mov r9w, si                 ; Y
    movzx ebx, dl               ; button

    ; Allocate event on stack
    sub rsp, EVENT_SIZE

    ; Initialize event
    mov rdi, rsp
    mov esi, EVT_MOUSE_DOWN
    call event_init

    ; Fill mouse data
    mov word [rsp + EVT_DATA + MEVT_X], r8w
    mov word [rsp + EVT_DATA + MEVT_Y], r9w
    mov byte [rsp + EVT_DATA + MEVT_BUTTON], bl

    ; Queue event
    mov rdi, rsp
    call evt_queue_push

    ; Clean up
    add rsp, EVENT_SIZE

    pop rdi
    pop r9
    pop r8
    pop rbx
    ret

; ────────────────────────────────────────────────────────────────────────────
; EVT_POST_MOUSE_UP - Post a mouse button up event
; Input:  DI = X position, SI = Y position, DL = button (MBTN_*)
; Output: EAX = 1 if queued, 0 if failed
; ────────────────────────────────────────────────────────────────────────────
evt_post_mouse_up:
    push rbx
    push r8
    push r9
    push rdi

    ; Save parameters
    mov r8w, di                 ; X
    mov r9w, si                 ; Y
    movzx ebx, dl               ; button

    ; Allocate event on stack
    sub rsp, EVENT_SIZE

    ; Initialize event
    mov rdi, rsp
    mov esi, EVT_MOUSE_UP
    call event_init

    ; Fill mouse data
    mov word [rsp + EVT_DATA + MEVT_X], r8w
    mov word [rsp + EVT_DATA + MEVT_Y], r9w
    mov byte [rsp + EVT_DATA + MEVT_BUTTON], bl

    ; Queue event
    mov rdi, rsp
    call evt_queue_push

    ; Clean up
    add rsp, EVENT_SIZE

    pop rdi
    pop r9
    pop r8
    pop rbx
    ret

; ────────────────────────────────────────────────────────────────────────────
; EVT_POST_MOUSE_SCROLL - Post a mouse scroll event
; Input:  DI = X position, SI = Y position, EDX = scroll delta (signed)
; Output: EAX = 1 if queued, 0 if failed
; ────────────────────────────────────────────────────────────────────────────
evt_post_mouse_scroll:
    push rbx
    push r8
    push r9
    push rdi

    ; Save parameters
    mov r8w, di                 ; X
    mov r9w, si                 ; Y
    mov ebx, edx                ; scroll delta

    ; Allocate event on stack
    sub rsp, EVENT_SIZE

    ; Initialize event
    mov rdi, rsp
    mov esi, EVT_MOUSE_SCROLL
    call event_init

    ; Fill mouse data
    mov word [rsp + EVT_DATA + MEVT_X], r8w
    mov word [rsp + EVT_DATA + MEVT_Y], r9w
    mov dword [rsp + EVT_DATA + MEVT_SCROLL], ebx

    ; Queue event
    mov rdi, rsp
    call evt_queue_push

    ; Clean up
    add rsp, EVENT_SIZE

    pop rdi
    pop r9
    pop r8
    pop rbx
    ret

; ════════════════════════════════════════════════════════════════════════════
; SYSTEM STATE
; ════════════════════════════════════════════════════════════════════════════
align 8
evt_system_ready:   db 0
