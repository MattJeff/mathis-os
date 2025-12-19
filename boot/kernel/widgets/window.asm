; ════════════════════════════════════════════════════════════════════════════
; WINDOW.ASM - Window Widget (Draggable Container with Title Bar)
; ════════════════════════════════════════════════════════════════════════════
; Window with title bar, close button, and content area.
; Can contain child widgets. Supports dragging.
; Inherits from Widget base class.
; ════════════════════════════════════════════════════════════════════════════

; ════════════════════════════════════════════════════════════════════════════
; WINDOW STRUCTURE (extends Widget - 64 + 64 = 128 bytes)
; ════════════════════════════════════════════════════════════════════════════
; Offset  Size  Field         Description
; ──────────────────────────────────────────────────────────────────────────
;   0-63   64   base          Widget base structure
;  64       8   title         Pointer to window title string
;  72       8   close_callback Function called on close (or 0)
;  80       4   title_height  Height of title bar
;  84       4   border_width  Border width
;  88       4   bg_color      Window background color
;  92       4   title_bg      Title bar background color
;  96       4   title_fg      Title text color
; 100       4   border_color  Border color
; 104       4   drag_state    DRAG_STATE_*
; 108       4   drag_offset_x Offset from window X when dragging
; 112       4   drag_offset_y Offset from window Y when dragging
; 116       4   resizable     1 if resizable, 0 if not
; 120       8   content       Pointer to content widget (or 0)
; ════════════════════════════════════════════════════════════════════════════

WINDOW_SIZE         equ 128

; Structure offsets (after Widget base)
WIN_TITLE           equ 64
WIN_CLOSE_CB        equ 72
WIN_TITLE_HEIGHT    equ 80
WIN_BORDER_WIDTH    equ 84
WIN_BG_COLOR        equ 88
WIN_TITLE_BG        equ 92
WIN_TITLE_FG        equ 96
WIN_BORDER_COLOR    equ 100
WIN_DRAG_STATE      equ 104
WIN_DRAG_OFF_X      equ 108
WIN_DRAG_OFF_Y      equ 112
WIN_RESIZABLE       equ 116
WIN_CONTENT         equ 120

; Drag states
DRAG_STATE_NONE     equ 0
DRAG_STATE_MOVING   equ 1
DRAG_STATE_RESIZING equ 2

; Default sizes
WIN_DEF_TITLE_H     equ 24
WIN_DEF_BORDER_W    equ 2

; Default colors (dark theme)
WIN_DEF_BG          equ 0x00282828      ; Dark gray background
WIN_DEF_TITLE_BG    equ 0x00404040      ; Title bar gray
WIN_DEF_TITLE_FG    equ 0x00FFFFFF      ; White title text
WIN_DEF_BORDER_COL  equ 0x00505050      ; Border gray
WIN_CLOSE_BTN_SIZE  equ 16              ; Close button size

; ════════════════════════════════════════════════════════════════════════════
; WINDOW V-TABLE
; ════════════════════════════════════════════════════════════════════════════
window_vtable:
    dq window_draw              ; VT_DRAW
    dq window_on_key            ; VT_ON_KEY
    dq window_on_click          ; VT_ON_CLICK
    dq window_on_focus          ; VT_ON_FOCUS
    dq window_destroy_impl      ; VT_DESTROY

