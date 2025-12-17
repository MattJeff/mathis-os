; ============================================================================
; MathisOS - File Manager Draw
; ============================================================================
; Fonctions de rendu pour le file manager
; ============================================================================

; Colors for file manager
FILES_COL_BG        equ 0x00181818    ; Dark background
FILES_COL_HEADER    equ 0x00302820    ; Header bar
FILES_COL_PATHBAR   equ 0x00252525    ; Path bar
FILES_COL_TABLE_BG  equ 0x00222222    ; Table background
FILES_COL_TABLE_HDR equ 0x002a2a2a    ; Table header row
FILES_COL_BORDER    equ 0x00505050    ; Borders
FILES_COL_SEP       equ 0x00404040    ; Separators
FILES_COL_SELECT    equ 0x00403020    ; Selection highlight
FILES_COL_WHITE     equ 0x00FFFFFF    ; White text
FILES_COL_GRAY      equ 0x00808080    ; Gray text
FILES_COL_LIGHTGRAY equ 0x00B0B0B0    ; Light gray
FILES_COL_TEXT      equ 0x00E0E0E0    ; Normal text
FILES_COL_FOLDER    equ 0x0080C0FF    ; Folder color (blue)
FILES_COL_PATH      equ 0x0080FF80    ; Path color (green)
FILES_COL_FOOTER    equ 0x00909090    ; Footer text

; ════════════════════════════════════════════════════════════════════════════
; FILES_DRAW_LIST - Draw the file list view
; ════════════════════════════════════════════════════════════════════════════
files_draw_list:
    push rax
    push rbx
    push rcx
    push rdx
    push rdi
    push rsi
    push r8
    push r9

    ; 1. Clear screen
    call files_clear_screen

    ; 2. Draw header bar
    call files_draw_header

    ; 3. Draw path bar
    call files_draw_pathbar

    ; 4. Draw table frame
    call files_draw_table_frame

    ; 5. Draw column headers
    call files_draw_columns

    ; 6. Draw file entries
    call files_draw_entries

    ; 7. Draw footer
    call files_draw_footer

    pop r9
    pop r8
    pop rsi
    pop rdi
    pop rdx
    pop rcx
    pop rbx
    pop rax
    ret

; ════════════════════════════════════════════════════════════════════════════
; FILES_CLEAR_SCREEN - Clear to dark background
; ════════════════════════════════════════════════════════════════════════════
files_clear_screen:
    push rax
    push rcx
    push rdi

    mov rdi, [screen_fb]
    mov eax, [screen_width]
    imul eax, [screen_height]
    mov ecx, eax
    mov eax, FILES_COL_BG           ; Dark background (0x00181818)
.clear_loop:
    mov dword [rdi], eax
    add rdi, 4
    dec ecx
    jnz .clear_loop

    pop rdi
    pop rcx
    pop rax
    ret

; ════════════════════════════════════════════════════════════════════════════
; FILES_DRAW_HEADER - Draw top header bar (50px high)
; ════════════════════════════════════════════════════════════════════════════
files_draw_header:
    push rax
    push rcx
    push rdi
    push rsi
    push r8

    ; Header background
    mov rdi, [screen_fb]
    mov eax, [screen_width]
    imul eax, 50
    mov ecx, eax
    mov eax, FILES_COL_HEADER
.header_bg:
    mov dword [rdi], eax
    add rdi, 4
    dec ecx
    jnz .header_bg

    ; Title "FILES" at (40, 18)
    mov rdi, [screen_fb]
    add rdi, 160                     ; 40 * 4
    mov eax, [screen_pitch]
    imul eax, 18
    add rdi, rax
    mov rsi, str_files_title
    mov r8d, FILES_COL_WHITE
    call draw_text

    ; "[ESC] Back" at right side
    mov rdi, [screen_fb]
    mov eax, [screen_width]
    sub eax, 150
    shl eax, 2
    add rdi, rax
    mov eax, [screen_pitch]
    imul eax, 18
    add rdi, rax
    mov rsi, str_esc_back
    mov r8d, FILES_COL_GRAY
    call draw_text

    pop r8
    pop rsi
    pop rdi
    pop rcx
    pop rax
    ret

