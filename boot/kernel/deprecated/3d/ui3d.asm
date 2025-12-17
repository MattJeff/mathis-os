; ============================================================================
; UI3D.ASM - Main 3D User Interface for MATHIS OS
; ============================================================================
[BITS 64]
; Main loop handling input, rendering, and state transitions

; UI States
UI_STATE_SPACE      equ 0       ; Navigating in 3D space
UI_STATE_TERMINAL   equ 1       ; Inside Terminal app
UI_STATE_FILES      equ 2       ; Inside Files app
UI_STATE_HYPERCUBE  equ 3       ; Inside HyperCubeX
UI_STATE_SETTINGS   equ 4       ; Inside Settings

; ============================================================================
; UI DATA
; ============================================================================
align 4
ui_state:           dd UI_STATE_SPACE
ui_prev_state:      dd UI_STATE_SPACE
ui_transition:      dd 0        ; Transition animation counter
ui_running:         dd 1        ; Main loop flag

; Crosshair position (center of screen)
crosshair_x:        dd 0
crosshair_y:        dd 0


; ============================================================================
; UI3D_INIT - Initialize the 3D UI system
; ============================================================================
ui3d_init:
    push rax

    ; Initialize camera
    call camera_init

    ; Initialize world
    call world_init

    ; Calculate crosshair position (screen center)
    mov eax, [screen_width]
    shr eax, 1
    mov [crosshair_x], eax

    mov eax, [screen_height]
    shr eax, 1
    mov [crosshair_y], eax

    ; Set initial state
    mov dword [ui_state], UI_STATE_SPACE
    mov dword [ui_running], 1

    pop rax
    ret

; ============================================================================
; UI3D_MAIN - Main 3D UI loop
; ============================================================================
ui3d_main:
    push rax
    push rbx
    push rcx
    push rdx

.main_loop:
    ; Check if still running
    cmp dword [ui_running], 0
    je .exit_loop

    ; Check if mode changed (Tab pressed) - exit to let main kernel handle mode switch
    cmp byte [mode_flag], 3
    jne .exit_loop

    ; Process input
    call ui3d_input

    ; Update world state
    call world_update

    ; Render based on current state
    mov eax, [ui_state]
    cmp eax, UI_STATE_SPACE
    je .render_space
    cmp eax, UI_STATE_TERMINAL
    je .render_terminal
    cmp eax, UI_STATE_FILES
    je .render_files
    cmp eax, UI_STATE_HYPERCUBE
    je .render_hypercube
    cmp eax, UI_STATE_SETTINGS
    je .render_settings
    jmp .render_done

.render_space:
    call ui3d_render_space
    jmp .render_done

.render_terminal:
    call ui3d_render_terminal
    jmp .render_done

.render_files:
    call ui3d_render_files
    jmp .render_done

.render_hypercube:
    call ui3d_render_hypercube
    jmp .render_done

.render_settings:
    call ui3d_render_settings
    jmp .render_done

.render_done:
    ; Small delay for frame timing
    call ui3d_delay

    jmp .main_loop

.exit_loop:
    pop rdx
    pop rcx
    pop rbx
    pop rax
    ret

; ============================================================================
; UI3D_INPUT - Process keyboard input (uses key3d_scancode from kernel IRQ)
; ============================================================================
ui3d_input:
    push rax
    push rbx

    ; Read scancode from kernel's 3D key buffer
    movzx eax, byte [key3d_scancode]
    test al, al
    jz .no_input

    ; Clear the scancode so we don't process it again
    mov byte [key3d_scancode], 0

    ; Check current state for input handling
    mov ebx, [ui_state]
    cmp ebx, UI_STATE_SPACE
    je .space_input
    jmp .app_input

.space_input:
    ; Movement keys (WASD)
    cmp al, 0x11                ; W - forward
    je .move_forward
    cmp al, 0x1F                ; S - backward
    je .move_backward
    cmp al, 0x1E                ; A - strafe left
    je .strafe_left
    cmp al, 0x20                ; D - strafe right
    je .strafe_right

    ; Rotation (arrow keys)
    cmp al, 0x4B                ; Left arrow
    je .rotate_left
    cmp al, 0x4D                ; Right arrow
    je .rotate_right

    ; Up/Down movement
    cmp al, 0x48                ; Up arrow
    je .move_up
    cmp al, 0x50                ; Down arrow
    je .move_down

    ; Selection
    cmp al, 0x1C                ; Enter - select node
    je .select_node
    cmp al, 0x39                ; Space - select node
    je .select_node

    jmp .no_input

