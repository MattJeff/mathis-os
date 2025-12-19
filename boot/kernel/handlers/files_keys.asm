; ============================================================================
; MathisOS - Files Keys Handler (REFACTORED with Widgets)
; ============================================================================
; Touches pour le mode FILES (mode 4)
; Now forwards to files_app widget system
; ============================================================================

; ════════════════════════════════════════════════════════════════════════════
; HANDLE FILES KEYS
; ════════════════════════════════════════════════════════════════════════════
; Entree: al = scancode
; Sortie: al = 1 si handled, 0 sinon
; ════════════════════════════════════════════════════════════════════════════
handle_files_keys:
    ; Forward all keys to the widget-based app
    call files_app_on_key
    ret
