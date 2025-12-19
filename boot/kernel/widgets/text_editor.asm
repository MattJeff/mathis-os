; ════════════════════════════════════════════════════════════════════════════
; TEXT_EDITOR.ASM - Text Editor Widget (SOLID - Single Responsibility)
; ════════════════════════════════════════════════════════════════════════════
; Simple text editor with line numbers and cursor
; Supports: navigation, insert, delete, save
; ════════════════════════════════════════════════════════════════════════════

; ════════════════════════════════════════════════════════════════════════════
; TEXT_EDITOR STRUCTURE (extends Widget + 96 bytes)
; ════════════════════════════════════════════════════════════════════════════
TEXT_EDITOR_SIZE    equ WIDGET_SIZE + 96

; Extra fields
TE_BUFFER           equ WIDGET_SIZE + 0     ; Text buffer pointer (8 bytes)
TE_BUFFER_SIZE      equ WIDGET_SIZE + 8     ; Buffer capacity (4 bytes)
TE_TEXT_LEN         equ WIDGET_SIZE + 12    ; Current text length (4 bytes)
TE_CURSOR_POS       equ WIDGET_SIZE + 16    ; Cursor position in buffer (4 bytes)
TE_CURSOR_LINE      equ WIDGET_SIZE + 20    ; Cursor line number (4 bytes)
TE_CURSOR_COL       equ WIDGET_SIZE + 24    ; Cursor column (4 bytes)
TE_SCROLL_Y         equ WIDGET_SIZE + 28    ; Vertical scroll offset (4 bytes)
TE_SCROLL_X         equ WIDGET_SIZE + 32    ; Horizontal scroll offset (4 bytes)
TE_VISIBLE_LINES    equ WIDGET_SIZE + 36    ; Visible line count (4 bytes)
TE_LINE_HEIGHT      equ WIDGET_SIZE + 40    ; Height per line (4 bytes)
TE_LINE_NUM_WIDTH   equ WIDGET_SIZE + 44    ; Line number gutter width (4 bytes)
TE_MODIFIED         equ WIDGET_SIZE + 48    ; Modified flag (4 bytes)
TE_FILENAME         equ WIDGET_SIZE + 52    ; Filename pointer (8 bytes) - unaligned!
TE_BG_COLOR         equ WIDGET_SIZE + 60    ; Background (4 bytes)
TE_FG_COLOR         equ WIDGET_SIZE + 64    ; Text color (4 bytes)
TE_LINE_NUM_COLOR   equ WIDGET_SIZE + 68    ; Line number color (4 bytes)
TE_CURSOR_COLOR     equ WIDGET_SIZE + 72    ; Cursor color (4 bytes)
TE_GUTTER_COLOR     equ WIDGET_SIZE + 76    ; Gutter background (4 bytes)
TE_ON_SAVE          equ WIDGET_SIZE + 80    ; Save callback (8 bytes)
TE_ON_CLOSE         equ WIDGET_SIZE + 88    ; Close callback (8 bytes)

; ════════════════════════════════════════════════════════════════════════════
; TEXT_EDITOR V-TABLE
; ════════════════════════════════════════════════════════════════════════════
text_editor_vtable:
    dq text_editor_draw     ; VT_DRAW
    dq text_editor_on_key   ; VT_ON_KEY
    dq text_editor_on_click ; VT_ON_CLICK
    dq text_editor_on_focus ; VT_ON_FOCUS
    dq text_editor_destroy  ; VT_DESTROY

