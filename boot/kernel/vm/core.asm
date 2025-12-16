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
    
    ; Math (0x30-0x39)
    cmp al, 0x30
    je vm_op_add
    cmp al, 0x31
    je vm_op_sub
    cmp al, 0x32
    je vm_op_mul
    cmp al, 0x33
    je vm_op_div
    cmp al, 0x34
    je vm_op_mod
    cmp al, 0x35
    je vm_op_neg
    cmp al, 0x36
    je vm_op_and
    cmp al, 0x37
    je vm_op_or
    cmp al, 0x38
    je vm_op_xor
    cmp al, 0x39
    je vm_op_not

    ; Comparison (0x40-0x45)
    cmp al, 0x40
    je vm_op_eq
    cmp al, 0x41
    je vm_op_ne
    cmp al, 0x42
    je vm_op_lt
    cmp al, 0x43
    je vm_op_gt
    cmp al, 0x44
    je vm_op_le
    cmp al, 0x45
    je vm_op_ge

    ; Stack (0x50-0x57)
    cmp al, 0x50
    je vm_op_dup
    cmp al, 0x51
    je vm_op_pop
    cmp al, 0x52
    je vm_op_swap
    cmp al, 0x53
    je vm_op_over
    cmp al, 0x54
    je vm_op_rot
    cmp al, 0x55
    je vm_op_pick
    cmp al, 0x56
    je vm_op_roll
    cmp al, 0x57
    je vm_op_depth

    ; Control flow (0x60-0x6F)
    cmp al, 0x60
    je vm_op_jmp
    cmp al, 0x61
    je vm_op_jz
    cmp al, 0x62
    je vm_op_jnz
    cmp al, 0x63
    je vm_op_call
    cmp al, 0x64
    je vm_op_ret
    cmp al, 0x65
    je vm_op_loop

    ; Memory (0x20-0x27)
    cmp al, 0x20
    je vm_op_load
    cmp al, 0x21
    je vm_op_store
    cmp al, 0x22
    je vm_op_load_local
    cmp al, 0x23
    je vm_op_store_local
    cmp al, 0x24
    je vm_op_load_global
    cmp al, 0x25
    je vm_op_store_global
    cmp al, 0x26
    je vm_op_alloc
    cmp al, 0x27
    je vm_op_free

    ; Bitwise (0x70-0x74)
    cmp al, 0x70
    je vm_op_shl
    cmp al, 0x71
    je vm_op_shr
    cmp al, 0x72
    je vm_op_band
    cmp al, 0x73
    je vm_op_bor
    cmp al, 0x74
    je vm_op_bxor
    cmp al, 0x75
    je vm_op_bnot

    ; Float arithmetic (0x80-0x8F)
    cmp al, 0x80
    je vm_op_fadd
    cmp al, 0x81
    je vm_op_fsub
    cmp al, 0x82
    je vm_op_fmul
    cmp al, 0x83
    je vm_op_fdiv
    cmp al, 0x84
    je vm_op_fmod
    cmp al, 0x85
    je vm_op_fneg
    cmp al, 0x86
    je vm_op_fabs
    cmp al, 0x87
    je vm_op_fsqrt

    ; Float trig (0x88-0x8F)
    cmp al, 0x88
    je vm_op_fsin
    cmp al, 0x89
    je vm_op_fcos
    cmp al, 0x8A
    je vm_op_ftan
    cmp al, 0x8B
    je vm_op_fatan
    cmp al, 0x8C
    je vm_op_fatan2
    cmp al, 0x8D
    je vm_op_fsincos

    ; Float advanced (0x90-0x97)
    cmp al, 0x90
    je vm_op_fpow
    cmp al, 0x91
    je vm_op_flog
    cmp al, 0x92
    je vm_op_flog10
    cmp al, 0x93
    je vm_op_fln
    cmp al, 0x94
    je vm_op_fexp

    ; Float conversion (0x98-0x9B)
    cmp al, 0x98
    je vm_op_itof
    cmp al, 0x99
    je vm_op_ftoi
    cmp al, 0x9A
    je vm_op_ftoi_round

    ; Float comparison (0x9C-0x9F)
    cmp al, 0x9C
    je vm_op_fcmp
    cmp al, 0x9D
    je vm_op_flt
    cmp al, 0x9E
    je vm_op_fgt
    cmp al, 0x9F
    je vm_op_feq

    ; Float constants (0xA0-0xA7)
    cmp al, 0xA0
    je vm_op_fconst
    cmp al, 0xA1
    je vm_op_fconst_pi
    cmp al, 0xA2
    je vm_op_fconst_e
    cmp al, 0xA3
    je vm_op_fconst_0
    cmp al, 0xA4
    je vm_op_fconst_1

    ; Float stack (0xA8-0xAB)
    cmp al, 0xA8
    je vm_op_fdup
    cmp al, 0xA9
    je vm_op_fdrop
    cmp al, 0xAA
    je vm_op_fswap
    cmp al, 0xAB
    je vm_op_fover

    ; Float special (0xAC-0xAF)
    cmp al, 0xAC
    je vm_op_fmin
    cmp al, 0xAD
    je vm_op_fmax
    cmp al, 0xAE
    je vm_op_fclamp
    cmp al, 0xAF
    je vm_op_flerp

    ; I/O (0xC0-0xCF)
    cmp al, 0xC0
    je vm_op_print_char
    cmp al, 0xC1
    je vm_op_print_string
    cmp al, 0xC2
    je vm_op_print_nl
    cmp al, 0xC3
    je vm_op_print_int
    cmp al, 0xC4
    je vm_op_read_char
    cmp al, 0xC5
    je vm_op_read_int

    ; Unknown - skip
    jmp vm_loop

; ════════════════════════════════════════════════════════════════════════════
; INCLUDE MODULES (all use global vm_* labels)
; ════════════════════════════════════════════════════════════════════════════
%include "vm/math.asm"
%include "vm/stack.asm"
%include "vm/io.asm"
%include "vm/control.asm"
%include "vm/memory.asm"
%include "vm/bitwise.asm"
%include "vm/float.asm"

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
