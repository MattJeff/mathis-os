; ============================================================================
; PAGE_FAULT.ASM - Page Fault Handler (#PF, INT 0x0E)
; ============================================================================
; CR2 contains the faulting address
; Error code bits:
;   Bit 0 (P): 0=non-present, 1=protection violation
;   Bit 1 (W): 0=read, 1=write
;   Bit 2 (U): 0=supervisor, 1=user
;   Bit 3 (RSVD): reserved bit set in page table
;   Bit 4 (I): instruction fetch
; ============================================================================

[BITS 64]

; Uses constants from vmm_const.asm (included before this file)

; ============================================================================
; PAGE FAULT ERROR CODE FLAGS
; ============================================================================
PF_ERR_PRESENT      equ (1 << 0)
PF_ERR_WRITE        equ (1 << 1)
PF_ERR_USER         equ (1 << 2)
PF_ERR_RSVD         equ (1 << 3)
PF_ERR_IFETCH       equ (1 << 4)

; ============================================================================
; HEAP BOUNDARIES (for demand paging validation)
; ============================================================================
HEAP_START_ADDR     equ 0x400000
HEAP_END_ADDR       equ 0x1400000

section .data
pf_fault_addr:      dq 0
pf_error_code:      dq 0
pf_count:           dq 0                ; Page fault counter

section .text

; ============================================================================
; PAGE_FAULT_HANDLER - Main page fault handler
; ============================================================================
; Called from IDT entry for INT 0x0E
; Stack: [error_code] [RIP] [CS] [RFLAGS] [RSP] [SS]
; ============================================================================
page_fault_handler:
    push rax
    push rbx
    push rcx
    push rdx
    push rsi
    push rdi

    ; Get faulting address from CR2
    mov rax, cr2
    mov [pf_fault_addr], rax
    mov rdi, rax

    ; Get error code
    mov rsi, [rsp + 48]                  ; After 6 pushes (6*8=48)
    mov [pf_error_code], rsi

    ; Increment fault counter
    inc qword [pf_count]

    ; Check if this is a non-present page
    test rsi, PF_ERR_PRESENT
    jnz .protection_fault

    ; Validate address is in heap range
    cmp rdi, HEAP_START_ADDR
    jb .fatal
    cmp rdi, HEAP_END_ADDR
    jae .fatal

    ; Demand paging: allocate and map page
    call pf_demand_page
    test eax, eax
    jnz .fatal

    jmp .done

.protection_fault:
    ; Protection violation - check for COW (future)
    ; For now, treat as fatal
    jmp .fatal

.fatal:
    ; Cannot recover - jump to BSOD
    pop rdi
    pop rsi
    pop rdx
    pop rcx
    pop rbx
    pop rax

    push qword 14                        ; Exception number
    jmp exc_common

.done:
    pop rdi
    pop rsi
    pop rdx
    pop rcx
    pop rbx
    pop rax
    add rsp, 8                           ; Remove error code
    iretq

; ============================================================================
; PF_DEMAND_PAGE - Handle demand paging
; ============================================================================
; Input: RDI = faulting address
; Output: EAX = 0 on success, -1 on failure
; ============================================================================
pf_demand_page:
    push rbx
    push rsi
    push rdx

    ; Page-align address
    mov rbx, rdi
    and rbx, ~(PAGE_SIZE - 1)

    ; Allocate physical page
    call pmm_alloc_page
    test rax, rax
    jz .fail

    ; Map the new page
    mov rdi, rbx                         ; Virtual address
    mov rsi, rax                         ; Physical address
    mov rdx, PTE_USER_RW                 ; User read/write
    call vmm_map_page
    test eax, eax
    jnz .fail

    ; Zero the new page
    mov rdi, rbx
    mov rcx, PAGE_SIZE / 8
    xor rax, rax
    rep stosq

    xor eax, eax
    jmp .done

.fail:
    mov eax, -1

.done:
    pop rdx
    pop rsi
    pop rbx
    ret
