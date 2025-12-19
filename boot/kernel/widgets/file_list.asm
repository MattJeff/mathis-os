; ════════════════════════════════════════════════════════════════════════════
; FILE_LIST.ASM - File List Widget (SOLID - Single Responsibility)
; ════════════════════════════════════════════════════════════════════════════
; Displays scrollable list of files/folders with selection
; Columns: Name, Size, Modified
; ════════════════════════════════════════════════════════════════════════════

; ════════════════════════════════════════════════════════════════════════════
; FILE ENTRY STRUCTURE (32 bytes each)
; ════════════════════════════════════════════════════════════════════════════
FILE_ENTRY_SIZE     equ 32

FE_NAME             equ 0           ; Pointer to name string (8 bytes)
FE_SIZE             equ 8           ; File size in bytes (4 bytes)
FE_FLAGS            equ 12          ; Flags: is_dir, selected, etc (4 bytes)
FE_MOD_DATE         equ 16          ; Pointer to modified date string (8 bytes)
FE_RESERVED         equ 24          ; Reserved (8 bytes)

; File entry flags
FEF_DIRECTORY       equ 0x01
FEF_SELECTED        equ 0x02
FEF_HIDDEN          equ 0x04

; ════════════════════════════════════════════════════════════════════════════
; FILE_LIST STRUCTURE (extends Widget + 64 bytes)
; ════════════════════════════════════════════════════════════════════════════
FILE_LIST_SIZE      equ WIDGET_SIZE + 64

; Extra fields
FL_ENTRIES          equ WIDGET_SIZE + 0     ; Pointer to entries array (8 bytes)
FL_COUNT            equ WIDGET_SIZE + 8     ; Number of entries (4 bytes)
FL_SELECTED         equ WIDGET_SIZE + 12    ; Selected index (4 bytes)
FL_SCROLL           equ WIDGET_SIZE + 16    ; Scroll offset (4 bytes)
FL_VISIBLE_ROWS     equ WIDGET_SIZE + 20    ; Visible rows count (4 bytes)
FL_ROW_HEIGHT       equ WIDGET_SIZE + 24    ; Height per row (4 bytes)
FL_HEADER_HEIGHT    equ WIDGET_SIZE + 28    ; Column header height (4 bytes)
FL_BG_COLOR         equ WIDGET_SIZE + 32    ; Background color (4 bytes)
FL_FG_COLOR         equ WIDGET_SIZE + 36    ; Text color (4 bytes)
FL_SEL_BG           equ WIDGET_SIZE + 40    ; Selection background (4 bytes)
FL_SEL_FG           equ WIDGET_SIZE + 44    ; Selection text color (4 bytes)
FL_DIR_COLOR        equ WIDGET_SIZE + 48    ; Directory name color (4 bytes)
FL_BORDER_COLOR     equ WIDGET_SIZE + 52    ; Border color (4 bytes)
FL_ON_SELECT        equ WIDGET_SIZE + 56    ; Callback on selection (8 bytes)

; ════════════════════════════════════════════════════════════════════════════
; FILE_LIST V-TABLE
; ════════════════════════════════════════════════════════════════════════════
file_list_vtable:
    dq file_list_draw       ; VT_DRAW
    dq file_list_on_key     ; VT_ON_KEY
    dq file_list_on_click   ; VT_ON_CLICK
    dq file_list_on_focus   ; VT_ON_FOCUS
    dq file_list_destroy    ; VT_DESTROY

