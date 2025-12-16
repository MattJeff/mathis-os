; ============================================================================
; RENDER3D.ASM - 3D Rendering for MATHIS OS
; ============================================================================
[BITS 64]

; Colors (VGA 256-color palette indices) - prefixed with 3D_ to avoid conflicts
COL3D_BG          equ 0               ; Black background
COL3D_STAR        equ 7               ; White stars
COL3D_GRID        equ 8               ; Dark gray grid
COL3D_NODE        equ 47              ; Cyan node
COL3D_NODE_HI     equ 44              ; Yellow highlight
COL3D_LINK        equ 33              ; Blue link
COL3D_LINK_HI     equ 36              ; Bright blue
COL3D_TEXT        equ 15              ; White text
COL3D_PARTICLE    equ 23              ; Dim cyan particle
COL3D_HYPERCUBE   equ 47              ; Cyan for HyperCubeX
COL3D_FILES       equ 44              ; Yellow for Files
COL3D_TERMINAL    equ 46              ; Green for Terminal
COL3D_SETTINGS    equ 7               ; Gray for Settings

; ============================================================================
; RENDER3D_CLEAR - Clear screen with stars background
; ============================================================================
render3d_clear:
    push rax
    push rcx
    push rdi

    ; Fill with black
    mov rdi, [screen_fb]
    mov eax, [screen_width]
    imul eax, [screen_height]
    mov ecx, eax
    xor al, al                      ; Color 0 = black
    rep stosb

    ; Draw some stars (random-ish positions)
    mov ecx, 50                     ; 50 stars
    mov ebx, 12345                  ; Seed

.star_loop:
    push rcx

    ; Pseudo-random position
    imul ebx, ebx, 1103515245
    add ebx, 12345
    mov eax, ebx
    shr eax, 16
    and eax, 0x3FFF                 ; 0-16383

    ; Check bounds
    mov edx, [screen_width]
    imul edx, [screen_height]
    cmp eax, edx
    jge .skip_star

    ; Draw star pixel
    mov rdi, [screen_fb]
    add rdi, rax
    mov byte [rdi], COL3D_STAR

.skip_star:
    pop rcx
    loop .star_loop

    pop rdi
    pop rcx
    pop rax
    ret

; ============================================================================
; DRAW_PIXEL_3D - Draw a pixel (with bounds check)
; Input: EDI = x, ESI = y, DL = color
; ============================================================================
draw_pixel_3d:
    push rax
    push rbx

    ; Bounds check
    cmp edi, 0
    jl .skip
    cmp edi, [screen_width]
    jge .skip
    cmp esi, 0
    jl .skip
    cmp esi, [screen_height]
    jge .skip

    ; Calculate offset
    mov eax, esi
    imul eax, [screen_pitch]
    add eax, edi
    mov rbx, [screen_fb]
    mov [rbx + rax], dl

.skip:
    pop rbx
    pop rax
    ret

; ============================================================================
; DRAW_LINE_3D - Draw 3D line between two world points
; Input: Stack contains: x1, y1, z1, x2, y2, z2 (all 16.16 fixed-point)
;        DL = color
; ============================================================================
draw_line_3d_world:
    push rbp
    mov rbp, rsp
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

    ; Get parameters from stack
    ; [rbp+16] = x1, [rbp+24] = y1, [rbp+32] = z1
    ; [rbp+40] = x2, [rbp+48] = y2, [rbp+56] = z2

    mov r14b, dl                    ; Save color

    ; Get camera position and rotation
    call camera_get_pos             ; R8=x, R9=y, R10=z
    call camera_get_rot             ; R11=rot_y

    ; Project point 1
    mov edi, [rbp+16]               ; x1
    mov esi, [rbp+24]               ; y1
    mov edx, [rbp+32]               ; z1
    call project_point
    test ecx, ecx
    jz .line_not_visible
    mov r12d, eax                   ; screen_x1
    mov r13d, ebx                   ; screen_y1

    ; Project point 2
    mov edi, [rbp+40]               ; x2
    mov esi, [rbp+48]               ; y2
    mov edx, [rbp+56]               ; z2
    call project_point
    test ecx, ecx
    jz .line_not_visible

    ; Draw 2D line from (r12, r13) to (eax, ebx)
    mov edi, r12d                   ; x1
    mov esi, r13d                   ; y1
    mov edx, eax                    ; x2
    mov ecx, ebx                    ; y2
    mov r8b, r14b                   ; color
    call draw_line_2d

.line_not_visible:
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
    pop rbp
    ret