; ════════════════════════════════════════════════════════════════════════════
; TEXT_EDITOR_CREATE - Create a text editor widget
; Input:  ESI = x, EDX = y, ECX = width, R8D = height
; Output: RAX = text editor widget pointer (or 0)
; ════════════════════════════════════════════════════════════════════════════
text_editor_create:
    push rbx
    push r12
    push r13
    push r14
    push r15

    mov r12d, esi
    mov r13d, edx
    mov r14d, ecx
    mov r15d, r8d

    ; Allocate editor structure
    mov rdi, TEXT_EDITOR_SIZE
    call kmalloc
    test rax, rax
    jz .fail

    mov rbx, rax

    ; Allocate text buffer (4KB default)
    push rbx
    mov rdi, 4096
    call kmalloc
    pop rbx
    test rax, rax
    jz .fail_free_widget

    mov [rbx + TE_BUFFER], rax
    mov dword [rbx + TE_BUFFER_SIZE], 4096

    ; Clear buffer
    push rbx
    mov rdi, rax
    mov rcx, 4096
    xor al, al
    rep stosb
    pop rbx

    ; Initialize base widget fields
    lea rax, [text_editor_vtable]
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

    ; Initialize editor specific fields
    mov dword [rbx + TE_TEXT_LEN], 0
    mov dword [rbx + TE_CURSOR_POS], 0
    mov dword [rbx + TE_CURSOR_LINE], 0
    mov dword [rbx + TE_CURSOR_COL], 0
    mov dword [rbx + TE_SCROLL_Y], 0
    mov dword [rbx + TE_SCROLL_X], 0
    mov dword [rbx + TE_LINE_HEIGHT], 12
    mov dword [rbx + TE_LINE_NUM_WIDTH], 40
    mov dword [rbx + TE_MODIFIED], 0

    ; Calculate visible lines
    mov eax, r15d
    sub eax, 4                      ; Padding
    xor edx, edx
    mov ecx, 12
    div ecx
    mov [rbx + TE_VISIBLE_LINES], eax

    ; Colors
    mov dword [rbx + TE_BG_COLOR], 0x001E1E1E       ; VS Code dark
    mov dword [rbx + TE_FG_COLOR], 0x00D4D4D4       ; Light gray
    mov dword [rbx + TE_LINE_NUM_COLOR], 0x00858585 ; Dim gray
    mov dword [rbx + TE_CURSOR_COLOR], 0x00FFFFFF   ; White
    mov dword [rbx + TE_GUTTER_COLOR], 0x00252526   ; Slightly lighter

    mov qword [rbx + TE_FILENAME], 0
    mov qword [rbx + TE_ON_SAVE], 0
    mov qword [rbx + TE_ON_CLOSE], 0

    mov rax, rbx
    jmp .done

.fail_free_widget:
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
; TEXT_EDITOR_DRAW - Render the text editor
; Input:  RDI = text editor widget pointer
; ════════════════════════════════════════════════════════════════════════════
text_editor_draw:
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
    mov r8d, [rbx + TE_BG_COLOR]
    call fill_rect

    ; Draw line number gutter
    mov edi, [rbx + W_X]
    mov esi, [rbx + W_Y]
    mov edx, [rbx + TE_LINE_NUM_WIDTH]
    mov ecx, [rbx + W_H]
    mov r8d, [rbx + TE_GUTTER_COLOR]
    call fill_rect

    ; Draw text lines
    mov r14d, [rbx + TE_SCROLL_Y]   ; Start line
    mov r15d, 0                     ; Lines drawn

    ; Get text buffer
    mov r12, [rbx + TE_BUFFER]
    test r12, r12
    jz .no_text

    ; Find start of first visible line
    xor ecx, ecx                    ; Current line
    xor esi, esi                    ; Buffer position
.find_start_line:
    cmp ecx, r14d
    jge .draw_lines
    cmp esi, [rbx + TE_TEXT_LEN]
    jge .draw_lines

    ; Skip to next line
.skip_char:
    cmp byte [r12 + rsi], 0
    je .draw_lines
    cmp byte [r12 + rsi], 10        ; Newline
    je .next_line
    inc esi
    jmp .skip_char

.next_line:
    inc esi
    inc ecx
    jmp .find_start_line

.draw_lines:
    ; esi = buffer position for first visible line
    ; r14d = line number
    push rsi

.draw_line_loop:
    cmp r15d, [rbx + TE_VISIBLE_LINES]
    jge .text_done

    pop rsi
    push rsi

    ; Calculate Y position for this line
    mov eax, r15d
    imul eax, [rbx + TE_LINE_HEIGHT]
    add eax, [rbx + W_Y]
    add eax, 2
    mov r13d, eax                   ; r13 = Y position

    ; Draw line number
    push rsi

    ; Calculate actual line number (scroll + visible row + 1)
    mov eax, r14d                   ; scroll offset
    add eax, r15d                   ; + visible row index
    inc eax                         ; + 1 (1-based)

    ; Convert number to string in temp buffer
    push rax
    lea rdi, [te_line_num_buf + 3]  ; End of buffer
    mov byte [rdi], 0               ; Null terminate
.convert_loop:
    dec rdi
    xor edx, edx
    mov ecx, 10
    div ecx                         ; eax = quotient, edx = remainder
    add dl, '0'
    mov [rdi], dl
    test eax, eax
    jnz .convert_loop
    ; Pad with spaces
.pad_loop:
    cmp rdi, te_line_num_buf
    jle .pad_done
    dec rdi
    mov byte [rdi], ' '
    jmp .pad_loop
