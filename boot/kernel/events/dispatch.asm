; ════════════════════════════════════════════════════════════════════════════
; DISPATCH.ASM - Event Dispatcher
; ════════════════════════════════════════════════════════════════════════════
; SOLID Phase 5: Route events to registered handlers
;
; Design principles:
;   - Single Responsibility: Only routes events to handlers
;   - Open/Closed: New handlers can be registered without modifying dispatcher
;   - Dependency Inversion: Handlers are function pointers, not hardcoded
;
; Architecture:
;   - Handler table: array of function pointers indexed by event type
;   - Default handler: called if no specific handler registered
;   - Chain of responsibility: handlers can mark event as handled
;
; ════════════════════════════════════════════════════════════════════════════

[BITS 64]

; ════════════════════════════════════════════════════════════════════════════
; DISPATCHER CONSTANTS
; ════════════════════════════════════════════════════════════════════════════

EVT_HANDLER_TABLE_SIZE  equ (EVT_TYPE_MAX * 8)  ; 256 qword pointers

; ════════════════════════════════════════════════════════════════════════════
; EVT_DISPATCH_INIT - Initialize the event dispatcher
; ════════════════════════════════════════════════════════════════════════════
evt_dispatch_init:
    push rax
    push rcx
    push rdi

    ; Clear handler table (all NULL)
    lea rdi, [evt_handler_table]
    mov rcx, EVT_TYPE_MAX
    xor eax, eax
    rep stosq

    ; Clear default handler
    mov qword [evt_default_handler], 0

    ; Clear statistics
    mov dword [evt_dispatched_count], 0
    mov dword [evt_unhandled_count], 0

    ; Mark as initialized
    mov byte [evt_dispatch_ready], 1

    pop rdi
    pop rcx
    pop rax
    ret

; ════════════════════════════════════════════════════════════════════════════
; EVT_REGISTER_HANDLER - Register handler for event type
; Input:  EDI = event type (0-255)
;         RSI = handler function pointer (NULL to unregister)
; Output: EAX = 1 if success, 0 if invalid type
; Handler signature: void handler(event_t* event) - RDI = event pointer
; ════════════════════════════════════════════════════════════════════════════
evt_register_handler:
    ; Validate type
    cmp edi, EVT_TYPE_MAX
    jae .fail

    ; Store handler in table
    lea rax, [evt_handler_table]
    mov [rax + rdi * 8], rsi

    mov eax, 1
    ret

.fail:
    xor eax, eax
    ret

; ════════════════════════════════════════════════════════════════════════════
; EVT_SET_DEFAULT_HANDLER - Set default handler for unhandled events
; Input:  RDI = handler function pointer (NULL to clear)
; ════════════════════════════════════════════════════════════════════════════
evt_set_default_handler:
    mov [evt_default_handler], rdi
    ret

; ════════════════════════════════════════════════════════════════════════════
; EVT_DISPATCH - Dispatch a single event to its handler
; Input:  RDI = pointer to event
; Output: EAX = 1 if handled, 0 if no handler found
; ════════════════════════════════════════════════════════════════════════════
evt_dispatch:
    push rbx
    push rcx
    push rdi

    ; Check if initialized
    cmp byte [evt_dispatch_ready], 1
    jne .not_handled

    ; Get event type
    mov eax, [rdi + EVT_TYPE]
    cmp eax, EVT_TYPE_MAX
    jae .try_default

    ; Look up handler in table
    lea rbx, [evt_handler_table]
    mov rcx, [rbx + rax * 8]
    test rcx, rcx
    jz .try_default

    ; Call handler (RDI already contains event pointer)
    call rcx

    ; Update stats
    inc dword [evt_dispatched_count]

    ; Check if handler marked event as handled
    pop rdi
    push rdi
    mov eax, [rdi + EVT_FLAGS]
    and eax, EVF_HANDLED
    jz .handled_implicit      ; Handler didn't mark it, but we still called it

    mov eax, 1
    jmp .done

.handled_implicit:
    mov eax, 1
    jmp .done

.try_default:
    ; Try default handler
    mov rcx, [evt_default_handler]
    test rcx, rcx
    jz .not_handled

    ; Call default handler
    call rcx
    inc dword [evt_dispatched_count]
    mov eax, 1
    jmp .done

.not_handled:
    inc dword [evt_unhandled_count]
    xor eax, eax

.done:
    pop rdi
    pop rcx
    pop rbx
    ret

; ════════════════════════════════════════════════════════════════════════════
; EVT_DISPATCH_ALL - Process all pending events from queue
; Output: EAX = number of events processed
; ════════════════════════════════════════════════════════════════════════════
evt_dispatch_all:
    push rbx
    push rcx
    push rdi

    xor ebx, ebx                ; Event counter

    ; Allocate stack space for event
    sub rsp, EVENT_SIZE
    mov rdi, rsp

.loop:
    ; Try to pop event from queue
    call evt_queue_pop
    test eax, eax
    jz .done                    ; Queue empty

    ; Dispatch the event
    mov rdi, rsp
    call evt_dispatch

    inc ebx
    jmp .loop

.done:
    ; Free stack space
    add rsp, EVENT_SIZE

    mov eax, ebx                ; Return count

    pop rdi
    pop rcx
    pop rbx
    ret

; ════════════════════════════════════════════════════════════════════════════
; EVT_DISPATCH_ONE - Process one event if available
; Output: EAX = 1 if event processed, 0 if queue empty
; ════════════════════════════════════════════════════════════════════════════
evt_dispatch_one:
    push rdi

    ; Allocate stack space for event
    sub rsp, EVENT_SIZE
    mov rdi, rsp

    ; Try to pop event from queue
    call evt_queue_pop
    test eax, eax
    jz .empty

    ; Dispatch the event
    mov rdi, rsp
    call evt_dispatch

    add rsp, EVENT_SIZE
    mov eax, 1
    pop rdi
    ret

.empty:
    add rsp, EVENT_SIZE
    xor eax, eax
    pop rdi
    ret

; ════════════════════════════════════════════════════════════════════════════
; EVT_GET_HANDLER - Get registered handler for event type
; Input:  EDI = event type
; Output: RAX = handler pointer (NULL if none)
; ════════════════════════════════════════════════════════════════════════════
evt_get_handler:
    cmp edi, EVT_TYPE_MAX
    jae .none

    lea rax, [evt_handler_table]
    mov rax, [rax + rdi * 8]
    ret

.none:
    xor eax, eax
    ret

; ════════════════════════════════════════════════════════════════════════════
; EVT_GET_DISPATCH_STATS - Get dispatcher statistics
; Input:  RDI = pointer to stats buffer (8 bytes)
;         +0: dispatched count (4 bytes)
;         +4: unhandled count (4 bytes)
; ════════════════════════════════════════════════════════════════════════════
evt_get_dispatch_stats:
    push rax

    mov eax, [evt_dispatched_count]
    mov [rdi], eax
    mov eax, [evt_unhandled_count]
    mov [rdi + 4], eax

    pop rax
    ret

; ════════════════════════════════════════════════════════════════════════════
; DISPATCHER DATA
; ════════════════════════════════════════════════════════════════════════════
align 8

evt_dispatch_ready:     db 0
align 8
evt_default_handler:    dq 0

; Statistics
evt_dispatched_count:   dd 0
evt_unhandled_count:    dd 0

; Handler table (256 function pointers)
align 64
evt_handler_table:      times EVT_TYPE_MAX dq 0
