; ════════════════════════════════════════════════════════════════════════════
; CONTAINER.ASM - Container Widget (Parent for Multiple Children)
; ════════════════════════════════════════════════════════════════════════════
; Widget that can hold multiple child widgets.
; Handles drawing and event routing to children.
; Inherits from Widget base class.
; ════════════════════════════════════════════════════════════════════════════

; ════════════════════════════════════════════════════════════════════════════
; CONTAINER STRUCTURE (extends Widget - 64 + 32 = 96 bytes)
; ════════════════════════════════════════════════════════════════════════════
; Offset  Size  Field         Description
; ──────────────────────────────────────────────────────────────────────────
;   0-63   64   base          Widget base structure
;  64       8   children_arr  Pointer to children array
;  72       4   child_count   Number of children
;  76       4   child_cap     Capacity of children array
;  80       4   bg_color      Background color (0 = transparent)
;  84       4   padding       Inner padding
;  88       4   spacing       Spacing between children
;  92       4   layout        LAYOUT_*
; ════════════════════════════════════════════════════════════════════════════

CONTAINER_SIZE      equ 96

; Structure offsets (after Widget base)
CONT_CHILDREN       equ 64
CONT_CHILD_COUNT    equ 72
CONT_CHILD_CAP      equ 76
CONT_BG_COLOR       equ 80
CONT_PADDING        equ 84
CONT_SPACING        equ 88
CONT_LAYOUT         equ 92

; Layout modes
LAYOUT_NONE         equ 0           ; Manual positioning
LAYOUT_VERTICAL     equ 1           ; Stack vertically
LAYOUT_HORIZONTAL   equ 2           ; Stack horizontally

; Default values
CONT_DEF_CAPACITY   equ 16
CONT_DEF_BG         equ 0x00000000  ; Transparent
CONT_DEF_PADDING    equ 0
CONT_DEF_SPACING    equ 4

; ════════════════════════════════════════════════════════════════════════════
; CONTAINER V-TABLE
; ════════════════════════════════════════════════════════════════════════════
container_vtable:
    dq container_draw           ; VT_DRAW
    dq container_on_key         ; VT_ON_KEY
    dq container_on_click       ; VT_ON_CLICK
    dq container_on_focus       ; VT_ON_FOCUS
    dq container_destroy_impl   ; VT_DESTROY

; ════════════════════════════════════════════════════════════════════════════
; CONTAINER_CREATE - Create a new container widget
; Input:  ESI = x, EDX = y, ECX = w, R8D = h
; Output: RAX = container pointer (or 0 on failure)
; ════════════════════════════════════════════════════════════════════════════
container_create:
    push rbx
    push r12
    push r13
    push r14
    push r15

    ; Save params
    mov r12d, esi                   ; x
    mov r13d, edx                   ; y
    mov r14d, ecx                   ; w
    mov r15d, r8d                   ; h

    ; Allocate container
    mov rdi, CONTAINER_SIZE
    call kmalloc
    test rax, rax
    jz .fail

    mov rbx, rax

    ; Allocate children array
    mov rdi, CONT_DEF_CAPACITY * 8  ; Array of pointers
    call kmalloc
    test rax, rax
    jz .fail_free_container

    mov [rbx + CONT_CHILDREN], rax

    ; Initialize widget base
    lea rax, [container_vtable]
    mov qword [rbx + W_VTABLE], rax
    mov dword [rbx + W_X], r12d
    mov dword [rbx + W_Y], r13d
    mov dword [rbx + W_W], r14d
    mov dword [rbx + W_H], r15d
    mov dword [rbx + W_FLAGS], WF_VISIBLE | WF_ENABLED | WF_DIRTY
    mov dword [rbx + W_ID], 0
    mov qword [rbx + W_PARENT], 0
    mov qword [rbx + W_USERDATA], 0
    mov qword [rbx + W_CHILDREN], 0

    ; Generate unique ID
    mov eax, [widget_next_id]
    mov [rbx + W_ID], eax
    inc dword [widget_next_id]

    ; Initialize container-specific fields
    mov dword [rbx + CONT_CHILD_COUNT], 0
    mov dword [rbx + CONT_CHILD_CAP], CONT_DEF_CAPACITY
    mov dword [rbx + CONT_BG_COLOR], CONT_DEF_BG
    mov dword [rbx + CONT_PADDING], CONT_DEF_PADDING
    mov dword [rbx + CONT_SPACING], CONT_DEF_SPACING
    mov dword [rbx + CONT_LAYOUT], LAYOUT_NONE

    mov rax, rbx
    jmp .done

