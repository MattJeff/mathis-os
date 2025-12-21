; ============================================================================
; VMM_HELPERS.ASM - Virtual Memory Manager Helper Functions
; ============================================================================
; Helper functions for page table management
; ============================================================================

[BITS 64]

; Uses constants from vmm_const.asm and vmm.asm (included before this file)

section .text

; ============================================================================
; VMM_ENSURE_TABLE - Ensure page table exists at entry
; ============================================================================
; Input:  RDI = pointer to page table entry
; Output: RAX = address of next level table, or 0 on failure
; ============================================================================
vmm_ensure_table:
    push rbx
    push rcx

    mov rax, [rdi]
    test rax, PTE_PRESENT
    jnz .exists

    ; Allocate new page table
    call pmm_alloc_frame
    test rax, rax
    jz .fail

    ; Zero the new table
    mov rbx, rax
    push rdi
    mov rdi, rax
    mov rcx, 512                         ; 512 entries
    xor rax, rax
    rep stosq
    pop rdi
    mov rax, rbx

    ; Store entry with flags
    or rax, PTE_PRESENT | PTE_WRITE | PTE_USER
    mov [rdi], rax

.exists:
    ; Extract table address
    mov rax, [rdi]
    and rax, PTE_ADDR_MASK
    jmp .done

.fail:
    xor eax, eax

.done:
    pop rcx
    pop rbx
    ret

; ============================================================================
; VMM_UNMAP_PAGE - Unmap virtual address
; ============================================================================
; Input: RDI = virtual address
; ============================================================================
vmm_unmap_page:
    push rax
    push rbx
    push rcx

    mov rbx, [vmm_pml4]

    ; Walk to PT entry
    mov rcx, rdi
    shr rcx, VMM_PML4_SHIFT
    and ecx, VMM_INDEX_MASK
    mov rax, [rbx + rcx * 8]
    test rax, PTE_PRESENT
    jz .done
    and rax, PTE_ADDR_MASK

    mov rcx, rdi
    shr rcx, VMM_PDPT_SHIFT
    and ecx, VMM_INDEX_MASK
    mov rax, [rax + rcx * 8]
    test rax, PTE_PRESENT
    jz .done
    and rax, PTE_ADDR_MASK

    mov rcx, rdi
    shr rcx, VMM_PD_SHIFT
    and ecx, VMM_INDEX_MASK
    mov rax, [rax + rcx * 8]
    test rax, PTE_PRESENT
    jz .done
    and rax, PTE_ADDR_MASK

    mov rcx, rdi
    shr rcx, VMM_PT_SHIFT
    and ecx, VMM_INDEX_MASK

    ; Clear PT entry
    mov qword [rax + rcx * 8], 0

    ; Invalidate TLB
    invlpg [rdi]

.done:
    pop rcx
    pop rbx
    pop rax
    ret

; ============================================================================
; VMM_SWITCH_SPACE - Switch to different address space
; ============================================================================
; Input: RDI = new PML4 physical address
; ============================================================================
vmm_switch_space:
    mov [vmm_pml4], rdi
    mov cr3, rdi
    ret

; ============================================================================
; VMM_GET_PHYS - Get physical address for virtual address
; ============================================================================
; Input:  RDI = virtual address
; Output: RAX = physical address, or 0 if not mapped
; ============================================================================
vmm_get_phys:
    push rbx
    push rcx

    mov rbx, [vmm_pml4]

    ; Walk page tables
    mov rcx, rdi
    shr rcx, VMM_PML4_SHIFT
    and ecx, VMM_INDEX_MASK
    mov rax, [rbx + rcx * 8]
    test rax, PTE_PRESENT
    jz .not_mapped
    and rax, PTE_ADDR_MASK

    mov rcx, rdi
    shr rcx, VMM_PDPT_SHIFT
    and ecx, VMM_INDEX_MASK
    mov rax, [rax + rcx * 8]
    test rax, PTE_PRESENT
    jz .not_mapped
    and rax, PTE_ADDR_MASK

    mov rcx, rdi
    shr rcx, VMM_PD_SHIFT
    and ecx, VMM_INDEX_MASK
    mov rax, [rax + rcx * 8]
    test rax, PTE_PRESENT
    jz .not_mapped
    and rax, PTE_ADDR_MASK

    mov rcx, rdi
    shr rcx, VMM_PT_SHIFT
    and ecx, VMM_INDEX_MASK
    mov rax, [rax + rcx * 8]
    test rax, PTE_PRESENT
    jz .not_mapped

    ; Extract physical address and add offset
    and rax, PTE_ADDR_MASK
    mov rcx, rdi
    and ecx, 0xFFF                       ; Page offset
    or rax, rcx
    jmp .done

.not_mapped:
    xor eax, eax

.done:
    pop rcx
    pop rbx
    ret
