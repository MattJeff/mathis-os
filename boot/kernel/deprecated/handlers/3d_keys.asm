; ============================================================================
; MathisOS - 3D Mode Keys Handler
; ============================================================================
; Touches pour le mode 3D (mode 3)
; Note: Le mode 3D gere lui-meme ses inputs via ui3d.asm
; Ce fichier est un stub pour la compatibilite avec dispatcher.asm
; ============================================================================

; ════════════════════════════════════════════════════════════════════════════
; HANDLE 3D KEYS - Stub (le mode 3D gere ses propres inputs)
; ════════════════════════════════════════════════════════════════════════════
; Entree: al = scancode
; Sortie: al = 1 si handled, 0 sinon
; ════════════════════════════════════════════════════════════════════════════
handle_3d_keys:
    ; Le mode 3D utilise ui3d.asm qui a sa propre boucle
    ; Ce stub ne fait rien car le dispatcher est appele depuis main_loop
    ; mais le mode 3D utilise ui3d_main qui ne revient pas via main_loop
    xor al, al              ; Not handled ici
    ret
