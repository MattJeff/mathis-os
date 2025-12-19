; ════════════════════════════════════════════════════════════════════════════
; FS_EVENTS.ASM - Filesystem Event System (SOLID - Observer Pattern)
; ════════════════════════════════════════════════════════════════════════════
; Allows other modules (desktop, files_app, etc.) to react to filesystem
; changes without tight coupling.
;
; Usage:
;   ; Register a listener
;   lea rdi, [my_callback]
;   call fs_add_listener
;
;   ; Listener callback signature:
;   ; Input: EDI = event type, RSI = path (null-terminated)
;   my_callback:
;       cmp edi, FS_EVT_CREATE
;       je .handle_create
;       ...
;       ret
;
; ════════════════════════════════════════════════════════════════════════════

[BITS 64]

; ════════════════════════════════════════════════════════════════════════════
; EVENT TYPES
; ════════════════════════════════════════════════════════════════════════════
FS_EVT_CREATE       equ 1       ; File or directory created
FS_EVT_DELETE       equ 2       ; File or directory deleted
FS_EVT_RENAME       equ 3       ; File or directory renamed
FS_EVT_MODIFY       equ 4       ; File content modified
FS_EVT_MKDIR        equ 5       ; Directory created (specific)

FS_MAX_LISTENERS    equ 8       ; Max registered listeners

; ════════════════════════════════════════════════════════════════════════════
; FS_EVENTS_INIT - Initialize event system
; ════════════════════════════════════════════════════════════════════════════
fs_events_init:
    push rdi
    push rcx
    push rax

    ; Clear listener table
    lea rdi, [fs_listeners]
    mov ecx, FS_MAX_LISTENERS
    xor eax, eax
.clear_loop:
    mov [rdi], rax
    add rdi, 8
    dec ecx
    jnz .clear_loop

    mov byte [fs_listener_count], 0

    pop rax
    pop rcx
    pop rdi
    ret

; ════════════════════════════════════════════════════════════════════════════
; FS_ADD_LISTENER - Register a callback for filesystem events
; ════════════════════════════════════════════════════════════════════════════
; Input:  RDI = callback function pointer
; Output: EAX = 1 on success, 0 if table full
; ════════════════════════════════════════════════════════════════════════════
fs_add_listener:
    push rbx
    push rcx

    ; Check if table is full
    movzx ecx, byte [fs_listener_count]
    cmp ecx, FS_MAX_LISTENERS
    jge .listener_full

    ; Add listener to table
    lea rbx, [fs_listeners]
    shl ecx, 3                      ; * 8 (pointer size)
    mov [rbx + rcx], rdi

    ; Increment count
    inc byte [fs_listener_count]

    mov eax, 1
    jmp .add_done

.listener_full:
    xor eax, eax

.add_done:
    pop rcx
    pop rbx
    ret

; ════════════════════════════════════════════════════════════════════════════
; FS_REMOVE_LISTENER - Unregister a callback
; ════════════════════════════════════════════════════════════════════════════
; Input:  RDI = callback function pointer to remove
; Output: EAX = 1 if removed, 0 if not found
; ════════════════════════════════════════════════════════════════════════════
fs_remove_listener:
    push rbx
    push rcx
    push rdx

    movzx ecx, byte [fs_listener_count]
    test ecx, ecx
    jz .not_found

    lea rbx, [fs_listeners]
    xor edx, edx                    ; index

.find_loop:
    cmp edx, ecx
    jge .not_found

    mov rax, [rbx + rdx*8]
    cmp rax, rdi
    je .found

    inc edx
    jmp .find_loop

.found:
    ; Shift remaining entries down
    mov eax, ecx
    dec eax                         ; last index

.shift_loop:
    cmp edx, eax
    jge .shift_done

    ; Copy next entry to current
    mov rax, [rbx + rdx*8 + 8]
    mov [rbx + rdx*8], rax
    inc edx
    jmp .shift_loop

.shift_done:
    ; Clear last entry and decrement count
    mov qword [rbx + rdx*8], 0
    dec byte [fs_listener_count]

    mov eax, 1
    jmp .remove_done

.not_found:
    xor eax, eax

.remove_done:
    pop rdx
    pop rcx
    pop rbx
    ret

; ════════════════════════════════════════════════════════════════════════════
; FS_DISPATCH_EVENT - Notify all listeners of a filesystem event
; ════════════════════════════════════════════════════════════════════════════
; Input:  EDI = event type (FS_EVT_*)
;         RSI = path (null-terminated)
; ════════════════════════════════════════════════════════════════════════════
fs_dispatch_event:
    push rbx
    push rcx
    push rdx
    push rdi
    push rsi
    push r12
    push r13

    mov r12d, edi                   ; r12 = event type
    mov r13, rsi                    ; r13 = path

    movzx ecx, byte [fs_listener_count]
    test ecx, ecx
    jz .dispatch_done

    lea rbx, [fs_listeners]
    xor edx, edx                    ; index

.notify_loop:
    cmp edx, ecx
    jge .dispatch_done

    mov rax, [rbx + rdx*8]
    test rax, rax
    jz .next_listener

    ; Call listener: EDI = event type, RSI = path
    push rcx
    push rdx
    mov edi, r12d
    mov rsi, r13
    call rax
    pop rdx
    pop rcx

.next_listener:
    inc edx
    jmp .notify_loop

.dispatch_done:
    pop r13
    pop r12
    pop rsi
    pop rdi
    pop rdx
    pop rcx
    pop rbx
    ret

; ════════════════════════════════════════════════════════════════════════════
; DATA
; ════════════════════════════════════════════════════════════════════════════
fs_listener_count:  db 0
align 8
fs_listeners:       times FS_MAX_LISTENERS dq 0