; ============================================================================
; DRAW_LINE_2D - Draw 2D line (Bresenham)
; Input: EDI = x1, ESI = y1, EDX = x2, ECX = y2, R8B = color
; ============================================================================
draw_line_2d:
    push rax
    push rbx
    push rcx
    push rdx
    push rdi
    push rsi
    push r9
    push r10
    push r11
    push r12
    push r13

    mov r9d, edx                    ; x2
    mov r10d, ecx                   ; y2
    mov r13b, r8b                   ; color

    ; dx = abs(x2 - x1)
    mov eax, r9d
    sub eax, edi
    mov r11d, eax
    test r11d, r11d
    jns .dx_pos
    neg r11d
.dx_pos:

    ; dy = -abs(y2 - y1)
    mov eax, r10d
    sub eax, esi
    mov r12d, eax
    test r12d, r12d
    jns .dy_pos
    neg r12d
.dy_pos:
    neg r12d

    ; sx = x1 < x2 ? 1 : -1
    mov eax, 1
    cmp edi, r9d
    jl .sx_done
    neg eax
.sx_done:
    mov ebx, eax                    ; sx

    ; sy = y1 < y2 ? 1 : -1
    mov eax, 1
    cmp esi, r10d
    jl .sy_done
    neg eax
.sy_done:
    mov ecx, eax                    ; sy

    ; err = dx + dy
    mov eax, r11d
    add eax, r12d
    ; eax = err, ebx = sx, ecx = sy

.line_loop:
    ; Draw pixel at (edi, esi)
    push rdx
    mov dl, r13b
    call draw_pixel_3d
    pop rdx

    ; Check if done
    cmp edi, r9d
    jne .not_done
    cmp esi, r10d
    je .line_done
.not_done:

    ; e2 = 2 * err
    mov edx, eax
    shl edx, 1

    ; if e2 >= dy
    cmp edx, r12d
    jl .skip_x
    add eax, r12d                   ; err += dy
    add edi, ebx                    ; x1 += sx
.skip_x:

    ; if e2 <= dx
    cmp edx, r11d
    jg .skip_y
    add eax, r11d                   ; err += dx
    add esi, ecx                    ; y1 += sy
.skip_y:

    jmp .line_loop

.line_done:
    pop r13
    pop r12
    pop r11
    pop r10
    pop r9
    pop rsi
    pop rdi
    pop rdx
    pop rcx
    pop rbx
    pop rax
    ret

; ============================================================================
; DRAW_NODE_3D - Draw a 3D node (cube/sphere representation)
; Input: EDI = x (16.16), ESI = y (16.16), EDX = z (16.16)
;        CL = color, CH = size (1-10)
; ============================================================================
draw_node_3d:
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

    mov r12d, edi                   ; Save x
    mov r13d, esi                   ; Save y
    mov r14d, edx                   ; Save z
    movzx r8d, cl                   ; color
    mov r9d, ecx
    shr r9d, 8
    and r9d, 0xFF                   ; size (from CH)

    ; Get camera
    call camera_get_pos
    call camera_get_rot

    ; Project center point
    mov edi, r12d
    mov esi, r13d
    mov edx, r14d
    call project_point
    test ecx, ecx
    jz .node_not_visible

    ; eax = screen_x, ebx = screen_y

    ; Calculate screen size based on depth
    ; size_screen = base_size * FOV / z
    mov r10d, eax                   ; screen_x
    mov r11d, ebx                   ; screen_y

    ; Use fixed size for now (5 pixels radius)
    mov r9d, 5

    ; Draw filled circle (simplified as square for now)
    mov edi, r10d
    sub edi, r9d                    ; x - size
    mov esi, r11d
    sub esi, r9d                    ; y - size
    mov edx, r9d
    shl edx, 1                      ; width = size * 2
    mov ecx, edx                    ; height = width
    mov r8b, r8b                    ; color already in r8b
    call draw_filled_rect

    ; Draw border
    mov edi, r10d
    sub edi, r9d
    mov esi, r11d
    sub esi, r9d
    mov edx, r9d
    shl edx, 1
    mov ecx, edx
    mov r8b, COL3D_TEXT             ; White border
    call draw_rect_outline

.node_not_visible:
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
; DRAW_FILLED_RECT - Draw filled rectangle
; Input: EDI = x, ESI = y, EDX = width, ECX = height, R8B = color
; ============================================================================
draw_filled_rect:
    push rax
    push rbx
    push rcx
    push rdx
    push rdi
    push rsi

    mov eax, ecx                    ; height
    mov ebx, edx                    ; width

.fill_row:
    push rax
    push rdi

    mov ecx, ebx                    ; width
.fill_col:
    push rdx
    mov dl, r8b
    call draw_pixel_3d
    pop rdx
    inc edi
    loop .fill_col

    pop rdi
    pop rax
    inc esi                         ; next row
    dec eax
    jnz .fill_row

    pop rsi
    pop rdi
    pop rdx
    pop rcx
    pop rbx
    pop rax
    ret