.fail_free_container:
    mov rdi, rbx
    call kfree
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
; CONTAINER_DRAW - Draw container and all children
; Input:  RDI = container pointer
; ════════════════════════════════════════════════════════════════════════════
container_draw:
    push rbx
    push r12
    push r13

    mov rbx, rdi                    ; rbx = container

    ; Draw background if not transparent
    mov eax, [rbx + CONT_BG_COLOR]
    test eax, eax
    jz .no_background

    mov edi, [rbx + W_X]
    mov esi, [rbx + W_Y]
    mov edx, [rbx + W_W]
    mov ecx, [rbx + W_H]
    mov r8d, eax
    call fill_rect

.no_background:
    ; Draw all children
    mov r12d, [rbx + CONT_CHILD_COUNT]
    test r12d, r12d
    jz .done

    mov r13, [rbx + CONT_CHILDREN]
    xor ecx, ecx                    ; index

.draw_loop:
    cmp ecx, r12d
    jge .done

    push rcx
    mov rdi, [r13 + rcx*8]          ; Get child pointer
    test rdi, rdi
    jz .next_child
    call widget_draw

.next_child:
    pop rcx
    inc ecx
    jmp .draw_loop

.done:
    pop r13
    pop r12
    pop rbx
    ret

; ════════════════════════════════════════════════════════════════════════════
; CONTAINER_ON_KEY - Forward key to focused child
; Input:  RDI = container, ESI = scancode
; Output: EAX = 1 if handled, 0 otherwise
; ════════════════════════════════════════════════════════════════════════════
container_on_key:
    push rbx
    push r12
    push r13
    push r14

    mov rbx, rdi
    mov r14d, esi                   ; scancode

    ; Find focused child and forward key
    mov r12d, [rbx + CONT_CHILD_COUNT]
    test r12d, r12d
    jz .not_handled

    mov r13, [rbx + CONT_CHILDREN]
    xor ecx, ecx

.find_focused:
    cmp ecx, r12d
    jge .not_handled

    push rcx
    mov rdi, [r13 + rcx*8]
    test rdi, rdi
    jz .next_key

    ; Check if focused
    test dword [rdi + W_FLAGS], WF_FOCUSED
    jz .next_key

    ; Forward key
    mov esi, r14d
    call widget_on_key
    pop rcx
    jmp .done

.next_key:
    pop rcx
    inc ecx
    jmp .find_focused

.not_handled:
    xor eax, eax

.done:
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; ════════════════════════════════════════════════════════════════════════════
; CONTAINER_ON_CLICK - Forward click to appropriate child
; Input:  RDI = container, ESI = x, EDX = y, ECX = button
; Output: EAX = 1 if handled, 0 otherwise
; ════════════════════════════════════════════════════════════════════════════
container_on_click:
    push rbx
    push r12
    push r13
    push r14
    push r15

    mov rbx, rdi
    mov r12d, esi                   ; x
    mov r13d, edx                   ; y
    mov r14d, ecx                   ; button

    ; Check each child for hit
    mov r15d, [rbx + CONT_CHILD_COUNT]
    test r15d, r15d
    jz .not_handled

    mov rdi, [rbx + CONT_CHILDREN]
    xor ecx, ecx

.check_child:
    cmp ecx, r15d
    jge .not_handled

    push rcx
    push rdi

    mov rdi, [rdi + rcx*8]          ; Get child
    test rdi, rdi
    jz .next_click

    ; Forward click (widget_on_click checks bounds)
    mov esi, r12d
    mov edx, r13d
    mov ecx, r14d
    call widget_on_click
    test eax, eax
    jnz .handled_pop

