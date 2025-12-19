; ════════════════════════════════════════════════════════════════════════════
; DESKTOP_ICON.ASM - Desktop Icon Widget (SOLID - Single Responsibility)
; ════════════════════════════════════════════════════════════════════════════
; Clickable desktop icon with label text.
; Inherits from Widget base class.
; ════════════════════════════════════════════════════════════════════════════

[BITS 64]

; ════════════════════════════════════════════════════════════════════════════
; DESKTOP ICON STRUCTURE (extends Widget - 64 + 48 = 112 bytes)
; ════════════════════════════════════════════════════════════════════════════
; Offset  Size  Field       Description
; ──────────────────────────────────────────────────────────────────────────
;   0-63   64   base        Widget base structure
;  64       8   text        Pointer to label text
;  72       8   callback    Function called on double-click (or 0)
;  80       4   icon_type   ICON_TYPE_* (terminal, folder, cube, file)
;  84       4   icon_color  Icon color
;  88       4   text_color  Text color
;  92       4   selected    1 if selected, 0 otherwise
;  96       8   path        Path string (for file icons, or 0)
; 104       8   reserved    Future use
; ════════════════════════════════════════════════════════════════════════════

DICON_SIZE          equ 112

; Structure offsets (after Widget base)
DICON_TEXT          equ 64
DICON_CALLBACK      equ 72
DICON_TYPE          equ 80
DICON_ICON_COLOR    equ 84
DICON_TEXT_COLOR    equ 88
DICON_SELECTED      equ 92
DICON_PATH          equ 96
DICON_RESERVED      equ 104

; Icon types
ICON_TYPE_TERMINAL  equ 0
ICON_TYPE_FOLDER    equ 1
ICON_TYPE_CUBE      equ 2
ICON_TYPE_FILE      equ 3
ICON_TYPE_CUSTOM    equ 4

; Default colors (32-bit BGRA)
DICON_DEF_TEXT      equ 0x00FFFFFF      ; White text
DICON_DEF_SELECT_BG equ 0x00406080      ; Selection highlight
DICON_COL_WHITE     equ 0x00FFFFFF      ; White for default icon
DICON_COL_CYAN      equ 0x00FFFF00      ; Cyan (BGRA)
DICON_COL_YELLOW    equ 0x0000FFFF      ; Yellow (BGRA)
DICON_COL_GREEN     equ 0x0000FF00      ; Green (BGRA)

; ════════════════════════════════════════════════════════════════════════════
; DESKTOP ICON V-TABLE
; ════════════════════════════════════════════════════════════════════════════
dicon_vtable:
    dq dicon_draw               ; VT_DRAW
    dq dicon_on_key             ; VT_ON_KEY
    dq dicon_on_click           ; VT_ON_CLICK
    dq dicon_on_focus           ; VT_ON_FOCUS
    dq dicon_destroy_impl       ; VT_DESTROY

; ════════════════════════════════════════════════════════════════════════════
; DICON_CREATE - Create a new desktop icon widget
; Input:  ESI = x, EDX = y, R8D = icon_type, R9 = text pointer
; Output: RAX = icon pointer (or 0 on failure)
; ════════════════════════════════════════════════════════════════════════════
dicon_create:
    push rbx
    push r12
    push r13
    push r14

    ; Save params
    mov r12d, esi               ; x
    mov r13d, edx               ; y
    mov r14d, r8d               ; icon_type
    mov rbx, r9                 ; text

    ; Allocate icon
    mov rdi, DICON_SIZE
    call kmalloc
    test rax, rax
    jz .fail

    push rax
    mov rax, [rsp]
    pop rax
    mov rcx, rax                ; rcx = icon

    ; Initialize widget base
    lea rax, [dicon_vtable]
    mov qword [rcx + W_VTABLE], rax
    mov dword [rcx + W_X], r12d
    mov dword [rcx + W_Y], r13d
    mov dword [rcx + W_W], 48           ; Icon width (clickable area)
    mov dword [rcx + W_H], 48           ; Icon height + text
    mov dword [rcx + W_FLAGS], WF_VISIBLE | WF_ENABLED | WF_DIRTY
    mov dword [rcx + W_ID], 0
    mov qword [rcx + W_PARENT], 0
    mov qword [rcx + W_USERDATA], 0
    mov qword [rcx + W_CHILDREN], 0

    ; Generate unique ID
    mov eax, [widget_next_id]
    mov [rcx + W_ID], eax
    inc dword [widget_next_id]

    ; Initialize desktop icon-specific fields
    mov [rcx + DICON_TEXT], rbx
    mov qword [rcx + DICON_CALLBACK], 0
    mov dword [rcx + DICON_TYPE], r14d
    mov dword [rcx + DICON_SELECTED], 0
    mov qword [rcx + DICON_PATH], 0
    mov qword [rcx + DICON_RESERVED], 0

    ; Set default colors based on icon type
    mov dword [rcx + DICON_TEXT_COLOR], DICON_DEF_TEXT

    ; Set icon color based on type
    cmp r14d, ICON_TYPE_TERMINAL
    jne .not_terminal
    mov dword [rcx + DICON_ICON_COLOR], DICON_COL_CYAN
    jmp .color_done