.pad_done:
    pop rax

    mov edi, [rbx + W_X]
    add edi, 4
    mov esi, r13d
    lea rdx, [te_line_num_buf]
    mov ecx, [rbx + TE_LINE_NUM_COLOR]
    call video_text
    pop rsi

    ; Draw text content - copy line to temp buffer first
    pop rsi                         ; Get buffer offset
    push rsi

    ; Copy line to temp buffer until newline or end
    lea rdi, [te_line_buf]
    xor ecx, ecx                    ; char count
.copy_line_char:
    cmp ecx, 255                    ; Max line length
    jge .copy_line_done
    mov eax, esi
    add eax, ecx
    cmp eax, [rbx + TE_TEXT_LEN]
    jge .copy_line_done
    mov al, [r12 + rax]
    cmp al, 0
    je .copy_line_done
    cmp al, 10                      ; Newline?
    je .copy_line_done
    mov [rdi + rcx], al
    inc ecx
    jmp .copy_line_char
.copy_line_done:
    mov byte [rdi + rcx], 0         ; Null terminate

    ; Draw the line
    mov edi, [rbx + W_X]
    add edi, [rbx + TE_LINE_NUM_WIDTH]
    add edi, 4
    mov esi, r13d                   ; Y position
    lea rdx, [te_line_buf]
    mov ecx, [rbx + TE_FG_COLOR]
    call video_text

    ; Move to next line in buffer
    pop rsi
    push rsi
.find_eol:
    cmp esi, [rbx + TE_TEXT_LEN]
    jge .line_done
    cmp byte [r12 + rsi], 0
    je .line_done
    cmp byte [r12 + rsi], 10
    je .found_eol
    inc esi
    jmp .find_eol

.found_eol:
    inc esi                         ; Skip newline

.line_done:
    pop rax                         ; Discard old position
    push rsi                        ; Save new position
    inc r15d
    jmp .draw_line_loop

.text_done:
    pop rsi

    ; Draw cursor
    mov eax, [rbx + TE_CURSOR_LINE]
    sub eax, [rbx + TE_SCROLL_Y]
    js .no_cursor                   ; Cursor above visible area
    cmp eax, [rbx + TE_VISIBLE_LINES]
    jge .no_cursor                  ; Cursor below visible area

    ; Calculate cursor Y
    imul eax, [rbx + TE_LINE_HEIGHT]
    add eax, [rbx + W_Y]
    add eax, 2
    mov r13d, eax

    ; Calculate cursor X
    mov eax, [rbx + TE_CURSOR_COL]
    shl eax, 3                      ; * 8 pixels per char
    add eax, [rbx + W_X]
    add eax, [rbx + TE_LINE_NUM_WIDTH]
    add eax, 4
    mov r12d, eax

    ; Draw cursor block (wider for visibility)
    mov edi, r12d
    mov esi, r13d
    mov edx, 8                      ; Width = 8px (one char wide)
    mov ecx, [rbx + TE_LINE_HEIGHT]
    mov r8d, 0x00FFCC00             ; Yellow/orange cursor for visibility
    call fill_rect

