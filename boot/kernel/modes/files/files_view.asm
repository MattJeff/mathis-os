; ============================================================================
; MathisOS - File Manager Viewer
; ============================================================================
; Mode visualisation de fichiers (README, ASM avec syntax highlighting)
; ============================================================================

; Viewer colors
VIEW_COL_BG         equ 0x001a1a1a    ; Dark background
VIEW_COL_HEADER     equ 0x00252525    ; Header bar
VIEW_COL_WHITE      equ 0x00FFFFFF    ; White text
VIEW_COL_GRAY       equ 0x00808080    ; Gray text
VIEW_COL_LINENUM    equ 0x00606060    ; Line numbers
VIEW_COL_TEXT       equ 0x00d0d0d0    ; Normal text
VIEW_COL_COMMENT    equ 0x00009a4a    ; Comments (green)
VIEW_COL_LABEL      equ 0x000066cc    ; Labels (blue)

; ════════════════════════════════════════════════════════════════════════════
; FILES_DRAW_VIEWER - Draw file viewer mode
; ════════════════════════════════════════════════════════════════════════════
files_draw_viewer:
    push rax
    push rbx
    push rcx
    push rdx
    push rdi
    push rsi
    push r8
    push r9

    ; 1. Clear screen
    call view_clear_screen

    ; 2. Draw header with filename
    call view_draw_header

    ; 3. Draw content based on file type
    cmp dword [files_selected], 1
    jne .draw_asm
    call view_draw_readme
    jmp .draw_footer
.draw_asm:
    call view_draw_asm

.draw_footer:
    ; 4. Draw footer
    call view_draw_footer

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
; VIEW_CLEAR_SCREEN
; ════════════════════════════════════════════════════════════════════════════
view_clear_screen:
    push rax
    push rcx
    push rdi

    mov rdi, [screen_fb]
    mov eax, [screen_width]
    imul eax, [screen_height]
    mov ecx, eax
    mov eax, VIEW_COL_BG
.clear:
    mov dword [rdi], eax
    add rdi, 4
    dec ecx
    jnz .clear

    pop rdi
    pop rcx
    pop rax
    ret

; ════════════════════════════════════════════════════════════════════════════
; VIEW_DRAW_HEADER - Draw header bar with filename
; ════════════════════════════════════════════════════════════════════════════
view_draw_header:
    push rax
    push rcx
    push rdi
    push rsi
    push r8

    ; Header background (40px)
    mov rdi, [screen_fb]
    mov eax, [screen_width]
    imul eax, 40
    mov ecx, eax
    mov eax, VIEW_COL_HEADER
.header_bg:
    mov dword [rdi], eax
    add rdi, 4
    dec ecx
    jnz .header_bg

    ; Filename at (10, 14)
    mov rdi, [screen_fb]
    mov eax, [screen_pitch]
    imul eax, 14
    add rdi, rax
    add rdi, 40

    ; Pick filename based on selection
    cmp dword [files_selected], 1
    jne .name_asm
    mov rsi, str_view_readme
    jmp .name_draw
.name_asm:
    mov rsi, str_view_hello
.name_draw:
    mov r8d, VIEW_COL_WHITE
    call draw_text

    pop r8
    pop rsi
    pop rdi
    pop rcx
    pop rax
    ret

; ════════════════════════════════════════════════════════════════════════════
; VIEW_DRAW_README - Draw README.TXT content
; ════════════════════════════════════════════════════════════════════════════
view_draw_readme:
    push rax
    push rdi
    push rsi
    push r8

    ; Line 1 at (20, 60)
    mov rdi, [screen_fb]
    add rdi, 80
    mov eax, [screen_pitch]
    imul eax, 60
    add rdi, rax
    mov rsi, str_readme_l1
    mov r8d, VIEW_COL_COMMENT
    call draw_text

    ; Line 2 at (20, 80) - empty
    mov rdi, [screen_fb]
    add rdi, 80
    mov eax, [screen_pitch]
    imul eax, 80
    add rdi, rax
    mov rsi, str_readme_l2
    mov r8d, VIEW_COL_TEXT
    call draw_text

    ; Line 3 at (20, 100)
    mov rdi, [screen_fb]
    add rdi, 80
    mov eax, [screen_pitch]
    imul eax, 100
    add rdi, rax
    mov rsi, str_readme_l3
    mov r8d, VIEW_COL_TEXT
    call draw_text

    pop r8
    pop rsi
    pop rdi
    pop rax
    ret