; ════════════════════════════════════════════════════════════════════════════
; FILE_LIST_CREATE - Create a file list widget
; Input:  ESI = x, EDX = y, ECX = width, R8D = height
; Output: RAX = file list widget pointer (or 0)
; ════════════════════════════════════════════════════════════════════════════
file_list_create:
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

    ; Allocate file list
    mov rdi, FILE_LIST_SIZE
    call kmalloc
    test rax, rax
    jz .fail

    mov rbx, rax

    ; Initialize base widget fields
    lea rax, [file_list_vtable]
    mov qword [rbx + W_VTABLE], rax
    mov dword [rbx + W_X], r12d
    mov dword [rbx + W_Y], r13d
    mov dword [rbx + W_W], r14d
    mov dword [rbx + W_H], r15d
    mov dword [rbx + W_FLAGS], WF_VISIBLE | WF_ENABLED | WF_FOCUSED | WF_DIRTY
    mov ecx, [widget_next_id]
    mov [rbx + W_ID], ecx
    inc dword [widget_next_id]
    mov qword [rbx + W_PARENT], 0
    mov qword [rbx + W_USERDATA], 0
    mov qword [rbx + W_CHILDREN], 0

    ; Initialize file list specific fields
    mov qword [rbx + FL_ENTRIES], 0
    mov dword [rbx + FL_COUNT], 0
    mov dword [rbx + FL_SELECTED], 0
    mov dword [rbx + FL_SCROLL], 0
    mov dword [rbx + FL_ROW_HEIGHT], 24
    mov dword [rbx + FL_HEADER_HEIGHT], 28

    ; Calculate visible rows
    mov eax, r15d
    sub eax, 28                     ; Subtract header
    mov ecx, 24                     ; Row height
    xor edx, edx
    div ecx
    mov dword [rbx + FL_VISIBLE_ROWS], eax

    ; Colors
    mov dword [rbx + FL_BG_COLOR], 0x00202020       ; Dark background
    mov dword [rbx + FL_FG_COLOR], 0x00CCCCCC       ; Light gray text
    mov dword [rbx + FL_SEL_BG], 0x00404080         ; Blue selection
    mov dword [rbx + FL_SEL_FG], 0x00FFFFFF         ; White text
    mov dword [rbx + FL_DIR_COLOR], 0x0080FFFF      ; Cyan for directories
    mov dword [rbx + FL_BORDER_COLOR], 0x00606060   ; Border gray
    mov qword [rbx + FL_ON_SELECT], 0

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
; FILE_LIST_DRAW - Render the file list
; Input:  RDI = file list widget pointer
; ════════════════════════════════════════════════════════════════════════════
file_list_draw:
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
    mov r8d, [rbx + FL_BG_COLOR]
    call fill_rect

    ; Draw border
    mov edi, [rbx + W_X]
    mov esi, [rbx + W_Y]
    mov edx, [rbx + W_W]
    mov ecx, [rbx + W_H]
    mov r8d, [rbx + FL_BORDER_COLOR]
    call draw_rect

    ; Draw column header background
    mov edi, [rbx + W_X]
    inc edi
    mov esi, [rbx + W_Y]
    inc esi
    mov edx, [rbx + W_W]
    sub edx, 2
    mov ecx, [rbx + FL_HEADER_HEIGHT]
    mov r8d, 0x00383838             ; Darker header
    call fill_rect

    ; Draw column headers
    mov r12d, [rbx + W_X]
    add r12d, 12
    mov r13d, [rbx + W_Y]
    add r13d, 8

    ; "Name" column
    mov edi, r12d
    mov esi, r13d
    mov rdx, fl_col_name
    mov ecx, 0x00AAAAAA
    call video_text

    ; "Size" column (at ~60% width)
    mov edi, [rbx + W_X]
    mov eax, [rbx + W_W]
    shr eax, 1
    add eax, 80
    add edi, eax
    mov esi, r13d
    mov rdx, fl_col_size
    mov ecx, 0x00AAAAAA
    call video_text

    ; "Modified" column (at ~80% width)
    mov edi, [rbx + W_X]
    add edi, [rbx + W_W]
    sub edi, 120
    mov esi, r13d
    mov rdx, fl_col_modified
    mov ecx, 0x00AAAAAA
    call video_text

    ; Draw separator line
    mov edi, [rbx + W_X]
    inc edi
    mov esi, [rbx + W_Y]
    add esi, [rbx + FL_HEADER_HEIGHT]
    mov edx, [rbx + W_W]
    sub edx, 2
    mov ecx, 1
    mov r8d, [rbx + FL_BORDER_COLOR]
    call fill_rect

    ; Draw entries
    mov r14d, [rbx + FL_COUNT]
    test r14d, r14d
    jz .no_entries

    mov r15d, 0                     ; Current row index

