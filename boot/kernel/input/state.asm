; ============================================================================
; MathisOS - Input State Variables
; ============================================================================
; Variables d'etat pour clavier et souris
; Centralise tout l'etat input en un seul endroit
; ============================================================================

; ════════════════════════════════════════════════════════════════════════════
; KEYBOARD STATE
; ════════════════════════════════════════════════════════════════════════════
shift_state:        db 0            ; 1 si shift appuye
ctrl_state:         db 0            ; 1 si ctrl appuye
alt_state:          db 0            ; 1 si alt appuye

; Event-driven keyboard (nouveau systeme)
key_pressed:        db 0            ; Dernier scancode appuye
key_ready:          db 0            ; 1 si nouvelle touche a traiter
last_scancode:      db 0            ; Dernier scancode (press ou release)

; ════════════════════════════════════════════════════════════════════════════
; MOUSE STATE
; ════════════════════════════════════════════════════════════════════════════
mouse_x:            dw 160          ; Position X curseur
mouse_y:            dw 100          ; Position Y curseur
mouse_buttons:      db 0            ; Etat boutons (bit 0 = left, bit 1 = right)

; PS/2 Mouse packet handling
mouse_cycle:        db 0            ; Cycle packet (0, 1, 2)
mouse_byte0:        db 0            ; Byte 0 du packet
mouse_byte1:        db 0            ; Byte 1 du packet (delta X)
mouse_byte2:        db 0            ; Byte 2 du packet (delta Y)

; Click debounce
last_mouse_btn:     db 0            ; Etat precedent bouton gauche
click_cooldown:     dd 0            ; Cooldown entre clics (~150ms)