; ════════════════════════════════════════════════════════════════════════════
; VIEW_DRAW_ASM - Draw HELLO.ASM with syntax highlighting
; ════════════════════════════════════════════════════════════════════════════
view_draw_asm:
    push rax
    push rdi
    push rsi
    push r8

    ; Line 1: comment (green)
    mov edi, 70
    mov rsi, str_ln_1
    mov r8d, VIEW_COL_LINENUM
    call view_draw_line_num
    mov rsi, str_asm_l1
    mov r8d, VIEW_COL_COMMENT
    call view_draw_line_content

    ; Line 2: section .text
    mov edi, 90
    mov rsi, str_ln_2
    mov r8d, VIEW_COL_LINENUM
    call view_draw_line_num
    mov rsi, str_asm_l2
    mov r8d, VIEW_COL_TEXT
    call view_draw_line_content

    ; Line 3: global _start
    mov edi, 110
    mov rsi, str_ln_3
    mov r8d, VIEW_COL_LINENUM
    call view_draw_line_num
    mov rsi, str_asm_l3
    mov r8d, VIEW_COL_TEXT
    call view_draw_line_content

    ; Line 4: _start: (label = blue)
    mov edi, 130
    mov rsi, str_ln_4
    mov r8d, VIEW_COL_LINENUM
    call view_draw_line_num
    mov rsi, str_asm_l4
    mov r8d, VIEW_COL_LABEL
    call view_draw_line_content

    ; Line 5: mov rax, 1
    mov edi, 150
    mov rsi, str_ln_5
    mov r8d, VIEW_COL_LINENUM
    call view_draw_line_num
    mov rsi, str_asm_l5
    mov r8d, VIEW_COL_TEXT
    call view_draw_line_content

    ; Line 6: mov rdi, 1
    mov edi, 170
    mov rsi, str_ln_6
    mov r8d, VIEW_COL_LINENUM
    call view_draw_line_num
    mov rsi, str_asm_l6
    mov r8d, VIEW_COL_TEXT
    call view_draw_line_content

    pop r8
    pop rsi
    pop rdi
    pop rax
    ret

; ════════════════════════════════════════════════════════════════════════════
; VIEW_DRAW_LINE_NUM - Draw line number
; Input: edi=y, rsi=str, r8d=color
; ════════════════════════════════════════════════════════════════════════════
view_draw_line_num:
    push rax
    push rdi
    push r9

    mov r9d, edi                     ; save y
    mov rdi, [screen_fb]
    add rdi, 40                      ; x=10 * 4
    mov eax, [screen_pitch]
    imul eax, r9d
    add rdi, rax
    call draw_text

    pop r9
    pop rdi
    pop rax
    ret

; ════════════════════════════════════════════════════════════════════════════
; VIEW_DRAW_LINE_CONTENT - Draw line content
; Input: edi=y (saved in r9), rsi=str, r8d=color
; ════════════════════════════════════════════════════════════════════════════
view_draw_line_content:
    push rax
    push rdi

    mov rdi, [screen_fb]
    add rdi, 140                     ; x=35 * 4
    mov eax, [screen_pitch]
    imul eax, r9d                    ; use saved y
    add rdi, rax
    call draw_text

    pop rdi
    pop rax
    ret

; ════════════════════════════════════════════════════════════════════════════
; VIEW_DRAW_FOOTER - Draw footer with help
; ════════════════════════════════════════════════════════════════════════════
view_draw_footer:
    push rax
    push rdi
    push rsi
    push r8

    mov rdi, [screen_fb]
    mov eax, [screen_height]
    sub eax, 30
    imul eax, [screen_pitch]
    add rdi, rax
    add rdi, 40
    mov rsi, str_view_help
    mov r8d, VIEW_COL_GRAY
    call draw_text

    pop r8
    pop rsi
    pop rdi
    pop rax
    ret
