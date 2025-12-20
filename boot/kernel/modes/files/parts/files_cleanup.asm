; ════════════════════════════════════════════════════════════════════════════
; FILES_CLEANUP.ASM - Cleanup functions for Files App
; ════════════════════════════════════════════════════════════════════════════

[BITS 64]

; ════════════════════════════════════════════════════════════════════════════
; FILES_APP_CLEANUP - Destroy all widgets
; ════════════════════════════════════════════════════════════════════════════
files_app_cleanup:
    mov rdi, [fa_header]
    test rdi, rdi
    jz .no_header
    call widget_destroy
    mov qword [fa_header], 0
.no_header:

    mov rdi, [fa_pathbar]
    test rdi, rdi
    jz .no_pathbar
    call widget_destroy
    mov qword [fa_pathbar], 0
.no_pathbar:

    mov rdi, [fa_file_list]
    test rdi, rdi
    jz .no_filelist
    call widget_destroy
    mov qword [fa_file_list], 0
.no_filelist:

    mov rdi, [fa_statusbar]
    test rdi, rdi
    jz .no_statusbar
    call widget_destroy
    mov qword [fa_statusbar], 0
.no_statusbar:

    mov rdi, [fa_editor]
    test rdi, rdi
    jz .no_editor
    call widget_destroy
    mov qword [fa_editor], 0
.no_editor:

    mov rdi, [fa_dialog]
    test rdi, rdi
    jz .no_dialog
    call widget_destroy
    mov qword [fa_dialog], 0
.no_dialog:

    mov byte [fa_initialized], 0
    ret