; ════════════════════════════════════════════════════════════════════════════
; FILES_DRAW_PATHBAR - Draw path bar (y=60-90)
; ════════════════════════════════════════════════════════════════════════════
files_draw_pathbar:
    push rax
    push rcx
    push rdi
    push rsi
    push r8

    ; Path bar background (one line at y=60)
    mov rdi, [screen_fb]
    mov eax, [screen_pitch]
    imul eax, 60
    add rdi, rax
    add rdi, 400                     ; x=100 * 4
    mov ecx, 824
    mov eax, FILES_COL_PATHBAR
.pathbar_bg:
    mov dword [rdi], eax
    add rdi, 4
    dec ecx
    jnz .pathbar_bg

    ; Path text "/ (root)" at (110, 72)
    mov rdi, [screen_fb]
    add rdi, 440                     ; 110 * 4
    mov eax, [screen_pitch]
    imul eax, 72
    add rdi, rax
    mov rsi, str_path_icon
    mov r8d, FILES_COL_PATH
    call draw_text

    pop r8
    pop rsi
    pop rdi
    pop rcx
    pop rax
    ret

; ════════════════════════════════════════════════════════════════════════════
; FILES_DRAW_TABLE_FRAME - Draw table borders and background
; ════════════════════════════════════════════════════════════════════════════
files_draw_table_frame:
    push rax
    push rcx
    push rdi
    push r9

    ; Top border (y=100)
    mov rdi, [screen_fb]
    mov eax, [screen_pitch]
    imul eax, 100
    add rdi, rax
    add rdi, 400
    mov ecx, 824
    mov eax, FILES_COL_BORDER
.top_border:
    mov dword [rdi], eax
    add rdi, 4
    dec ecx
    jnz .top_border

    ; Table background (y=101 to y=379)
    mov r9d, 101
.table_bg:
    cmp r9d, 380
    jge .table_bg_done
    mov rdi, [screen_fb]
    mov eax, [screen_pitch]
    imul eax, r9d
    add rdi, rax
    add rdi, 400
    mov ecx, 824
    mov eax, FILES_COL_TABLE_BG
.table_row:
    mov dword [rdi], eax
    add rdi, 4
    dec ecx
    jnz .table_row
    inc r9d
    jmp .table_bg
.table_bg_done:

    ; Bottom border (y=380)
    mov rdi, [screen_fb]
    mov eax, [screen_pitch]
    imul eax, 380
    add rdi, rax
    add rdi, 400
    mov ecx, 824
    mov eax, FILES_COL_BORDER
.bot_border:
    mov dword [rdi], eax
    add rdi, 4
    dec ecx
    jnz .bot_border

    ; Left border (x=100)
    mov r9d, 100
.left_border:
    cmp r9d, 381
    jge .left_done
    mov rdi, [screen_fb]
    mov eax, [screen_pitch]
    imul eax, r9d
    add rdi, rax
    add rdi, 400
    mov dword [rdi], FILES_COL_BORDER
    inc r9d
    jmp .left_border
.left_done:

    ; Right border (x=923)
    mov r9d, 100
.right_border:
    cmp r9d, 381
    jge .right_done
    mov rdi, [screen_fb]
    mov eax, [screen_pitch]
    imul eax, r9d
    add rdi, rax
    add rdi, 3692                    ; 923 * 4
    mov dword [rdi], FILES_COL_BORDER
    inc r9d
    jmp .right_border
.right_done:

    pop r9
    pop rdi
    pop rcx
    pop rax
    ret

; ════════════════════════════════════════════════════════════════════════════
; FILES_DRAW_COLUMNS - Draw column headers
; ════════════════════════════════════════════════════════════════════════════
files_draw_columns:
    push rax
    push rcx
    push rdi
    push rsi
    push r8
    push r9

    ; Header row background (y=105-135)
    mov r9d, 105
.hdr_bg:
    cmp r9d, 135
    jge .hdr_bg_done
    mov rdi, [screen_fb]
    mov eax, [screen_pitch]
    imul eax, r9d
    add rdi, rax
    add rdi, 404
    mov ecx, 820
    mov eax, FILES_COL_TABLE_HDR
