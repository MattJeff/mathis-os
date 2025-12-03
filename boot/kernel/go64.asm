; ════════════════════════════════════════════════════════════════════════════
; GO64.ASM - Trampoline vers kernel 64-bit
; ════════════════════════════════════════════════════════════════════════════
; Ce fichier est inclus EN DERNIER avant data_all.asm
; Modifier ce fichier ne décale pas keyboard_code.asm
; ════════════════════════════════════════════════════════════════════════════

do_go64:
    ; Afficher '64' pour confirmer qu'on est dans go64
    mov byte [0xB8000], '6'
    mov byte [0xB8001], 0x4E
    mov byte [0xB8002], '4'
    mov byte [0xB8003], 0x4E

    ; Pour l'instant, juste halt - la transition 64-bit viendra après
    ; quand on aura résolu le problème de chargement
    mov byte [0xB8004], '!'
    mov byte [0xB8005], 0x0A

    cli
    hlt
