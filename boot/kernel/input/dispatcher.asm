; ============================================================================
; MathisOS - Input Dispatcher
; ============================================================================
; Route les events clavier vers les bons handlers selon le mode
; Appele depuis la main loop, PAS depuis l'ISR
; ============================================================================

; ════════════════════════════════════════════════════════════════════════════
; PROCESS INPUT - Appeler depuis main loop
; ════════════════════════════════════════════════════════════════════════════
; Verifie si une touche est prete et la route vers le bon handler
; ════════════════════════════════════════════════════════════════════════════
process_input:
    push rax
    push rbx

    ; Check si nouvelle touche
    cmp byte [key_ready], 0
    je .no_key

    ; Clear flag et recuperer scancode
    mov byte [key_ready], 0
    mov al, [key_pressed]

    ; === GLOBAL KEYS (toujours traites en premier) ===
    call handle_global_keys
    test al, al                         ; Si handled (al=1), skip le reste
    jnz .no_key

    ; === ROUTER SELON MODE ===
    mov bl, [mode_flag]

    cmp bl, 4                           ; Mode FILES
    je .dispatch_files

    cmp bl, 3                           ; Mode 3D
    je .dispatch_3d

    cmp bl, 2                           ; Mode GUI
    je .dispatch_gui

    cmp bl, 1                           ; Mode SHELL
    je .dispatch_shell

    ; Mode 0 = graphics mode (pas de handler)
    jmp .no_key

.dispatch_shell:
    mov al, [key_pressed]
    call handle_shell_keys
    jmp .no_key

.dispatch_files:
    mov al, [key_pressed]
    call handle_files_keys
    jmp .no_key

.dispatch_3d:
    mov al, [key_pressed]
    call handle_3d_keys
    jmp .no_key

.dispatch_gui:
    mov al, [key_pressed]
    call handle_gui_keys

.no_key:
    pop rbx
    pop rax
    ret

; ════════════════════════════════════════════════════════════════════════════
; HANDLE GLOBAL KEYS - Touches traitees dans tous les modes
; ════════════════════════════════════════════════════════════════════════════
; Entree: al = scancode
; Sortie: al = 1 si handled, 0 sinon
; ════════════════════════════════════════════════════════════════════════════
handle_global_keys:
    ; ESC = reboot
    cmp al, 0x01
    je .do_reboot

    ; Tab = cycle modes
    cmp al, 0x0F
    je .do_tab

    ; F9 = Ring 3 demo (si implemente)
    cmp al, 0x43
    je .do_f9

    ; Pas handled
    xor al, al
    ret

.do_reboot:
    lidt [idt64_null]
    int 0
    ; Never returns

.do_tab:
    inc byte [mode_flag]
    cmp byte [mode_flag], 5
    jl .tab_done
    mov byte [mode_flag], 0
.tab_done:
    mov byte [files_dirty], 1           ; Refresh si on entre en mode files
    mov al, 1
    ret

.do_f9:
    ; TODO: Launch Ring 3 user process
    ; mov rdi, user_process_demo
    ; mov rsi, user_stack_top
    ; call switch_to_ring3
    mov al, 1
    ret
