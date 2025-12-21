; ============================================================================
; LABEL_MOD.ASM - Text Label Widget
; ============================================================================
; Static text display widget
; ============================================================================

[BITS 64]
[DEFAULT REL]

; ============================================================================
; CONSTANTS
; ============================================================================
WIDGET_SIZE             equ 44
LABEL_TEXT_OFFSET       equ WIDGET_SIZE
LABEL_COLOR_OFFSET      equ WIDGET_SIZE + 8
LABEL_STRUCT_SIZE       equ WIDGET_SIZE + 12

COLOR_TEXT_DEFAULT      equ 0x00000000

; ============================================================================
; EXPORTS
; ============================================================================
global label_draw
global label_set_text
global label_set_color
global label_vtable

; ============================================================================
; IMPORTS
; ============================================================================
extern text_draw_string_xy

; ============================================================================
; CODE
; ============================================================================
section .text

; ----------------------------------------------------------------------------
; label_draw - Draw label widget
; Input: RDI = label widget pointer
; ----------------------------------------------------------------------------
label_draw:
    push rbx
    mov rbx, rdi

    ; Get text pointer
    mov rdx, [rbx + LABEL_TEXT_OFFSET]
    test rdx, rdx
    jz .done

    ; Get position
    mov edi, [rbx + 8]              ; WIDGET_X
    mov esi, [rbx + 12]             ; WIDGET_Y

    ; Get color
    mov ecx, [rbx + LABEL_COLOR_OFFSET]
    test ecx, ecx
    jnz .has_color
    mov ecx, COLOR_TEXT_DEFAULT
.has_color:

    call text_draw_string_xy

.done:
    pop rbx
    ret

; ----------------------------------------------------------------------------
; label_set_text - Set label text
; Input: RDI = label, RSI = text string pointer
; ----------------------------------------------------------------------------
label_set_text:
    mov [rdi + LABEL_TEXT_OFFSET], rsi
    ret

; ----------------------------------------------------------------------------
; label_set_color - Set label text color
; Input: RDI = label, ESI = color (ARGB)
; ----------------------------------------------------------------------------
label_set_color:
    mov [rdi + LABEL_COLOR_OFFSET], esi
    ret

; ============================================================================
; DATA - Label vtable
; ============================================================================
section .data

label_vtable:
    dq label_draw           ; VT_DRAW
    dq 0                    ; VT_ON_KEY
    dq 0                    ; VT_ON_CLICK
    dq 0                    ; VT_ON_FOCUS
    dq 0                    ; VT_DESTROY