; ════════════════════════════════════════════════════════════════════════════
; WINDOW_CREATE - Create a new window widget
; Input:  ESI = x, EDX = y, ECX = w, R8D = h, R9 = title pointer
; Output: RAX = window pointer (or 0 on failure)
; ════════════════════════════════════════════════════════════════════════════
window_create:
    push rbx
    push r12

    mov r12, r9                     ; Save title pointer

    ; Allocate window
    push rsi
    push rdx
    push rcx
    push r8

    mov rdi, WINDOW_SIZE
    call kmalloc
    test rax, rax
    jz .fail_pop

    mov rbx, rax

    pop r8
    pop rcx
    pop rdx
    pop rsi

    ; Initialize widget base
    lea rax, [window_vtable]
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

    ; Initialize window-specific fields
    mov [rbx + WIN_TITLE], r12
    mov qword [rbx + WIN_CLOSE_CB], 0
    mov dword [rbx + WIN_TITLE_HEIGHT], WIN_DEF_TITLE_H
    mov dword [rbx + WIN_BORDER_WIDTH], WIN_DEF_BORDER_W
    mov dword [rbx + WIN_BG_COLOR], WIN_DEF_BG
    mov dword [rbx + WIN_TITLE_BG], WIN_DEF_TITLE_BG
    mov dword [rbx + WIN_TITLE_FG], WIN_DEF_TITLE_FG
    mov dword [rbx + WIN_BORDER_COLOR], WIN_DEF_BORDER_COL
    mov dword [rbx + WIN_DRAG_STATE], DRAG_STATE_NONE
    mov dword [rbx + WIN_DRAG_OFF_X], 0
    mov dword [rbx + WIN_DRAG_OFF_Y], 0
    mov dword [rbx + WIN_RESIZABLE], 0
    mov qword [rbx + WIN_CONTENT], 0

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
; WINDOW_DRAW - Draw the window
; Input:  RDI = window pointer
; ════════════════════════════════════════════════════════════════════════════
window_draw:
    push rbx
    push r12
    push r13
    push r14

    mov rbx, rdi                    ; rbx = window

    ; Draw window background
    mov edi, [rbx + W_X]
    mov esi, [rbx + W_Y]
    mov edx, [rbx + W_W]
    mov ecx, [rbx + W_H]
    mov r8d, [rbx + WIN_BG_COLOR]
    call fill_rect

    ; Draw border
    mov edi, [rbx + W_X]
    mov esi, [rbx + W_Y]
    mov edx, [rbx + W_W]
    mov ecx, [rbx + W_H]
    mov r8d, [rbx + WIN_BORDER_COLOR]
    call draw_rect

    ; Draw title bar background
    mov edi, [rbx + W_X]
    mov esi, [rbx + W_Y]
    mov edx, [rbx + W_W]
    mov ecx, [rbx + WIN_TITLE_HEIGHT]
    mov r8d, [rbx + WIN_TITLE_BG]
    call fill_rect

    ; Draw title bar bottom border
    mov edi, [rbx + W_X]
    mov esi, [rbx + W_Y]
    add esi, [rbx + WIN_TITLE_HEIGHT]
    mov edx, [rbx + W_X]
    add edx, [rbx + W_W]
    mov ecx, esi
    mov r8d, [rbx + WIN_BORDER_COLOR]
    call draw_line

    ; Draw title text
    mov r12, [rbx + WIN_TITLE]
    test r12, r12
    jz .no_title

    mov edi, [rbx + W_X]
    add edi, 8                      ; Left padding
    mov esi, [rbx + W_Y]
    mov eax, [rbx + WIN_TITLE_HEIGHT]
    sub eax, 8                      ; Font height
    shr eax, 1
    add esi, eax                    ; Vertically centered
    mov rdx, r12
    mov ecx, [rbx + WIN_TITLE_FG]
    call video_text

.no_title:
    ; Draw close button [X]
    mov r13d, [rbx + W_X]
    add r13d, [rbx + W_W]
    sub r13d, WIN_CLOSE_BTN_SIZE
    sub r13d, 4                     ; Right padding

    mov r14d, [rbx + W_Y]
    mov eax, [rbx + WIN_TITLE_HEIGHT]
    sub eax, WIN_CLOSE_BTN_SIZE
    shr eax, 1
    add r14d, eax                   ; Vertically centered

    ; Close button background
    mov edi, r13d
    mov esi, r14d
    mov edx, WIN_CLOSE_BTN_SIZE
    mov ecx, WIN_CLOSE_BTN_SIZE
    mov r8d, 0x00C04040             ; Red-ish
    call fill_rect

    ; Draw X
    mov edi, r13d
    add edi, 4
    mov esi, r14d
    add esi, 4
    mov rdx, win_close_char
    mov ecx, 0x00FFFFFF             ; White
    call video_text

    ; Draw content widget if exists
    mov rdi, [rbx + WIN_CONTENT]
    test rdi, rdi
    jz .done
    call widget_draw

