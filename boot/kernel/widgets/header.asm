; ════════════════════════════════════════════════════════════════════════════
; HEADER.ASM - Header Bar Widget (SOLID - Single Responsibility)
; ════════════════════════════════════════════════════════════════════════════
; Displays title and action buttons (e.g., [ESC] Back)
; Example: "📁 FILES                              [ESC] Back"
; ════════════════════════════════════════════════════════════════════════════

; ════════════════════════════════════════════════════════════════════════════
; HEADER STRUCTURE (extends Widget + 32 bytes)
; ════════════════════════════════════════════════════════════════════════════
HEADER_SIZE         equ WIDGET_SIZE + 32

; Extra fields (after Widget base)
H_TITLE             equ WIDGET_SIZE + 0     ; Pointer to title string (8 bytes)
H_ACTION_TEXT       equ WIDGET_SIZE + 8     ; Pointer to action text (8 bytes)
H_BG_COLOR          equ WIDGET_SIZE + 16    ; Background color (4 bytes)
H_FG_COLOR          equ WIDGET_SIZE + 20    ; Foreground/text color (4 bytes)
H_RESERVED          equ WIDGET_SIZE + 24    ; Reserved (8 bytes)

; ════════════════════════════════════════════════════════════════════════════
; HEADER V-TABLE
; ════════════════════════════════════════════════════════════════════════════
header_vtable:
    dq header_draw          ; VT_DRAW
    dq header_on_key        ; VT_ON_KEY
    dq header_on_click      ; VT_ON_CLICK
    dq header_on_focus      ; VT_ON_FOCUS
    dq header_destroy       ; VT_DESTROY

; ════════════════════════════════════════════════════════════════════════════
; HEADER_CREATE - Create a header widget
; Input:  ESI = x, EDX = y, ECX = width, R8D = height
;         R9 = title string ptr
; Output: RAX = header widget pointer (or 0)
; ════════════════════════════════════════════════════════════════════════════
header_create:
    push rbx
    push r12

    mov r12, r9                     ; Save title

    ; Allocate header (larger than base widget)
    push rsi
    push rdx
    push rcx
    push r8

    mov rdi, HEADER_SIZE
    call kmalloc
    test rax, rax
    jz .fail_pop

    mov rbx, rax

    pop r8
    pop rcx
    pop rdx
    pop rsi

    ; Initialize base widget fields
    lea rax, [header_vtable]
    mov qword [rbx + W_VTABLE], rax
    mov dword [rbx + W_X], esi
    mov dword [rbx + W_Y], edx
    mov dword [rbx + W_W], ecx
    mov dword [rbx + W_H], r8d
    mov dword [rbx + W_FLAGS], WF_VISIBLE | WF_ENABLED | WF_DIRTY
    mov ecx, [widget_next_id]
    mov [rbx + W_ID], ecx
    inc dword [widget_next_id]
    mov qword [rbx + W_PARENT], 0
    mov qword [rbx + W_USERDATA], 0
    mov qword [rbx + W_CHILDREN], 0

    ; Initialize header-specific fields
    mov qword [rbx + H_TITLE], r12
    mov qword [rbx + H_ACTION_TEXT], header_default_action
    mov dword [rbx + H_BG_COLOR], 0x00404040     ; Dark gray
    mov dword [rbx + H_FG_COLOR], 0x00FFFFFF     ; White

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
; HEADER_DRAW - Render the header bar
; Input:  RDI = header widget pointer
; ════════════════════════════════════════════════════════════════════════════
header_draw:
    push rbx
    push r12
    push r13
    push r14
    push r15

    mov rbx, rdi

    ; Draw background
    mov edi, [rbx + W_X]
    mov esi, [rbx + W_Y]
    mov edx, [rbx + W_W]
    mov ecx, [rbx + W_H]
    mov r8d, [rbx + H_BG_COLOR]
    call fill_rect

    ; Draw title (left side)
    mov r12d, [rbx + W_X]
    add r12d, 16                    ; Left padding
    mov r13d, [rbx + W_Y]
    add r13d, 6                     ; Center vertically (assuming 20px height)

    mov edi, r12d
    mov esi, r13d
    mov rdx, [rbx + H_TITLE]
    mov ecx, [rbx + H_FG_COLOR]
    call video_text

    ; Draw action text (right side)
    mov rdi, [rbx + H_ACTION_TEXT]
    test rdi, rdi
    jz .no_action

    ; Calculate right position (action text is ~10 chars = 80px)
    mov r14d, [rbx + W_X]
    add r14d, [rbx + W_W]
    sub r14d, 100                   ; Right padding

    mov edi, r14d
    mov esi, r13d
    mov rdx, [rbx + H_ACTION_TEXT]
    mov ecx, [rbx + H_FG_COLOR]
    call video_text

.no_action:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; ════════════════════════════════════════════════════════════════════════════
; HEADER_ON_KEY - Handle key input (header doesn't handle keys)
; Input:  RDI = widget, ESI = scancode
; Output: EAX = 0 (not handled)
; ════════════════════════════════════════════════════════════════════════════
header_on_key:
    xor eax, eax
    ret

; ════════════════════════════════════════════════════════════════════════════
; HEADER_ON_CLICK - Handle click (header doesn't handle clicks)
; Input:  RDI = widget, ESI = x, EDX = y, ECX = button
; Output: EAX = 0 (not handled)
; ════════════════════════════════════════════════════════════════════════════
header_on_click:
    xor eax, eax
    ret

; ════════════════════════════════════════════════════════════════════════════
; HEADER_ON_FOCUS - Handle focus change
; Input:  RDI = widget, ESI = gained (1/0)
; ════════════════════════════════════════════════════════════════════════════
header_on_focus:
    ret

; ════════════════════════════════════════════════════════════════════════════
; HEADER_DESTROY - Cleanup header widget
; Input:  RDI = header widget pointer
; ════════════════════════════════════════════════════════════════════════════
header_destroy:
    ; Nothing to free (strings are static)
    ret

; ════════════════════════════════════════════════════════════════════════════
; HEADER_SET_TITLE - Change header title
; Input:  RDI = header widget, RSI = new title string
; ════════════════════════════════════════════════════════════════════════════
header_set_title:
    test rdi, rdi
    jz .done
    mov [rdi + H_TITLE], rsi
    or dword [rdi + W_FLAGS], WF_DIRTY
.done:
    ret

; ════════════════════════════════════════════════════════════════════════════
; HEADER_SET_ACTION - Change action text
; Input:  RDI = header widget, RSI = new action string
; ════════════════════════════════════════════════════════════════════════════
header_set_action:
    test rdi, rdi
    jz .done
    mov [rdi + H_ACTION_TEXT], rsi
    or dword [rdi + W_FLAGS], WF_DIRTY
.done:
    ret

; ════════════════════════════════════════════════════════════════════════════
; DATA
; ════════════════════════════════════════════════════════════════════════════
header_default_action:  db "[ESC] Back", 0
