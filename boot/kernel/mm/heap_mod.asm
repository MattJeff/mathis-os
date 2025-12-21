; ============================================================================
; HEAP_MOD.ASM - Dynamic Memory Allocator (Modular Version)
; ============================================================================
; Free-list allocator with first-fit strategy and coalescing
; ============================================================================

[BITS 64]
[DEFAULT REL]

; ============================================================================
; CONSTANTS
; ============================================================================
HEAP_START          equ 0x400000
HEAP_SIZE           equ 0x1000000
HEAP_END            equ HEAP_START + HEAP_SIZE

BLOCK_HEADER_SIZE   equ 8
BLOCK_MIN_SIZE      equ 32
BLOCK_ALIGNMENT     equ 16

BLOCK_FREE          equ 1
BLOCK_SIZE_MASK     equ ~0xF

; ============================================================================
; EXPORTS
; ============================================================================
global heap_init
global malloc
global free
global realloc
global calloc
global kmalloc
global kfree
global krealloc
global kcalloc
global heap_get_stats

; ============================================================================
; CODE SECTION
; ============================================================================
section .text

; ============================================================================
; HEAP_INIT - Initialize the heap
; ============================================================================
heap_init:
    push rax
    push rdi

    mov rdi, HEAP_START
    mov rax, HEAP_SIZE
    or rax, BLOCK_FREE
    mov [rdi], rax
    mov qword [rdi + 8], 0
    mov qword [rdi + 16], 0

    mov qword [heap_free_list], rdi
    mov qword [heap_total_size], HEAP_SIZE
    mov qword [heap_used_size], 0
    mov dword [heap_alloc_count], 0
    mov dword [heap_free_count], 0
    mov byte [heap_initialized], 1

    pop rdi
    pop rax
    ret

; ============================================================================
; MALLOC - Allocate memory block
; Input: RDI = size    Output: RAX = pointer or 0
; ============================================================================
malloc:
    push rbx
    push rcx
    push rdx
    push rdi
    push r8
    push r9

    cmp byte [heap_initialized], 0
    je .fail

    add rdi, BLOCK_HEADER_SIZE
    add rdi, BLOCK_ALIGNMENT - 1
    and rdi, ~(BLOCK_ALIGNMENT - 1)

    cmp rdi, BLOCK_MIN_SIZE
    jge .size_ok
    mov rdi, BLOCK_MIN_SIZE
.size_ok:

    mov rbx, [heap_free_list]

.search:
    test rbx, rbx
    jz .fail

    mov rax, [rbx]
    and rax, BLOCK_SIZE_MASK

    cmp rax, rdi
    jge .found

    mov rbx, [rbx + 16]
    jmp .search

.found:
    mov rcx, rax
    sub rcx, rdi
    cmp rcx, BLOCK_MIN_SIZE
    jl .no_split

    ; Split block
    mov r8, rbx
    add r8, rdi

    mov rax, rcx
    or rax, BLOCK_FREE
    mov [r8], rax

    mov rax, [rbx + 8]
    mov [r8 + 8], rax
    mov rax, [rbx + 16]
    mov [r8 + 16], rax

    mov rax, [r8 + 8]
    test rax, rax
    jz .update_head
    mov [rax + 16], r8
    jmp .update_next

.update_head:
    mov [heap_free_list], r8

.update_next:
    mov rax, [r8 + 16]
    test rax, rax
    jz .split_done
    mov [rax + 8], r8

.split_done:
    mov qword [rbx], rdi
    jmp .alloc_done

.no_split:
    mov rdi, rax
    mov r8, [rbx + 8]
    mov r9, [rbx + 16]

    test r8, r8
    jz .remove_head
    mov [r8 + 16], r9
    jmp .remove_next

.remove_head:
    mov [heap_free_list], r9

.remove_next:
    test r9, r9
    jz .remove_done
    mov [r9 + 8], r8

.remove_done:
    mov [rbx], rdi

.alloc_done:
    lea rax, [rbx + BLOCK_HEADER_SIZE]
    mov rcx, [rbx]
    and rcx, BLOCK_SIZE_MASK
    add [heap_used_size], rcx
    inc dword [heap_alloc_count]
    jmp .exit

.fail:
    xor eax, eax

.exit:
    pop r9
    pop r8
    pop rdi
    pop rdx
    pop rcx
    pop rbx
    ret

; ============================================================================
; FREE - Free allocated memory block
; Input: RDI = pointer
; ============================================================================
free:
    push rax
    push rbx
    push rcx
    push r8
    push r9

    test rdi, rdi
    jz .done

    sub rdi, BLOCK_HEADER_SIZE

    cmp rdi, HEAP_START
    jb .done
    cmp rdi, HEAP_END
    jae .done

    mov rax, [rdi]
    test rax, BLOCK_FREE
    jnz .done

    mov rcx, rax
    and rcx, BLOCK_SIZE_MASK
    sub [heap_used_size], rcx
    inc dword [heap_free_count]

    or rax, BLOCK_FREE
    mov [rdi], rax

    mov rax, [heap_free_list]
    mov qword [rdi + 8], 0
    mov [rdi + 16], rax

    test rax, rax
    jz .set_head
    mov [rax + 8], rdi