.hdr_row:
    mov dword [rdi], eax
    add rdi, 4
    dec ecx
    jnz .hdr_row
    inc r9d
    jmp .hdr_bg
.hdr_bg_done:

    ; Header separator (y=135)
    mov rdi, [screen_fb]
    mov eax, [screen_pitch]
    imul eax, 135
    add rdi, rax
    add rdi, 400
    mov ecx, 824
    mov eax, FILES_COL_SEP
.hdr_sep:
    mov dword [rdi], eax
    add rdi, 4
    dec ecx
    jnz .hdr_sep

    ; Column: Name (x=120, y=115)
    mov rdi, [screen_fb]
    add rdi, 480
    mov eax, [screen_pitch]
    imul eax, 115
    add rdi, rax
    mov rsi, str_col_name
    mov r8d, FILES_COL_LIGHTGRAY
    call draw_text

    ; Column: Size (x=550, y=115)
    mov rdi, [screen_fb]
    add rdi, 2200
    mov eax, [screen_pitch]
    imul eax, 115
    add rdi, rax
    mov rsi, str_col_size
    mov r8d, FILES_COL_LIGHTGRAY
    call draw_text

    ; Column: Modified (x=700, y=115)
    mov rdi, [screen_fb]
    add rdi, 2800
    mov eax, [screen_pitch]
    imul eax, 115
    add rdi, rax
    mov rsi, str_col_mod
    mov r8d, FILES_COL_LIGHTGRAY
    call draw_text

    pop r9
    pop r8
    pop rsi
    pop rdi
    pop rcx
    pop rax
    ret

; ════════════════════════════════════════════════════════════════════════════
; FILES_DRAW_ENTRIES - Draw file entries with selection
; ════════════════════════════════════════════════════════════════════════════
files_draw_entries:
    push rax
    push rbx
    push rcx
    push rdx
    push rdi
    push rsi
    push r8
    push r9

    ; Entry 0: PROJECTS/ at y=160 (selection y=145-185)
    xor ebx, ebx                     ; entry index = 0
    mov edx, 145                     ; selection y start
    mov ecx, 160                     ; text y
    mov rsi, str_files_e0
    mov r8d, FILES_COL_FOLDER        ; folder = blue
    call files_draw_entry_row
    mov rsi, str_size_dir
    call files_draw_entry_size
    mov rsi, str_mod_1
    call files_draw_entry_mod

    ; Entry 1: README.TXT at y=210 (selection y=195-235)
    mov ebx, 1
    mov edx, 195
    mov ecx, 210
    mov rsi, str_files_e1
    mov r8d, FILES_COL_TEXT
    call files_draw_entry_row
    mov rsi, str_size_readme
    call files_draw_entry_size
    mov rsi, str_mod_2
    call files_draw_entry_mod

    ; Entry 2: HELLO.ASM at y=260 (selection y=245-285)
    mov ebx, 2
    mov edx, 245
    mov ecx, 260
    mov rsi, str_files_e2
    mov r8d, FILES_COL_TEXT
    call files_draw_entry_row
    mov rsi, str_size_hello
    call files_draw_entry_size
    mov rsi, str_mod_3
    call files_draw_entry_mod

    pop r9
    pop r8
    pop rsi
    pop rdi
    pop rdx
    pop rcx
    pop rbx
    pop rax
    ret

; ════════════════════════════════════════════════════════════════════════════
; FILES_DRAW_ENTRY_ROW - Draw single entry name with selection
; Input: ebx=index, edx=sel_y, ecx=text_y, rsi=name, r8d=color
; ════════════════════════════════════════════════════════════════════════════
files_draw_entry_row:
    push rax
    push rcx
    push rdx
    push rdi
    push r9
    push r10
    push r11

    mov r10d, ecx                    ; save text_y
    mov r11d, r8d                    ; save color

    ; Check if selected
    cmp ebx, [files_selected]
    jne .no_selection

    ; Draw selection highlight (40 pixels high)
    mov r9d, edx                     ; y start
    add edx, 40                      ; y end
