; ════════════════════════════════════════════════════════════════════════════
; BUTTON.ASM - Button Widget (Clickable)
; ════════════════════════════════════════════════════════════════════════════
; Interactive button with text label and click callback.
; Inherits from Widget base class.
; ════════════════════════════════════════════════════════════════════════════

; ════════════════════════════════════════════════════════════════════════════
; BUTTON STRUCTURE (extends Widget - 64 + 48 = 112 bytes)
; ════════════════════════════════════════════════════════════════════════════
; Offset  Size  Field       Description
; ──────────────────────────────────────────────────────────────────────────
;   0-63   64   base        Widget base structure
;  64       8   text        Pointer to button label text
;  72       8   callback    Function called on click (or 0)
;  80       4   fg_color    Text color
;  84       4   bg_color    Background color
;  88       4   hover_color Color when hovered
;  92       4   press_color Color when pressed
;  96       4   border_color Border color
; 100       4   state       BTN_STATE_*
; 104       8   reserved    Future use
; ════════════════════════════════════════════════════════════════════════════

BUTTON_SIZE         equ 112

; Structure offsets (after Widget base)
BTN_TEXT            equ 64
BTN_CALLBACK        equ 72
BTN_FG_COLOR        equ 80
BTN_BG_COLOR        equ 84
BTN_HOVER_COLOR     equ 88
BTN_PRESS_COLOR     equ 92
BTN_BORDER_COLOR    equ 96
BTN_STATE           equ 100
BTN_RESERVED        equ 104

; Button states
BTN_STATE_NORMAL    equ 0
BTN_STATE_HOVER     equ 1
BTN_STATE_PRESSED   equ 2
BTN_STATE_DISABLED  equ 3

; Default colors (dark theme)
BTN_DEF_FG          equ 0x00FFFFFF      ; White text
BTN_DEF_BG          equ 0x00404040      ; Dark gray
BTN_DEF_HOVER       equ 0x00505050      ; Lighter gray
BTN_DEF_PRESS       equ 0x00303030      ; Darker gray
BTN_DEF_BORDER      equ 0x00606060      ; Border gray

; ════════════════════════════════════════════════════════════════════════════
; BUTTON V-TABLE
; ════════════════════════════════════════════════════════════════════════════
button_vtable:
    dq button_draw              ; VT_DRAW
    dq button_on_key            ; VT_ON_KEY
    dq button_on_click          ; VT_ON_CLICK
    dq button_on_focus          ; VT_ON_FOCUS
    dq button_destroy_impl      ; VT_DESTROY

; ════════════════════════════════════════════════════════════════════════════
; BUTTON_CREATE - Create a new button widget
; Input:  ESI = x, EDX = y, ECX = w, R8D = h, R9 = text pointer
; Output: RAX = button pointer (or 0 on failure)
; ════════════════════════════════════════════════════════════════════════════
button_create:
    push rbx
    push r12

    mov r12, r9                     ; Save text pointer

    ; Allocate button
    push rsi
    push rdx
    push rcx
    push r8

    mov rdi, BUTTON_SIZE
    call kmalloc
    test rax, rax
    jz .fail_pop

    mov rbx, rax

    pop r8
    pop rcx
    pop rdx
    pop rsi

    ; Initialize widget base
    lea rax, [button_vtable]
    mov qword [rbx + W_VTABLE], rax
    mov dword [rbx + W_X], esi
    mov dword [rbx + W_Y], edx
    mov dword [rbx + W_W], ecx
    mov dword [rbx + W_H], r8d
    mov dword [rbx + W_FLAGS], WF_VISIBLE | WF_ENABLED | WF_DIRTY
    mov dword [rbx + W_ID], 0
    mov qword [rbx + W_PARENT], 0
    mov qword [rbx + W_USERDATA], 0
    mov qword [rbx + W_CHILDREN], 0

    ; Generate unique ID
    mov eax, [widget_next_id]
    mov [rbx + W_ID], eax
    inc dword [widget_next_id]

    ; Initialize button-specific fields
    mov [rbx + BTN_TEXT], r12
    mov qword [rbx + BTN_CALLBACK], 0
    mov dword [rbx + BTN_FG_COLOR], BTN_DEF_FG
    mov dword [rbx + BTN_BG_COLOR], BTN_DEF_BG
    mov dword [rbx + BTN_HOVER_COLOR], BTN_DEF_HOVER
    mov dword [rbx + BTN_PRESS_COLOR], BTN_DEF_PRESS
    mov dword [rbx + BTN_BORDER_COLOR], BTN_DEF_BORDER
    mov dword [rbx + BTN_STATE], BTN_STATE_NORMAL
    mov qword [rbx + BTN_RESERVED], 0

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
; BUTTON_DRAW - Draw the button
; Input:  RDI = button pointer
; ════════════════════════════════════════════════════════════════════════════
button_draw:
    push rbx
    push r12
    push r13

    mov rbx, rdi                    ; rbx = button

    ; Determine background color based on state
    mov r12d, [rbx + BTN_BG_COLOR]  ; Default: normal

    mov eax, [rbx + BTN_STATE]
    cmp eax, BTN_STATE_HOVER
    jne .not_hover
    mov r12d, [rbx + BTN_HOVER_COLOR]
    jmp .draw_bg