.no_cursor:
.no_text:
    ; ══════════════════════════════════════════════════════════════════════
    ; Draw statusbar at bottom
    ; ══════════════════════════════════════════════════════════════════════
    ; Calculate statusbar Y position
    mov eax, [rbx + W_Y]
    add eax, [rbx + W_H]
    sub eax, 20                     ; Statusbar height = 20px
    mov r13d, eax

    ; Draw statusbar background
    mov edi, [rbx + W_X]
    mov esi, r13d
    mov edx, [rbx + W_W]
    mov ecx, 20
    mov r8d, 0x00333333             ; Dark gray background
    call fill_rect

    ; Draw top border line
    mov edi, [rbx + W_X]
    mov esi, r13d
    mov edx, [rbx + W_W]
    mov ecx, 1
    mov r8d, 0x00505050             ; Border color
    call fill_rect

    ; Build status text: "Line X, Col Y"
    lea rdi, [te_status_buf]

    ; "Line "
    mov byte [rdi], 'L'
    mov byte [rdi+1], 'i'
    mov byte [rdi+2], 'n'
    mov byte [rdi+3], 'e'
    mov byte [rdi+4], ' '
    add rdi, 5

    ; Convert line number (1-based)
    mov eax, [rbx + TE_CURSOR_LINE]
    inc eax
    call te_int_to_str

    ; ", Col "
    mov byte [rdi], ','
    mov byte [rdi+1], ' '
    mov byte [rdi+2], 'C'
    mov byte [rdi+3], 'o'
    mov byte [rdi+4], 'l'
    mov byte [rdi+5], ' '
    add rdi, 6

    ; Convert col number (1-based)
    mov eax, [rbx + TE_CURSOR_COL]
    inc eax
    call te_int_to_str

    ; Add separator and file type
    mov byte [rdi], ' '
    mov byte [rdi+1], ' '
    mov byte [rdi+2], '|'
    mov byte [rdi+3], ' '
    mov byte [rdi+4], ' '
    mov byte [rdi+5], 'A'
    mov byte [rdi+6], 'S'
    mov byte [rdi+7], 'M'
    mov byte [rdi+8], ' '
    mov byte [rdi+9], ' '
    mov byte [rdi+10], '|'
    mov byte [rdi+11], ' '
    mov byte [rdi+12], ' '
    mov byte [rdi+13], 'U'
    mov byte [rdi+14], 'T'
    mov byte [rdi+15], 'F'
    mov byte [rdi+16], '-'
    mov byte [rdi+17], '8'
    mov byte [rdi+18], ' '
    mov byte [rdi+19], ' '
    mov byte [rdi+20], '|'
    mov byte [rdi+21], ' '
    mov byte [rdi+22], ' '
    mov byte [rdi+23], 'L'
    mov byte [rdi+24], 'F'
    mov byte [rdi+25], ' '
    mov byte [rdi+26], ' '
    mov byte [rdi+27], '|'
    mov byte [rdi+28], ' '
    mov byte [rdi+29], ' '
    add rdi, 30

    ; "Saved" or "Modified"
    cmp dword [rbx + TE_MODIFIED], 0
    jne .show_modified
    mov byte [rdi], 'S'
    mov byte [rdi+1], 'a'
    mov byte [rdi+2], 'v'
    mov byte [rdi+3], 'e'
    mov byte [rdi+4], 'd'
    mov byte [rdi+5], 0
    jmp .draw_status_text
.show_modified:
    mov byte [rdi], 'M'
    mov byte [rdi+1], 'o'
    mov byte [rdi+2], 'd'
    mov byte [rdi+3], 'i'
    mov byte [rdi+4], 'f'
    mov byte [rdi+5], 'i'
    mov byte [rdi+6], 'e'
    mov byte [rdi+7], 'd'
    mov byte [rdi+8], 0

.draw_status_text:
    ; Draw status text
    mov edi, [rbx + W_X]
    add edi, 10
    mov esi, r13d
    add esi, 5
    lea rdx, [te_status_buf]
    mov ecx, 0x00AAAAAA             ; Light gray text
    call video_text

    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; Helper: Convert integer in EAX to string at RDI, advance RDI
; Simple approach: write digits backwards into temp, then copy forward
te_int_to_str:
    push rbx
    push rcx
    push rdx
    push rsi

    mov ebx, eax                    ; Save value
    lea rsi, [te_int_tmp + 11]      ; Point past end
    mov byte [rsi], 0               ; Null terminate
    dec rsi                         ; Point to last char position

    ; Handle 0 specially
    test ebx, ebx
    jnz .its_convert
    mov byte [rsi], '0'
    dec rsi
    jmp .its_copy

.its_convert:
    mov eax, ebx
.its_digit_loop:
    test eax, eax
    jz .its_copy
    xor edx, edx
    mov ecx, 10
    div ecx                         ; eax = eax/10, edx = eax%10
    add dl, '0'
    mov [rsi], dl
    dec rsi
    jmp .its_digit_loop

.its_copy:
    inc rsi                         ; Point to first digit
.its_copy_loop:
    mov al, [rsi]
    test al, al
    jz .its_done
    mov [rdi], al
    inc rdi
    inc rsi
    jmp .its_copy_loop

.its_done:
    pop rsi
    pop rdx
    pop rcx
    pop rbx
    ret

