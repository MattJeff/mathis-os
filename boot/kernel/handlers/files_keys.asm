; ============================================================================
; MathisOS - Files Keys Handler
; ============================================================================
; Touches pour le mode FILES (mode 4)
; - W/Up   : Monter dans la liste
; - S/Down : Descendre dans la liste
; - Enter  : Ouvrir fichier/dossier
; - ESC    : Fermer viewer
; ============================================================================

; ════════════════════════════════════════════════════════════════════════════
; HANDLE FILES KEYS
; ════════════════════════════════════════════════════════════════════════════
; Entree: al = scancode
; Sortie: al = 1 si handled, 0 sinon
; ════════════════════════════════════════════════════════════════════════════
handle_files_keys:
    push rbx

    ; ─────────────────────────────────────────────────────────────────────────
    ; W (0x11) or Up Arrow (0x48) = Navigate up
    ; ─────────────────────────────────────────────────────────────────────────
    cmp al, 0x11                        ; W
    je .key_up
    cmp al, 0x48                        ; Up arrow
    je .key_up

    ; ─────────────────────────────────────────────────────────────────────────
    ; S (0x1F) or Down Arrow (0x50) = Navigate down
    ; ─────────────────────────────────────────────────────────────────────────
    cmp al, 0x1F                        ; S
    je .key_down
    cmp al, 0x50                        ; Down arrow
    je .key_down

    ; ─────────────────────────────────────────────────────────────────────────
    ; Enter (0x1C) = Open file/folder
    ; ─────────────────────────────────────────────────────────────────────────
    cmp al, 0x1C
    je .key_enter

    ; ─────────────────────────────────────────────────────────────────────────
    ; ESC (0x01) = Close viewer (retour a la liste)
    ; ─────────────────────────────────────────────────────────────────────────
    cmp al, 0x01
    je .key_esc

    ; ─────────────────────────────────────────────────────────────────────────
    ; Backspace (0x0E) = Go back / parent folder
    ; ─────────────────────────────────────────────────────────────────────────
    cmp al, 0x0E
    je .key_back

    ; Not handled - let global keys process it
    xor al, al
    pop rbx
    ret

; ════════════════════════════════════════════════════════════════════════════
; UP - Move selection up
; ════════════════════════════════════════════════════════════════════════════
.key_up:
    cmp dword [files_selected], 0
    je .handled                         ; Already at top
    dec dword [files_selected]
    mov byte [files_dirty], 1           ; Mark for redraw
    jmp .handled

; ════════════════════════════════════════════════════════════════════════════
; DOWN - Move selection down
; ════════════════════════════════════════════════════════════════════════════
.key_down:
    cmp dword [files_selected], 2       ; Max = 2 (3 entries: 0,1,2)
    jge .handled                        ; Already at bottom
    inc dword [files_selected]
    mov byte [files_dirty], 1           ; Mark for redraw
    jmp .handled

; ════════════════════════════════════════════════════════════════════════════
; ENTER - Open selected file/folder
; ════════════════════════════════════════════════════════════════════════════
.key_enter:
    ; Check if viewing a file
    cmp byte [files_viewing], 1
    je .handled                         ; Already viewing, ignore

    ; Check selection
    cmp dword [files_selected], 0
    je .handled                         ; Can't open folder yet (entry 0)

    ; Open file for viewing
    mov byte [files_viewing], 1
    mov byte [files_dirty], 1           ; Mark for redraw
    jmp .handled

; ════════════════════════════════════════════════════════════════════════════
; ESC - Close viewer, return to list
; ════════════════════════════════════════════════════════════════════════════
.key_esc:
    cmp byte [files_viewing], 0
    je .not_handled                     ; Not viewing, let global handle ESC
    mov byte [files_viewing], 0
    mov byte [files_dirty], 1           ; Mark for redraw
    jmp .handled

; ════════════════════════════════════════════════════════════════════════════
; BACK - Go to parent folder
; ════════════════════════════════════════════════════════════════════════════
.key_back:
    ; TODO: Navigate to parent folder
    ; For now, just close viewer if open
    cmp byte [files_viewing], 1
    jne .handled
    mov byte [files_viewing], 0
    mov byte [files_dirty], 1
    jmp .handled

; ════════════════════════════════════════════════════════════════════════════
.handled:
    mov al, 1
    pop rbx
    ret

.not_handled:
    xor al, al
    pop rbx
    ret
