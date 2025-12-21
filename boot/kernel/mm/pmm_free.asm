; ============================================================================
; PMM_FREE.ASM - Physical Frame Deallocation
; ============================================================================
; Single Responsibility: Free physical memory frames
; Depends: pmm_const.asm, pmm_bitmap.asm
; ============================================================================

[BITS 64]

; pmm_free_count defined in pmm_init.asm (same compilation unit via %include)

section .text

; ============================================================================
; PMM_FREE_FRAME - Free a single physical frame
; ============================================================================
; Input:  RDI = physical address (must be page-aligned)
; Output: None
; Preserves: RBX, R12-R15
; ============================================================================
pmm_free_frame:
    push rax
    push rdi

    ; Convert physical address to frame index
    shr rdi, PAGE_SHIFT

    ; Check bounds
    mov rax, PMM_BITMAP_SIZE
    shl rax, 3                           ; Total frames
    cmp rdi, rax
    jge .done                            ; Out of range

    ; Check if already free (avoid double-free)
    call pmm_bitmap_test
    test al, al
    jz .done                             ; Already free

    ; Mark as free
    call pmm_bitmap_clear
    inc qword [pmm_free_count]

.done:
    pop rdi
    pop rax
    ret

; ============================================================================
; PMM_FREE_PAGES - Free multiple contiguous frames
; ============================================================================
; Input:  RDI = base physical address (page-aligned)
;         ESI = number of pages to free
; Output: None
; ============================================================================
pmm_free_pages:
    push r12
    push r13

    ; Convert to frame index
    mov r12, rdi
    shr r12, PAGE_SHIFT
    mov r13d, esi                        ; Zero-extends automatically

.loop:
    test r13d, r13d
    jz .done

    mov rdi, r12
    shl rdi, PAGE_SHIFT                  ; Back to physical address
    call pmm_free_frame

    inc r12
    dec r13d
    jmp .loop

.done:
    pop r13
    pop r12
    ret
