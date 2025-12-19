; ============================================================================
; MathisOS - Global Keys Handler
; ============================================================================
; Touches globales traitees dans TOUS les modes
; - ESC : Reboot
; - Tab : Cycle modes
; - F9  : Ring 3 demo
; ============================================================================

; ════════════════════════════════════════════════════════════════════════════
; HANDLE GLOBAL KEYS
; ════════════════════════════════════════════════════════════════════════════
; Entree: al = scancode
; Sortie: al = 1 si handled, 0 sinon
; ════════════════════════════════════════════════════════════════════════════
handle_global_keys:
    push rbx

    ; ─────────────────────────────────────────────────────────────────────────
    ; ESC (0x01) = Reboot (but NOT if files mode has dialog/editor active)
    ; ─────────────────────────────────────────────────────────────────────────
    cmp al, 0x01
    jne .skip_esc_check
    ; Check if in files mode with dialog or editor active
    cmp byte [mode_flag], 4
    jne .do_reboot                  ; Not in files mode, allow reboot
    cmp dword [fa_state], FA_STATE_LIST
    jne .not_handled_global         ; Dialog or editor active, let files handle ESC
    jmp .do_reboot
.skip_esc_check:

    ; ─────────────────────────────────────────────────────────────────────────
    ; Tab (0x0F) = Cycle modes (0 → 1 → 2 → 3 → 4 → 0)
    ; BUT: Skip if files mode has dialog/editor active
    ; ─────────────────────────────────────────────────────────────────────────
    cmp al, 0x0F
    jne .skip_tab_check
    ; Check if in files mode with dialog or editor active
    cmp byte [mode_flag], 4
    jne .do_tab                     ; Not in files mode, allow tab cycling
    cmp dword [fa_state], FA_STATE_LIST
    jne .not_handled_global         ; Dialog or editor active, let files handle it
    jmp .do_tab
.skip_tab_check:

    ; ─────────────────────────────────────────────────────────────────────────
    ; F9 (0x43) = Launch Ring 3 user process demo
    ; ─────────────────────────────────────────────────────────────────────────
    cmp al, 0x43
    je .do_f9

    ; ─────────────────────────────────────────────────────────────────────────
    ; F10 (0x44) = Reserved for future use
    ; ─────────────────────────────────────────────────────────────────────────
    cmp al, 0x44
    je .do_f10

    ; Pas handled
.not_handled_global:
    xor al, al
    pop rbx
    ret

; ════════════════════════════════════════════════════════════════════════════
; REBOOT - Triple fault
; ════════════════════════════════════════════════════════════════════════════
.do_reboot:
    lidt [idt64_null]
    int 0
    ; Never returns

; ════════════════════════════════════════════════════════════════════════════
; TAB - Cycle display modes
; ════════════════════════════════════════════════════════════════════════════
.do_tab:
    inc byte [mode_flag]
    cmp byte [mode_flag], 5
    jl .tab_ok
    mov byte [mode_flag], 0
.tab_ok:
    ; Refresh files mode si on y entre
    mov byte [files_dirty], 1
    ; Clear key state to prevent double-processing
    mov byte [key_pressed], 0
    mov byte [key3d_scancode], 0
    mov al, 1
    pop rbx
    ret

; ════════════════════════════════════════════════════════════════════════════
; F9 - Ring 3 user process demo
; ════════════════════════════════════════════════════════════════════════════
.do_f9:
    ; Launch user process in Ring 3
    mov rdi, user_process_demo
    mov rsi, user_stack_top
    call switch_to_ring3
    ; Never returns if successful
    mov al, 1
    pop rbx
    ret

; ════════════════════════════════════════════════════════════════════════════
; F10 - Reserved
; ════════════════════════════════════════════════════════════════════════════
.do_f10:
    ; TODO: Future feature
    mov al, 1
    pop rbx
    ret
