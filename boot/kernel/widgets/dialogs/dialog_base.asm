; ════════════════════════════════════════════════════════════════════════════
; DIALOG_BASE.ASM - Base Dialog Widget (SOLID - Single Responsibility)
; ════════════════════════════════════════════════════════════════════════════
; Base class for modal dialogs (center screen, title, buttons)
; ════════════════════════════════════════════════════════════════════════════

; ════════════════════════════════════════════════════════════════════════════
; DIALOG STRUCTURE (extends Widget + 64 bytes)
; ════════════════════════════════════════════════════════════════════════════
DIALOG_SIZE         equ WIDGET_SIZE + 64

; Extra fields
DLG_TITLE           equ WIDGET_SIZE + 0     ; Title string (8 bytes)
DLG_BTN1_TEXT       equ WIDGET_SIZE + 8     ; Button 1 text (8 bytes)
DLG_BTN2_TEXT       equ WIDGET_SIZE + 16    ; Button 2 text (8 bytes)
DLG_SELECTED_BTN    equ WIDGET_SIZE + 24    ; Selected button 0/1 (4 bytes)
DLG_RESULT          equ WIDGET_SIZE + 28    ; Dialog result (4 bytes)
DLG_ON_CONFIRM      equ WIDGET_SIZE + 32    ; Confirm callback (8 bytes)
DLG_ON_CANCEL       equ WIDGET_SIZE + 40    ; Cancel callback (8 bytes)
DLG_BG_COLOR        equ WIDGET_SIZE + 48    ; Background (4 bytes)
DLG_BORDER_COLOR    equ WIDGET_SIZE + 52    ; Border (4 bytes)
DLG_TITLE_BG        equ WIDGET_SIZE + 56    ; Title bar bg (4 bytes)
DLG_BTN_COLOR       equ WIDGET_SIZE + 60    ; Button color (4 bytes)

; Dialog results
DLG_RESULT_NONE     equ 0
DLG_RESULT_OK       equ 1
DLG_RESULT_CANCEL   equ 2

; ════════════════════════════════════════════════════════════════════════════
; DIALOG V-TABLE
; ════════════════════════════════════════════════════════════════════════════
dialog_vtable:
    dq dialog_draw          ; VT_DRAW
    dq dialog_on_key        ; VT_ON_KEY
    dq dialog_on_click      ; VT_ON_CLICK
    dq dialog_on_focus      ; VT_ON_FOCUS
    dq dialog_destroy       ; VT_DESTROY

