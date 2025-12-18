; ════════════════════════════════════════════════════════════════════════════
; ALLOC_SVC.ASM - Allocator Service Implementation
; ════════════════════════════════════════════════════════════════════════════
; Wraps mm/heap.asm as a service for the registry
; ════════════════════════════════════════════════════════════════════════════

; ════════════════════════════════════════════════════════════════════════════
; ALLOC SERVICE V-TABLE
; ════════════════════════════════════════════════════════════════════════════
alloc_svc_vtable:
    dq kmalloc              ; Offset 0:  malloc(size) -> ptr
    dq kfree                ; Offset 8:  free(ptr)
    dq krealloc             ; Offset 16: realloc(ptr, size) -> ptr
    dq kcalloc              ; Offset 24: calloc(count, size) -> ptr

; ════════════════════════════════════════════════════════════════════════════
; ALLOC_SVC_INIT - Register allocator service
; Call this after heap_init and registry_init
; ════════════════════════════════════════════════════════════════════════════
alloc_svc_init:
    push rdi
    push rsi

    mov edi, SVC_ALLOC
    lea rsi, [alloc_svc_vtable]
    call register_service

    pop rsi
    pop rdi
    ret
