; ════════════════════════════════════════════════════════════════════════════
; WIDGET.ASM - Base Widget Class (SOLID - Single Responsibility)
; ════════════════════════════════════════════════════════════════════════════
; Abstract base class for all UI widgets
; All widgets inherit this structure and implement the V-Table methods
; ════════════════════════════════════════════════════════════════════════════

; ════════════════════════════════════════════════════════════════════════════
; WIDGET STRUCTURE (64 bytes)
; ════════════════════════════════════════════════════════════════════════════
; Offset  Size  Field       Description
; ──────────────────────────────────────────────────────────────────────────
;   0      8    vtable      Pointer to V-Table (methods)
;   8      4    x           X position
;  12      4    y           Y position
;  16      4    w           Width
;  20      4    h           Height
;  24      4    flags       VISIBLE, ENABLED, FOCUSED, DIRTY
;  28      4    id          Widget unique ID
;  32      8    parent      Pointer to parent widget (or 0)
;  40      8    userdata    Custom data pointer
;  48      8    children    Pointer to children list (or 0)
;  56      8    reserved    Future use
; ════════════════════════════════════════════════════════════════════════════

WIDGET_SIZE         equ 64

; Structure offsets
W_VTABLE            equ 0
W_X                 equ 8
W_Y                 equ 12
W_W                 equ 16
W_H                 equ 20
W_FLAGS             equ 24
W_ID                equ 28
W_PARENT            equ 32
W_USERDATA          equ 40
W_CHILDREN          equ 48
W_RESERVED          equ 56

; ════════════════════════════════════════════════════════════════════════════
; WIDGET FLAGS
; ════════════════════════════════════════════════════════════════════════════
WF_VISIBLE          equ 0x01    ; Widget is visible
WF_ENABLED          equ 0x02    ; Widget accepts input
WF_FOCUSED          equ 0x04    ; Widget has focus
WF_DIRTY            equ 0x08    ; Widget needs redraw
WF_MODAL            equ 0x10    ; Widget blocks input to others

; ════════════════════════════════════════════════════════════════════════════
; V-TABLE OFFSETS (all widgets implement these)
; ════════════════════════════════════════════════════════════════════════════
VT_DRAW             equ 0       ; draw(self) - render widget
VT_ON_KEY           equ 8       ; on_key(self, scancode) -> handled (1/0)
VT_ON_CLICK         equ 16      ; on_click(self, x, y, btn) -> handled (1/0)
VT_ON_FOCUS         equ 24      ; on_focus(self, gained) - focus changed
VT_DESTROY          equ 32      ; destroy(self) - cleanup and free

; ════════════════════════════════════════════════════════════════════════════
; WIDGET_CREATE - Allocate and initialize a widget
; Input:  RDI = vtable pointer
;         ESI = x, EDX = y, ECX = w, R8D = h
; Output: RAX = widget pointer (or 0 on failure)
; ════════════════════════════════════════════════════════════════════════════
widget_create:
    push rbx
    push r12
    push r13
    push r14
    push r15

    ; Save params
    mov r12, rdi                    ; vtable
    mov r13d, esi                   ; x
    mov r14d, edx                   ; y
    mov r15d, ecx                   ; w
    mov ebx, r8d                    ; h

    ; Allocate widget
    mov rdi, WIDGET_SIZE
    call kmalloc
    test rax, rax
    jz .fail

    ; Initialize structure
    mov qword [rax + W_VTABLE], r12
    mov dword [rax + W_X], r13d
    mov dword [rax + W_Y], r14d
    mov dword [rax + W_W], r15d
    mov dword [rax + W_H], ebx
    mov dword [rax + W_FLAGS], WF_VISIBLE | WF_ENABLED | WF_DIRTY
    mov dword [rax + W_ID], 0
    mov qword [rax + W_PARENT], 0
    mov qword [rax + W_USERDATA], 0
    mov qword [rax + W_CHILDREN], 0
    mov qword [rax + W_RESERVED], 0

    ; Generate unique ID
    mov ecx, [widget_next_id]
    mov [rax + W_ID], ecx
    inc dword [widget_next_id]

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
; WIDGET_DESTROY - Call destructor and free memory
; Input:  RDI = widget pointer
; ════════════════════════════════════════════════════════════════════════════
widget_destroy:
    test rdi, rdi
    jz .done

    push rbx
    mov rbx, rdi

    ; Call vtable destroy method
    mov rax, [rbx + W_VTABLE]
    test rax, rax
    jz .free
    call [rax + VT_DESTROY]

.free:
    mov rdi, rbx
    call kfree

    pop rbx
.done:
    ret

