; ============================================================================
; WORLD3D.ASM - 3D World Nodes for MATHIS OS
; ============================================================================
[BITS 64]
; Defines the floating nodes in 3D space: FILES, TERMINAL, HYPERCUBEX, SETTINGS
; Each node has position, size, color, label, and connections

; ============================================================================
; NODE STRUCTURE (32 bytes each)
; ============================================================================
; Offset 0:  X position (16.16 fixed-point)
; Offset 4:  Y position (16.16 fixed-point)
; Offset 8:  Z position (16.16 fixed-point)
; Offset 12: Color (byte) + Size (byte) + Flags (word)
; Offset 16: Label pointer (8 bytes)
; Offset 24: Link mask (byte) + Reserved (7 bytes)

NODE_SIZE       equ 32
NODE_COUNT      equ 4

; Node indices
NODE_TERMINAL   equ 0
NODE_FILES      equ 1
NODE_HYPERCUBEX equ 2
NODE_SETTINGS   equ 3

; ============================================================================
; NODE DATA
; ============================================================================
align 8
world_nodes:
    ; Node 0: TERMINAL (front-left)
    dd 0xFFFE0000               ; X = -2.0
    dd 0x00000000               ; Y = 0.0
    dd 0xFFFC0000               ; Z = -4.0
    db COL3D_TERMINAL           ; Color = green
    db 6                        ; Size
    dw 0                        ; Flags
    dq str3d_terminal           ; Label
    db 0b00000110               ; Links to FILES(1), HYPERCUBEX(2)
    times 7 db 0

    ; Node 1: FILES (front-right)
    dd 0x00020000               ; X = 2.0
    dd 0x00000000               ; Y = 0.0
    dd 0xFFFC0000               ; Z = -4.0
    db COL3D_FILES              ; Color = yellow
    db 6                        ; Size
    dw 0                        ; Flags
    dq str3d_files              ; Label
    db 0b00000101               ; Links to TERMINAL(0), HYPERCUBEX(2)
    times 7 db 0

    ; Node 2: HYPERCUBEX (center-back, larger)
    dd 0x00000000               ; X = 0.0
    dd 0x00010000               ; Y = 1.0 (slightly elevated)
    dd 0xFFF80000               ; Z = -8.0 (further back)
    db COL3D_HYPERCUBE          ; Color = cyan
    db 10                       ; Size (larger - main attraction)
    dw 0                        ; Flags
    dq str3d_hypercubex         ; Label
    db 0b00001011               ; Links to TERMINAL(0), FILES(1), SETTINGS(3)
    times 7 db 0

    ; Node 3: SETTINGS (bottom-center)
    dd 0x00000000               ; X = 0.0
    dd 0xFFFF0000               ; Y = -1.0 (below)
    dd 0xFFFA0000               ; Z = -6.0
    db COL3D_SETTINGS           ; Color = gray
    db 4                        ; Size (smaller)
    dw 0                        ; Flags
    dq str3d_settings           ; Label
    db 0b00000100               ; Links to HYPERCUBEX(2)
    times 7 db 0

; Node labels (prefixed to avoid conflicts)
str3d_terminal:   db "TERMINAL", 0
str3d_files:      db "FILES", 0
str3d_hypercubex: db "HYPERCUBEX", 0
str3d_settings:   db "SETTINGS", 0

; Currently selected node (-1 = none)
align 4
selected_node:  dd -1
hover_node:     dd -1

; ============================================================================
; WORLD_INIT - Initialize the 3D world
; ============================================================================
world_init:
    push rax

    mov dword [selected_node], -1
    mov dword [hover_node], -1

    ; Initialize particles
    call init_particles

    pop rax
    ret

; ============================================================================
; WORLD_RENDER - Render all world nodes and connections
; ============================================================================
world_render:
    push rax
    push rbx
    push rcx
    push rdx
    push rdi
    push rsi
    push r8
    push r9
    push r10
    push r11
    push r12
    push r13
    push r14
    push r15

    ; First, draw connections between nodes
    call world_draw_links

    ; Then draw all nodes
    mov ecx, NODE_COUNT
    lea r15, [world_nodes]