.move_forward:
    call camera_move_forward
    jmp .no_input

.move_backward:
    call camera_move_backward
    jmp .no_input

.strafe_left:
    call camera_strafe_left
    jmp .no_input

.strafe_right:
    call camera_strafe_right
    jmp .no_input

.rotate_left:
    call camera_rotate_left
    jmp .no_input

.rotate_right:
    call camera_rotate_right
    jmp .no_input

.move_up:
    call camera_move_up
    jmp .no_input

.move_down:
    call camera_move_down
    jmp .no_input

.select_node:
    call world_select_node
    cmp eax, -1
    je .no_input
    ; Enter the selected node
    inc eax                     ; State = node_index + 1
    mov [ui_state], eax
    jmp .no_input

.app_input:
    ; Inside an app - Escape returns to space
    cmp al, 0x01                ; Escape
    je .return_to_space
    jmp .no_input

.return_to_space:
    mov dword [ui_state], UI_STATE_SPACE
    call camera_init            ; Reset camera position

.no_input:
    pop rbx
    pop rax
    ret

; ============================================================================
; UI3D_RENDER_SPACE - Render the 3D space view
; ============================================================================
ui3d_render_space:
    push rax
    push rbx
    push rcx
    push rdx
    push rdi
    push rsi

    ; Clear screen with stars
    call render3d_clear

    ; Draw ground grid for spatial reference
    call draw_ground_grid

    ; Render world (nodes, links, particles)
    call world_render

    ; Draw crosshair in center
    call draw_crosshair

    ; Draw HUD
    call draw_hud

    pop rsi
    pop rdi
    pop rdx
    pop rcx
    pop rbx
    pop rax
    ret

; ============================================================================
; DRAW_CROSSHAIR - Draw stylized targeting crosshair at screen center
; ============================================================================
draw_crosshair:
    push rax
    push rbx
    push rcx
    push rdx
    push rdi
    push rsi

    mov edi, [crosshair_x]
    mov esi, [crosshair_y]

    ; Center dot (bright)
    mov edx, COL3D_TEXT
    call draw_pixel_3d

    ; Draw corner brackets instead of full cross
    ; Top-left corner
    mov eax, edi
    sub eax, 12
    mov ebx, esi
    sub ebx, 12

    ; Top-left horizontal
    mov ecx, 6
.tl_h:
    push rdi
    mov edi, eax
    push rsi
    mov esi, ebx
    mov edx, COL3D_TEXT
    call draw_pixel_3d
    pop rsi
    pop rdi
    inc eax
    loop .tl_h

    ; Top-left vertical
    mov eax, edi
    sub eax, 12
    mov ecx, 6
.tl_v:
    push rdi
    mov edi, eax
    push rsi
    mov esi, ebx
    mov edx, COL3D_TEXT
    call draw_pixel_3d
    pop rsi
    pop rdi
    inc ebx
    loop .tl_v

    ; Top-right corner
    mov eax, edi
    add eax, 7
    mov ebx, esi
    sub ebx, 12

    mov ecx, 6
.tr_h:
    push rdi
    mov edi, eax
    push rsi
    mov esi, ebx
    mov edx, COL3D_TEXT
    call draw_pixel_3d
    pop rsi
    pop rdi
    inc eax
    loop .tr_h

    mov eax, edi
    add eax, 12
    mov ecx, 6
.tr_v:
    push rdi
    mov edi, eax
    push rsi
    mov esi, ebx
    mov edx, COL3D_TEXT
    call draw_pixel_3d
    pop rsi
    pop rdi
    inc ebx
    loop .tr_v

    ; Bottom-left corner
    mov eax, edi
    sub eax, 12
    mov ebx, esi
    add ebx, 12

    mov ecx, 6
.bl_h:
    push rdi
    mov edi, eax
    push rsi
    mov esi, ebx
    mov edx, COL3D_TEXT
    call draw_pixel_3d
    pop rsi
    pop rdi
    inc eax
    loop .bl_h

    mov eax, edi
    sub eax, 12
    mov ebx, esi
    add ebx, 7
    mov ecx, 6