; ════════════════════════════════════════════════════════════════════════════
; WIDGET_DRAW - Call draw method via vtable
; Input:  RDI = widget pointer
; ════════════════════════════════════════════════════════════════════════════
widget_draw:
    test rdi, rdi
    jz .done

    ; Check if visible
    test dword [rdi + W_FLAGS], WF_VISIBLE
    jz .done

    ; Call vtable draw method
    mov rax, [rdi + W_VTABLE]
    test rax, rax
    jz .done
    call [rax + VT_DRAW]

    ; Clear dirty flag
    and dword [rdi + W_FLAGS], ~WF_DIRTY

.done:
    ret

; ════════════════════════════════════════════════════════════════════════════
; WIDGET_ON_KEY - Forward key event to widget
; Input:  RDI = widget pointer, ESI = scancode
; Output: EAX = 1 if handled, 0 otherwise
; ════════════════════════════════════════════════════════════════════════════
widget_on_key:
    test rdi, rdi
    jz .not_handled

    ; Check if enabled and focused
    mov eax, [rdi + W_FLAGS]
    test eax, WF_ENABLED
    jz .not_handled
    test eax, WF_FOCUSED
    jz .not_handled

    ; Call vtable on_key method
    mov rax, [rdi + W_VTABLE]
    test rax, rax
    jz .not_handled
    call [rax + VT_ON_KEY]
    ret

.not_handled:
    xor eax, eax
    ret

; ════════════════════════════════════════════════════════════════════════════
; WIDGET_ON_CLICK - Forward click event to widget
; Input:  RDI = widget pointer, ESI = x, EDX = y, ECX = button
; Output: EAX = 1 if handled, 0 otherwise
; ════════════════════════════════════════════════════════════════════════════
widget_on_click:
    test rdi, rdi
    jz .not_handled

    ; Check if enabled and visible
    mov eax, [rdi + W_FLAGS]
    test eax, WF_ENABLED
    jz .not_handled
    test eax, WF_VISIBLE
    jz .not_handled

    ; Check if click is inside widget bounds
    push rdi
    push rsi
    push rdx

    ; x >= widget.x
    cmp esi, [rdi + W_X]
    jl .outside
    ; x < widget.x + widget.w
    mov eax, [rdi + W_X]
    add eax, [rdi + W_W]
    cmp esi, eax
    jge .outside
    ; y >= widget.y
    cmp edx, [rdi + W_Y]
    jl .outside
    ; y < widget.y + widget.h
    mov eax, [rdi + W_Y]
    add eax, [rdi + W_H]
    cmp edx, eax
    jge .outside

    pop rdx
    pop rsi
    pop rdi

    ; Call vtable on_click method
    mov rax, [rdi + W_VTABLE]
    test rax, rax
    jz .not_handled
    call [rax + VT_ON_CLICK]
    ret

.outside:
    pop rdx
    pop rsi
    pop rdi

.not_handled:
    xor eax, eax
    ret

; ════════════════════════════════════════════════════════════════════════════
; WIDGET_SET_FOCUS - Set or clear focus on widget
; Input:  RDI = widget pointer, ESI = 1 to focus, 0 to unfocus
; ════════════════════════════════════════════════════════════════════════════
widget_set_focus:
    test rdi, rdi
    jz .done

    push rbx
    mov rbx, rdi

    test esi, esi
    jz .clear_focus

    ; Set focus
    or dword [rbx + W_FLAGS], WF_FOCUSED | WF_DIRTY
    jmp .call_handler

.clear_focus:
    and dword [rbx + W_FLAGS], ~WF_FOCUSED
    or dword [rbx + W_FLAGS], WF_DIRTY

.call_handler:
    ; Call vtable on_focus method
    mov rax, [rbx + W_VTABLE]
    test rax, rax
    jz .no_handler
    mov rdi, rbx
    call [rax + VT_ON_FOCUS]

.no_handler:
    pop rbx
.done:
    ret

; ════════════════════════════════════════════════════════════════════════════
; WIDGET_MARK_DIRTY - Mark widget for redraw
; Input:  RDI = widget pointer
; ════════════════════════════════════════════════════════════════════════════
widget_mark_dirty:
    test rdi, rdi
    jz .done
    or dword [rdi + W_FLAGS], WF_DIRTY
.done:
    ret

; ════════════════════════════════════════════════════════════════════════════
; WIDGET_IS_DIRTY - Check if widget needs redraw
; Input:  RDI = widget pointer
; Output: EAX = 1 if dirty, 0 otherwise
; ════════════════════════════════════════════════════════════════════════════
widget_is_dirty:
    xor eax, eax
    test rdi, rdi
    jz .done
    test dword [rdi + W_FLAGS], WF_DIRTY
    jz .done
    mov eax, 1
.done:
    ret

; ════════════════════════════════════════════════════════════════════════════
; DATA
; ════════════════════════════════════════════════════════════════════════════
widget_next_id:     dd 1
