; ════════════════════════════════════════════════════════════════════════════
; MATHIS KERNEL - VM MODULE (MODULAR)
; Bytecode virtual machine - Split into submodules
; ════════════════════════════════════════════════════════════════════════════
;
; Structure:
;   vm/core.asm  - Main loop, dispatch, print_number
;   vm/math.asm  - Arithmetic (ADD, SUB, MUL, DIV, MOD)
;   vm/stack.asm - Stack ops (DUP, POP, SWAP, OVER, ROT)
;   vm/io.asm    - I/O (PRINT_INT, PRINT_STRING)
;
; All modules use global vm_* labels to avoid conflicts
; ════════════════════════════════════════════════════════════════════════════

%include "vm/core.asm"
