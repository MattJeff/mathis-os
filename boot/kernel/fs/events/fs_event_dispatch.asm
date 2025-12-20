; ════════════════════════════════════════════════════════════════════════════
; FS_EVENT_DISPATCH.ASM - Event creation and dispatching
; ════════════════════════════════════════════════════════════════════════════

[BITS 64]

; ════════════════════════════════════════════════════════════════════════════
; TEMPORARY EVENT BUFFER
; ════════════════════════════════════════════════════════════════════════════
fs_evt_temp:        times FS_EVT_SIZE db 0

; ════════════════════════════════════════════════════════════════════════════
; LISTENER CALLBACKS (max 4 listeners)
; ════════════════════════════════════════════════════════════════════════════
FS_EVT_MAX_LISTENERS equ 4
fs_evt_listeners:   times FS_EVT_MAX_LISTENERS dq 0
fs_evt_listener_count: dd 0

; ════════════════════════════════════════════════════════════════════════════
; FS_EVT_REGISTER - Register a listener callback
; Input:  RDI = callback function pointer (receives RDI = event ptr)
; Output: EAX = 1 if success, 0 if max listeners reached
; ════════════════════════════════════════════════════════════════════════════
fs_evt_register:
    push rbx

    mov eax, [fs_evt_listener_count]
    cmp eax, FS_EVT_MAX_LISTENERS
    jge .full

    ; Add listener
    lea rbx, [fs_evt_listeners]
    mov [rbx + rax*8], rdi
    inc dword [fs_evt_listener_count]

    mov eax, 1
    jmp .done

.full:
    xor eax, eax

.done:
    pop rbx
    ret

; ════════════════════════════════════════════════════════════════════════════
; FS_EVT_UNREGISTER - Remove a listener callback
; Input:  RDI = callback function pointer to remove
; Output: EAX = 1 if found and removed, 0 if not found
; ════════════════════════════════════════════════════════════════════════════
fs_evt_unregister:
    push rbx
    push rcx

    xor ecx, ecx                    ; Index
    mov eax, [fs_evt_listener_count]
    test eax, eax
    jz .not_found

.search:
    cmp ecx, eax
    jge .not_found

    lea rbx, [fs_evt_listeners]
    cmp [rbx + rcx*8], rdi
    je .found

    inc ecx
    jmp .search

.found:
    ; Shift remaining listeners down
    mov eax, [fs_evt_listener_count]
    dec eax
.shift:
    cmp ecx, eax
    jge .shift_done
    mov rbx, [fs_evt_listeners + rcx*8 + 8]
    mov [fs_evt_listeners + rcx*8], rbx
    inc ecx
    jmp .shift

.shift_done:
    dec dword [fs_evt_listener_count]
    mov eax, 1
    jmp .done

.not_found:
    xor eax, eax

.done:
    pop rcx
    pop rbx
    ret

; ════════════════════════════════════════════════════════════════════════════
; FS_EVT_EMIT - Create and dispatch an event
; Input:  DIL = event type, SIL = flags, RDX = path ptr, RCX = extra ptr
; ════════════════════════════════════════════════════════════════════════════
fs_evt_emit:
    push rax
    push rbx
    push rcx
    push rdx
    push rsi
    push rdi
    push r12
    push r13

    ; Build event in temp buffer
    lea rbx, [fs_evt_temp]

    ; Clear buffer
    push rdi
    mov rdi, rbx
    xor eax, eax
    mov ecx, FS_EVT_SIZE
    rep stosb
    pop rdi

    ; Set type and flags
    mov [rbx + FS_EVT_TYPE], dil
    mov [rbx + FS_EVT_FLAGS], sil

    ; Copy path (if provided)
    test rdx, rdx
    jz .no_path
    push rcx
    lea rdi, [rbx + FS_EVT_PATH]
    mov rsi, rdx
    mov ecx, FS_EVT_PATH_LEN - 1
.copy_path:
    lodsb
    test al, al
    jz .path_done
    stosb
    dec ecx
    jnz .copy_path
.path_done:
    mov byte [rdi], 0
    pop rcx
.no_path:

    ; Copy extra (if provided)
    test rcx, rcx
    jz .no_extra
    lea rdi, [rbx + FS_EVT_EXTRA]
    mov rsi, rcx
    mov ecx, FS_EVT_EXTRA_LEN - 1
.copy_extra:
    lodsb
    test al, al
    jz .extra_done
    stosb
    dec ecx
    jnz .copy_extra
.extra_done:
    mov byte [rdi], 0
.no_extra:

    ; Push to queue
    mov rdi, rbx
    call fs_evt_push

    ; Notify all listeners
    xor r12d, r12d                  ; Index
    mov r13d, [fs_evt_listener_count]

.notify_loop:
    cmp r12d, r13d
    jge .notify_done

    lea rax, [fs_evt_listeners]
    mov rax, [rax + r12*8]
    test rax, rax
    jz .next_listener

    ; Call listener with event pointer
    mov rdi, rbx
    call rax

.next_listener:
    inc r12d
    jmp .notify_loop

.notify_done:
    pop r13
    pop r12
    pop rdi
    pop rsi
    pop rdx
    pop rcx
    pop rbx
    pop rax
    ret

; ════════════════════════════════════════════════════════════════════════════
; FS_EVT_PROCESS - Process all pending events (call from main loop)
; ════════════════════════════════════════════════════════════════════════════
fs_evt_process:
    push rax
    push rdi

.process_loop:
    ; Check if queue has events
    call fs_evt_get_count
    test eax, eax
    jz .done

    ; Pop and process
    lea rdi, [fs_evt_temp]
    call fs_evt_pop
    test eax, eax
    jz .done

    ; Event already dispatched when emitted, just dequeue
    jmp .process_loop

.done:
    pop rdi
    pop rax
    ret
