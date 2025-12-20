; ════════════════════════════════════════════════════════════════════════════
; CURSOR.ASM - Redirects to cursor_widget
; ════════════════════════════════════════════════════════════════════════════
; This file is kept for compatibility - actual implementation in widgets/cursor_widget.asm
; ════════════════════════════════════════════════════════════════════════════

[BITS 64]

; Include the actual cursor widget implementation
%include "widgets/cursor_widget.asm"