.next_click:
    pop rdi
    pop rcx
    inc ecx
    jmp .check_child

.handled_pop:
    pop rdi
    pop rcx
    jmp .done

.not_handled:
    xor eax, eax

.done:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; ════════════════════════════════════════════════════════════════════════════
; CONTAINER_ON_FOCUS - Handle focus change
; Input:  RDI = container, ESI = gained (1/0)
; ════════════════════════════════════════════════════════════════════════════
container_on_focus:
    or dword [rdi + W_FLAGS], WF_DIRTY
    ret

; ════════════════════════════════════════════════════════════════════════════
; CONTAINER_DESTROY_IMPL - Cleanup and destroy all children
; Input:  RDI = container
; ════════════════════════════════════════════════════════════════════════════
container_destroy_impl:
    push rbx
    push r12
    push r13

    mov rbx, rdi

    ; Destroy all children
    mov r12d, [rbx + CONT_CHILD_COUNT]
    test r12d, r12d
    jz .free_array

    mov r13, [rbx + CONT_CHILDREN]
    xor ecx, ecx

.destroy_loop:
    cmp ecx, r12d
    jge .free_array

    push rcx
    mov rdi, [r13 + rcx*8]
    test rdi, rdi
    jz .next_destroy
    call widget_destroy

.next_destroy:
    pop rcx
    inc ecx
    jmp .destroy_loop

.free_array:
    ; Free children array
    mov rdi, [rbx + CONT_CHILDREN]
    test rdi, rdi
    jz .done
    call kfree

.done:
    pop r13
    pop r12
    pop rbx
    ret

; ════════════════════════════════════════════════════════════════════════════
; CONTAINER_ADD_CHILD - Add a child widget
; Input:  RDI = container, RSI = child widget
; Output: EAX = 1 on success, 0 on failure (full)
; ════════════════════════════════════════════════════════════════════════════
container_add_child:
    test rdi, rdi
    jz .fail
    test rsi, rsi
    jz .fail

    push rbx
    push r12

    mov rbx, rdi
    mov r12, rsi

    ; Check capacity
    mov eax, [rbx + CONT_CHILD_COUNT]
    cmp eax, [rbx + CONT_CHILD_CAP]
    jge .full

    ; Add to array
    mov rcx, [rbx + CONT_CHILDREN]
    mov [rcx + rax*8], r12

    ; Increment count
    inc dword [rbx + CONT_CHILD_COUNT]

    ; Set parent
    mov [r12 + W_PARENT], rbx

    ; Apply layout if needed
    call container_layout

    or dword [rbx + W_FLAGS], WF_DIRTY
    mov eax, 1
    jmp .done

.full:
    pop r12
    pop rbx
.fail:
    xor eax, eax
    ret

.done:
    pop r12
    pop rbx
    ret

; ════════════════════════════════════════════════════════════════════════════
; CONTAINER_REMOVE_CHILD - Remove a child widget (does not destroy it)
; Input:  RDI = container, RSI = child widget
; Output: EAX = 1 if removed, 0 if not found
; ════════════════════════════════════════════════════════════════════════════
container_remove_child:
    test rdi, rdi
    jz .fail
    test rsi, rsi
    jz .fail

    push rbx
    push r12
    push r13

    mov rbx, rdi
    mov r12, rsi

    ; Find child
    mov r13d, [rbx + CONT_CHILD_COUNT]
    test r13d, r13d
    jz .not_found

    mov rcx, [rbx + CONT_CHILDREN]
    xor eax, eax

.find_loop:
    cmp eax, r13d
    jge .not_found

    cmp [rcx + rax*8], r12
    je .found
    inc eax
    jmp .find_loop

.found:
    ; Clear parent
    mov qword [r12 + W_PARENT], 0

    ; Shift remaining children
    mov edx, eax                    ; index