.not_terminal:
    cmp r14d, ICON_TYPE_FOLDER
    jne .not_folder
    mov dword [rcx + DICON_ICON_COLOR], DICON_COL_YELLOW
    jmp .color_done
.not_folder:
    cmp r14d, ICON_TYPE_CUBE
    jne .not_cube
    mov dword [rcx + DICON_ICON_COLOR], DICON_COL_GREEN
    jmp .color_done
.not_cube:
    mov dword [rcx + DICON_ICON_COLOR], DICON_COL_WHITE

.color_done:
    mov rax, rcx
    jmp .done

.fail:
    xor eax, eax

.done:
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; ════════════════════════════════════════════════════════════════════════════
; DICON_DRAW - Draw the desktop icon
; Input:  RDI = icon pointer
; ════════════════════════════════════════════════════════════════════════════
dicon_draw:
    push rbx
    push r12
    push r13
    push r14

    mov rbx, rdi                    ; rbx = icon

    ; Get position
    mov r12d, [rbx + W_X]           ; x
    mov r13d, [rbx + W_Y]           ; y

    ; Draw selection background if selected
    cmp dword [rbx + DICON_SELECTED], 1
    jne .no_selection

    mov edi, r12d
    sub edi, 4
    mov esi, r13d
    sub esi, 4
    mov edx, 56                     ; width
    mov ecx, 56                     ; height
    mov r8d, DICON_DEF_SELECT_BG
    call fill_rect

.no_selection:
    ; Draw icon based on type
    mov r14d, [rbx + DICON_TYPE]
    mov edi, r12d
    mov esi, r13d
    mov edx, [rbx + DICON_ICON_COLOR]

    cmp r14d, ICON_TYPE_TERMINAL
    jne .try_folder
    call draw_icon_terminal
    jmp .draw_text

.try_folder:
    cmp r14d, ICON_TYPE_FOLDER
    jne .try_cube
    call draw_icon_folder
    jmp .draw_text

.try_cube:
    cmp r14d, ICON_TYPE_CUBE
    jne .try_file
    call draw_icon_cube
    jmp .draw_text

.try_file:
    ; Default: draw file icon (simple rectangle)
    call dicon_draw_file_icon

.draw_text:
    ; Draw label text below icon
    mov rsi, [rbx + DICON_TEXT]
    test rsi, rsi
    jz .done

    ; Calculate text X (centered under icon)
    mov rdi, rsi
    call dicon_strlen
    shl eax, 3                      ; * 8 pixels per char
    mov r14d, eax                   ; text_width

    mov edi, r12d                   ; icon x
    add edi, 24                     ; center of icon (48/2)
    sub edi, r14d
    shr edi, 1                      ; Oops, this is wrong
    ; Actually: x = icon_x + (icon_w - text_w) / 2
    mov edi, r12d
    mov eax, 48
    sub eax, r14d
    shr eax, 1
    add edi, eax

    ; Text Y = icon_y + 32 + 4 (below icon with padding)
    mov esi, r13d
    add esi, 36

    ; Draw text
    mov rdx, [rbx + DICON_TEXT]
    mov ecx, [rbx + DICON_TEXT_COLOR]
    call video_text

.done:
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; ════════════════════════════════════════════════════════════════════════════
; DICON_DRAW_FILE_ICON - Draw a generic file icon
; Input:  EDI = x, ESI = y, EDX = color
; ════════════════════════════════════════════════════════════════════════════
dicon_draw_file_icon:
    push rbx
    push r12
    push r13
    push r14

    mov r12d, edi               ; x
    mov r13d, esi               ; y
    mov r14d, edx               ; color

    ; Draw document shape (rectangle with folded corner)
    ; Main body
    mov edi, r12d
    add edi, 8
    mov esi, r13d
    mov edx, 16                 ; width
    mov ecx, 24                 ; height
    mov r8d, r14d
    call fill_rect

    ; Folded corner (top-right)
    mov edi, r12d
    add edi, 18
    mov esi, r13d
    mov edx, 6
    mov ecx, 6
    mov r8d, 0x00A0A0A0         ; Lighter shade
    call fill_rect

    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; ════════════════════════════════════════════════════════════════════════════
