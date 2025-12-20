; ════════════════════════════════════════════════════════════════════════════
; FILES_INIT.ASM - Files App initialization
; ════════════════════════════════════════════════════════════════════════════

[BITS 64]

; ════════════════════════════════════════════════════════════════════════════
; FILES_APP_INIT - Initialize all widgets
; ════════════════════════════════════════════════════════════════════════════
files_app_init:
    cmp byte [fa_initialized], 1
    je .done                        ; Already initialized

    push rbx
    push r12
    push r13
    push r14
    push r15

    ; Load directory from filesystem
    call fa_load_directory

    ; Get screen dimensions
    mov r12d, [screen_width]
    mov r13d, [screen_height]

    ; Create header (full width, 24px height, at top)
    xor esi, esi                    ; x = 0
    xor edx, edx                    ; y = 0
    mov ecx, r12d                   ; w = screen_width
    mov r8d, 24                     ; h = 24
    mov r9, fa_title_files          ; title
    call header_create
    mov [fa_header], rax

    ; Create pathbar (below header, after sidebar)
    mov esi, SIDEBAR_WIDTH          ; x = sidebar width
    mov edx, 24                     ; y = 24
    mov ecx, r12d
    sub ecx, SIDEBAR_WIDTH          ; w = screen_width - sidebar
    mov r8d, 20                     ; h = 20
    mov r9, fa_current_path         ; path
    call pathbar_create
    mov [fa_pathbar], rax

    ; Initialize sidebar (left side)
    xor edi, edi                    ; x = 0
    mov esi, 24                     ; y = 24 (below header)
    mov edx, r13d
    sub edx, 70                     ; h = screen_height - header - statusbar
    call sidebar_init

    ; Set sidebar callback
    mov rdi, fa_on_location_change
    call sidebar_set_callback

    ; Create file list (main area, right of sidebar)
    mov esi, SIDEBAR_WIDTH
    add esi, 10                     ; x = sidebar + margin
    mov edx, 54                     ; y = 24 + 20 + 10
    mov ecx, r12d
    sub ecx, SIDEBAR_WIDTH
    sub ecx, 20                     ; w = screen_width - sidebar - margins
    mov r8d, r13d
    sub r8d, 110                    ; h = screen_height - header - pathbar - statusbar
    call file_list_create
    mov [fa_file_list], rax

    ; Set file entries (from dynamic data)
    mov rdi, rax
    mov rsi, fa_entries
    mov edx, [fa_entry_count]
    call file_list_set_entries

    ; Set callback for file selection
    mov rdi, [fa_file_list]
    mov rsi, fa_on_file_select
    call file_list_set_callback

    ; Create statusbar (at bottom)
    xor esi, esi                    ; x = 0
    mov edx, r13d
    sub edx, 46                     ; y = screen_height - 46
    mov ecx, r12d                   ; w = screen_width
    mov r8d, 46                     ; h = 46
    call statusbar_create
    mov [fa_statusbar], rax

    mov byte [fa_initialized], 1
    mov dword [fa_state], FA_STATE_LIST

    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx

.done:
    ret