.render_loop:
    push rcx

    ; Get node position
    mov edi, [r15]              ; X
    mov esi, [r15 + 4]          ; Y
    mov edx, [r15 + 8]          ; Z

    ; Get node attributes into ECX (CL=color, high bits=size)
    movzx eax, byte [r15 + 12]  ; Color
    movzx ecx, byte [r15 + 13]  ; Size
    shl ecx, 8
    or ecx, eax                 ; Pack: high byte=size, CL=color

    ; Check if this is selected/hovered node
    mov eax, NODE_COUNT
    mov r8d, ecx                ; Save packed attributes
    pop rcx
    push rcx
    sub eax, ecx                ; Current node index
    cmp eax, [hover_node]
    mov ecx, r8d                ; Restore packed attributes
    jne .not_hovered
    and ecx, 0xFF00             ; Keep size, clear color
    or cl, COL3D_NODE_HI        ; Set highlight color
.not_hovered:

    ; Draw the node
    call draw_node_3d

    ; Draw label below node
    mov edi, [r15]              ; X
    mov esi, [r15 + 4]          ; Y
    sub esi, 0x00008000         ; Y - 0.5 (label below)
    mov edx, [r15 + 8]          ; Z
    mov r8, [r15 + 16]          ; Label pointer
    mov r9b, COL3D_TEXT         ; White text
    call draw_text_3d

    ; Next node
    add r15, NODE_SIZE
    pop rcx
    dec ecx
    jnz .render_loop

    ; Draw particles for ambiance
    call draw_particles

    pop r15
    pop r14
    pop r13
    pop r12
    pop r11
    pop r10
    pop r9
    pop r8
    pop rsi
    pop rdi
    pop rdx
    pop rcx
    pop rbx
    pop rax
    ret

; ============================================================================
; WORLD_DRAW_LINKS - Draw connections between linked nodes
; ============================================================================
world_draw_links:
    push rax
    push rbx
    push rcx
    push rdx
    push rdi
    push rsi
    push r8
    push r9
    push r10
    push r11
    push r12
    push r13
    push r14
    push r15
    push rbp

    ; For each node, check its link mask and draw lines
    xor r12d, r12d              ; Node index i = 0
    lea r14, [world_nodes]

.link_outer:
    cmp r12d, NODE_COUNT
    jge .link_done

    ; Get link mask for node i
    movzx r13d, byte [r14 + 24] ; Link mask

    ; For each bit set, draw line to that node
    xor r15d, r15d              ; Node index j = 0

.link_inner:
    cmp r15d, NODE_COUNT
    jge .next_outer

    ; Only draw if j > i (avoid duplicates) and bit is set
    cmp r15d, r12d
    jle .next_inner

    ; Check if bit j is set in link mask
    mov eax, 1
    mov ecx, r15d
    shl eax, cl
    test r13d, eax
    jz .next_inner

    ; Draw line from node i to node j
    ; Calculate address of node j
    mov eax, r15d
    imul eax, NODE_SIZE
    lea rbx, [world_nodes]
    add rbx, rax

    ; Push coordinates for draw_line_3d_world
    ; We need: x1, y1, z1, x2, y2, z2 on stack
    sub rsp, 48

    mov eax, [r14]              ; x1
    mov [rsp], eax
    mov eax, [r14 + 4]          ; y1
    mov [rsp + 8], eax
    mov eax, [r14 + 8]          ; z1
    mov [rsp + 16], eax
    mov eax, [rbx]              ; x2
    mov [rsp + 24], eax
    mov eax, [rbx + 4]          ; y2
    mov [rsp + 32], eax
    mov eax, [rbx + 8]          ; z2
    mov [rsp + 40], eax

    mov dl, COL3D_LINK          ; Link color

    ; Manual inline of draw_line_3d_world logic
    ; Project point 1
    mov edi, [rsp]              ; x1
    mov esi, [rsp + 8]          ; y1
    mov edx, [rsp + 16]         ; z1
    call project_point
    test ecx, ecx
    jz .line_skip
    mov r8d, eax                ; screen_x1
    mov r9d, ebx                ; screen_y1

    ; Project point 2
    mov edi, [rsp + 24]         ; x2
    mov esi, [rsp + 32]         ; y2
    mov edx, [rsp + 40]         ; z2
    call project_point
    test ecx, ecx
    jz .line_skip

    ; Draw 2D line
    mov edi, r8d                ; x1
    mov esi, r9d                ; y1
    mov edx, eax                ; x2
    mov ecx, ebx                ; y2
    mov r8b, COL3D_LINK         ; color
    call draw_line_2d