.bl_v:
    push rdi
    mov edi, eax
    push rsi
    mov esi, ebx
    mov edx, COL3D_TEXT
    call draw_pixel_3d
    pop rsi
    pop rdi
    inc ebx
    loop .bl_v

    ; Bottom-right corner
    mov eax, edi
    add eax, 7
    mov ebx, esi
    add ebx, 12

    mov ecx, 6
.br_h:
    push rdi
    mov edi, eax
    push rsi
    mov esi, ebx
    mov edx, COL3D_TEXT
    call draw_pixel_3d
    pop rsi
    pop rdi
    inc eax
    loop .br_h

    mov eax, edi
    add eax, 12
    mov ebx, esi
    add ebx, 7
    mov ecx, 6
.br_v:
    push rdi
    mov edi, eax
    push rsi
    mov esi, ebx
    mov edx, COL3D_TEXT
    call draw_pixel_3d
    pop rsi
    pop rdi
    inc ebx
    loop .br_v

    ; Draw small cross in center
    mov eax, edi
    sub eax, 3
    mov ecx, 7
.small_h:
    cmp ecx, 4                  ; Skip center
    je .skip_h
    push rdi
    mov edi, eax
    mov edx, COL3D_NODE_HI       ; Yellow for targeting
    call draw_pixel_3d
    pop rdi
.skip_h:
    inc eax
    loop .small_h

    mov ebx, esi
    sub ebx, 3
    mov ecx, 7
.small_v:
    cmp ecx, 4
    je .skip_v
    push rsi
    mov esi, ebx
    mov edx, COL3D_NODE_HI
    call draw_pixel_3d
    pop rsi
.skip_v:
    inc ebx
    loop .small_v

    pop rsi
    pop rdi
    pop rdx
    pop rcx
    pop rbx
    pop rax
    ret

; ============================================================================
; DRAW_HUD - Draw heads-up display info
; ============================================================================
draw_hud:
    push rax
    push rbx
    push rcx
    push rdx
    push rdi
    push rsi
    push r8
    push r9

    ; Draw "MATHIS OS 3D" at top-left with cyan color
    mov rdi, [screen_fb]
    add rdi, 10                 ; X = 10
    mov eax, [screen_pitch]
    imul eax, 10                ; Y = 10
    add rdi, rax
    lea rsi, [hud_title]
    mov r8d, COL3D_HYPERCUBE    ; Cyan title
    call draw_text

    ; Draw version below
    mov rdi, [screen_fb]
    add rdi, 10
    mov eax, [screen_pitch]
    imul eax, 22
    add rdi, rax
    lea rsi, [hud_version]
    mov r8d, COL3D_STAR_DIM     ; Dim gray
    call draw_text

    ; Draw node count indicator at top-right area
    mov rdi, [screen_fb]
    mov eax, [screen_width]
    sub eax, 120                ; Right side
    add rdi, rax
    mov eax, [screen_pitch]
    imul eax, 10
    add rdi, rax
    lea rsi, [hud_nodes]
    mov r8d, COL3D_TEXT
    call draw_text

    ; Draw controls hint at bottom
    mov rdi, [screen_fb]
    add rdi, 10
    mov eax, [screen_pitch]
    mov ebx, [screen_height]
    sub ebx, 20
    imul eax, ebx
    add rdi, rax
    lea rsi, [hud_controls]
    mov r8d, COL3D_STAR_DIM     ; Dim color
    call draw_text

    ; If hovering over a node, show its name with selection brackets
    mov eax, [hover_node]
    cmp eax, -1
    je .no_hover_name

    ; Get node label
    imul eax, NODE_SIZE
    lea rbx, [world_nodes]
    add rbx, rax
    mov r9, [rbx + 16]          ; Label pointer (save for later)

    ; Draw selection indicator "[ ]" around name
    ; First draw "[ "
    mov rdi, [screen_fb]
    mov eax, [crosshair_x]
    sub eax, 50                 ; Center text roughly
    add rdi, rax
    mov eax, [screen_pitch]
    mov ebx, [crosshair_y]
    add ebx, 25
    imul eax, ebx
    add rdi, rax
    lea rsi, [hud_bracket_l]
    mov r8d, COL3D_TEXT
    call draw_text

    ; Draw node name
    add rdi, 16                 ; After bracket
    mov rsi, r9
    mov r8d, COL3D_NODE_HI      ; Highlight color (yellow)
    call draw_text

    ; Draw " ]"
    add rdi, 80                 ; After name
    lea rsi, [hud_bracket_r]
    mov r8d, COL3D_TEXT
    call draw_text

    ; Draw "Press ENTER" hint below
    mov rdi, [screen_fb]
    mov eax, [crosshair_x]
    sub eax, 45
    add rdi, rax
    mov eax, [screen_pitch]
    mov ebx, [crosshair_y]
    add ebx, 40
    imul eax, ebx
    add rdi, rax
    lea rsi, [hud_enter_hint]
    mov r8d, COL3D_STAR_DIM
    call draw_text

