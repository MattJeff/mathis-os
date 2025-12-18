; ════════════════════════════════════════════════════════════════════════════
; HEAP.ASM - Dynamic Memory Allocator (malloc/free/realloc)
; Free-list allocator with first-fit strategy and coalescing
; ════════════════════════════════════════════════════════════════════════════
;
; Block Structure:
;   +0:  size (8 bytes) - includes header, low bit = FREE flag
;   +8:  prev (8 bytes) - previous free block (only when free)
;   +16: next (8 bytes) - next free block (only when free)
;   +24: data...        - user data starts here
;
; Minimum block size: 32 bytes (header + prev + next pointers)
; Alignment: 16 bytes (for SSE compatibility)
;
; ════════════════════════════════════════════════════════════════════════════

; Heap constants
HEAP_START          equ 0x400000        ; 4MB - heap starts here
HEAP_SIZE           equ 0x1000000       ; 16MB initial heap
HEAP_END            equ HEAP_START + HEAP_SIZE

BLOCK_HEADER_SIZE   equ 8               ; Size field only
BLOCK_MIN_SIZE      equ 32              ; Minimum block including header
BLOCK_ALIGNMENT     equ 16              ; 16-byte alignment

; Block flags (stored in low bits of size)
BLOCK_FREE          equ 1               ; Block is free
BLOCK_SIZE_MASK     equ ~0xF            ; Mask to get size (aligned)

; ════════════════════════════════════════════════════════════════════════════
; HEAP_INIT - Initialize the heap
; ════════════════════════════════════════════════════════════════════════════
heap_init:
    push rax
    push rbx
    push rcx
    push rdi

    ; Create initial free block spanning entire heap
    mov rdi, HEAP_START

    ; Set size with FREE flag
    mov rax, HEAP_SIZE
    or rax, BLOCK_FREE
    mov [rdi], rax                      ; Block size + free flag

    ; Set prev/next to null (single block in free list)
    mov qword [rdi + 8], 0              ; prev = null
    mov qword [rdi + 16], 0             ; next = null

    ; Set free list head
    mov qword [heap_free_list], rdi

    ; Initialize statistics
    mov qword [heap_total_size], HEAP_SIZE
    mov qword [heap_used_size], 0
    mov dword [heap_alloc_count], 0
    mov dword [heap_free_count], 0

    ; Set initialized flag
    mov byte [heap_initialized], 1

    pop rdi
    pop rcx
    pop rbx
    pop rax
    ret

; ════════════════════════════════════════════════════════════════════════════
; MALLOC - Allocate memory block
; Input: RDI = size in bytes
; Output: RAX = pointer to allocated memory (or 0 on failure)
; ════════════════════════════════════════════════════════════════════════════
malloc:
    push rbx
    push rcx
    push rdx
    push rsi
    push rdi
    push r8
    push r9

    ; Check if heap initialized
    cmp byte [heap_initialized], 0
    je .malloc_fail

    ; Calculate actual size needed (header + data, aligned)
    add rdi, BLOCK_HEADER_SIZE          ; Add header size
    add rdi, BLOCK_ALIGNMENT - 1        ; Round up
    and rdi, ~(BLOCK_ALIGNMENT - 1)     ; Align

    ; Minimum size
    cmp rdi, BLOCK_MIN_SIZE
    jge .size_ok
    mov rdi, BLOCK_MIN_SIZE

.size_ok:
    ; Search free list (first-fit)
    mov rbx, [heap_free_list]

.search_loop:
    test rbx, rbx
    jz .malloc_fail                     ; No suitable block found

    ; Get block size (mask out flags)
    mov rax, [rbx]
    and rax, BLOCK_SIZE_MASK

    ; Check if block is large enough
    cmp rax, rdi
    jge .found_block

    ; Try next block
    mov rbx, [rbx + 16]                 ; next pointer
    jmp .search_loop