; ════════════════════════════════════════════════════════════════════════════
; DIALOG_CREATE - Create a centered dialog
; Input:  ESI = width, EDX = height, RCX = title string
; Output: RAX = dialog widget pointer (or 0)
; ════════════════════════════════════════════════════════════════════════════
dialog_create:
    push rbx
    push r12
    push r13
    push r14

    mov r12d, esi                   ; width
    mov r13d, edx                   ; height
    mov r14, rcx                    ; title

    ; Allocate dialog
    mov rdi, DIALOG_SIZE
    call kmalloc
    test rax, rax
    jz .fail

    mov rbx, rax

    ; Calculate centered position
    mov eax, [screen_width]
    sub eax, r12d
    shr eax, 1                      ; x = (screen_w - w) / 2

    mov ecx, [screen_height]
    sub ecx, r13d
    shr ecx, 1                      ; y = (screen_h - h) / 2

    ; Initialize base widget fields
    lea rdx, [dialog_vtable]
    mov qword [rbx + W_VTABLE], rdx
    mov dword [rbx + W_X], eax
    mov dword [rbx + W_Y], ecx
    mov dword [rbx + W_W], r12d
    mov dword [rbx + W_H], r13d
    mov dword [rbx + W_FLAGS], WF_VISIBLE | WF_ENABLED | WF_FOCUSED | WF_MODAL | WF_DIRTY
    mov ecx, [widget_next_id]
    mov [rbx + W_ID], ecx
    inc dword [widget_next_id]
    mov qword [rbx + W_PARENT], 0
    mov qword [rbx + W_USERDATA], 0
    mov qword [rbx + W_CHILDREN], 0

    ; Initialize dialog specific fields
    mov qword [rbx + DLG_TITLE], r14
    mov qword [rbx + DLG_BTN1_TEXT], dlg_btn_cancel
    mov qword [rbx + DLG_BTN2_TEXT], dlg_btn_ok
    mov dword [rbx + DLG_SELECTED_BTN], 1       ; Default to OK
    mov dword [rbx + DLG_RESULT], DLG_RESULT_NONE
    mov qword [rbx + DLG_ON_CONFIRM], 0
    mov qword [rbx + DLG_ON_CANCEL], 0

    ; Colors
    mov dword [rbx + DLG_BG_COLOR], 0x00353535      ; Dark gray
    mov dword [rbx + DLG_BORDER_COLOR], 0x00606060  ; Border
    mov dword [rbx + DLG_TITLE_BG], 0x00404040      ; Title bg
    mov dword [rbx + DLG_BTN_COLOR], 0x00505050     ; Button bg

    mov rax, rbx
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
; DIALOG_DRAW - Render the dialog
; Input:  RDI = dialog widget pointer
; ════════════════════════════════════════════════════════════════════════════
dialog_draw:
    push rbx
    push r12
    push r13

    mov rbx, rdi

    ; Draw shadow (offset by 4,4)
    mov edi, [rbx + W_X]
    add edi, 4
    mov esi, [rbx + W_Y]
    add esi, 4
    mov edx, [rbx + W_W]
    mov ecx, [rbx + W_H]
    mov r8d, 0x00000000             ; Black shadow
    call fill_rect

    ; Draw background
    mov edi, [rbx + W_X]
    mov esi, [rbx + W_Y]
    mov edx, [rbx + W_W]
    mov ecx, [rbx + W_H]
    mov r8d, [rbx + DLG_BG_COLOR]
    call fill_rect

    ; Draw border
    mov edi, [rbx + W_X]
    mov esi, [rbx + W_Y]
    mov edx, [rbx + W_W]
    mov ecx, [rbx + W_H]
    mov r8d, [rbx + DLG_BORDER_COLOR]
    call draw_rect

    ; Draw title bar
    mov edi, [rbx + W_X]
    inc edi
    mov esi, [rbx + W_Y]
    inc esi
    mov edx, [rbx + W_W]
    sub edx, 2
    mov ecx, 24
    mov r8d, [rbx + DLG_TITLE_BG]
    call fill_rect

    ; Draw title text
    mov r12d, [rbx + W_X]
    add r12d, 12
    mov r13d, [rbx + W_Y]
    add r13d, 6

    mov edi, r12d
    mov esi, r13d
    mov rdx, [rbx + DLG_TITLE]
    mov ecx, 0x00FFFFFF
    call video_text

    ; Draw separator line
    mov edi, [rbx + W_X]
    inc edi
    mov esi, [rbx + W_Y]
    add esi, 25
    mov edx, [rbx + W_W]
    sub edx, 2
    mov ecx, 1
    mov r8d, [rbx + DLG_BORDER_COLOR]
    call fill_rect

    ; Draw buttons at bottom
    ; Button 1 (Cancel) - left
    mov r12d, [rbx + W_X]
    add r12d, 20
    mov r13d, [rbx + W_Y]
    add r13d, [rbx + W_H]
    sub r13d, 40

    ; Button background
    mov edi, r12d
    mov esi, r13d
    mov edx, 80
    mov ecx, 24
    mov r8d, [rbx + DLG_BTN_COLOR]
    cmp dword [rbx + DLG_SELECTED_BTN], 0
    jne .btn1_not_selected
    mov r8d, 0x00606080             ; Highlight if selected