.no_hover_name:
    pop r9
    pop r8
    pop rsi
    pop rdi
    pop rdx
    pop rcx
    pop rbx
    pop rax
    ret

; HUD strings
hud_title:      db "MATHIS OS 3D", 0
hud_version:    db "v1.0 - 64-bit", 0
hud_nodes:      db "NODES: 4", 0
hud_controls:   db "WASD:Move    Arrows:Look    Enter:Select", 0
hud_bracket_l:  db "[ ", 0
hud_bracket_r:  db " ]", 0
hud_enter_hint: db "Press ENTER", 0

; ============================================================================
; UI3D_RENDER_TERMINAL - Render terminal inside view
; ============================================================================
ui3d_render_terminal:
    push rax
    push rbx
    push rdi
    push rsi

    ; Clear to black
    mov rdi, [screen_fb]
    mov eax, [screen_pitch]
    imul eax, [screen_height]
    mov ecx, eax
    xor al, al
    rep stosb

    ; Draw "TERMINAL" title
    mov rdi, [screen_fb]
    add rdi, 20
    mov eax, [screen_pitch]
    imul eax, 20
    add rdi, rax
    lea rsi, [term_title]
    mov r8d, COL3D_TERMINAL
    call draw_text

    ; Draw prompt "> "
    mov rdi, [screen_fb]
    add rdi, 20
    mov eax, [screen_pitch]
    imul eax, 50
    add rdi, rax
    lea rsi, [term_prompt]
    mov r8d, COL3D_TERMINAL
    call draw_text

    ; Draw ESC hint
    mov rdi, [screen_fb]
    add rdi, 20
    mov eax, [screen_pitch]
    mov ebx, [screen_height]
    sub ebx, 30
    imul eax, ebx
    add rdi, rax
    lea rsi, [str_esc_exit]
    mov r8d, 0x666666
    call draw_text

    pop rsi
    pop rdi
    pop rbx
    pop rax
    ret

term_title:     db "MATHIS TERMINAL", 0

; ============================================================================
; UI3D_RENDER_FILES - Render files browser inside view
; ============================================================================
ui3d_render_files:
    push rax
    push rbx
    push rdi
    push rsi

    ; Clear to dark background (24-bit = 3 bytes per pixel)
    mov rdi, [screen_fb]
    mov eax, [screen_pitch]
    imul eax, [screen_height]
    mov ecx, eax
    xor al, al
    rep stosb

    ; Draw files border
    mov edi, 10
    mov esi, 10
    mov eax, [screen_width]
    sub eax, 20
    mov edx, eax
    mov eax, [screen_height]
    sub eax, 20
    mov ecx, eax
    mov r8d, COL3D_FILES
    call draw_rect_outline

    ; Draw "FILES" title
    mov rdi, [screen_fb]
    add rdi, 20
    mov eax, [screen_pitch]
    imul eax, 20
    add rdi, rax
    lea rsi, [str3d_files]
    mov r8d, COL3D_FILES
    call draw_text

    ; Draw "Press ESC to exit"
    mov rdi, [screen_fb]
    add rdi, 20
    mov eax, [screen_pitch]
    mov ebx, [screen_height]
    sub ebx, 30
    imul eax, ebx
    add rdi, rax
    lea rsi, [str_esc_exit]
    mov r8d, COL3D_TEXT
    call draw_text

    pop rsi
    pop rdi
    pop rbx
    pop rax
    ret