.found_block:
    ; RBX = suitable free block
    ; RAX = block size
    ; RDI = required size

    ; Check if we should split the block
    mov rcx, rax
    sub rcx, rdi                        ; Remaining size
    cmp rcx, BLOCK_MIN_SIZE
    jl .no_split

    ; Split block: create new free block after allocated portion
    mov r8, rbx
    add r8, rdi                         ; New block address

    ; Set up new free block
    mov rax, rcx
    or rax, BLOCK_FREE
    mov [r8], rax                       ; Size + free flag

    ; Copy prev/next from original block
    mov rax, [rbx + 8]                  ; Original prev
    mov [r8 + 8], rax
    mov rax, [rbx + 16]                 ; Original next
    mov [r8 + 16], rax

    ; Update adjacent blocks to point to new block
    mov rax, [r8 + 8]                   ; prev
    test rax, rax
    jz .update_head
    mov [rax + 16], r8                  ; prev->next = new block
    jmp .update_next

.update_head:
    mov [heap_free_list], r8            ; Update free list head

.update_next:
    mov rax, [r8 + 16]                  ; next
    test rax, rax
    jz .split_done
    mov [rax + 8], r8                   ; next->prev = new block

.split_done:
    ; Update allocated block size
    mov qword [rbx], rdi                ; Size without free flag = allocated
    jmp .alloc_done

.no_split:
    ; Use entire block - remove from free list
    mov rdi, rax                        ; Save full block size

    ; Get prev and next
    mov r8, [rbx + 8]                   ; prev
    mov r9, [rbx + 16]                  ; next

    ; Update prev->next
    test r8, r8
    jz .remove_head
    mov [r8 + 16], r9
    jmp .remove_next

.remove_head:
    mov [heap_free_list], r9

.remove_next:
    ; Update next->prev
    test r9, r9
    jz .remove_done
    mov [r9 + 8], r8

.remove_done:
    ; Mark as allocated (clear free flag)
    mov [rbx], rdi

.alloc_done:
    ; Return pointer to user data (after header)
    lea rax, [rbx + BLOCK_HEADER_SIZE]

    ; Update statistics
    mov rcx, [rbx]
    and rcx, BLOCK_SIZE_MASK
    add [heap_used_size], rcx
    inc dword [heap_alloc_count]

    jmp .malloc_exit

.malloc_fail:
    xor eax, eax

.malloc_exit:
    pop r9
    pop r8
    pop rdi
    pop rsi
    pop rdx
    pop rcx
    pop rbx
    ret

; ════════════════════════════════════════════════════════════════════════════
; FREE - Free allocated memory block
; Input: RDI = pointer to memory (returned by malloc)
; ════════════════════════════════════════════════════════════════════════════
free:
    push rax
    push rbx
    push rcx
    push rdx
    push rsi
    push r8
    push r9

    ; Validate pointer
    test rdi, rdi
    jz .free_done

    ; Get block header
    sub rdi, BLOCK_HEADER_SIZE          ; RDI = block start

    ; Validate block is in heap range
    cmp rdi, HEAP_START
    jb .free_done
    cmp rdi, HEAP_END
    jae .free_done

    ; Check if already free
    mov rax, [rdi]
    test rax, BLOCK_FREE
    jnz .free_done                      ; Already free!

    ; Get block size
    mov rcx, rax
    and rcx, BLOCK_SIZE_MASK

    ; Update statistics
    sub [heap_used_size], rcx
    inc dword [heap_free_count]

    ; Mark block as free
    or rax, BLOCK_FREE
    mov [rdi], rax

    ; Add to free list (at head for simplicity)
    mov rax, [heap_free_list]
    mov [rdi + 8], qword 0              ; prev = null
    mov [rdi + 16], rax                 ; next = old head

    ; Update old head's prev
    test rax, rax
    jz .set_head
    mov [rax + 8], rdi