; ============================================================================
; DRAW_RECT_OUTLINE - Draw rectangle outline
; Input: EDI = x, ESI = y, EDX = width, ECX = height, R8B = color
; ============================================================================
draw_rect_outline:
    push rax
    push rbx
    push rcx
    push rdx
    push rdi
    push rsi
    push r9
    push r10

    mov r9d, edx                    ; width
    mov r10d, ecx                   ; height

    ; Top line
    mov ecx, r9d
.top_line:
    push rdx
    mov dl, r8b
    call draw_pixel_3d
    pop rdx
    inc edi
    loop .top_line

    ; Right line
    sub edi, 1
    mov ecx, r10d
.right_line:
    push rdx
    mov dl, r8b
    call draw_pixel_3d
    pop rdx
    inc esi
    loop .right_line

    ; Bottom line
    sub esi, 1
    mov ecx, r9d
.bottom_line:
    push rdx
    mov dl, r8b
    call draw_pixel_3d
    pop rdx
    dec edi
    loop .bottom_line

    ; Left line
    add edi, 1
    mov ecx, r10d
.left_line:
    push rdx
    mov dl, r8b
    call draw_pixel_3d
    pop rdx
    dec esi
    loop .left_line

    pop r10
    pop r9
    pop rsi
    pop rdi
    pop rdx
    pop rcx
    pop rbx
    pop rax
    ret

; ============================================================================
; DRAW_TEXT_3D - Draw text at 3D position
; Input: EDI = x (16.16), ESI = y (16.16), EDX = z (16.16)
;        R8 = string pointer, R9B = color
; ============================================================================
draw_text_3d:
    push rax
    push rbx
    push rcx
    push rdx
    push rdi
    push rsi
    push r10
    push r11

    mov r10, r8                     ; Save string pointer
    mov r11b, r9b                   ; Save color

    ; Get camera
    call camera_get_pos
    call camera_get_rot

    ; Project point
    call project_point
    test ecx, ecx
    jz .text_not_visible

    ; Draw text at screen position (eax, ebx)
    ; Use kernel's draw_text function
    mov rdi, [screen_fb]
    mov rcx, [screen_pitch]
    imul ecx, ebx                   ; y * pitch
    add ecx, eax                    ; + x
    add rdi, rcx                    ; screen position

    mov rsi, r10                    ; string
    movzx r8d, r11b                 ; color
    call draw_text

.text_not_visible:
    pop r11
    pop r10
    pop rsi
    pop rdi
    pop rdx
    pop rcx
    pop rbx
    pop rax
    ret

; ============================================================================
; DRAW_PARTICLES - Draw floating particles for ambiance
; Input: none (uses global particle array)
; ============================================================================
align 8
particle_count: dd 20
particles:      times 20 * 3 dd 0   ; x, y, z for each particle

draw_particles:
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

    mov ecx, [particle_count]
    lea r12, [particles]

.particle_loop:
    push rcx

    ; Get particle position
    mov edi, [r12]                  ; x
    mov esi, [r12 + 4]              ; y
    mov edx, [r12 + 8]              ; z

    ; Get camera
    call camera_get_pos
    call camera_get_rot

    ; Project particle
    call project_point
    test ecx, ecx
    jz .skip_particle

    ; Draw small dot
    mov edi, eax
    mov esi, ebx
    mov dl, COL3D_PARTICLE
    call draw_pixel_3d

.skip_particle:
    add r12, 12                     ; Next particle (3 dwords)
    pop rcx
    loop .particle_loop

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
; INIT_PARTICLES - Initialize particle positions randomly
; ============================================================================
init_particles:
    push rax
    push rbx
    push rcx
    push rdi

    mov ecx, [particle_count]
    lea rdi, [particles]
    mov ebx, 54321                  ; Random seed

.init_loop:
    ; Random X (-5 to 5)
    imul ebx, ebx, 1103515245
    add ebx, 12345
    mov eax, ebx
    sar eax, 16
    and eax, 0xF                    ; 0-15
    sub eax, 7                      ; -7 to 8
    shl eax, 16                     ; To fixed-point
    mov [rdi], eax

    ; Random Y (-3 to 3)
    imul ebx, ebx, 1103515245
    add ebx, 12345
    mov eax, ebx
    sar eax, 16
    and eax, 0x7                    ; 0-7
    sub eax, 3                      ; -3 to 4
    shl eax, 16
    mov [rdi + 4], eax

    ; Random Z (-8 to 0)
    imul ebx, ebx, 1103515245
    add ebx, 12345
    mov eax, ebx
    sar eax, 16
    and eax, 0xF                    ; 0-15
    sub eax, 12                     ; -12 to 3
    shl eax, 16
    mov [rdi + 8], eax

    add rdi, 12
    loop .init_loop

    pop rdi
    pop rcx
    pop rbx
    pop rax
    ret
