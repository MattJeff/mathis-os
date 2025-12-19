; ════════════════════════════════════════════════════════════════════════════
; QUEUE.ASM - Lock-Free Event Queue (Ring Buffer)
; ════════════════════════════════════════════════════════════════════════════
; SOLID Phase 5: Thread-safe event queue
;
; Design principles:
;   - Single Responsibility: Only manages event storage/retrieval
;   - Lock-free for ISR safety (single producer, single consumer)
;   - Fixed-size ring buffer (no allocation needed)
;   - Cache-line aligned for performance
;
; Usage:
;   - ISRs call evt_queue_push() to add events
;   - Main loop calls evt_queue_pop() to process events
;   - No locking needed (SPSC - Single Producer Single Consumer)
;
; ════════════════════════════════════════════════════════════════════════════

[BITS 64]

; ════════════════════════════════════════════════════════════════════════════
; QUEUE CONSTANTS
; ════════════════════════════════════════════════════════════════════════════

EVT_QUEUE_CAPACITY  equ 64          ; Number of events (power of 2!)
EVT_QUEUE_MASK      equ (EVT_QUEUE_CAPACITY - 1)
EVT_QUEUE_SIZE      equ (EVT_QUEUE_CAPACITY * EVENT_SIZE)

; ════════════════════════════════════════════════════════════════════════════
; QUEUE STRUCTURE
; ════════════════════════════════════════════════════════════════════════════
; The queue uses head/tail indices:
;   - head: next slot to write (producer advances)
;   - tail: next slot to read (consumer advances)
;   - empty when head == tail
;   - full when (head + 1) % capacity == tail
;
; ════════════════════════════════════════════════════════════════════════════

; ════════════════════════════════════════════════════════════════════════════
; EVT_QUEUE_INIT - Initialize the event queue
; ════════════════════════════════════════════════════════════════════════════
evt_queue_init:
    push rax
    push rcx
    push rdi

    ; Reset indices
    mov dword [evt_queue_head], 0
    mov dword [evt_queue_tail], 0

    ; Clear queue buffer
    lea rdi, [evt_queue_buffer]
    mov rcx, EVT_QUEUE_SIZE / 8
    xor eax, eax
    rep stosq

    ; Reset statistics
    mov dword [evt_queue_pushed], 0
    mov dword [evt_queue_popped], 0
    mov dword [evt_queue_dropped], 0

    ; Mark as initialized
    mov byte [evt_queue_ready], 1

    pop rdi
    pop rcx
    pop rax
    ret

; ════════════════════════════════════════════════════════════════════════════
; EVT_QUEUE_PUSH - Add event to queue (called from ISR)
; Input:  RDI = pointer to event to copy into queue
; Output: EAX = 1 if success, 0 if queue full
; Note:   Safe to call from ISR (no locks)
; ════════════════════════════════════════════════════════════════════════════
evt_queue_push:
    push rbx
    push rcx
    push rsi
    push rdi

    ; Check if initialized
    cmp byte [evt_queue_ready], 1
    jne .fail

    ; Calculate next head position
    mov eax, [evt_queue_head]
    mov ebx, eax
    inc ebx
    and ebx, EVT_QUEUE_MASK         ; Wrap around

    ; Check if queue is full (next_head == tail)
    cmp ebx, [evt_queue_tail]
    je .full

    ; Calculate destination address: buffer + (head * EVENT_SIZE)
    mov ecx, eax                    ; head index
    shl ecx, 5                      ; * 32 (EVENT_SIZE)
    lea rsi, [evt_queue_buffer]
    add rsi, rcx                    ; RSI = destination slot

    ; Copy event (32 bytes = 4 qwords)
    mov rcx, [rdi]
    mov [rsi], rcx
    mov rcx, [rdi + 8]
    mov [rsi + 8], rcx
    mov rcx, [rdi + 16]
    mov [rsi + 16], rcx
    mov rcx, [rdi + 24]
    mov [rsi + 24], rcx

    ; Memory barrier (ensure write is visible before updating head)
    mfence

    ; Update head (atomic on x86)
    mov [evt_queue_head], ebx

    ; Update stats
    inc dword [evt_queue_pushed]

    mov eax, 1
    jmp .done

.full:
    inc dword [evt_queue_dropped]
.fail:
    xor eax, eax

.done:
    pop rdi
    pop rsi
    pop rcx
    pop rbx
    ret