.not_hover:
    cmp eax, BTN_STATE_PRESSED
    jne .draw_bg
    mov r12d, [rbx + BTN_PRESS_COLOR]

.draw_bg:
    ; Draw background
    mov edi, [rbx + W_X]
    mov esi, [rbx + W_Y]
    mov edx, [rbx + W_W]
    mov ecx, [rbx + W_H]
    mov r8d, r12d
    call fill_rect

    ; Draw border
    mov edi, [rbx + W_X]
    mov esi, [rbx + W_Y]
    mov edx, [rbx + W_W]
    mov ecx, [rbx + W_H]
    mov r8d, [rbx + BTN_BORDER_COLOR]
    call draw_rect

    ; Draw focus indicator if focused
    test dword [rbx + W_FLAGS], WF_FOCUSED
    jz .no_focus_border

    ; Inner border for focus
    mov edi, [rbx + W_X]
    add edi, 2
    mov esi, [rbx + W_Y]
    add esi, 2
    mov edx, [rbx + W_W]
    sub edx, 4
    mov ecx, [rbx + W_H]
    sub ecx, 4
    mov r8d, 0x00FFFF00             ; Yellow focus
    call draw_rect

.no_focus_border:
    ; Draw text (centered)
    mov r12, [rbx + BTN_TEXT]
    test r12, r12
    jz .done

    ; Calculate text width
    mov rdi, r12
    call button_strlen
    shl eax, 3                      ; * 8 pixels per char
    mov r13d, eax                   ; r13 = text_width

    ; Calculate X (centered)
    mov edi, [rbx + W_X]
    mov eax, [rbx + W_W]
    sub eax, r13d
    shr eax, 1
    add edi, eax

    ; Calculate Y (centered)
    mov esi, [rbx + W_Y]
    mov eax, [rbx + W_H]
    sub eax, 8                      ; Font height
    shr eax, 1
    add esi, eax

    ; Offset text slightly when pressed for 3D effect
    cmp dword [rbx + BTN_STATE], BTN_STATE_PRESSED
    jne .draw_text
    inc edi
    inc esi

.draw_text:
    mov rdx, r12                    ; text
    mov ecx, [rbx + BTN_FG_COLOR]   ; color
    call video_text

.done:
    pop r13
    pop r12
    pop rbx
    ret

; ════════════════════════════════════════════════════════════════════════════
; BUTTON_STRLEN - Get string length
; Input:  RDI = string pointer
; Output: EAX = length
; ════════════════════════════════════════════════════════════════════════════
button_strlen:
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
; BUTTON_ON_KEY - Handle key input
; Input:  RDI = button, ESI = scancode
; Output: EAX = 1 if handled, 0 otherwise
; ════════════════════════════════════════════════════════════════════════════
button_on_key:
    push rbx
    mov rbx, rdi

    ; Check for Enter or Space (activate button)
    cmp esi, 0x1C                   ; Enter scancode
    je .activate
    cmp esi, 0x39                   ; Space scancode
    je .activate

    xor eax, eax
    jmp .done