.set_head:
    mov [heap_free_list], rdi

    ; Try to coalesce with adjacent blocks
    call heap_coalesce

.free_done:
    pop r9
    pop r8
    pop rsi
    pop rdx
    pop rcx
    pop rbx
    pop rax
    ret

; ════════════════════════════════════════════════════════════════════════════
; REALLOC - Resize allocated memory block
; Input: RDI = pointer to memory, RSI = new size
; Output: RAX = new pointer (may be different), or 0 on failure
; ════════════════════════════════════════════════════════════════════════════
realloc:
    push rbx
    push rcx
    push rdx
    push rdi
    push rsi
    push r8

    ; Handle special cases
    test rdi, rdi
    jz .realloc_malloc                  ; realloc(NULL, size) = malloc(size)

    test rsi, rsi
    jz .realloc_free                    ; realloc(ptr, 0) = free(ptr)

    ; Get current block
    mov r8, rdi                         ; Save original pointer
    sub rdi, BLOCK_HEADER_SIZE
    mov rcx, [rdi]
    and rcx, BLOCK_SIZE_MASK            ; Current block size
    sub rcx, BLOCK_HEADER_SIZE          ; Usable size

    ; If new size fits in current block, just return
    cmp rsi, rcx
    jle .realloc_inplace

    ; Need to allocate new block
    push r8                             ; Save old pointer
    push rcx                            ; Save old size
    mov rdi, rsi
    call malloc
    pop rcx
    pop r8

    test rax, rax
    jz .realloc_fail

    ; Copy old data to new block
    push rax
    mov rdi, rax                        ; Destination
    mov rsi, r8                         ; Source
    ; RCX still has old usable size
    rep movsb
    pop rax

    ; Free old block
    mov rdi, r8
    push rax
    call free
    pop rax

    jmp .realloc_done

.realloc_inplace:
    mov rax, r8                         ; Return original pointer
    jmp .realloc_done

.realloc_malloc:
    mov rdi, rsi
    call malloc
    jmp .realloc_done

.realloc_free:
    call free
    xor eax, eax
    jmp .realloc_done

.realloc_fail:
    xor eax, eax

.realloc_done:
    pop r8
    pop rsi
    pop rdi
    pop rdx
    pop rcx
    pop rbx
    ret

; ════════════════════════════════════════════════════════════════════════════
; CALLOC - Allocate and zero memory
; Input: RDI = count, RSI = element size
; Output: RAX = pointer to zeroed memory, or 0 on failure
; ════════════════════════════════════════════════════════════════════════════
calloc:
    push rbx
    push rcx
    push rdi

    ; Calculate total size
    imul rdi, rsi

    ; Allocate
    mov rbx, rdi                        ; Save size
    call malloc
    test rax, rax
    jz .calloc_done

    ; Zero the memory
    push rax
    mov rdi, rax
    xor eax, eax
    mov rcx, rbx
    rep stosb
    pop rax

.calloc_done:
    pop rdi
    pop rcx
    pop rbx
    ret

; ════════════════════════════════════════════════════════════════════════════
; HEAP_COALESCE - Merge adjacent free blocks
; ════════════════════════════════════════════════════════════════════════════
heap_coalesce:
    push rax
    push rbx
    push rcx
    push rdx
    push rsi
    push rdi
    push r8
    push r9

    ; Simple coalescing: scan all blocks and merge adjacent free ones
    mov rdi, HEAP_START