.set_head:
    mov [heap_free_list], rdi
    call heap_coalesce

.done:
    pop r9
    pop r8
    pop rcx
    pop rbx
    pop rax
    ret

; ============================================================================
; REALLOC - Resize allocated memory block
; ============================================================================
realloc:
    push rbx
    push rcx
    push rdi
    push rsi
    push r8

    test rdi, rdi
    jz .do_malloc

    test rsi, rsi
    jz .do_free

    mov r8, rdi
    sub rdi, BLOCK_HEADER_SIZE
    mov rcx, [rdi]
    and rcx, BLOCK_SIZE_MASK
    sub rcx, BLOCK_HEADER_SIZE

    cmp rsi, rcx
    jle .inplace

    push r8
    push rcx
    mov rdi, rsi
    call malloc
    pop rcx
    pop r8

    test rax, rax
    jz .exit

    push rax
    mov rdi, rax
    mov rsi, r8
    rep movsb
    pop rax

    mov rdi, r8
    push rax
    call free
    pop rax
    jmp .exit

.inplace:
    mov rax, r8
    jmp .exit

.do_malloc:
    mov rdi, rsi
    call malloc
    jmp .exit

.do_free:
    call free
    xor eax, eax

.exit:
    pop r8
    pop rsi
    pop rdi
    pop rcx
    pop rbx
    ret

; ============================================================================
; CALLOC - Allocate and zero memory
; ============================================================================
calloc:
    push rbx
    push rcx
    push rdi

    imul rdi, rsi
    mov rbx, rdi
    call malloc
    test rax, rax
    jz .done

    push rax
    mov rdi, rax
    xor eax, eax
    mov rcx, rbx
    rep stosb
    pop rax

.done:
    pop rdi
    pop rcx
    pop rbx
    ret

; ============================================================================
; HEAP_COALESCE - Merge adjacent free blocks
; ============================================================================
heap_coalesce:
    push rax
    push rbx
    push rcx
    push rdx
    push rdi
    push rsi
    push r8
    push r9

    mov rdi, HEAP_START

.loop:
    cmp rdi, HEAP_END
    jae .done

    mov rax, [rdi]
    mov rcx, rax
    and rcx, BLOCK_SIZE_MASK

    test rax, BLOCK_FREE
    jz .next

    mov rbx, rdi
    add rbx, rcx

    cmp rbx, HEAP_END
    jae .next

    mov rdx, [rbx]
    test rdx, BLOCK_FREE
    jz .next

    mov rsi, rdx
    and rsi, BLOCK_SIZE_MASK

    mov r8, [rbx + 8]
    mov r9, [rbx + 16]

    test r8, r8
    jz .update_head_merge
    mov [r8 + 16], r9
    jmp .update_next_merge

.update_head_merge:
    cmp [heap_free_list], rbx
    jne .update_next_merge
    mov [heap_free_list], rdi

.update_next_merge:
    test r9, r9
    jz .merge_done
    mov [r9 + 8], r8

.merge_done:
    add rcx, rsi
    or rcx, BLOCK_FREE
    mov [rdi], rcx
    jmp .loop

.next:
    add rdi, rcx
    jmp .loop

.done:
    pop r9
    pop r8
    pop rsi
    pop rdi
    pop rdx
    pop rcx
    pop rbx
    pop rax
    ret

; ============================================================================
; HEAP_GET_STATS - Get heap statistics
; ============================================================================
heap_get_stats:
    push rax
    push rbx
    push rcx
    push rdx

    mov rax, [heap_total_size]
    mov [rdi], rax
    mov rax, [heap_used_size]
    mov [rdi + 8], rax
    mov eax, [heap_alloc_count]
    mov [rdi + 16], eax
    mov eax, [heap_free_count]
    mov [rdi + 20], eax

    xor ecx, ecx
    xor edx, edx
    mov rbx, [heap_free_list]

.count:
    test rbx, rbx
    jz .count_done
    inc ecx
    mov rax, [rbx]
    and rax, BLOCK_SIZE_MASK
    cmp eax, edx
    jle .not_larger
    mov edx, eax
.not_larger:
    mov rbx, [rbx + 16]
    jmp .count

.count_done:
    mov [rdi + 24], ecx
    mov [rdi + 28], edx

    pop rdx
    pop rcx
    pop rbx
    pop rax
    ret

; ============================================================================
; KERNEL API ALIASES
; ============================================================================
kmalloc:    jmp malloc
kfree:      jmp free
krealloc:   jmp realloc
kcalloc:    jmp calloc

; ============================================================================
; DATA SECTION
; ============================================================================
section .data

heap_initialized:   db 0
align 8
heap_free_list:     dq 0
heap_total_size:    dq 0
heap_used_size:     dq 0
heap_alloc_count:   dd 0
heap_free_count:    dd 0

; ============================================================================
; BSS SECTION
; ============================================================================
section .bss