.sel_bg:
    cmp r9d, edx
    jge .sel_done
    mov rdi, [screen_fb]
    mov eax, [screen_pitch]
    imul eax, r9d
    add rdi, rax
    add rdi, 404
    mov ecx, 820
    mov eax, FILES_COL_SELECT
.sel_row:
    mov dword [rdi], eax
    add rdi, 4
    dec ecx
    jnz .sel_row
    inc r9d
    jmp .sel_bg
.sel_done:
    mov r11d, FILES_COL_WHITE        ; selected = white text

.no_selection:
    ; Draw name at (120, text_y)
    mov rdi, [screen_fb]
    add rdi, 480                     ; 120 * 4
    mov eax, [screen_pitch]
    imul eax, r10d
    add rdi, rax
    mov r8d, r11d
    call draw_text

    pop r11
    pop r10
    pop r9
    pop rdi
    pop rdx
    pop rcx
    pop rax
    ret

; ════════════════════════════════════════════════════════════════════════════
; FILES_DRAW_ENTRY_SIZE - Draw size column
; Input: ecx=text_y (from previous call), rsi=size_str
; ════════════════════════════════════════════════════════════════════════════
files_draw_entry_size:
    push rax
    push rdi
    push r8

    mov rdi, [screen_fb]
    add rdi, 2200                    ; 550 * 4
    mov eax, [screen_pitch]
    imul eax, r10d                   ; use saved text_y from r10
    add rdi, rax
    mov r8d, FILES_COL_GRAY
    call draw_text

    pop r8
    pop rdi
    pop rax
    ret

; ════════════════════════════════════════════════════════════════════════════
; FILES_DRAW_ENTRY_MOD - Draw modified column
; Input: rsi=mod_str
; ════════════════════════════════════════════════════════════════════════════
files_draw_entry_mod:
    push rax
    push rdi
    push r8

    mov rdi, [screen_fb]
    add rdi, 2800                    ; 700 * 4
    mov eax, [screen_pitch]
    imul eax, r10d                   ; use saved text_y from r10
    add rdi, rax
    mov r8d, FILES_COL_GRAY
    call draw_text

    pop r8
    pop rdi
    pop rax
    ret

; ════════════════════════════════════════════════════════════════════════════
; FILES_DRAW_FOOTER - Draw footer with help text
; ════════════════════════════════════════════════════════════════════════════
files_draw_footer:
    push rax
    push rcx
    push rdi
    push rsi
    push r8
    push r9

    ; Footer background (y=700-768)
    mov r9d, 700
.ftr_bg:
    cmp r9d, 768
    jge .ftr_bg_done
    mov rdi, [screen_fb]
    mov eax, [screen_pitch]
    imul eax, r9d
    add rdi, rax
    mov ecx, [screen_width]
    mov eax, FILES_COL_PATHBAR
.ftr_row:
    mov dword [rdi], eax
    add rdi, 4
    dec ecx
    jnz .ftr_row
    inc r9d
    jmp .ftr_bg
.ftr_bg_done:

    ; Footer separator (y=700)
    mov rdi, [screen_fb]
    mov eax, [screen_pitch]
    imul eax, 700
    add rdi, rax
    mov ecx, [screen_width]
    mov eax, FILES_COL_SEP
.ftr_sep:
    mov dword [rdi], eax
    add rdi, 4
    dec ecx
    jnz .ftr_sep

    ; Help line 1 (y=720)
    mov rdi, [screen_fb]
    add rdi, 160
    mov eax, [screen_pitch]
    imul eax, 720
    add rdi, rax
    mov rsi, str_files_help1
    mov r8d, FILES_COL_FOOTER
    call draw_text

    ; Help line 2 (y=745)
    mov rdi, [screen_fb]
    add rdi, 160
    mov eax, [screen_pitch]
    imul eax, 745
    add rdi, rax
    mov rsi, str_files_help2
    mov r8d, FILES_COL_FOOTER
    call draw_text

    pop r9
    pop r8
    pop rsi
    pop rdi
    pop rcx
    pop rax
    ret
