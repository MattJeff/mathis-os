; ============================================================================
; VMM.ASM - Virtual Memory Manager
; ============================================================================
; 4-Level paging: PML4 -> PDPT -> PD -> PT -> Page
; ============================================================================

[BITS 64]

; Uses constants from vmm_const.asm (included before this file)

section .text

; ============================================================================
; VMM_INIT - Initialize virtual memory manager
; ============================================================================
vmm_init:
    mov rax, cr3
    mov [vmm_pml4], rax
    ret

; ============================================================================
; VMM_GET_PML4 - Get current PML4 address
; ============================================================================
; Output: RAX = PML4 physical address
; ============================================================================
vmm_get_pml4:
    mov rax, [vmm_pml4]
    ret

; ============================================================================
; VMM_MAP_PAGE - Map virtual address to physical address
; ============================================================================
; Input:  RDI = virtual address
;         RSI = physical address
;         RDX = flags (PTE_PRESENT | PTE_WRITE | ...)
; Output: RAX = 0 on success, -1 on failure
; Preserves: R12-R15, RBX, RBP
; ============================================================================
vmm_map_page:
    push rbx
    push rcx
    push r8
    push r9
    push r10

    mov r8, rdi                          ; Save virtual address
    mov r9, rsi                          ; Save physical address
    mov r10, rdx                         ; Save flags

    ; Get PML4 entry
    mov rax, [vmm_pml4]
    mov rcx, r8
    shr rcx, VMM_PML4_SHIFT
    and ecx, VMM_INDEX_MASK
    lea rbx, [rax + rcx * 8]

    ; Ensure PDPT exists
    mov rdi, rbx
    call vmm_ensure_table
    test rax, rax
    jz .fail

    ; Get PDPT entry
    mov rcx, r8
    shr rcx, VMM_PDPT_SHIFT
    and ecx, VMM_INDEX_MASK
    lea rbx, [rax + rcx * 8]

    ; Ensure PD exists
    mov rdi, rbx
    call vmm_ensure_table
    test rax, rax
    jz .fail

    ; Get PD entry
    mov rcx, r8
    shr rcx, VMM_PD_SHIFT
    and ecx, VMM_INDEX_MASK
    lea rbx, [rax + rcx * 8]

    ; Ensure PT exists
    mov rdi, rbx
    call vmm_ensure_table
    test rax, rax
    jz .fail

    ; Get PT entry and write mapping
    mov rcx, r8
    shr rcx, VMM_PT_SHIFT
    and ecx, VMM_INDEX_MASK
    lea rbx, [rax + rcx * 8]

    ; Create page entry: physical | flags
    mov rax, r9
    and rax, PTE_ADDR_MASK
    or rax, r10
    mov [rbx], rax

    ; Invalidate TLB for this address
    invlpg [r8]

    xor eax, eax                         ; Success
    jmp .done

.fail:
    mov rax, -1

.done:
    pop r10
    pop r9
    pop r8
    pop rcx
    pop rbx
    ret

; ============================================================================
; DATA
; ============================================================================
section .data
vmm_pml4:           dq 0                ; Current PML4 address