.done:
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; Close button text
win_close_char:     db "X", 0

; ════════════════════════════════════════════════════════════════════════════
; WINDOW_ON_KEY - Handle key input
; Input:  RDI = window, ESI = scancode
; Output: EAX = 1 if handled, 0 otherwise
; ════════════════════════════════════════════════════════════════════════════
window_on_key:
    push rbx
    mov rbx, rdi

    ; ESC to close window
    cmp esi, 0x01                   ; ESC scancode
    je .close

    ; Forward to content widget if exists
    mov rdi, [rbx + WIN_CONTENT]
    test rdi, rdi
    jz .not_handled

    ; Forward key to content
    call widget_on_key
    jmp .done

.close:
    ; Call close callback
    mov rax, [rbx + WIN_CLOSE_CB]
    test rax, rax
    jz .hide_window
    mov rdi, rbx
    call rax
    jmp .handled

.hide_window:
    ; Just hide the window
    and dword [rbx + W_FLAGS], ~WF_VISIBLE

.handled:
    mov eax, 1
    jmp .done

.not_handled:
    xor eax, eax

.done:
    pop rbx
    ret

; ════════════════════════════════════════════════════════════════════════════
; WINDOW_ON_CLICK - Handle mouse click
; Input:  RDI = window, ESI = x, EDX = y, ECX = button
; Output: EAX = 1 if handled, 0 otherwise
; ════════════════════════════════════════════════════════════════════════════
window_on_click:
    push rbx
    push r12
    push r13
    push r14

    mov rbx, rdi
    mov r12d, esi                   ; x
    mov r13d, edx                   ; y
    mov r14d, ecx                   ; button

    ; Check if click is on close button
    mov eax, [rbx + W_X]
    add eax, [rbx + W_W]
    sub eax, WIN_CLOSE_BTN_SIZE
    sub eax, 4
    cmp r12d, eax
    jl .not_close_btn

    mov eax, [rbx + W_X]
    add eax, [rbx + W_W]
    sub eax, 4
    cmp r12d, eax
    jge .not_close_btn

    mov eax, [rbx + W_Y]
    mov ecx, [rbx + WIN_TITLE_HEIGHT]
    sub ecx, WIN_CLOSE_BTN_SIZE
    shr ecx, 1
    add eax, ecx
    cmp r13d, eax
    jl .not_close_btn

    add eax, WIN_CLOSE_BTN_SIZE
    cmp r13d, eax
    jge .not_close_btn

    ; Close button clicked
    mov rax, [rbx + WIN_CLOSE_CB]
    test rax, rax
    jz .hide_only
    mov rdi, rbx
    call rax
    jmp .handled

.hide_only:
    and dword [rbx + W_FLAGS], ~WF_VISIBLE
    jmp .handled

.not_close_btn:
    ; Check if click is on title bar (for dragging)
    mov eax, [rbx + W_Y]
    add eax, [rbx + WIN_TITLE_HEIGHT]
    cmp r13d, eax
    jge .check_content

    ; Title bar clicked - start drag
    mov dword [rbx + WIN_DRAG_STATE], DRAG_STATE_MOVING
    ; Calculate offset from window corner
    mov eax, r12d
    sub eax, [rbx + W_X]
    mov [rbx + WIN_DRAG_OFF_X], eax
    mov eax, r13d
    sub eax, [rbx + W_Y]
    mov [rbx + WIN_DRAG_OFF_Y], eax
    jmp .handled

.check_content:
    ; Forward to content widget
    mov rdi, [rbx + WIN_CONTENT]
    test rdi, rdi
    jz .handled

    mov esi, r12d
    mov edx, r13d
    mov ecx, r14d
    call widget_on_click
    jmp .done

.handled:
    mov eax, 1

.done:
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; ════════════════════════════════════════════════════════════════════════════
; WINDOW_ON_FOCUS - Handle focus change
; Input:  RDI = window, ESI = gained (1/0)
; ════════════════════════════════════════════════════════════════════════════
window_on_focus:
    or dword [rdi + W_FLAGS], WF_DIRTY
    ret