.draw_entry_loop:
    cmp r15d, r14d
    jge .entries_done

    ; Calculate visible position
    mov eax, r15d
    sub eax, [rbx + FL_SCROLL]
    js .skip_entry                  ; Entry is above visible area
    cmp eax, [rbx + FL_VISIBLE_ROWS]
    jge .entries_done               ; Entry is below visible area

    ; Calculate Y position
    push rax
    imul eax, [rbx + FL_ROW_HEIGHT]
    add eax, [rbx + W_Y]
    add eax, [rbx + FL_HEADER_HEIGHT]
    add eax, 2                      ; Small gap after header
    mov r12d, eax                   ; r12 = row Y
    pop rax

    ; Check if selected
    cmp r15d, [rbx + FL_SELECTED]
    jne .not_selected

    ; Draw selection background
    push r15
    mov edi, [rbx + W_X]
    add edi, 2
    mov esi, r12d
    mov edx, [rbx + W_W]
    sub edx, 4
    mov ecx, [rbx + FL_ROW_HEIGHT]
    mov r8d, [rbx + FL_SEL_BG]
    call fill_rect
    pop r15

.not_selected:
    ; Get entry pointer
    mov rax, [rbx + FL_ENTRIES]
    test rax, rax
    jz .skip_entry

    mov ecx, r15d
    imul ecx, FILE_ENTRY_SIZE
    add rax, rcx                    ; rax = entry pointer

    ; Draw entry name
    push rax
    mov r13d, [rbx + W_X]
    add r13d, 12

    ; Choose color based on selection and type
    mov ecx, [rbx + FL_FG_COLOR]
    cmp r15d, [rbx + FL_SELECTED]
    jne .check_dir
    mov ecx, [rbx + FL_SEL_FG]
    jmp .draw_name

.check_dir:
    test dword [rax + FE_FLAGS], FEF_DIRECTORY
    jz .draw_name
    mov ecx, [rbx + FL_DIR_COLOR]

.draw_name:
    mov edi, r13d
    mov esi, r12d
    add esi, 4
    mov rdx, [rax + FE_NAME]
    call video_text

    pop rax

    ; Draw size (skip for directories)
    test dword [rax + FE_FLAGS], FEF_DIRECTORY
    jnz .draw_modified

    push rax
    mov edi, [rbx + W_X]
    mov eax, [rbx + W_W]
    shr eax, 1
    add eax, 80
    add edi, eax
    mov esi, r12d
    add esi, 4
    mov rdx, fl_placeholder_size    ; TODO: Format actual size
    mov ecx, 0x00888888
    call video_text
    pop rax

.draw_modified:
    ; Draw modified date
    push rax
    mov edi, [rbx + W_X]
    add edi, [rbx + W_W]
    sub edi, 120
    mov esi, r12d
    add esi, 4
    mov rdx, [rax + FE_MOD_DATE]
    test rdx, rdx
    jz .no_date
    mov ecx, 0x00888888
    call video_text
.no_date:
    pop rax

.skip_entry:
    inc r15d
    jmp .draw_entry_loop

.entries_done:
.no_entries:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; ════════════════════════════════════════════════════════════════════════════
; FILE_LIST_ON_KEY - Handle keyboard navigation
; Input:  RDI = widget, ESI = scancode
; Output: EAX = 1 if handled
; ════════════════════════════════════════════════════════════════════════════
file_list_on_key:
    push rbx
    mov rbx, rdi

    ; W or Up arrow (0x11 = W, 0x48 = Up)
    cmp esi, 0x11
    je .move_up
    cmp esi, 0x48
    je .move_up

    ; S or Down arrow (0x1F = S, 0x50 = Down)
    cmp esi, 0x1F
    je .move_down
    cmp esi, 0x50
    je .move_down

    ; Enter (0x1C)
    cmp esi, 0x1C
    je .select_entry

    ; Not handled
    xor eax, eax
    jmp .done

.move_up:
    mov eax, [rbx + FL_SELECTED]
    test eax, eax
    jz .handled                     ; Already at top
    dec eax
    mov [rbx + FL_SELECTED], eax

    ; Adjust scroll if needed
    cmp eax, [rbx + FL_SCROLL]
    jge .mark_dirty
    mov [rbx + FL_SCROLL], eax
    jmp .mark_dirty

.move_down:
    mov eax, [rbx + FL_SELECTED]
    inc eax
    cmp eax, [rbx + FL_COUNT]
    jge .handled                    ; Already at bottom
    mov [rbx + FL_SELECTED], eax

    ; Adjust scroll if needed
    mov ecx, [rbx + FL_SCROLL]
    add ecx, [rbx + FL_VISIBLE_ROWS]
    dec ecx
    cmp eax, ecx
    jle .mark_dirty
    mov ecx, eax
    sub ecx, [rbx + FL_VISIBLE_ROWS]
    inc ecx
    mov [rbx + FL_SCROLL], ecx
    jmp .mark_dirty

