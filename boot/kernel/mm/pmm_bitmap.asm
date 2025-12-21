; ============================================================================
; PMM_BITMAP.ASM - Bitmap Operations for Physical Memory Manager
; ============================================================================
; Single Responsibility: Low-level bitmap bit manipulation
; ============================================================================

[BITS 64]

section .text

; ============================================================================
; PMM_BITMAP_SET - Mark a frame as used
; ============================================================================
; Input:  RDI = frame index (not physical address)
; Output: None
; Clobbers: RAX
; ============================================================================
pmm_bitmap_set:
    push rcx
    push rdx

    ; Calculate qword offset: frame_index / 64
    mov rax, rdi
    shr rax, QWORD_SHIFT
    
    ; Calculate bit position: frame_index % 64
    mov ecx, edi
    and ecx, BIT_MASK
    
    ; Set bit at PMM_BITMAP_ADDR[qword_offset]
    lea rdx, [PMM_BITMAP_ADDR + rax * 8]
    bts qword [rdx], rcx

    pop rdx
    pop rcx
    ret

; ============================================================================
; PMM_BITMAP_CLEAR - Mark a frame as free
; ============================================================================
; Input:  RDI = frame index (not physical address)
; Output: None
; Clobbers: RAX
; ============================================================================
pmm_bitmap_clear:
    push rcx
    push rdx

    ; Calculate qword offset: frame_index / 64
    mov rax, rdi
    shr rax, QWORD_SHIFT
    
    ; Calculate bit position: frame_index % 64
    mov ecx, edi
    and ecx, BIT_MASK
    
    ; Clear bit at PMM_BITMAP_ADDR[qword_offset]
    lea rdx, [PMM_BITMAP_ADDR + rax * 8]
    btr qword [rdx], rcx

    pop rdx
    pop rcx
    ret

; ============================================================================
; PMM_BITMAP_TEST - Test if frame is used
; ============================================================================
; Input:  RDI = frame index (not physical address)
; Output: AL = 1 if used, 0 if free
; Clobbers: RAX
; ============================================================================
pmm_bitmap_test:
    push rcx
    push rdx

    ; Calculate qword offset: frame_index / 64
    mov rax, rdi
    shr rax, QWORD_SHIFT
    
    ; Calculate bit position: frame_index % 64
    mov ecx, edi
    and ecx, BIT_MASK
    
    ; Test bit at PMM_BITMAP_ADDR[qword_offset]
    lea rdx, [PMM_BITMAP_ADDR + rax * 8]
    bt qword [rdx], rcx
    
    ; Set AL based on carry flag
    setc al
    movzx eax, al

    pop rdx
    pop rcx
    ret