; ════════════════════════════════════════════════════════════════════════════
; WINDOW_DESTROY_IMPL - Cleanup
; Input:  RDI = window
; ════════════════════════════════════════════════════════════════════════════
window_destroy_impl:
    push rbx
    mov rbx, rdi

    ; Destroy content widget if exists
    mov rdi, [rbx + WIN_CONTENT]
    test rdi, rdi
    jz .done
    call widget_destroy

.done:
    pop rbx
    ret

; ════════════════════════════════════════════════════════════════════════════
; WINDOW_SET_TITLE - Change window title
; Input:  RDI = window, RSI = title string
; ════════════════════════════════════════════════════════════════════════════
window_set_title:
    test rdi, rdi
    jz .done
    mov [rdi + WIN_TITLE], rsi
    or dword [rdi + W_FLAGS], WF_DIRTY
.done:
    ret

; ════════════════════════════════════════════════════════════════════════════
; WINDOW_SET_CLOSE_CALLBACK - Set close callback
; Input:  RDI = window, RSI = callback function
; ════════════════════════════════════════════════════════════════════════════
window_set_close_callback:
    test rdi, rdi
    jz .done
    mov [rdi + WIN_CLOSE_CB], rsi
.done:
    ret

; ════════════════════════════════════════════════════════════════════════════
; WINDOW_SET_CONTENT - Set content widget
; Input:  RDI = window, RSI = content widget
; ════════════════════════════════════════════════════════════════════════════
window_set_content:
    test rdi, rdi
    jz .done
    mov [rdi + WIN_CONTENT], rsi

    ; Update content position relative to window
    test rsi, rsi
    jz .done

    ; Set content position to window content area
    mov eax, [rdi + W_X]
    add eax, [rdi + WIN_BORDER_WIDTH]
    mov [rsi + W_X], eax

    mov eax, [rdi + W_Y]
    add eax, [rdi + WIN_TITLE_HEIGHT]
    mov [rsi + W_Y], eax

    ; Set parent
    mov [rsi + W_PARENT], rdi

    or dword [rdi + W_FLAGS], WF_DIRTY
.done:
    ret

; ════════════════════════════════════════════════════════════════════════════
; WINDOW_MOVE - Move window to new position
; Input:  RDI = window, ESI = new x, EDX = new y
; ════════════════════════════════════════════════════════════════════════════
window_move:
    test rdi, rdi
    jz .done

    push rbx
    mov rbx, rdi

    ; Calculate delta
    mov eax, esi
    sub eax, [rbx + W_X]
    mov ecx, edx
    sub ecx, [rbx + W_Y]

    ; Update window position
    mov [rbx + W_X], esi
    mov [rbx + W_Y], edx

    ; Update content position if exists
    mov rdi, [rbx + WIN_CONTENT]
    test rdi, rdi
    jz .no_content

    add [rdi + W_X], eax
    add [rdi + W_Y], ecx

.no_content:
    or dword [rbx + W_FLAGS], WF_DIRTY
    pop rbx
.done:
    ret

; ════════════════════════════════════════════════════════════════════════════
; WINDOW_GET_CONTENT_AREA - Get content area dimensions
; Input:  RDI = window
; Output: EAX = x, EDX = y, ECX = w, R8D = h (of content area)
; ════════════════════════════════════════════════════════════════════════════
window_get_content_area:
    test rdi, rdi
    jz .fail

    mov eax, [rdi + W_X]
    add eax, [rdi + WIN_BORDER_WIDTH]

    mov edx, [rdi + W_Y]
    add edx, [rdi + WIN_TITLE_HEIGHT]

    mov ecx, [rdi + W_W]
    sub ecx, [rdi + WIN_BORDER_WIDTH]
    sub ecx, [rdi + WIN_BORDER_WIDTH]

    mov r8d, [rdi + W_H]
    sub r8d, [rdi + WIN_TITLE_HEIGHT]
    sub r8d, [rdi + WIN_BORDER_WIDTH]

    ret

.fail:
    xor eax, eax
    xor edx, edx
    xor ecx, ecx
    xor r8d, r8d
    ret
