; ════════════════════════════════════════════════════════════════════════════
; KERNEL64 - Version debug minimale
; ════════════════════════════════════════════════════════════════════════════

[BITS 32]
[ORG 0x200000]

kernel64_entry:
    ; Afficher 'X' en haut à gauche
    mov byte [0xB8000], 'X'
    mov byte [0xB8001], 0x4F

    cli
.halt:
    hlt
    jmp .halt

times 4096 - ($ - $$) db 0
