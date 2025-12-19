; ════════════════════════════════════════════════════════════════════════════
; STATUSBAR.ASM - Status Bar Widget (SOLID - Single Responsibility)
; ════════════════════════════════════════════════════════════════════════════
; Displays keyboard shortcuts and status info at bottom
; Example: "[W/S] Navigate  [ENTER] Open  [N] New  [D] Del  [R] Rename"
; ════════════════════════════════════════════════════════════════════════════

; ════════════════════════════════════════════════════════════════════════════
; STATUSBAR STRUCTURE (extends Widget + 32 bytes)
; ════════════════════════════════════════════════════════════════════════════
STATUSBAR_SIZE      equ WIDGET_SIZE + 32

; Extra fields
SB_TEXT             equ WIDGET_SIZE + 0     ; Pointer to status text (8 bytes)
SB_TEXT2            equ WIDGET_SIZE + 8     ; Second line text (8 bytes)
SB_BG_COLOR         equ WIDGET_SIZE + 16    ; Background color (4 bytes)
SB_FG_COLOR         equ WIDGET_SIZE + 20    ; Text color (4 bytes)
SB_KEY_COLOR        equ WIDGET_SIZE + 24    ; Key highlight color (4 bytes)

; ════════════════════════════════════════════════════════════════════════════
; STATUSBAR V-TABLE
; ════════════════════════════════════════════════════════════════════════════
statusbar_vtable:
    dq statusbar_draw       ; VT_DRAW
    dq statusbar_on_key     ; VT_ON_KEY
    dq statusbar_on_click   ; VT_ON_CLICK
    dq statusbar_on_focus   ; VT_ON_FOCUS
    dq statusbar_destroy    ; VT_DESTROY

; ════════════════════════════════════════════════════════════════════════════
; STATUSBAR_CREATE - Create a statusbar widget
; Input:  ESI = x, EDX = y, ECX = width, R8D = height
; Output: RAX = statusbar widget pointer (or 0)
; ════════════════════════════════════════════════════════════════════════════
statusbar_create:
    push rbx
    push r12
    push r13
    push r14
    push r15

    mov r12d, esi
    mov r13d, edx
    mov r14d, ecx
    mov r15d, r8d

    ; Allocate statusbar
    mov rdi, STATUSBAR_SIZE
    call kmalloc
    test rax, rax
    jz .fail

    mov rbx, rax

    ; Initialize base widget fields
    lea rax, [statusbar_vtable]
    mov qword [rbx + W_VTABLE], rax
    mov dword [rbx + W_X], r12d
    mov dword [rbx + W_Y], r13d
    mov dword [rbx + W_W], r14d
    mov dword [rbx + W_H], r15d
    mov dword [rbx + W_FLAGS], WF_VISIBLE | WF_DIRTY
    mov ecx, [widget_next_id]
    mov [rbx + W_ID], ecx
    inc dword [widget_next_id]
    mov qword [rbx + W_PARENT], 0
    mov qword [rbx + W_USERDATA], 0
    mov qword [rbx + W_CHILDREN], 0

    ; Initialize statusbar specific fields
    mov qword [rbx + SB_TEXT], sb_default_text
    mov qword [rbx + SB_TEXT2], sb_default_text2
    mov dword [rbx + SB_BG_COLOR], 0x00303030       ; Dark gray
    mov dword [rbx + SB_FG_COLOR], 0x00AAAAAA       ; Light gray
    mov dword [rbx + SB_KEY_COLOR], 0x00FFFF00      ; Yellow for keys

    mov rax, rbx
    jmp .done

.fail:
    xor eax, eax

.done:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; ════════════════════════════════════════════════════════════════════════════
; STATUSBAR_DRAW - Render the status bar
; Input:  RDI = statusbar widget pointer
; ════════════════════════════════════════════════════════════════════════════
statusbar_draw:
    push rbx
    push r12
    push r13

    mov rbx, rdi

    ; Draw background
    mov edi, [rbx + W_X]
    mov esi, [rbx + W_Y]
    mov edx, [rbx + W_W]
    mov ecx, [rbx + W_H]
    mov r8d, [rbx + SB_BG_COLOR]
    call fill_rect

    ; Draw first line of text
    mov r12d, [rbx + W_X]
    add r12d, 12
    mov r13d, [rbx + W_Y]
    add r13d, 4

    mov edi, r12d
    mov esi, r13d
    mov rdx, [rbx + SB_TEXT]
    test rdx, rdx
    jz .no_text1
    mov ecx, [rbx + SB_FG_COLOR]
    call video_text

.no_text1:
    ; Draw second line if height allows
    cmp dword [rbx + W_H], 24
    jl .no_text2

    add r13d, 12
    mov edi, r12d
    mov esi, r13d
    mov rdx, [rbx + SB_TEXT2]
    test rdx, rdx
    jz .no_text2
    mov ecx, [rbx + SB_FG_COLOR]
    call video_text

.no_text2:
    pop r13
    pop r12
    pop rbx
    ret

; ════════════════════════════════════════════════════════════════════════════
; STATUSBAR_ON_KEY - Handle key (statusbar doesn't handle keys)
; ════════════════════════════════════════════════════════════════════════════
statusbar_on_key:
    xor eax, eax
    ret

; ════════════════════════════════════════════════════════════════════════════
; STATUSBAR_ON_CLICK - Handle click (statusbar doesn't handle clicks)
; ════════════════════════════════════════════════════════════════════════════
statusbar_on_click:
    xor eax, eax
    ret

; ════════════════════════════════════════════════════════════════════════════
; STATUSBAR_ON_FOCUS
; ════════════════════════════════════════════════════════════════════════════
statusbar_on_focus:
    ret

; ════════════════════════════════════════════════════════════════════════════
; STATUSBAR_DESTROY
; ════════════════════════════════════════════════════════════════════════════
statusbar_destroy:
    ret

; ════════════════════════════════════════════════════════════════════════════
; STATUSBAR_SET_TEXT - Set status text
; Input:  RDI = widget, RSI = line1, RDX = line2 (or 0)
; ════════════════════════════════════════════════════════════════════════════
statusbar_set_text:
    test rdi, rdi
    jz .done
    mov [rdi + SB_TEXT], rsi
    mov [rdi + SB_TEXT2], rdx
    or dword [rdi + W_FLAGS], WF_DIRTY
.done:
    ret

; ════════════════════════════════════════════════════════════════════════════
; DATA
; ════════════════════════════════════════════════════════════════════════════
sb_default_text:    db "[W/S] Navigate  [ENTER] Open  [N] New  [D] Del  [R] Rename", 0
sb_default_text2:   db "[TAB] Switch mode  [ESC] Back", 0
