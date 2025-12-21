; ============================================================================
; PMM_ALLOC.ASM - Physical Frame Allocation
; ============================================================================
; Single Responsibility: Allocate physical memory frames
; Depends: pmm_const.asm, pmm_bitmap.asm
; ============================================================================

[BITS 64]

; pmm_free_count defined in pmm_init.asm (same compilation unit via %include)

section .text

; ============================================================================
; PMM_ALLOC_FRAME - Allocate a single physical frame
; ============================================================================
; Output: RAX = physical address (page-aligned), 0 if out of memory
; Preserves: RBX, R12-R15
; ============================================================================
pmm_alloc_frame:
    push rcx
    push rdx
    push rdi

    ; Check if any free pages
    cmp qword [pmm_free_count], 0
    je .out_of_memory

    ; Scan bitmap for first free bit
    mov rdi, PMM_BITMAP_ADDR
    mov rcx, PMM_BITMAP_SIZE / 8

.search_qword:
    mov rax, [rdi]
    cmp rax, 0xFFFFFFFFFFFFFFFF         ; All bits used?
    jne .found_free_qword
    add rdi, 8
    dec rcx
    jnz .search_qword

.out_of_memory:
    xor eax, eax
    jmp .done

.found_free_qword:
    ; Calculate base frame index from qword offset
    mov rdx, rdi
    sub rdx, PMM_BITMAP_ADDR
    shl rdx, 3                           ; QWord index * 8 = bit offset base

    ; Find first clear bit in qword
    xor ecx, ecx
.find_bit:
    bt rax, rcx
    jnc .got_bit
    inc ecx
    cmp ecx, BITS_PER_QWORD
    jl .find_bit
    jmp .out_of_memory                   ; Should not happen

.got_bit:
    ; Mark frame as used
    bts qword [rdi], rcx

    ; Calculate physical address
    add rdx, rcx                         ; Frame index
    shl rdx, PAGE_SHIFT                  ; Physical address
    mov rax, rdx

    ; Decrement free count
    dec qword [pmm_free_count]

.done:
    pop rdi
    pop rdx
    pop rcx
    ret

; ============================================================================
; PMM_ALLOC_PAGES - Allocate multiple contiguous frames
; ============================================================================
; Input:  EDI = number of pages to allocate
; Output: RAX = base physical address, 0 if failed
; Note: Simple implementation - finds first fit
; ============================================================================
pmm_alloc_pages:
    push rbx
    push r12
    push r13
    push r14

    mov r12d, edi                        ; Page count needed (zero-extends)
    test r12d, r12d
    jz .fail

    ; Single page? Use simpler path
    cmp r12d, 1
    je .single_page

    ; Scan for contiguous free region
    xor r13d, r13d                       ; Current frame index
    mov r14d, PMM_BITMAP_SIZE
    shl r14d, 3                          ; Total bits

.scan_start:
    cmp r13d, r14d
    jge .fail

    ; Check if r12 pages starting at r13 are free
    mov ebx, r12d                        ; Pages to check
    mov rdi, r13                         ; Start frame

.check_range:
    call pmm_bitmap_test
    test al, al
    jnz .range_not_free

    inc rdi
    dec ebx
    jnz .check_range

    ; Found contiguous region - mark all as used
    mov rdi, r13
    mov rsi, r12
    call pmm_mark_range_used

    ; Return base address
    mov rax, r13
    shl rax, PAGE_SHIFT
    jmp .done

.range_not_free:
    inc r13d
    jmp .scan_start

.single_page:
    call pmm_alloc_frame
    jmp .done

.fail:
    xor eax, eax

.done:
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; ============================================================================
; PMM_MARK_RANGE_USED - Helper to mark range as used
; ============================================================================
; Input: RDI = start frame, RSI = count
; ============================================================================
pmm_mark_range_used:
    push rdi
    push rsi

.loop:
    test rsi, rsi
    jz .done
    call pmm_bitmap_set
    dec qword [pmm_free_count]
    inc rdi
    dec rsi
    jmp .loop

.done:
    pop rsi
    pop rdi
    ret

; ============================================================================
; PMM_GET_FREE_COUNT - Get number of free frames
; ============================================================================
; Output: RAX = free frame count
; ============================================================================
pmm_get_free_count:
    mov rax, [pmm_free_count]
    ret