.line_skip:
    add rsp, 48

.next_inner:
    inc r15d
    jmp .link_inner

.next_outer:
    add r14, NODE_SIZE
    inc r12d
    jmp .link_outer

.link_done:
    pop rbp
    pop r15
    pop r14
    pop r13
    pop r12
    pop r11
    pop r10
    pop r9
    pop r8
    pop rsi
    pop rdi
    pop rdx
    pop rcx
    pop rbx
    pop rax
    ret

; ============================================================================
; WORLD_UPDATE - Update world state (animation, hover detection)
; ============================================================================
world_update:
    push rax
    push rbx
    push rcx
    push rdx
    push rdi
    push rsi
    push r8
    push r9

    ; Update particles (simple float animation)
    call update_particles

    ; Check which node is closest to center of screen (for hover)
    mov dword [hover_node], -1
    mov r8d, 50                 ; Min distance threshold (pixels)

    mov ecx, NODE_COUNT
    lea rdi, [world_nodes]
    xor esi, esi                ; Node index

.hover_check:
    push rcx

    ; Project node center
    push rdi
    push rsi
    mov edi, [rdi]              ; X
    mov esi, [rdi + 4]          ; Y
    mov edx, [rdi + 8]          ; Z
    call project_point
    pop rsi
    pop rdi

    test ecx, ecx
    jz .hover_next

    ; Calculate distance from screen center
    ; center_x = screen_width / 2
    ; center_y = screen_height / 2
    mov ecx, [screen_width]
    shr ecx, 1
    sub eax, ecx                ; dx = screen_x - center_x
    imul eax, eax               ; dx^2

    mov ecx, [screen_height]
    shr ecx, 1
    sub ebx, ecx                ; dy = screen_y - center_y
    imul ebx, ebx               ; dy^2

    add eax, ebx                ; dist^2 = dx^2 + dy^2

    ; Compare with best distance
    cmp eax, r8d
    jge .hover_next
    imul r9d, r8d, r8d          ; threshold^2
    cmp eax, r9d
    jge .hover_next

    mov r8d, eax                ; New best distance
    mov [hover_node], esi       ; This node is hovered

.hover_next:
    add rdi, NODE_SIZE
    inc esi
    pop rcx
    loop .hover_check

    pop r9
    pop r8
    pop rsi
    pop rdi
    pop rdx
    pop rcx
    pop rbx
    pop rax
    ret

; ============================================================================
; UPDATE_PARTICLES - Animate particles
; ============================================================================
update_particles:
    push rax
    push rcx
    push rdi

    mov ecx, [particle_count]
    lea rdi, [particles]

.update_loop:
    ; Move particle slowly upward
    mov eax, [rdi + 4]          ; Y
    add eax, 0x00000200         ; += 0.002

    ; Wrap around if too high
    cmp eax, 0x00040000         ; > 4.0
    jl .no_wrap
    sub eax, 0x00080000         ; -= 8.0 (wrap to -4)
.no_wrap:
    mov [rdi + 4], eax

    add rdi, 12
    loop .update_loop

    pop rdi
    pop rcx
    pop rax
    ret

; ============================================================================
; WORLD_SELECT_NODE - Select the currently hovered node
; Output: EAX = selected node index, or -1 if none
; ============================================================================
world_select_node:
    mov eax, [hover_node]
    cmp eax, -1
    je .no_selection
    mov [selected_node], eax
.no_selection:
    ret

; ============================================================================
; WORLD_GET_SELECTED - Get currently selected node
; Output: EAX = node index (-1 if none)
; ============================================================================
world_get_selected:
    mov eax, [selected_node]
    ret

; ============================================================================
; WORLD_ENTER_NODE - Enter the selected node (transition to app)
; Input: EAX = node index
; Output: EAX = app ID to launch (0=terminal, 1=files, 2=hypercubex, 3=settings)
; ============================================================================
world_enter_node:
    ; Node index is directly the app ID
    ret

