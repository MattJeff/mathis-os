; ============================================================================
; DESKTOP_ICONS_MOD.ASM - Desktop Icons
; ============================================================================
; Desktop icon rendering and click handling
; ============================================================================

[BITS 64]
[DEFAULT REL]

; ============================================================================
; CONSTANTS
; ============================================================================
ICON_SIZE               equ 48
ICON_SPACING            equ 80
ICON_TEXT_OFFSET        equ 54
ICON_START_X            equ 20
ICON_START_Y            equ 20
ICON_COLOR_BG           equ 0x00404060      ; Dark blue-gray
ICON_COLOR_BORDER       equ 0x00606080      ; Lighter border
ICON_COLOR_TEXT         equ 0x00FFFFFF      ; White text
MAX_ICONS               equ 8

; ============================================================================
; EXPORTS
; ============================================================================
global desktop_draw_icons
global desktop_icon_click
global desktop_add_icon
global icon_types

; ============================================================================
; IMPORTS
; ============================================================================
extern draw_fill_rect
extern text_draw_string_xy

; ============================================================================
; CODE
; ============================================================================
section .text

; ----------------------------------------------------------------------------
; desktop_draw_icons - Draw all desktop icons
; ----------------------------------------------------------------------------
desktop_draw_icons:
    push rbx
    push r12
    push r13
    push r14

    xor r12d, r12d              ; icon index
    mov r13d, ICON_START_X      ; x position
    mov r14d, ICON_START_Y      ; y position

.draw_loop:
    cmp r12d, [icon_count]
    jge .done

    ; Draw icon box
    mov edi, r13d
    mov esi, r14d
    mov edx, ICON_SIZE
    mov ecx, ICON_SIZE
    mov r8d, ICON_COLOR_BG
    call draw_fill_rect

    ; Draw icon symbol (first letter of label)
    mov edi, r13d
    add edi, 18                 ; Center in box
    mov esi, r14d
    add esi, 16
    mov eax, r12d
    shl eax, 3
    lea rdx, [icon_labels + rax]
    mov rdx, [rdx]
    mov ecx, ICON_COLOR_TEXT
    call text_draw_string_xy

    ; Draw icon label
    mov edi, r13d
    mov esi, r14d
    add esi, ICON_TEXT_OFFSET
    mov eax, r12d
    shl eax, 3
    lea rdx, [icon_labels + rax]
    mov rdx, [rdx]
    mov ecx, ICON_COLOR_TEXT
    call text_draw_string_xy

    ; Next position
    add r14d, ICON_SPACING
    inc r12d
    jmp .draw_loop

.done:
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; ----------------------------------------------------------------------------
; desktop_icon_click - Handle click on icon
; Input: EDI = x, ESI = y
; Output: EAX = icon index (-1 if none)
; ----------------------------------------------------------------------------
desktop_icon_click:
    push r12
    push r13

    xor r12d, r12d
    mov r13d, ICON_START_Y

.check_loop:
    cmp r12d, [icon_count]
    jge .no_hit

    ; Check Y bounds
    cmp esi, r13d
    jl .next
    mov eax, r13d
    add eax, ICON_SIZE
    cmp esi, eax
    jg .next

    ; Check X bounds
    cmp edi, ICON_START_X
    jl .next
    mov eax, ICON_START_X
    add eax, ICON_SIZE
    cmp edi, eax
    jg .next

    ; Hit
    mov eax, r12d
    jmp .done

.next:
    add r13d, ICON_SPACING
    inc r12d
    jmp .check_loop

.no_hit:
    mov eax, -1

.done:
    pop r13
    pop r12
    ret

; ----------------------------------------------------------------------------
; desktop_add_icon - Add icon to desktop
; Input: RDI = label string, ESI = app type
; Output: EAX = icon index
; ----------------------------------------------------------------------------
desktop_add_icon:
    mov eax, [icon_count]
    cmp eax, MAX_ICONS
    jge .full

    mov ecx, eax
    shl ecx, 3
    mov [icon_labels + rcx], rdi
    mov [icon_types + rcx], esi

    inc dword [icon_count]
    ret

.full:
    mov eax, -1
    ret

; ============================================================================
; DATA
; ============================================================================
section .rodata

str_calc:               db "Calc", 0
str_clock:              db "Clock", 0
str_files:              db "Files", 0
str_term:               db "Term", 0

section .data

icon_count:             dd 4

icon_labels:
    dq str_calc
    dq str_clock
    dq str_files
    dq str_term
    dq 0, 0, 0, 0

icon_types:
    dd 1, 2, 4, 5
    dd 0, 0, 0, 0
