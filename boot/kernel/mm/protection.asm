; ============================================================================
; PROTECTION.ASM - Memory Protection Setup
; ============================================================================
; Configures user/kernel space separation
; Kernel: entries 256-511 in PML4 (upper half)
; User:   entries 0-255 in PML4 (lower half)
; ============================================================================

[BITS 64]

; Uses constants from vmm_const.asm (included before this file)

; ============================================================================
; PML4 ENTRY RANGES
; ============================================================================
PML4_USER_START     equ 0               ; Entries 0-255 = user space
PML4_USER_END       equ 256
PML4_KERNEL_START   equ 256             ; Entries 256-511 = kernel space
PML4_KERNEL_END     equ 512

section .text

; ============================================================================
; PROTECTION_INIT - Setup memory protection
; ============================================================================
; Removes U bit from kernel space entries in PML4
; ============================================================================
protection_init:
    push rax
    push rbx
    push rcx

    mov rax, cr3

    ; Remove USER flag from kernel half (entries 256-511)
    lea rbx, [rax + PML4_KERNEL_START * 8]
    mov ecx, PML4_KERNEL_END - PML4_KERNEL_START

.loop:
    mov rax, [rbx]
    test rax, PTE_PRESENT
    jz .next

    ; Clear USER bit
    and rax, ~PTE_USER
    mov [rbx], rax

.next:
    add rbx, 8
    dec ecx
    jnz .loop

    ; Reload CR3 to flush TLB
    mov rax, cr3
    mov cr3, rax

    pop rcx
    pop rbx
    pop rax
    ret

; ============================================================================
; CHECK_USER_BUFFER - Verify buffer is in user space
; ============================================================================
; Input:  RDI = buffer address
;         RSI = buffer length
; Output: RAX = 1 if valid user buffer, 0 if in kernel space
; ============================================================================
check_user_buffer:
    push rbx

    ; Check start address
    mov rax, USER_SPACE_END
    cmp rdi, rax
    ja .invalid

    ; Check end address (no overflow)
    lea rbx, [rdi + rsi]
    jc .invalid                          ; Overflow
    cmp rbx, rax
    ja .invalid

    mov eax, 1
    jmp .done

.invalid:
    xor eax, eax

.done:
    pop rbx
    ret

; ============================================================================
; CHECK_USER_STRING - Verify string pointer is in user space
; ============================================================================
; Input:  RDI = string pointer
; Output: RAX = 1 if valid, 0 if invalid
; ============================================================================
check_user_string:
    mov rax, USER_SPACE_END
    cmp rdi, rax
    ja .invalid

    mov eax, 1
    ret

.invalid:
    xor eax, eax
    ret

; ============================================================================
; COPY_FROM_USER - Safe copy from user buffer
; ============================================================================
; Input:  RDI = kernel destination
;         RSI = user source
;         RDX = length
; Output: RAX = bytes copied, 0 on failure
; ============================================================================
copy_from_user:
    push rcx
    push rdi
    push rsi

    ; Validate user buffer
    mov rcx, rdx                         ; Save length
    mov rdi, rsi                         ; Check user source
    mov rsi, rdx
    call check_user_buffer
    test eax, eax
    jz .fail

    ; Restore and copy
    pop rsi
    pop rdi
    push rdi
    push rsi

    mov rcx, rdx
    rep movsb

    mov rax, rdx                         ; Return bytes copied
    jmp .done

.fail:
    xor eax, eax

.done:
    add rsp, 16                          ; Cleanup saved regs
    pop rcx
    ret

; ============================================================================
; COPY_TO_USER - Safe copy to user buffer
; ============================================================================
; Input:  RDI = user destination
;         RSI = kernel source
;         RDX = length
; Output: RAX = bytes copied, 0 on failure
; ============================================================================
copy_to_user:
    push rcx
    push rdi
    push rsi

    ; Validate user buffer
    mov rcx, rdx
    mov rsi, rdx
    call check_user_buffer
    test eax, eax
    jz .fail

    ; Restore and copy
    pop rsi
    pop rdi
    push rdi
    push rsi

    mov rcx, rdx
    rep movsb

    mov rax, rdx
    jmp .done

.fail:
    xor eax, eax

.done:
    add rsp, 16
    pop rcx
    ret
