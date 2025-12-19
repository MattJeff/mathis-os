; ════════════════════════════════════════════════════════════════════════════
; PATHBAR.ASM - Path Bar Widget (SOLID - Single Responsibility)
; ════════════════════════════════════════════════════════════════════════════
; Displays current directory path
; Example: "📍 /home/mat/projects"
; ════════════════════════════════════════════════════════════════════════════

; ════════════════════════════════════════════════════════════════════════════
; PATHBAR STRUCTURE (extends Widget + 24 bytes)
; ════════════════════════════════════════════════════════════════════════════
PATHBAR_SIZE        equ WIDGET_SIZE + 24

; Extra fields
PB_PATH             equ WIDGET_SIZE + 0     ; Pointer to path string (8 bytes)
PB_BG_COLOR         equ WIDGET_SIZE + 8     ; Background color (4 bytes)
PB_FG_COLOR         equ WIDGET_SIZE + 12    ; Text color (4 bytes)
PB_ICON_COLOR       equ WIDGET_SIZE + 16    ; Icon color (4 bytes)

; ════════════════════════════════════════════════════════════════════════════
; PATHBAR V-TABLE
; ════════════════════════════════════════════════════════════════════════════
pathbar_vtable:
    dq pathbar_draw         ; VT_DRAW
    dq pathbar_on_key       ; VT_ON_KEY
    dq pathbar_on_click     ; VT_ON_CLICK
    dq pathbar_on_focus     ; VT_ON_FOCUS
    dq pathbar_destroy      ; VT_DESTROY

; ════════════════════════════════════════════════════════════════════════════
; PATHBAR_CREATE - Create a pathbar widget
; Input:  ESI = x, EDX = y, ECX = width, R8D = height
;         R9 = initial path string ptr
; Output: RAX = pathbar widget pointer (or 0)
; ════════════════════════════════════════════════════════════════════════════
pathbar_create:
    push rbx
    push r12

    mov r12, r9                     ; Save path

    ; Allocate pathbar
    push rsi
    push rdx
    push rcx
    push r8

    mov rdi, PATHBAR_SIZE
    call kmalloc
    test rax, rax
    jz .fail_pop

    mov rbx, rax

    pop r8
    pop rcx
    pop rdx
    pop rsi

    ; Initialize base widget fields
    lea rax, [pathbar_vtable]
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

    ; Initialize pathbar-specific fields
    mov qword [rbx + PB_PATH], r12
    mov dword [rbx + PB_BG_COLOR], 0x00303030       ; Darker gray
    mov dword [rbx + PB_FG_COLOR], 0x0000FF00       ; Green (path)
    mov dword [rbx + PB_ICON_COLOR], 0x00FFFF00     ; Yellow (icon)

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
; PATHBAR_DRAW - Render the path bar
; Input:  RDI = pathbar widget pointer
; ════════════════════════════════════════════════════════════════════════════
pathbar_draw:
    push rbx
    push r12
    push r13

    mov rbx, rdi

    ; Draw background
    mov edi, [rbx + W_X]
    mov esi, [rbx + W_Y]
    mov edx, [rbx + W_W]
    mov ecx, [rbx + W_H]
    mov r8d, [rbx + PB_BG_COLOR]
    call fill_rect

    ; Draw path text
    mov r12d, [rbx + W_X]
    add r12d, 16                    ; Left padding
    mov r13d, [rbx + W_Y]
    add r13d, 4                     ; Vertical padding

    mov edi, r12d
    mov esi, r13d
    mov rdx, [rbx + PB_PATH]
    test rdx, rdx
    jz .no_path
    mov ecx, [rbx + PB_FG_COLOR]
    call video_text

.no_path:
    pop r13
    pop r12
    pop rbx
    ret

; ════════════════════════════════════════════════════════════════════════════
; PATHBAR_ON_KEY - Handle key input (pathbar doesn't handle keys)
; ════════════════════════════════════════════════════════════════════════════
pathbar_on_key:
    xor eax, eax
    ret

; ════════════════════════════════════════════════════════════════════════════
; PATHBAR_ON_CLICK - Handle click (pathbar doesn't handle clicks)
; ════════════════════════════════════════════════════════════════════════════
pathbar_on_click:
    xor eax, eax
    ret

; ════════════════════════════════════════════════════════════════════════════
; PATHBAR_ON_FOCUS - Handle focus change
; ════════════════════════════════════════════════════════════════════════════
pathbar_on_focus:
    ret

; ════════════════════════════════════════════════════════════════════════════
; PATHBAR_DESTROY - Cleanup
; ════════════════════════════════════════════════════════════════════════════
pathbar_destroy:
    ret

; ════════════════════════════════════════════════════════════════════════════
; PATHBAR_SET_PATH - Change displayed path
; Input:  RDI = pathbar widget, RSI = new path string
; ════════════════════════════════════════════════════════════════════════════
pathbar_set_path:
    test rdi, rdi
    jz .done
    mov [rdi + PB_PATH], rsi
    or dword [rdi + W_FLAGS], WF_DIRTY
.done:
    ret