; ════════════════════════════════════════════════════════════════════════════
; TEXT_EDITOR_ON_KEY - Handle keyboard input
; Input:  RDI = widget, ESI = scancode
; Output: EAX = 1 if handled
; ════════════════════════════════════════════════════════════════════════════
text_editor_on_key:
    push rbx
    mov rbx, rdi

    ; Arrow keys
    cmp esi, 0x48                   ; Up
    je .cursor_up
    cmp esi, 0x50                   ; Down
    je .cursor_down
    cmp esi, 0x4B                   ; Left
    je .cursor_left
    cmp esi, 0x4D                   ; Right
    je .cursor_right

    ; Backspace (0x0E)
    cmp esi, 0x0E
    je .backspace

    ; Enter (0x1C)
    cmp esi, 0x1C
    je .insert_newline

    ; Printable characters - convert scancode to ASCII
    call scancode_to_ascii
    test al, al
    jz .not_handled

    ; Insert character at cursor position
    push rax                        ; Save char
    mov rdi, [rbx + TE_BUFFER]
    test rdi, rdi
    jz .insert_fail

    ; Check buffer space
    mov ecx, [rbx + TE_TEXT_LEN]
    cmp ecx, [rbx + TE_BUFFER_SIZE]
    jge .insert_fail

    ; Find cursor position in buffer (simplified: use cursor_pos)
    mov edx, [rbx + TE_CURSOR_POS]

    ; Shift text after cursor right by 1
    mov rsi, rdi
    add rsi, rcx                    ; End of text
    mov rdi, rsi
    inc rdi                         ; Destination = end + 1
    mov ecx, [rbx + TE_TEXT_LEN]
    sub ecx, edx                    ; Bytes to move
    jle .no_shift
    std                             ; Reverse direction
    rep movsb
.no_shift:
    cld                             ; ALWAYS clear direction flag

    ; Insert character
    mov rdi, [rbx + TE_BUFFER]
    add rdi, rdx
    pop rax
    mov [rdi], al

    ; Update length and cursor
    inc dword [rbx + TE_TEXT_LEN]
    inc dword [rbx + TE_CURSOR_POS]
    inc dword [rbx + TE_CURSOR_COL]
    mov dword [rbx + TE_MODIFIED], 1
    jmp .mark_dirty

.insert_fail:
    pop rax
    jmp .handled

.cursor_up:
    cmp dword [rbx + TE_CURSOR_LINE], 0
    je .handled
    dec dword [rbx + TE_CURSOR_LINE]
    call te_update_cursor_pos
    jmp .mark_dirty

.cursor_down:
    inc dword [rbx + TE_CURSOR_LINE]
    ; TODO: Bounds check against line count
    call te_update_cursor_pos
    jmp .mark_dirty

.cursor_left:
    cmp dword [rbx + TE_CURSOR_COL], 0
    je .handled
    dec dword [rbx + TE_CURSOR_COL]
    call te_update_cursor_pos
    jmp .mark_dirty

.cursor_right:
    inc dword [rbx + TE_CURSOR_COL]
    ; TODO: Bounds check against line length
    call te_update_cursor_pos
    jmp .mark_dirty

.backspace:
    cmp dword [rbx + TE_CURSOR_POS], 0
    je .handled
    ; TODO: Implement delete
    mov dword [rbx + TE_MODIFIED], 1
    jmp .mark_dirty

.insert_newline:
    ; TODO: Insert newline at cursor
    mov dword [rbx + TE_MODIFIED], 1
    jmp .mark_dirty

.mark_dirty:
    or dword [rbx + W_FLAGS], WF_DIRTY

.handled:
    mov eax, 1
    jmp .done

.not_handled:
    xor eax, eax

.done:
    pop rbx
    ret

; Helper to update cursor buffer position from line/col
; Input: RBX = widget pointer
; Calculates TE_CURSOR_POS from TE_CURSOR_LINE and TE_CURSOR_COL
te_update_cursor_pos:
    push rax
    push rcx
    push rdx
    push rsi

    ; Get buffer pointer
    mov rsi, [rbx + TE_BUFFER]
    test rsi, rsi
    jz .update_done

    ; Find start of target line
    mov ecx, [rbx + TE_CURSOR_LINE]  ; Target line
    xor edx, edx                      ; Current position in buffer
    xor eax, eax                      ; Current line number

.find_line:
    cmp eax, ecx
    jge .found_line

    ; Check end of buffer
    cmp edx, [rbx + TE_TEXT_LEN]
    jge .found_line

    ; Check for newline
    cmp byte [rsi + rdx], 10
    jne .next_char
    inc eax                           ; Found newline, increment line
.next_char:
    inc edx
    jmp .find_line

.found_line:
    ; Now add column offset
    mov eax, [rbx + TE_CURSOR_COL]
    add edx, eax

    ; Clamp to buffer length
    cmp edx, [rbx + TE_TEXT_LEN]
    jle .pos_ok
    mov edx, [rbx + TE_TEXT_LEN]