.btn1_not_selected:
    call fill_rect

    ; Button border
    mov edi, r12d
    mov esi, r13d
    mov edx, 80
    mov ecx, 24
    mov r8d, [rbx + DLG_BORDER_COLOR]
    call draw_rect

    ; Button text
    add r12d, 16
    add r13d, 6
    mov edi, r12d
    mov esi, r13d
    mov rdx, [rbx + DLG_BTN1_TEXT]
    mov ecx, 0x00CCCCCC
    call video_text

    ; Button 2 (OK) - right
    mov r12d, [rbx + W_X]
    add r12d, [rbx + W_W]
    sub r12d, 100
    mov r13d, [rbx + W_Y]
    add r13d, [rbx + W_H]
    sub r13d, 40

    mov edi, r12d
    mov esi, r13d
    mov edx, 80
    mov ecx, 24
    mov r8d, [rbx + DLG_BTN_COLOR]
    cmp dword [rbx + DLG_SELECTED_BTN], 1
    jne .btn2_not_selected
    mov r8d, 0x00608060             ; Green highlight if selected
.btn2_not_selected:
    call fill_rect

    mov edi, r12d
    mov esi, r13d
    mov edx, 80
    mov ecx, 24
    mov r8d, [rbx + DLG_BORDER_COLOR]
    call draw_rect

    add r12d, 20
    add r13d, 6
    mov edi, r12d
    mov esi, r13d
    mov rdx, [rbx + DLG_BTN2_TEXT]
    mov ecx, 0x00CCCCCC
    call video_text

    pop r13
    pop r12
    pop rbx
    ret

; ════════════════════════════════════════════════════════════════════════════
; DIALOG_ON_KEY - Handle keyboard
; Input:  RDI = widget, ESI = scancode
; Output: EAX = 1 if handled
; ════════════════════════════════════════════════════════════════════════════
dialog_on_key:
    push rbx
    mov rbx, rdi

    ; Tab or Left/Right to switch buttons
    cmp esi, 0x0F                   ; Tab
    je .switch_btn
    cmp esi, 0x4B                   ; Left
    je .switch_btn
    cmp esi, 0x4D                   ; Right
    je .switch_btn

    ; Enter to confirm
    cmp esi, 0x1C
    je .confirm

    ; Escape to cancel
    cmp esi, 0x01
    je .cancel

    xor eax, eax
    jmp .done

.switch_btn:
    xor dword [rbx + DLG_SELECTED_BTN], 1
    or dword [rbx + W_FLAGS], WF_DIRTY
    jmp .handled

.confirm:
    mov eax, [rbx + DLG_SELECTED_BTN]
    test eax, eax
    jz .do_cancel                   ; Button 0 = Cancel

    ; Confirm (Button 1)
    mov dword [rbx + DLG_RESULT], DLG_RESULT_OK
    mov rax, [rbx + DLG_ON_CONFIRM]
    test rax, rax
    jz .handled
    mov rdi, rbx
    call rax
    jmp .handled

.cancel:
.do_cancel:
    mov dword [rbx + DLG_RESULT], DLG_RESULT_CANCEL
    mov rax, [rbx + DLG_ON_CANCEL]
    test rax, rax
    jz .handled
    mov rdi, rbx
    call rax
    jmp .handled

.handled:
    mov eax, 1

.done:
    pop rbx
    ret

; ════════════════════════════════════════════════════════════════════════════
; DIALOG_ON_CLICK - Handle mouse click
; ════════════════════════════════════════════════════════════════════════════
dialog_on_click:
    push rbx
    mov rbx, rdi

    ; Check if clicking on buttons
    ; Button Y range
    mov eax, [rbx + W_Y]
    add eax, [rbx + W_H]
    sub eax, 40
    cmp edx, eax
    jl .not_handled
    add eax, 24
    cmp edx, eax
    jg .not_handled

    ; Check Button 1 (Cancel) X range
    mov eax, [rbx + W_X]
    add eax, 20
    cmp esi, eax
    jl .not_handled
    add eax, 80
    cmp esi, eax
    jle .click_btn1

    ; Check Button 2 (OK) X range
    mov eax, [rbx + W_X]
    add eax, [rbx + W_W]
    sub eax, 100
    cmp esi, eax
    jl .not_handled
    add eax, 80
    cmp esi, eax
    jle .click_btn2

