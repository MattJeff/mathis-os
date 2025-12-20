; ════════════════════════════════════════════════════════════════════════════
; FS_EVENT_QUEUE.ASM - Circular event queue management
; ════════════════════════════════════════════════════════════════════════════

[BITS 64]

; ════════════════════════════════════════════════════════════════════════════
; QUEUE DATA
; ════════════════════════════════════════════════════════════════════════════
fs_evt_queue:       times (FS_EVT_SIZE * FS_EVT_QUEUE_SIZE) db 0
fs_evt_head:        dd 0            ; Read index
fs_evt_tail:        dd 0            ; Write index
fs_evt_count:       dd 0            ; Current event count

; ════════════════════════════════════════════════════════════════════════════
; FS_EVT_PUSH - Add event to queue
; Input:  RDI = pointer to FS_EVENT structure
; Output: EAX = 1 if success, 0 if queue full
; ════════════════════════════════════════════════════════════════════════════
fs_evt_push:
    push rbx
    push rcx
    push rsi
    push rdi

    ; Check if queue is full
    mov eax, [fs_evt_count]
    cmp eax, FS_EVT_QUEUE_SIZE
    jge .full

    ; Calculate destination: queue + tail * FS_EVT_SIZE
    mov eax, [fs_evt_tail]
    imul eax, FS_EVT_SIZE
    lea rbx, [fs_evt_queue + rax]

    ; Copy event (64 bytes)
    mov rsi, rdi                    ; Source = input event
    mov rdi, rbx                    ; Dest = queue slot
    mov ecx, FS_EVT_SIZE
    rep movsb

    ; Update tail (circular)
    mov eax, [fs_evt_tail]
    inc eax
    cmp eax, FS_EVT_QUEUE_SIZE
    jl .no_wrap_tail
    xor eax, eax
.no_wrap_tail:
    mov [fs_evt_tail], eax

    ; Increment count
    inc dword [fs_evt_count]

    mov eax, 1
    jmp .done

.full:
    xor eax, eax

.done:
    pop rdi
    pop rsi
    pop rcx
    pop rbx
    ret

; ════════════════════════════════════════════════════════════════════════════
; FS_EVT_POP - Remove event from queue
; Input:  RDI = pointer to buffer for FS_EVENT (64 bytes)
; Output: EAX = 1 if success, 0 if queue empty
; ════════════════════════════════════════════════════════════════════════════
fs_evt_pop:
    push rbx
    push rcx
    push rsi
    push rdi

    ; Check if queue is empty
    mov eax, [fs_evt_count]
    test eax, eax
    jz .empty

    ; Calculate source: queue + head * FS_EVT_SIZE
    mov eax, [fs_evt_head]
    imul eax, FS_EVT_SIZE
    lea rsi, [fs_evt_queue + rax]

    ; Copy event (64 bytes)
    mov ecx, FS_EVT_SIZE
    rep movsb

    ; Update head (circular)
    mov eax, [fs_evt_head]
    inc eax
    cmp eax, FS_EVT_QUEUE_SIZE
    jl .no_wrap_head
    xor eax, eax
.no_wrap_head:
    mov [fs_evt_head], eax

    ; Decrement count
    dec dword [fs_evt_count]

    mov eax, 1
    jmp .done

.empty:
    xor eax, eax

.done:
    pop rdi
    pop rsi
    pop rcx
    pop rbx
    ret

; ════════════════════════════════════════════════════════════════════════════
; FS_EVT_PEEK - Look at next event without removing
; Input:  RDI = pointer to buffer for FS_EVENT (64 bytes)
; Output: EAX = 1 if success, 0 if queue empty
; ════════════════════════════════════════════════════════════════════════════
fs_evt_peek:
    push rbx
    push rcx
    push rsi
    push rdi

    ; Check if queue is empty
    mov eax, [fs_evt_count]
    test eax, eax
    jz .empty

    ; Calculate source: queue + head * FS_EVT_SIZE
    mov eax, [fs_evt_head]
    imul eax, FS_EVT_SIZE
    lea rsi, [fs_evt_queue + rax]

    ; Copy event (64 bytes)
    mov ecx, FS_EVT_SIZE
    rep movsb

    mov eax, 1
    jmp .done

.empty:
    xor eax, eax

.done:
    pop rdi
    pop rsi
    pop rcx
    pop rbx
    ret

; ════════════════════════════════════════════════════════════════════════════
; FS_EVT_CLEAR - Clear all events from queue
; ════════════════════════════════════════════════════════════════════════════
fs_evt_clear:
    mov dword [fs_evt_head], 0
    mov dword [fs_evt_tail], 0
    mov dword [fs_evt_count], 0
    ret

; ════════════════════════════════════════════════════════════════════════════
; FS_EVT_COUNT - Get number of events in queue
; Output: EAX = event count
; ════════════════════════════════════════════════════════════════════════════
fs_evt_get_count:
    mov eax, [fs_evt_count]
    ret
