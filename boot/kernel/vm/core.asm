; ════════════════════════════════════════════════════════════════════════════
; MATHIS VM - CORE MODULE
; Main loop and opcode dispatch
; ════════════════════════════════════════════════════════════════════════════
; Uses GLOBAL labels (vm_*) to avoid conflicts with includes
; ════════════════════════════════════════════════════════════════════════════

VM_STACK    equ 0x25000
VM_HEAP     equ 0x26000

vm_run:
    push eax
    push ebx
    push ecx
    push edx
    push esi
    push edi
    push ebp
    
    call vga_newline
    mov esi, msg_vm_running
    mov ah, 0x0D
    call vga_print_line
    
    ; Initialize VM
    mov esi, 0x20000        ; Bytecode at 0x20000
    mov ebp, VM_STACK       ; Stack pointer
    mov edi, VM_HEAP        ; Heap pointer
    
    ; Check magic "MASM"
    cmp dword [esi], 0x4D53414D
    jne vm_error
    
    ; Skip 64-byte header
    add esi, 0x40

; ════════════════════════════════════════════════════════════════════════════
; MAIN VM LOOP - Global label for jumps from all modules
; ════════════════════════════════════════════════════════════════════════════
vm_loop:
    movzx eax, byte [esi]
    inc esi
    
    ; Control
    cmp al, 0x00
    je vm_loop              ; NOP
    cmp al, 0x01
    je vm_done              ; HALT
    cmp al, 0x68
    je vm_done              ; RET
    
    ; Constants (0x17-0x19)
    cmp al, 0x17
    je vm_op_const_small
    cmp al, 0x18
    je vm_op_const_int
    
    ; Math (0x30-0x35)
    cmp al, 0x30
    je vm_op_add
    cmp al, 0x31
    je vm_op_sub
    cmp al, 0x32
    je vm_op_mul
    cmp al, 0x33
    je vm_op_div
    
    ; Stack (0x50-0x54)
    cmp al, 0x50
    je vm_op_dup
    cmp al, 0x51
    je vm_op_pop
    cmp al, 0x52
    je vm_op_swap
    
    ; I/O (0xC3-0xC6)
    cmp al, 0xC3
    je vm_op_print_int
    
    ; Unknown - skip
    jmp vm_loop

; ════════════════════════════════════════════════════════════════════════════
; INCLUDE MODULES (all use global vm_* labels)
; ════════════════════════════════════════════════════════════════════════════
%include "vm/math.asm"
%include "vm/stack.asm"
%include "vm/io.asm"

; ════════════════════════════════════════════════════════════════════════════
; VM END HANDLERS
; ════════════════════════════════════════════════════════════════════════════
vm_done:
    call vga_newline
    mov esi, msg_vm_done
    mov ah, 0x0A
    call vga_print_line
    
    call vga_newline
    mov esi, msg_result
    mov ah, 0x0E
    call vga_print_line
    
    mov eax, [ebp]
    call vm_print_number
    jmp vm_exit

vm_error:
    call vga_newline
    mov esi, msg_vm_error
    mov ah, 0x0C
    call vga_print_line

vm_exit:
    pop ebp
    pop edi
    pop esi
    pop edx
    pop ecx
    pop ebx
    pop eax
    ret

; ════════════════════════════════════════════════════════════════════════════
; VM PRINT NUMBER
; ════════════════════════════════════════════════════════════════════════════
vm_print_number:
    push eax
    push ebx
    push ecx
    push edx
    push edi
    
    mov ebx, [prompt_line]
    imul ebx, 160
    add ebx, 0xB8000
    add ebx, 16
    mov edi, ebx
    
    test eax, eax
    jns vm_print_positive
    neg eax
    push eax
    mov al, '-'
    mov ah, 0x0F
    stosw
    pop eax
vm_print_positive:
    mov ecx, 0
    mov ebx, 10
vm_print_div:
    xor edx, edx
    div ebx
    push edx
    inc ecx
    test eax, eax
    jnz vm_print_div

vm_print_digits:
    pop eax
    add al, '0'
    mov ah, 0x0F
    stosw
    loop vm_print_digits
    
    pop edi
    pop edx
    pop ecx
    pop ebx
    pop eax
    ret
