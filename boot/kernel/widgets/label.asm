; ════════════════════════════════════════════════════════════════════════════
; LABEL.ASM - Label Widget (Static Text Display)
; ════════════════════════════════════════════════════════════════════════════
; Simple widget that displays text. Does not handle input.
; Inherits from Widget base class.
; ════════════════════════════════════════════════════════════════════════════

; ════════════════════════════════════════════════════════════════════════════
; LABEL STRUCTURE (extends Widget - 64 + 32 = 96 bytes)
; ════════════════════════════════════════════════════════════════════════════
; Offset  Size  Field       Description
; ──────────────────────────────────────────────────────────────────────────
;   0-63   64   base        Widget base structure
;  64       8   text        Pointer to text string
;  72       4   fg_color    Text color (BGRA)
;  76       4   bg_color    Background color (0 = transparent)
;  80       4   alignment   LABEL_ALIGN_*
;  84       4   padding     Padding in pixels
;  88       8   reserved    Future use
; ════════════════════════════════════════════════════════════════════════════

LABEL_SIZE          equ 96

; Structure offsets (after Widget base)
L_TEXT              equ 64
L_FG_COLOR          equ 72
L_BG_COLOR          equ 76
L_ALIGNMENT         equ 80
L_PADDING           equ 84
L_RESERVED          equ 88

; Alignment constants
LABEL_ALIGN_LEFT    equ 0
LABEL_ALIGN_CENTER  equ 1
LABEL_ALIGN_RIGHT   equ 2

; Default colors
LABEL_DEF_FG        equ 0x00FFFFFF      ; White
LABEL_DEF_BG        equ 0x00000000      ; Transparent

; ════════════════════════════════════════════════════════════════════════════
; LABEL V-TABLE
; ════════════════════════════════════════════════════════════════════════════
label_vtable:
    dq label_draw               ; VT_DRAW
    dq label_on_key             ; VT_ON_KEY (no-op)
    dq label_on_click           ; VT_ON_CLICK (no-op)
    dq label_on_focus           ; VT_ON_FOCUS (no-op)
    dq label_destroy_impl       ; VT_DESTROY

; ════════════════════════════════════════════════════════════════════════════
; LABEL_CREATE - Create a new label widget
; Input:  ESI = x, EDX = y, ECX = w, R8D = h, R9 = text pointer
; Output: RAX = label pointer (or 0 on failure)
; ════════════════════════════════════════════════════════════════════════════
label_create:
    push rbx
    push r12

    mov r12, r9                     ; Save text pointer

    ; Allocate label (larger than base widget)
    push rsi
    push rdx
    push rcx
    push r8

    mov rdi, LABEL_SIZE
    call kmalloc
    test rax, rax
    jz .fail_pop

    mov rbx, rax

    pop r8
    pop rcx
    pop rdx
    pop rsi

    ; Initialize widget base
    lea rax, [label_vtable]
    mov qword [rbx + W_VTABLE], rax
    mov dword [rbx + W_X], esi
    mov dword [rbx + W_Y], edx
    mov dword [rbx + W_W], ecx
    mov dword [rbx + W_H], r8d
    mov dword [rbx + W_FLAGS], WF_VISIBLE | WF_DIRTY
    mov dword [rbx + W_ID], 0
    mov qword [rbx + W_PARENT], 0
    mov qword [rbx + W_USERDATA], 0
    mov qword [rbx + W_CHILDREN], 0

    ; Generate unique ID
    mov eax, [widget_next_id]
    mov [rbx + W_ID], eax
    inc dword [widget_next_id]

    ; Initialize label-specific fields
    mov [rbx + L_TEXT], r12
    mov dword [rbx + L_FG_COLOR], LABEL_DEF_FG
    mov dword [rbx + L_BG_COLOR], LABEL_DEF_BG
    mov dword [rbx + L_ALIGNMENT], LABEL_ALIGN_LEFT
    mov dword [rbx + L_PADDING], 4
    mov qword [rbx + L_RESERVED], 0

    mov rax, rbx
    jmp .done

.fail_pop:
    pop r8
    pop rcx
    pop rdx
    pop rsi
    xor eax, eax

.done:
    pop r12
    pop rbx
    ret

; ════════════════════════════════════════════════════════════════════════════
; LABEL_DRAW - Draw the label
; Input:  RDI = label pointer
; ════════════════════════════════════════════════════════════════════════════
label_draw:
    push rbx
    push r12
    push r13
    push r14

    mov rbx, rdi                    ; rbx = label

    ; Draw background if not transparent
    mov eax, [rbx + L_BG_COLOR]
    test eax, eax
    jz .no_background

    mov edi, [rbx + W_X]
    mov esi, [rbx + W_Y]
    mov edx, [rbx + W_W]
    mov ecx, [rbx + W_H]
    mov r8d, eax                    ; color
    call fill_rect