.pos_ok:
    mov [rbx + TE_CURSOR_POS], edx

.update_done:
    pop rsi
    pop rdx
    pop rcx
    pop rax
    ret

; ════════════════════════════════════════════════════════════════════════════
; TEXT_EDITOR_ON_CLICK - Handle mouse click
; ════════════════════════════════════════════════════════════════════════════
text_editor_on_click:
    push rbx
    mov rbx, rdi

    ; Calculate line from Y
    mov eax, edx
    sub eax, [rbx + W_Y]
    xor edx, edx
    div dword [rbx + TE_LINE_HEIGHT]
    add eax, [rbx + TE_SCROLL_Y]
    mov [rbx + TE_CURSOR_LINE], eax

    ; Calculate column from X
    mov eax, esi
    sub eax, [rbx + W_X]
    sub eax, [rbx + TE_LINE_NUM_WIDTH]
    sub eax, 4
    js .col_zero
    shr eax, 3                      ; / 8 pixels per char
    mov [rbx + TE_CURSOR_COL], eax
    jmp .done_click

.col_zero:
    mov dword [rbx + TE_CURSOR_COL], 0

.done_click:
    or dword [rbx + W_FLAGS], WF_DIRTY
    mov eax, 1
    pop rbx
    ret

; ════════════════════════════════════════════════════════════════════════════
; TEXT_EDITOR_ON_FOCUS
; ════════════════════════════════════════════════════════════════════════════
text_editor_on_focus:
    ret

; ════════════════════════════════════════════════════════════════════════════
; TEXT_EDITOR_DESTROY - Free resources
; ════════════════════════════════════════════════════════════════════════════
text_editor_destroy:
    push rbx
    mov rbx, rdi

    ; Free text buffer
    mov rdi, [rbx + TE_BUFFER]
    test rdi, rdi
    jz .done
    call kfree

.done:
    pop rbx
    ret

; ════════════════════════════════════════════════════════════════════════════
; TEXT_EDITOR_SET_TEXT - Set editor content
; Input:  RDI = widget, RSI = text string, EDX = length
; ════════════════════════════════════════════════════════════════════════════
text_editor_set_text:
    test rdi, rdi
    jz .done
    push rbx
    push r12
    push r13

    mov rbx, rdi
    mov r12, rsi
    mov r13d, edx

    ; Check if fits in buffer
    cmp r13d, [rbx + TE_BUFFER_SIZE]
    jge .too_large

    ; Copy text
    mov rdi, [rbx + TE_BUFFER]
    mov rsi, r12
    mov ecx, r13d
    rep movsb
    mov byte [rdi], 0               ; Null terminate

    mov [rbx + TE_TEXT_LEN], r13d
    mov dword [rbx + TE_CURSOR_POS], 0
    mov dword [rbx + TE_CURSOR_LINE], 0
    mov dword [rbx + TE_CURSOR_COL], 0
    mov dword [rbx + TE_SCROLL_Y], 0
    mov dword [rbx + TE_MODIFIED], 0
    or dword [rbx + W_FLAGS], WF_DIRTY

.too_large:
    pop r13
    pop r12
    pop rbx
.done:
    ret

; ════════════════════════════════════════════════════════════════════════════
; TEXT_EDITOR_GET_TEXT - Get editor content
; Input:  RDI = widget
; Output: RAX = buffer pointer, EDX = length
; ════════════════════════════════════════════════════════════════════════════
text_editor_get_text:
    xor eax, eax
    xor edx, edx
    test rdi, rdi
    jz .done
    mov rax, [rdi + TE_BUFFER]
    mov edx, [rdi + TE_TEXT_LEN]
.done:
    ret

; ════════════════════════════════════════════════════════════════════════════
; TEXT_EDITOR_IS_MODIFIED - Check if modified
; Input:  RDI = widget
; Output: EAX = 1 if modified
; ════════════════════════════════════════════════════════════════════════════
text_editor_is_modified:
    xor eax, eax
    test rdi, rdi
    jz .done
    mov eax, [rdi + TE_MODIFIED]
.done:
    ret

; ════════════════════════════════════════════════════════════════════════════
; DATA
; ════════════════════════════════════════════════════════════════════════════
te_line_num_buf:    db "    ", 0    ; 4 chars + null for line numbers
te_line_buf:        times 256 db 0  ; Temp buffer for line rendering
te_status_buf:      times 80 db 0   ; Status bar text buffer
te_int_tmp:         times 12 db 0   ; Temp buffer for int-to-string
