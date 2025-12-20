; ════════════════════════════════════════════════════════════════════════════
; VFS_NOTIFY.ASM - Change notification system
; ════════════════════════════════════════════════════════════════════════════
; Notifies all listeners when directory changes
; ════════════════════════════════════════════════════════════════════════════

[BITS 64]

; ════════════════════════════════════════════════════════════════════════════
; LISTENER SLOTS (max 4)
; ════════════════════════════════════════════════════════════════════════════
VFS_MAX_LISTENERS   equ 4
vfs_listeners:      times VFS_MAX_LISTENERS dq 0
vfs_listener_count: dd 0

; ════════════════════════════════════════════════════════════════════════════
; VFS_REGISTER - Register a change listener
; Input: RDI = callback function pointer
; Output: EAX = 1 success, 0 fail
; ════════════════════════════════════════════════════════════════════════════
vfs_register:
    push rbx

    mov eax, [vfs_listener_count]
    cmp eax, VFS_MAX_LISTENERS
    jge .fail

    lea rbx, [vfs_listeners]
    mov [rbx + rax*8], rdi
    inc dword [vfs_listener_count]

    mov eax, 1
    jmp .done

.fail:
    xor eax, eax

.done:
    pop rbx
    ret

; ════════════════════════════════════════════════════════════════════════════
; VFS_UNREGISTER - Remove a listener
; Input: RDI = callback to remove
; ════════════════════════════════════════════════════════════════════════════
vfs_unregister:
    push rbx
    push rcx

    xor ecx, ecx
    mov eax, [vfs_listener_count]

.search:
    cmp ecx, eax
    jge .done

    lea rbx, [vfs_listeners]
    cmp [rbx + rcx*8], rdi
    jne .next

    ; Found - shift remaining
    mov eax, [vfs_listener_count]
    dec eax
.shift:
    cmp ecx, eax
    jge .shift_done
    mov rbx, [vfs_listeners + rcx*8 + 8]
    mov [vfs_listeners + rcx*8], rbx
    inc ecx
    jmp .shift

.shift_done:
    dec dword [vfs_listener_count]
    jmp .done

.next:
    inc ecx
    jmp .search

.done:
    pop rcx
    pop rbx
    ret

; ════════════════════════════════════════════════════════════════════════════
; VFS_NOTIFY_CHANGE - Notify all listeners of directory change
; ════════════════════════════════════════════════════════════════════════════
vfs_notify_change:
    push rax
    push rbx
    push rcx
    push rdi

    xor ecx, ecx
    mov eax, [vfs_listener_count]

.notify_loop:
    cmp ecx, eax
    jge .done

    lea rbx, [vfs_listeners]
    mov rbx, [rbx + rcx*8]
    test rbx, rbx
    jz .next

    ; Call listener
    push rax
    push rcx
    call rbx
    pop rcx
    pop rax

.next:
    inc ecx
    jmp .notify_loop

.done:
    pop rdi
    pop rcx
    pop rbx
    pop rax
    ret
