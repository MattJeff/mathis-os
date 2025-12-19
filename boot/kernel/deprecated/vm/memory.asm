; ════════════════════════════════════════════════════════════════════════════
; MATHIS VM - MEMORY MODULE
; Load/Store, locals, globals, heap - Uses global vm_* labels
; ════════════════════════════════════════════════════════════════════════════

VM_LOCALS       equ 0x28000         ; Local variables area (256 slots)
VM_GLOBALS      equ 0x29000         ; Global variables area (256 slots)
VM_HEAP_PTR     equ 0x2A000         ; Heap allocation pointer

vm_op_load:
    ; LOAD: Load from address on stack (addr -- value)
    mov eax, [ebp]
    mov eax, [eax]                  ; dereference
    mov [ebp], eax
    jmp vm_loop

vm_op_store:
    ; STORE: Store value to address (value addr --)
    mov eax, [ebp]                  ; addr
    mov ebx, [ebp + 4]              ; value
    add ebp, 8
    mov [eax], ebx
    jmp vm_loop

vm_op_load_local:
    ; LOAD_LOCAL n: Push local variable n
    movzx eax, byte [esi]
    inc esi
    shl eax, 2                      ; n * 4
    add eax, VM_LOCALS
    mov eax, [eax]
    sub ebp, 4
    mov [ebp], eax
    jmp vm_loop

vm_op_store_local:
    ; STORE_LOCAL n: Pop to local variable n
    movzx eax, byte [esi]
    inc esi
    shl eax, 2
    add eax, VM_LOCALS
    mov ebx, [ebp]
    add ebp, 4
    mov [eax], ebx
    jmp vm_loop

vm_op_load_global:
    ; LOAD_GLOBAL n: Push global variable n
    movzx eax, byte [esi]
    inc esi
    shl eax, 2
    add eax, VM_GLOBALS
    mov eax, [eax]
    sub ebp, 4
    mov [ebp], eax
    jmp vm_loop

vm_op_store_global:
    ; STORE_GLOBAL n: Pop to global variable n
    movzx eax, byte [esi]
    inc esi
    shl eax, 2
    add eax, VM_GLOBALS
    mov ebx, [ebp]
    add ebp, 4
    mov [eax], ebx
    jmp vm_loop

vm_op_alloc:
    ; ALLOC: Allocate n bytes on heap (n -- addr)
    mov eax, [ebp]
    mov ebx, [vm_heap_ptr]
    mov [ebp], ebx                  ; return address
    add ebx, eax                    ; advance heap
    add ebx, 3                      ; align to 4 bytes
    and ebx, ~3
    mov [vm_heap_ptr], ebx
    jmp vm_loop

vm_op_free:
    ; FREE: Free memory (addr --) - No-op for simple allocator
    add ebp, 4                      ; just pop
    jmp vm_loop

; ════════════════════════════════════════════════════════════════════════════
; BYTE/WORD ACCESS
; ════════════════════════════════════════════════════════════════════════════

vm_op_load_byte:
    ; LOADB: Load byte from address (addr -- value)
    mov eax, [ebp]
    movzx eax, byte [eax]
    mov [ebp], eax
    jmp vm_loop

vm_op_store_byte:
    ; STOREB: Store byte (value addr --)
    mov eax, [ebp]                  ; addr
    mov ebx, [ebp + 4]              ; value
    add ebp, 8
    mov [eax], bl
    jmp vm_loop

vm_op_load_word:
    ; LOADW: Load word (16-bit) from address
    mov eax, [ebp]
    movzx eax, word [eax]
    mov [ebp], eax
    jmp vm_loop

vm_op_store_word:
    ; STOREW: Store word (16-bit)
    mov eax, [ebp]                  ; addr
    mov ebx, [ebp + 4]              ; value
    add ebp, 8
    mov [eax], bx
    jmp vm_loop

; ════════════════════════════════════════════════════════════════════════════
; DATA
; ════════════════════════════════════════════════════════════════════════════
vm_heap_ptr:    dd VM_HEAP_PTR + 4  ; Current heap pointer