.not_handled:
    xor eax, eax
    jmp .done

.click_btn1:
    mov dword [rbx + DLG_SELECTED_BTN], 0
    mov dword [rbx + DLG_RESULT], DLG_RESULT_CANCEL
    or dword [rbx + W_FLAGS], WF_DIRTY
    mov rax, [rbx + DLG_ON_CANCEL]
    test rax, rax
    jz .handled
    mov rdi, rbx
    call rax
    jmp .handled

.click_btn2:
    mov dword [rbx + DLG_SELECTED_BTN], 1
    mov dword [rbx + DLG_RESULT], DLG_RESULT_OK
    or dword [rbx + W_FLAGS], WF_DIRTY
    mov rax, [rbx + DLG_ON_CONFIRM]
    test rax, rax
    jz .handled
    mov rdi, rbx
    call rax
    jmp .handled

.handled:
    mov eax, 1

.done:
    pop rbx
    ret

; ════════════════════════════════════════════════════════════════════════════
; DIALOG_ON_FOCUS
; ════════════════════════════════════════════════════════════════════════════
dialog_on_focus:
    ret

; ════════════════════════════════════════════════════════════════════════════
; DIALOG_DESTROY
; ════════════════════════════════════════════════════════════════════════════
dialog_destroy:
    ret

; ════════════════════════════════════════════════════════════════════════════
; DIALOG_SET_BUTTONS - Set button texts
; Input:  RDI = widget, RSI = btn1 text, RDX = btn2 text
; ════════════════════════════════════════════════════════════════════════════
dialog_set_buttons:
    test rdi, rdi
    jz .done
    mov [rdi + DLG_BTN1_TEXT], rsi
    mov [rdi + DLG_BTN2_TEXT], rdx
    or dword [rdi + W_FLAGS], WF_DIRTY
.done:
    ret

; ════════════════════════════════════════════════════════════════════════════
; DIALOG_SET_CALLBACKS - Set confirm/cancel callbacks
; Input:  RDI = widget, RSI = confirm callback, RDX = cancel callback
; ════════════════════════════════════════════════════════════════════════════
dialog_set_callbacks:
    test rdi, rdi
    jz .done
    mov [rdi + DLG_ON_CONFIRM], rsi
    mov [rdi + DLG_ON_CANCEL], rdx
.done:
    ret

; ════════════════════════════════════════════════════════════════════════════
; DIALOG_GET_INPUT - Get input text from dialog (polymorphic)
; Input:  RDI = dialog widget
; Output: RAX = pointer to input buffer (or 0 if no input)
;
; Works with: dialog_new (DN_NAME_BUF), dialog_rename (DR_NAME_BUF)
; ════════════════════════════════════════════════════════════════════════════
dialog_get_input:
    test rdi, rdi
    jz .no_input

    ; Check dialog type by looking at vtable
    mov rax, [rdi + W_VTABLE]

    ; Check if it's dialog_new
    lea rcx, [dialog_new_vtable]
    cmp rax, rcx
    je .get_new_input

    ; Check if it's dialog_rename
    lea rcx, [dialog_rename_vtable]
    cmp rax, rcx
    je .get_rename_input

    ; Unknown dialog type
.no_input:
    xor eax, eax
    ret

.get_new_input:
    mov rax, [rdi + DN_NAME_BUF]
    ret

.get_rename_input:
    mov rax, [rdi + DR_NEW_NAME_BUF]
    ret

; ════════════════════════════════════════════════════════════════════════════
; DATA
; ════════════════════════════════════════════════════════════════════════════
dlg_btn_ok:         db "OK", 0
dlg_btn_cancel:     db "CANCEL", 0