.coalesce_loop:
    ; Check if we're past heap end
    cmp rdi, HEAP_END
    jae .coalesce_done

    ; Get current block size
    mov rax, [rdi]
    mov rcx, rax
    and rcx, BLOCK_SIZE_MASK

    ; Check if block is free
    test rax, BLOCK_FREE
    jz .next_block

    ; Check next block
    mov rbx, rdi
    add rbx, rcx                        ; Next block address

    cmp rbx, HEAP_END
    jae .next_block

    ; Get next block info
    mov rdx, [rbx]
    test rdx, BLOCK_FREE
    jz .next_block                      ; Next block not free

    ; Merge blocks!
    mov rsi, rdx
    and rsi, BLOCK_SIZE_MASK            ; Next block size

    ; Remove next block from free list
    mov r8, [rbx + 8]                   ; next->prev
    mov r9, [rbx + 16]                  ; next->next

    test r8, r8
    jz .merge_update_head
    mov [r8 + 16], r9
    jmp .merge_update_next

.merge_update_head:
    ; If next block was head, current block becomes head
    cmp [heap_free_list], rbx
    jne .merge_update_next
    mov [heap_free_list], rdi

.merge_update_next:
    test r9, r9
    jz .merge_done_links
    mov [r9 + 8], r8

.merge_done_links:
    ; Update current block size (add next block size)
    add rcx, rsi
    or rcx, BLOCK_FREE
    mov [rdi], rcx

    ; Don't advance - check if we can merge more
    jmp .coalesce_loop

.next_block:
    ; Move to next block
    add rdi, rcx
    jmp .coalesce_loop

.coalesce_done:
    pop r9
    pop r8
    pop rdi
    pop rsi
    pop rdx
    pop rcx
    pop rbx
    pop rax
    ret

; ════════════════════════════════════════════════════════════════════════════
; HEAP_GET_STATS - Get heap statistics
; Input: RDI = pointer to stats buffer (32 bytes)
;   +0:  total_size (8 bytes)
;   +8:  used_size (8 bytes)
;   +16: alloc_count (4 bytes)
;   +20: free_count (4 bytes)
;   +24: free_blocks (4 bytes)
;   +28: largest_free (4 bytes)
; ════════════════════════════════════════════════════════════════════════════
heap_get_stats:
    push rax
    push rbx
    push rcx
    push rdx

    ; Copy basic stats
    mov rax, [heap_total_size]
    mov [rdi], rax
    mov rax, [heap_used_size]
    mov [rdi + 8], rax
    mov eax, [heap_alloc_count]
    mov [rdi + 16], eax
    mov eax, [heap_free_count]
    mov [rdi + 20], eax

    ; Count free blocks and find largest
    xor ecx, ecx                        ; Block count
    xor edx, edx                        ; Largest size
    mov rbx, [heap_free_list]

.count_loop:
    test rbx, rbx
    jz .count_done

    inc ecx

    mov rax, [rbx]
    and rax, BLOCK_SIZE_MASK
    cmp eax, edx
    jle .not_larger
    mov edx, eax

.not_larger:
    mov rbx, [rbx + 16]                 ; next
    jmp .count_loop

.count_done:
    mov [rdi + 24], ecx
    mov [rdi + 28], edx

    pop rdx
    pop rcx
    pop rbx
    pop rax
    ret

; ════════════════════════════════════════════════════════════════════════════
; HEAP_DEBUG_DUMP - Print heap info (debug)
; ════════════════════════════════════════════════════════════════════════════
heap_debug_dump:
    ; This would print debug info - stub for now
    ret

; ════════════════════════════════════════════════════════════════════════════
; HEAP DATA SECTION
; ════════════════════════════════════════════════════════════════════════════
align 8

; Heap state
heap_initialized:   db 0
align 8
heap_free_list:     dq 0                ; Head of free block list
heap_total_size:    dq 0                ; Total heap size
heap_used_size:     dq 0                ; Currently allocated

; Statistics
heap_alloc_count:   dd 0                ; Number of allocations
heap_free_count:    dd 0                ; Number of frees

; ════════════════════════════════════════════════════════════════════════════
; KERNEL API ALIASES (kmalloc/kfree)
; ════════════════════════════════════════════════════════════════════════════
kmalloc:    jmp malloc
kfree:      jmp free
krealloc:   jmp realloc
kcalloc:    jmp calloc