; DICON_STRLEN - Get string length
; Input:  RDI = string pointer
; Output: EAX = length
; ════════════════════════════════════════════════════════════════════════════
dicon_strlen:
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
; DICON_ON_KEY - Handle key input
; Input:  RDI = icon, ESI = scancode
; Output: EAX = 1 if handled, 0 otherwise
; ════════════════════════════════════════════════════════════════════════════
dicon_on_key:
    push rbx
    mov rbx, rdi

    ; Enter key activates icon
    cmp esi, 0x1C               ; Enter scancode
    jne .not_handled

    ; Call callback
    mov rax, [rbx + DICON_CALLBACK]
    test rax, rax
    jz .no_callback
    mov rdi, rbx
    call rax

.no_callback:
    mov eax, 1
    jmp .done

.not_handled:
    xor eax, eax

.done:
    pop rbx
    ret

; ════════════════════════════════════════════════════════════════════════════
; DICON_ON_CLICK - Handle mouse click (double-click activates)
; Input:  RDI = icon, ESI = x, EDX = y, ECX = button
; Output: EAX = 1 if handled, 0 otherwise
; ════════════════════════════════════════════════════════════════════════════
dicon_on_click:
    push rbx
    push r12
    mov rbx, rdi

    ; Only handle left click
    cmp ecx, 1
    jne .not_handled

    ; Select icon
    mov dword [rbx + DICON_SELECTED], 1
    or dword [rbx + W_FLAGS], WF_DIRTY

    ; Check for double-click (using simple tick-based detection)
    mov r12, [tick_count]
    mov rax, [dicon_last_click_tick]
    sub r12, rax
    cmp r12, 30                 ; ~300ms window for double-click
    ja .single_click

    ; Double-click: activate
    mov rax, [rbx + DICON_CALLBACK]
    test rax, rax
    jz .single_click
    mov rdi, rbx
    call rax
    jmp .handled

.single_click:
    ; Update last click time
    mov rax, [tick_count]
    mov [dicon_last_click_tick], rax

.handled:
    mov eax, 1
    jmp .done

.not_handled:
    xor eax, eax

.done:
    pop r12
    pop rbx
    ret

; ════════════════════════════════════════════════════════════════════════════
; DICON_ON_FOCUS - Handle focus change
; Input:  RDI = icon, ESI = gained (1/0)
; ════════════════════════════════════════════════════════════════════════════
dicon_on_focus:
    or dword [rdi + W_FLAGS], WF_DIRTY
    ret

; ════════════════════════════════════════════════════════════════════════════
; DICON_DESTROY_IMPL - Cleanup
; Input:  RDI = icon
; ════════════════════════════════════════════════════════════════════════════
dicon_destroy_impl:
    ret

; ════════════════════════════════════════════════════════════════════════════
; DICON_SET_CALLBACK - Set activation callback
; Input:  RDI = icon, RSI = callback function pointer
; ════════════════════════════════════════════════════════════════════════════
dicon_set_callback:
    test rdi, rdi
    jz .done
    mov [rdi + DICON_CALLBACK], rsi
.done:
    ret

; ════════════════════════════════════════════════════════════════════════════
; DICON_SET_PATH - Set file path (for file icons)
; Input:  RDI = icon, RSI = path string
; ════════════════════════════════════════════════════════════════════════════
dicon_set_path:
    test rdi, rdi
    jz .done
    mov [rdi + DICON_PATH], rsi
.done:
    ret

; ════════════════════════════════════════════════════════════════════════════
; DICON_DESELECT - Clear selection
; Input:  RDI = icon
; ════════════════════════════════════════════════════════════════════════════
dicon_deselect:
    test rdi, rdi
    jz .done
    mov dword [rdi + DICON_SELECTED], 0
    or dword [rdi + W_FLAGS], WF_DIRTY
.done:
    ret

; ════════════════════════════════════════════════════════════════════════════
; DATA
; ════════════════════════════════════════════════════════════════════════════
dicon_last_click_tick:  dq 0
