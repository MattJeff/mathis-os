; ============================================================================
; BUTTON_MOD.ASM - Button Widget
; ============================================================================
; Clickable button with label
; ============================================================================

[BITS 64]
[DEFAULT REL]

; ============================================================================
; CONSTANTS (from widget_base_mod and colors_mod)
; ============================================================================
WIDGET_VTABLE           equ 0
WIDGET_X                equ 8
WIDGET_Y                equ 12
WIDGET_W                equ 16
WIDGET_H                equ 20
WIDGET_FLAGS            equ 24
WIDGET_SIZE             equ 44

WIDGET_FLAG_HOVER       equ 0x08

BUTTON_LABEL_OFFSET     equ WIDGET_SIZE
BUTTON_CALLBACK_OFFSET  equ WIDGET_SIZE + 8
BUTTON_STRUCT_SIZE      equ WIDGET_SIZE + 16

COLOR_BUTTON_BG         equ 0x00E0E0E0
COLOR_BUTTON_HOVER      equ 0x00C0C0C0
COLOR_BUTTON_BORDER     equ 0x00808080
COLOR_BUTTON_TEXT       equ 0x00000000

; ============================================================================
; EXPORTS
; ============================================================================
global button_draw
global button_on_click
global button_set_label
global button_vtable

; ============================================================================
; IMPORTS
; ============================================================================
extern draw_fill_rect
extern draw_rect_outline
extern text_draw_string_xy

; ============================================================================
; CODE
; ============================================================================
section .text

; ----------------------------------------------------------------------------
; button_draw - Draw button widget
; Input: RDI = button widget pointer
; ----------------------------------------------------------------------------
button_draw:
    push rbx
    push r12
    mov rbx, rdi

    ; Get bounds
    mov edi, [rbx + WIDGET_X]
    mov esi, [rbx + WIDGET_Y]
    mov edx, [rbx + WIDGET_W]
    mov ecx, [rbx + WIDGET_H]

    ; Draw background
    mov r8d, COLOR_BUTTON_BG
    test byte [rbx + WIDGET_FLAGS], WIDGET_FLAG_HOVER
    jz .no_hover
    mov r8d, COLOR_BUTTON_HOVER
.no_hover:
    call draw_fill_rect

    ; Draw border
    mov edi, [rbx + WIDGET_X]
    mov esi, [rbx + WIDGET_Y]
    mov edx, [rbx + WIDGET_W]
    mov ecx, [rbx + WIDGET_H]
    mov r8d, COLOR_BUTTON_BORDER
    call draw_rect_outline

    ; Draw label if set
    mov rdx, [rbx + BUTTON_LABEL_OFFSET]
    test rdx, rdx
    jz .no_label

    mov edi, [rbx + WIDGET_X]
    add edi, 8
    mov esi, [rbx + WIDGET_Y]
    add esi, 10
    mov ecx, COLOR_BUTTON_TEXT
    call text_draw_string_xy

.no_label:
    pop r12
    pop rbx
    ret

; ----------------------------------------------------------------------------
; button_on_click - Handle button click
; Input: RDI = button, ESI = x, EDX = y
; Output: AL = 1 if handled
; ----------------------------------------------------------------------------
button_on_click:
    push rbx
    mov rbx, rdi

    ; Call callback if set
    mov rax, [rbx + BUTTON_CALLBACK_OFFSET]
    test rax, rax
    jz .no_callback

    mov rdi, rbx
    call rax

.no_callback:
    mov al, 1
    pop rbx
    ret

; ----------------------------------------------------------------------------
; button_set_label - Set button label
; Input: RDI = button, RSI = label string pointer
; ----------------------------------------------------------------------------
button_set_label:
    mov [rdi + BUTTON_LABEL_OFFSET], rsi
    ret

; ============================================================================
; DATA - Button vtable
; ============================================================================
section .data

button_vtable:
    dq button_draw          ; VT_DRAW
    dq 0                    ; VT_ON_KEY
    dq button_on_click      ; VT_ON_CLICK
    dq 0                    ; VT_ON_FOCUS
    dq 0                    ; VT_DESTROY