.select_entry:
    ; Call on_select callback if set
    mov rax, [rbx + FL_ON_SELECT]
    test rax, rax
    jz .handled
    mov rdi, rbx
    mov esi, [rbx + FL_SELECTED]
    call rax
    jmp .handled

.mark_dirty:
    or dword [rbx + W_FLAGS], WF_DIRTY

.handled:
    mov eax, 1

.done:
    pop rbx
    ret

; ════════════════════════════════════════════════════════════════════════════
; FILE_LIST_ON_CLICK - Handle mouse click
; Input:  RDI = widget, ESI = x, EDX = y, ECX = button
; Output: EAX = 1 if handled
; ════════════════════════════════════════════════════════════════════════════
file_list_on_click:
    push rbx
    mov rbx, rdi

    ; Calculate which row was clicked
    mov eax, edx
    sub eax, [rbx + W_Y]
    sub eax, [rbx + FL_HEADER_HEIGHT]
    js .not_handled                 ; Clicked on header

    ; Divide by row height
    xor edx, edx
    div dword [rbx + FL_ROW_HEIGHT]
    add eax, [rbx + FL_SCROLL]

    ; Check bounds
    cmp eax, [rbx + FL_COUNT]
    jge .not_handled

    ; Update selection
    mov [rbx + FL_SELECTED], eax
    or dword [rbx + W_FLAGS], WF_DIRTY

    ; If left button, call select callback
    test ecx, 1
    jz .handled
    mov rax, [rbx + FL_ON_SELECT]
    test rax, rax
    jz .handled
    mov rdi, rbx
    mov esi, [rbx + FL_SELECTED]
    call rax

.handled:
    mov eax, 1
    jmp .done

.not_handled:
    xor eax, eax

.done:
    pop rbx
    ret

; ════════════════════════════════════════════════════════════════════════════
; FILE_LIST_ON_FOCUS - Handle focus change
; ════════════════════════════════════════════════════════════════════════════
file_list_on_focus:
    ret

; ════════════════════════════════════════════════════════════════════════════
; FILE_LIST_DESTROY - Cleanup file list
; ════════════════════════════════════════════════════════════════════════════
file_list_destroy:
    push rbx
    mov rbx, rdi

    ; Free entries array if allocated
    mov rdi, [rbx + FL_ENTRIES]
    test rdi, rdi
    jz .done
    call kfree

.done:
    pop rbx
    ret

; ════════════════════════════════════════════════════════════════════════════
; FILE_LIST_SET_ENTRIES - Set the file entries
; Input:  RDI = widget, RSI = entries array ptr, EDX = count
; ════════════════════════════════════════════════════════════════════════════
file_list_set_entries:
    test rdi, rdi
    jz .done
    mov [rdi + FL_ENTRIES], rsi
    mov [rdi + FL_COUNT], edx
    mov dword [rdi + FL_SELECTED], 0
    mov dword [rdi + FL_SCROLL], 0
    or dword [rdi + W_FLAGS], WF_DIRTY
.done:
    ret

; ════════════════════════════════════════════════════════════════════════════
; FILE_LIST_GET_SELECTED - Get selected entry index
; Input:  RDI = widget
; Output: EAX = selected index
; ════════════════════════════════════════════════════════════════════════════
file_list_get_selected:
    xor eax, eax
    test rdi, rdi
    jz .done
    mov eax, [rdi + FL_SELECTED]
.done:
    ret

; ════════════════════════════════════════════════════════════════════════════
; FILE_LIST_SET_CALLBACK - Set selection callback
; Input:  RDI = widget, RSI = callback function ptr
; ════════════════════════════════════════════════════════════════════════════
file_list_set_callback:
    test rdi, rdi
    jz .done
    mov [rdi + FL_ON_SELECT], rsi
.done:
    ret

; ════════════════════════════════════════════════════════════════════════════
; DATA
; ════════════════════════════════════════════════════════════════════════════
fl_col_name:        db "Name", 0
fl_col_size:        db "Size", 0
fl_col_modified:    db "Modified", 0
fl_placeholder_size: db "--", 0
