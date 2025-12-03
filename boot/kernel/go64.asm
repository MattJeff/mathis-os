; ════════════════════════════════════════════════════════════════════════════
; GO64.ASM - Trampoline vers kernel 64-bit
; ════════════════════════════════════════════════════════════════════════════
; Ce fichier est inclus EN DERNIER avant data_all.asm
; Modifier ce fichier ne décale pas keyboard_code.asm
; ════════════════════════════════════════════════════════════════════════════

do_go64:
    mov eax, 0x200000
    jmp eax