; ============================================================================
; UI3D_RENDER_HYPERCUBE - Render HyperCubeX neural visualization
; ============================================================================
ui3d_render_hypercube:
    push rax
    push rbx
    push rcx
    push rdx
    push rdi
    push rsi

    ; Clear to black (24-bit = 3 bytes per pixel)
    mov rdi, [screen_fb]
    mov eax, [screen_pitch]
    imul eax, [screen_height]
    mov ecx, eax
    xor al, al
    rep stosb

    ; Draw "HYPERCUBEX" title centered
    mov rdi, [screen_fb]
    mov eax, [screen_width]
    shr eax, 1
    sub eax, 40                 ; Center roughly
    add rdi, rax
    mov eax, [screen_pitch]
    imul eax, 10
    add rdi, rax
    lea rsi, [str3d_hypercubex]
    mov r8d, COL3D_HYPERCUBE
    call draw_text

    ; Draw animated neural network visualization
    ; Simple: draw random "neurons" as dots
    mov ecx, 30                 ; 30 neurons
    mov ebx, 98765              ; Seed

.neuron_loop:
    push rcx

    ; Random X
    imul ebx, ebx, 1103515245
    add ebx, 12345
    mov eax, ebx
    shr eax, 16
    mov edx, [screen_width]
    sub edx, 40
    xor edx, edx
    mov edx, [screen_width]
    sub edx, 40
    and eax, 0xFF
    add eax, 20                 ; 20 to width-20

    mov edi, eax

    ; Random Y
    imul ebx, ebx, 1103515245
    add ebx, 12345
    mov eax, ebx
    shr eax, 16
    and eax, 0x7F
    add eax, 40                 ; 40 to ~170

    mov esi, eax

    ; Draw neuron dot
    mov edx, COL3D_HYPERCUBE
    call draw_pixel_3d
    ; Draw slightly larger
    inc edi
    call draw_pixel_3d
    inc esi
    call draw_pixel_3d
    dec edi
    call draw_pixel_3d

    pop rcx
    loop .neuron_loop

    ; Draw "Press ESC to exit"
    mov rdi, [screen_fb]
    add rdi, 20
    mov eax, [screen_pitch]
    mov ebx, [screen_height]
    sub ebx, 20
    imul eax, ebx
    add rdi, rax
    lea rsi, [str_esc_exit]
    mov r8d, COL3D_TEXT
    call draw_text

    pop rsi
    pop rdi
    pop rdx
    pop rcx
    pop rbx
    pop rax
    ret

; ============================================================================
; UI3D_RENDER_SETTINGS - Render settings view
; ============================================================================
ui3d_render_settings:
    push rax
    push rbx
    push rdi
    push rsi

    ; Clear (24-bit = 3 bytes per pixel)
    mov rdi, [screen_fb]
    mov eax, [screen_pitch]
    imul eax, [screen_height]
    mov ecx, eax
    xor al, al
    rep stosb

    ; Draw border
    mov edi, 10
    mov esi, 10
    mov eax, [screen_width]
    sub eax, 20
    mov edx, eax
    mov eax, [screen_height]
    sub eax, 20
    mov ecx, eax
    mov r8d, COL3D_SETTINGS
    call draw_rect_outline

    ; Draw "SETTINGS" title
    mov rdi, [screen_fb]
    add rdi, 20
    mov eax, [screen_pitch]
    imul eax, 20
    add rdi, rax
    lea rsi, [str3d_settings]
    mov r8d, COL3D_SETTINGS
    call draw_text

    ; Draw "Press ESC to exit"
    mov rdi, [screen_fb]
    add rdi, 20
    mov eax, [screen_pitch]
    mov ebx, [screen_height]
    sub ebx, 30
    imul eax, ebx
    add rdi, rax
    lea rsi, [str_esc_exit]
    mov r8d, COL3D_TEXT
    call draw_text

    pop rsi
    pop rdi
    pop rbx
    pop rax
    ret

str_esc_exit:   db "Press ESC to return", 0

; ============================================================================
; UI3D_DELAY - Simple delay for frame timing
; ============================================================================
ui3d_delay:
    push rcx
    mov ecx, 10000              ; Reduced delay for smoother render
.delay_loop:
    nop
    loop .delay_loop
    pop rcx
    ret

; ============================================================================
; UI3D_EXIT - Exit the 3D UI
; ============================================================================
ui3d_exit:
    mov dword [ui_running], 0
    ret

term_prompt:        db "> ", 0