.shift_loop:
    inc edx
    cmp edx, r13d
    jge .shift_done

    mov rsi, [rcx + rdx*8]
    mov [rcx + rax*8], rsi
    inc eax
    jmp .shift_loop

.shift_done:
    ; Clear last slot
    dec r13d
    mov qword [rcx + r13*8], 0
    mov [rbx + CONT_CHILD_COUNT], r13d

    or dword [rbx + W_FLAGS], WF_DIRTY
    mov eax, 1
    jmp .done

.not_found:
    pop r13
    pop r12
    pop rbx
.fail:
    xor eax, eax
    ret

.done:
    pop r13
    pop r12
    pop rbx
    ret

; ════════════════════════════════════════════════════════════════════════════
; CONTAINER_LAYOUT - Apply layout to children
; Input:  RBX = container (internal)
; ════════════════════════════════════════════════════════════════════════════
container_layout:
    push rbx
    push r12
    push r13
    push r14
    push r15

    ; Check if layout is NONE
    mov eax, [rbx + CONT_LAYOUT]
    test eax, eax
    jz .done

    ; Get starting position
    mov r12d, [rbx + W_X]
    add r12d, [rbx + CONT_PADDING]  ; x
    mov r13d, [rbx + W_Y]
    add r13d, [rbx + CONT_PADDING]  ; y

    mov r14d, [rbx + CONT_CHILD_COUNT]
    test r14d, r14d
    jz .done

    mov r15, [rbx + CONT_CHILDREN]
    xor ecx, ecx

    mov eax, [rbx + CONT_LAYOUT]
    cmp eax, LAYOUT_VERTICAL
    je .vertical_layout
    cmp eax, LAYOUT_HORIZONTAL
    je .horizontal_layout
    jmp .done

.vertical_layout:
    cmp ecx, r14d
    jge .done

    mov rdi, [r15 + rcx*8]
    test rdi, rdi
    jz .next_vert

    ; Set position
    mov [rdi + W_X], r12d
    mov [rdi + W_Y], r13d

    ; Advance Y
    add r13d, [rdi + W_H]
    add r13d, [rbx + CONT_SPACING]

.next_vert:
    inc ecx
    jmp .vertical_layout

.horizontal_layout:
    cmp ecx, r14d
    jge .done

    mov rdi, [r15 + rcx*8]
    test rdi, rdi
    jz .next_horiz

    ; Set position
    mov [rdi + W_X], r12d
    mov [rdi + W_Y], r13d

    ; Advance X
    add r12d, [rdi + W_W]
    add r12d, [rbx + CONT_SPACING]

.next_horiz:
    inc ecx
    jmp .horizontal_layout

.done:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; ════════════════════════════════════════════════════════════════════════════
; CONTAINER_SET_LAYOUT - Set layout mode
; Input:  RDI = container, ESI = layout mode
; ════════════════════════════════════════════════════════════════════════════
container_set_layout:
    test rdi, rdi
    jz .done
    mov [rdi + CONT_LAYOUT], esi

    ; Re-apply layout
    push rbx
    mov rbx, rdi
    call container_layout
    or dword [rbx + W_FLAGS], WF_DIRTY
    pop rbx
.done:
    ret

; ════════════════════════════════════════════════════════════════════════════
; CONTAINER_SET_SPACING - Set spacing between children
; Input:  RDI = container, ESI = spacing in pixels
; ════════════════════════════════════════════════════════════════════════════
container_set_spacing:
    test rdi, rdi
    jz .done
    mov [rdi + CONT_SPACING], esi
    or dword [rdi + W_FLAGS], WF_DIRTY
.done:
    ret

; ════════════════════════════════════════════════════════════════════════════
; CONTAINER_GET_CHILD_COUNT - Get number of children
; Input:  RDI = container
; Output: EAX = child count
; ════════════════════════════════════════════════════════════════════════════
container_get_child_count:
    xor eax, eax
    test rdi, rdi
    jz .done
    mov eax, [rdi + CONT_CHILD_COUNT]
.done:
    ret