.no_background:
    ; Get text pointer
    mov r12, [rbx + L_TEXT]
    test r12, r12
    jz .done                        ; No text

    ; Calculate text position based on alignment
    mov r13d, [rbx + W_X]
    add r13d, [rbx + L_PADDING]     ; Default: left aligned + padding

    mov eax, [rbx + L_ALIGNMENT]
    cmp eax, LABEL_ALIGN_CENTER
    je .center_align
    cmp eax, LABEL_ALIGN_RIGHT
    je .right_align
    jmp .draw_text

.center_align:
    ; Calculate text width (8 pixels per char)
    mov rdi, r12
    call label_strlen
    shl eax, 3                      ; * 8 pixels per char
    mov r14d, eax                   ; r14 = text_width

    mov r13d, [rbx + W_X]
    mov ecx, [rbx + W_W]
    sub ecx, r14d
    shr ecx, 1                      ; (w - text_width) / 2
    add r13d, ecx
    jmp .draw_text

.right_align:
    ; Calculate text width
    mov rdi, r12
    call label_strlen
    shl eax, 3                      ; * 8 pixels per char

    mov r13d, [rbx + W_X]
    add r13d, [rbx + W_W]
    sub r13d, eax
    sub r13d, [rbx + L_PADDING]     ; Right edge - text_width - padding
    jmp .draw_text

.draw_text:
    ; Calculate Y position (vertically centered)
    mov r14d, [rbx + W_Y]
    mov eax, [rbx + W_H]
    sub eax, 8                      ; Font height = 8
    shr eax, 1
    add r14d, eax

    ; Draw text
    mov edi, r13d                   ; x
    mov esi, r14d                   ; y
    mov rdx, r12                    ; text
    mov ecx, [rbx + L_FG_COLOR]     ; color
    call video_text

.done:
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; ════════════════════════════════════════════════════════════════════════════
; LABEL_STRLEN - Get string length
; Input:  RDI = string pointer
; Output: EAX = length
; ════════════════════════════════════════════════════════════════════════════
label_strlen:
    push rdi
    xor eax, eax
    test rdi, rdi
    jz .done
.loop:
    cmp byte [rdi], 0
    je .done
    inc rdi
    inc eax
    jmp .loop
.done:
    pop rdi
    ret

; ════════════════════════════════════════════════════════════════════════════
; LABEL_ON_KEY - Handle key input (no-op for labels)
; Input:  RDI = label, ESI = scancode
; Output: EAX = 0 (not handled)
; ════════════════════════════════════════════════════════════════════════════
label_on_key:
    xor eax, eax
    ret

; ════════════════════════════════════════════════════════════════════════════
; LABEL_ON_CLICK - Handle click (no-op for labels)
; Input:  RDI = label, ESI = x, EDX = y, ECX = button
; Output: EAX = 0 (not handled)
; ════════════════════════════════════════════════════════════════════════════
label_on_click:
    xor eax, eax
    ret

; ════════════════════════════════════════════════════════════════════════════
; LABEL_ON_FOCUS - Handle focus change (no-op for labels)
; Input:  RDI = label, ESI = gained (1/0)
; ════════════════════════════════════════════════════════════════════════════
label_on_focus:
    ret

; ════════════════════════════════════════════════════════════════════════════
; LABEL_DESTROY_IMPL - Cleanup (nothing to do for basic label)
; Input:  RDI = label
; ════════════════════════════════════════════════════════════════════════════
label_destroy_impl:
    ret

; ════════════════════════════════════════════════════════════════════════════
; LABEL_SET_TEXT - Change label text
; Input:  RDI = label, RSI = new text pointer
; ════════════════════════════════════════════════════════════════════════════
label_set_text:
    test rdi, rdi
    jz .done
    mov [rdi + L_TEXT], rsi
    or dword [rdi + W_FLAGS], WF_DIRTY
.done:
    ret

; ════════════════════════════════════════════════════════════════════════════
; LABEL_SET_COLOR - Change label colors
; Input:  RDI = label, ESI = fg_color, EDX = bg_color
; ════════════════════════════════════════════════════════════════════════════
label_set_color:
    test rdi, rdi
    jz .done
    mov [rdi + L_FG_COLOR], esi
    mov [rdi + L_BG_COLOR], edx
    or dword [rdi + W_FLAGS], WF_DIRTY
.done:
    ret

; ════════════════════════════════════════════════════════════════════════════
; LABEL_SET_ALIGNMENT - Change text alignment
; Input:  RDI = label, ESI = alignment (LABEL_ALIGN_*)
; ════════════════════════════════════════════════════════════════════════════
label_set_alignment:
    test rdi, rdi
    jz .done
    mov [rdi + L_ALIGNMENT], esi
    or dword [rdi + W_FLAGS], WF_DIRTY
.done:
    ret
