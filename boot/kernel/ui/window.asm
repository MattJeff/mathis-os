; ============================================================================
; MathisOS - Window Manager
; ============================================================================
; Gestion des fenetres (creation, dessin, clicks)
; - open_window      : Ouvrir une nouvelle fenetre
; - check_window_clicks : Gerer les clics sur fenetres
; - draw_windows     : Dessiner toutes les fenetres
; - draw_terminal_window : Dessiner le contenu terminal
; ============================================================================

; Window structure (32 bytes per window):
; Offset 0:  db active (0=inactive, 1=active)
; Offset 1:  db type (1=terminal, 2=files, 3=3D)
; Offset 2:  dw x
; Offset 4:  dw y
; Offset 6:  dw width
; Offset 8:  dw height
; Offset 10-31: reserved

; TODO: Deplacer les fonctions ici depuis go64.asm step by step
