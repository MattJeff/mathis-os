; ============================================================================
; WIDGET_BASE_MOD.ASM - Base Widget Structure
; ============================================================================
; Common widget structure and vtable definitions
; ============================================================================

[BITS 64]
[DEFAULT REL]

; ============================================================================
; WIDGET STRUCTURE OFFSETS
; ============================================================================
WIDGET_VTABLE           equ 0       ; Pointer to vtable
WIDGET_X                equ 8       ; X position
WIDGET_Y                equ 12      ; Y position
WIDGET_W                equ 16      ; Width
WIDGET_H                equ 20      ; Height
WIDGET_FLAGS            equ 24      ; Flags (visible, enabled, focused)
WIDGET_PARENT           equ 28      ; Parent widget pointer
WIDGET_DATA             equ 36      ; User data pointer
WIDGET_SIZE             equ 44      ; Total struct size

; ============================================================================
; WIDGET FLAGS
; ============================================================================
WIDGET_FLAG_VISIBLE     equ 0x01
WIDGET_FLAG_ENABLED     equ 0x02
WIDGET_FLAG_FOCUSED     equ 0x04
WIDGET_FLAG_HOVER       equ 0x08

; ============================================================================
; VTABLE OFFSETS
; ============================================================================
VT_DRAW                 equ 0       ; draw(widget)
VT_ON_KEY               equ 8       ; on_key(widget, scancode)
VT_ON_CLICK             equ 16      ; on_click(widget, x, y)
VT_ON_FOCUS             equ 24      ; on_focus(widget, focused)
VT_DESTROY              equ 32      ; destroy(widget)

; ============================================================================
; EXPORTS
; ============================================================================
global widget_init
global widget_set_bounds
global widget_contains_point
global widget_is_visible
global widget_set_visible

; ============================================================================
; CODE
; ============================================================================
section .text

; ----------------------------------------------------------------------------
; widget_init - Initialize widget structure
; Input: RDI = widget pointer, RSI = vtable pointer
; ----------------------------------------------------------------------------
widget_init:
    mov [rdi + WIDGET_VTABLE], rsi
    mov dword [rdi + WIDGET_X], 0
    mov dword [rdi + WIDGET_Y], 0
    mov dword [rdi + WIDGET_W], 100
    mov dword [rdi + WIDGET_H], 30
    mov dword [rdi + WIDGET_FLAGS], WIDGET_FLAG_VISIBLE | WIDGET_FLAG_ENABLED
    mov qword [rdi + WIDGET_PARENT], 0
    mov qword [rdi + WIDGET_DATA], 0
    ret

; ----------------------------------------------------------------------------
; widget_set_bounds - Set widget position and size
; Input: RDI = widget, ESI = x, EDX = y, ECX = w, R8D = h
; ----------------------------------------------------------------------------
widget_set_bounds:
    mov [rdi + WIDGET_X], esi
    mov [rdi + WIDGET_Y], edx
    mov [rdi + WIDGET_W], ecx
    mov [rdi + WIDGET_H], r8d
    ret

; ----------------------------------------------------------------------------
; widget_contains_point - Check if point is inside widget
; Input: RDI = widget, ESI = x, EDX = y
; Output: AL = 1 if inside, 0 otherwise
; ----------------------------------------------------------------------------
widget_contains_point:
    ; Check X bounds
    cmp esi, [rdi + WIDGET_X]
    jl .outside
    mov eax, [rdi + WIDGET_X]
    add eax, [rdi + WIDGET_W]
    cmp esi, eax
    jge .outside

    ; Check Y bounds
    cmp edx, [rdi + WIDGET_Y]
    jl .outside
    mov eax, [rdi + WIDGET_Y]
    add eax, [rdi + WIDGET_H]
    cmp edx, eax
    jge .outside

    mov al, 1
    ret

.outside:
    xor eax, eax
    ret

; ----------------------------------------------------------------------------
; widget_is_visible - Check if widget is visible
; Input: RDI = widget
; Output: AL = 1 if visible
; ----------------------------------------------------------------------------
widget_is_visible:
    mov al, [rdi + WIDGET_FLAGS]
    and al, WIDGET_FLAG_VISIBLE
    ret

; ----------------------------------------------------------------------------
; widget_set_visible - Set widget visibility
; Input: RDI = widget, SIL = visible (0 or 1)
; ----------------------------------------------------------------------------
widget_set_visible:
    test sil, sil
    jz .hide
    or byte [rdi + WIDGET_FLAGS], WIDGET_FLAG_VISIBLE
    ret
.hide:
    and byte [rdi + WIDGET_FLAGS], ~WIDGET_FLAG_VISIBLE
    ret