; ════════════════════════════════════════════════════════════════════════════
; EVT_QUEUE_POP - Remove event from queue
; Input:  RDI = pointer to buffer to copy event into
; Output: EAX = 1 if event retrieved, 0 if queue empty
; ════════════════════════════════════════════════════════════════════════════
evt_queue_pop:
    push rbx
    push rcx
    push rsi

    ; Check if initialized
    cmp byte [evt_queue_ready], 1
    jne .empty

    ; Check if queue is empty (head == tail)
    mov eax, [evt_queue_head]
    cmp eax, [evt_queue_tail]
    je .empty

    ; Calculate source address: buffer + (tail * EVENT_SIZE)
    mov eax, [evt_queue_tail]
    mov ecx, eax
    shl ecx, 5                      ; * 32 (EVENT_SIZE)
    lea rsi, [evt_queue_buffer]
    add rsi, rcx                    ; RSI = source slot

    ; Copy event (32 bytes = 4 qwords)
    mov rcx, [rsi]
    mov [rdi], rcx
    mov rcx, [rsi + 8]
    mov [rdi + 8], rcx
    mov rcx, [rsi + 16]
    mov [rdi + 16], rcx
    mov rcx, [rsi + 24]
    mov [rdi + 24], rcx

    ; Memory barrier (ensure read is complete before updating tail)
    mfence

    ; Update tail (advance to next slot)
    inc eax
    and eax, EVT_QUEUE_MASK
    mov [evt_queue_tail], eax

    ; Update stats
    inc dword [evt_queue_popped]

    mov eax, 1
    jmp .done

.empty:
    xor eax, eax

.done:
    pop rsi
    pop rcx
    pop rbx
    ret

; ════════════════════════════════════════════════════════════════════════════
; EVT_QUEUE_PEEK - Look at next event without removing it
; Input:  RDI = pointer to buffer to copy event into
; Output: EAX = 1 if event exists, 0 if queue empty
; ════════════════════════════════════════════════════════════════════════════
evt_queue_peek:
    push rbx
    push rcx
    push rsi

    ; Check if initialized
    cmp byte [evt_queue_ready], 1
    jne .empty

    ; Check if queue is empty
    mov eax, [evt_queue_head]
    cmp eax, [evt_queue_tail]
    je .empty

    ; Calculate source address
    mov eax, [evt_queue_tail]
    mov ecx, eax
    shl ecx, 5
    lea rsi, [evt_queue_buffer]
    add rsi, rcx

    ; Copy event (don't update tail)
    mov rcx, [rsi]
    mov [rdi], rcx
    mov rcx, [rsi + 8]
    mov [rdi + 8], rcx
    mov rcx, [rsi + 16]
    mov [rdi + 16], rcx
    mov rcx, [rsi + 24]
    mov [rdi + 24], rcx

    mov eax, 1
    jmp .done

.empty:
    xor eax, eax

.done:
    pop rsi
    pop rcx
    pop rbx
    ret

; ════════════════════════════════════════════════════════════════════════════
; EVT_QUEUE_IS_EMPTY - Check if queue is empty
; Output: EAX = 1 if empty, 0 if has events
; ════════════════════════════════════════════════════════════════════════════
evt_queue_is_empty:
    mov eax, [evt_queue_head]
    cmp eax, [evt_queue_tail]
    je .empty
    xor eax, eax
    ret
.empty:
    mov eax, 1
    ret

; ════════════════════════════════════════════════════════════════════════════
; EVT_QUEUE_COUNT - Get number of events in queue
; Output: EAX = number of pending events
; ════════════════════════════════════════════════════════════════════════════
evt_queue_count:
    mov eax, [evt_queue_head]
    sub eax, [evt_queue_tail]
    and eax, EVT_QUEUE_MASK
    ret

; ════════════════════════════════════════════════════════════════════════════
; EVT_QUEUE_CLEAR - Clear all events from queue
; ════════════════════════════════════════════════════════════════════════════
evt_queue_clear:
    mov eax, [evt_queue_head]
    mov [evt_queue_tail], eax       ; Set tail = head (empty)
    ret

; ════════════════════════════════════════════════════════════════════════════
; EVT_QUEUE_GET_STATS - Get queue statistics
; Input:  RDI = pointer to stats buffer (16 bytes)
;         +0: pushed (4 bytes)
;         +4: popped (4 bytes)
;         +8: dropped (4 bytes)
;         +12: current count (4 bytes)
; ════════════════════════════════════════════════════════════════════════════
evt_queue_get_stats:
    push rax

    mov eax, [evt_queue_pushed]
    mov [rdi], eax
    mov eax, [evt_queue_popped]
    mov [rdi + 4], eax
    mov eax, [evt_queue_dropped]
    mov [rdi + 8], eax

    ; Calculate current count
    mov eax, [evt_queue_head]
    sub eax, [evt_queue_tail]
    and eax, EVT_QUEUE_MASK
    mov [rdi + 12], eax

    pop rax
    ret

; ════════════════════════════════════════════════════════════════════════════
; QUEUE DATA
; ════════════════════════════════════════════════════════════════════════════
align 64                            ; Cache-line alignment

evt_queue_ready:    db 0
align 4
evt_queue_head:     dd 0            ; Write index (producer)
evt_queue_tail:     dd 0            ; Read index (consumer)

; Statistics
evt_queue_pushed:   dd 0            ; Total events pushed
evt_queue_popped:   dd 0            ; Total events popped
evt_queue_dropped:  dd 0            ; Events dropped (queue full)

align 64                            ; Cache-line align the buffer
evt_queue_buffer:   times EVT_QUEUE_SIZE db 0