.activate:
    ; Visual feedback - set pressed state
    mov dword [rbx + BTN_STATE], BTN_STATE_PRESSED
    or dword [rbx + W_FLAGS], WF_DIRTY

    ; Call callback
    mov rax, [rbx + BTN_CALLBACK]
    test rax, rax
    jz .no_callback
    mov rdi, rbx                    ; Pass button as arg
    call rax

.no_callback:
    ; Reset state
    mov dword [rbx + BTN_STATE], BTN_STATE_NORMAL
    or dword [rbx + W_FLAGS], WF_DIRTY

    mov eax, 1                      ; Handled

.done:
    pop rbx
    ret

; ════════════════════════════════════════════════════════════════════════════
; BUTTON_ON_CLICK - Handle mouse click
; Input:  RDI = button, ESI = x, EDX = y, ECX = button
; Output: EAX = 1 if handled, 0 otherwise
; ════════════════════════════════════════════════════════════════════════════
button_on_click:
    push rbx
    mov rbx, rdi

    ; Only handle left click
    cmp ecx, 1
    jne .not_handled

    ; Set pressed state
    mov dword [rbx + BTN_STATE], BTN_STATE_PRESSED
    or dword [rbx + W_FLAGS], WF_DIRTY

    ; Call callback
    mov rax, [rbx + BTN_CALLBACK]
    test rax, rax
    jz .no_callback
    mov rdi, rbx                    ; Pass button as arg
    call rax

.no_callback:
    ; Reset state
    mov dword [rbx + BTN_STATE], BTN_STATE_NORMAL
    or dword [rbx + W_FLAGS], WF_DIRTY

    mov eax, 1
    jmp .done

.not_handled:
    xor eax, eax

.done:
    pop rbx
    ret

; ════════════════════════════════════════════════════════════════════════════
; BUTTON_ON_FOCUS - Handle focus change
; Input:  RDI = button, ESI = gained (1/0)
; ════════════════════════════════════════════════════════════════════════════
button_on_focus:
    ; Just mark dirty for redraw
    or dword [rdi + W_FLAGS], WF_DIRTY
    ret

; ════════════════════════════════════════════════════════════════════════════
; BUTTON_DESTROY_IMPL - Cleanup
; Input:  RDI = button
; ════════════════════════════════════════════════════════════════════════════
button_destroy_impl:
    ret

; ════════════════════════════════════════════════════════════════════════════
; BUTTON_SET_CALLBACK - Set click callback function
; Input:  RDI = button, RSI = callback function pointer
; ════════════════════════════════════════════════════════════════════════════
button_set_callback:
    test rdi, rdi
    jz .done
    mov [rdi + BTN_CALLBACK], rsi
.done:
    ret

; ════════════════════════════════════════════════════════════════════════════
; BUTTON_SET_TEXT - Change button text
; Input:  RDI = button, RSI = new text pointer
; ════════════════════════════════════════════════════════════════════════════
button_set_text:
    test rdi, rdi
    jz .done
    mov [rdi + BTN_TEXT], rsi
    or dword [rdi + W_FLAGS], WF_DIRTY
.done:
    ret

; ════════════════════════════════════════════════════════════════════════════
; BUTTON_SET_COLORS - Set button colors
; Input:  RDI = button, ESI = fg, EDX = bg, ECX = border
; ════════════════════════════════════════════════════════════════════════════
button_set_colors:
    test rdi, rdi
    jz .done
    mov [rdi + BTN_FG_COLOR], esi
    mov [rdi + BTN_BG_COLOR], edx
    mov [rdi + BTN_BORDER_COLOR], ecx
    or dword [rdi + W_FLAGS], WF_DIRTY
.done:
    ret

; ════════════════════════════════════════════════════════════════════════════
; BUTTON_SET_STATE - Set button state (for hover effects)
; Input:  RDI = button, ESI = state (BTN_STATE_*)
; ════════════════════════════════════════════════════════════════════════════
button_set_state:
    test rdi, rdi
    jz .done
    mov [rdi + BTN_STATE], esi
    or dword [rdi + W_FLAGS], WF_DIRTY
.done:
    ret
