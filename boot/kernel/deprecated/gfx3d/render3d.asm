; ============================================================================
; RENDER3D.ASM - 3D Rendering for MATHIS OS (32-bit True Color)
; ============================================================================
[BITS 64]

; Colors in 32-bit XRGB format (0x00RRGGBB) for true color rendering
; This allows smooth gradients and millions of colors!

COL3D_BG          equ 0x00080010      ; Dark purple-black background
COL3D_STAR        equ 0x00FFFFFF      ; Bright white stars
COL3D_STAR_DIM    equ 0x00666688      ; Dim blue-gray stars
COL3D_STAR_BLUE   equ 0x008888FF      ; Blue-tinted stars
COL3D_GRID        equ 0x00333366      ; Dark blue-purple grid
COL3D_GRID_HI     equ 0x006666AA      ; Brighter grid lines
COL3D_NODE        equ 0x0000FFFF      ; Cyan node
COL3D_NODE_HI     equ 0x00FFFF00      ; Yellow highlight
COL3D_LINK        equ 0x006644FF      ; Purple-blue link
COL3D_LINK_HI     equ 0x00AA88FF      ; Bright purple
COL3D_TEXT        equ 0x00FFFFFF      ; White text
COL3D_PARTICLE    equ 0x00446688      ; Dim cyan particle

; Node colors - beautiful gradient-ready colors
COL3D_HYPERCUBE   equ 0x00FF44FF      ; Magenta/pink for HyperCubeX
COL3D_HYPERCUBE_GLOW equ 0x00AA22AA   ; Dim magenta glow
COL3D_FILES       equ 0x00FFCC00      ; Golden yellow for Files
COL3D_FILES_GLOW  equ 0x00AA8800      ; Dim gold glow
COL3D_TERMINAL    equ 0x0044FF88      ; Bright green for Terminal
COL3D_TERMINAL_GLOW equ 0x0022AA44    ; Dim green glow
COL3D_SETTINGS    equ 0x00AAAACC      ; Light blue-gray for Settings
COL3D_SETTINGS_GLOW equ 0x00666688    ; Dim gray glow

; Additional colors for effects
COL3D_GLOW_CORE   equ 0x00FFFFFF      ; White core of glow
COL3D_PURPLE      equ 0x00AA44FF      ; Purple accent

; ============================================================================
; RENDER3D_CLEAR - Clear screen with enhanced starfield (32-bit color)
; ============================================================================
render3d_clear:
    push rax
    push rbx
    push rcx
    push rdx
    push rdi
    push rsi

    ; Fill with dark purple-black background
    mov rdi, [screen_fb]
    mov eax, [screen_width]
    imul eax, [screen_height]

    ; Check BPP for correct fill method
    mov ebx, [screen_bpp]
    cmp ebx, 32
    je .fill_32bit
    cmp ebx, 24
    je .fill_24bit
    ; Fallback 8-bit
    mov ecx, eax
    mov al, 0
    rep stosb
    jmp .fill_done

.fill_32bit:
    mov ecx, eax
    mov eax, COL3D_BG
    rep stosd
    jmp .fill_done

.fill_24bit:
    ; 24-bit: write 3 bytes per pixel
    mov ecx, eax                    ; pixel count
    mov eax, COL3D_BG               ; 0x00RRGGBB
    mov ebx, eax
    shr ebx, 16                     ; ebx = RR
.fill_24_loop:
    mov [rdi], al                   ; Blue
    mov [rdi + 1], ah               ; Green
    mov [rdi + 2], bl               ; Red
    add rdi, 3
    dec ecx
    jnz .fill_24_loop

.fill_done:

    ; Draw many stars with varying brightness
    mov eax, [star_frame]
    inc eax
    mov [star_frame], eax

    ; Bright white stars (sparse)
    mov ecx, 100
    mov ebx, 12345
    mov r8d, COL3D_STAR
    call .draw_star_group

    ; Dim blue-gray stars (medium density)
    mov ecx, 200
    mov ebx, 54321
    mov r8d, COL3D_STAR_DIM
    call .draw_star_group

    ; Blue-tinted stars (sparse)
    mov ecx, 60
    mov ebx, 98765
    mov r8d, COL3D_STAR_BLUE
    call .draw_star_group

    ; Purple accent stars (very sparse)
    mov ecx, 30
    mov ebx, 11111
    mov r8d, COL3D_PURPLE
    call .draw_star_group

    pop rsi
    pop rdi
    pop rdx
    pop rcx
    pop rbx
    pop rax
    ret

; Generic star drawing for 32-bit
; Input: ECX = count, EBX = seed, R8D = color (32-bit)
.draw_star_group:
    push rcx
    push r9
.star_loop:
    push rcx

    ; Pseudo-random position
    imul ebx, ebx, 1103515245
    add ebx, 12345
    mov eax, ebx
    shr eax, 16

    ; Get X coordinate
    xor edx, edx
    mov r9d, [screen_width]
    div r9d
    mov edi, edx                    ; X = remainder

    ; Get Y coordinate
    imul ebx, ebx, 1103515245
    add ebx, 12345
    mov eax, ebx
    shr eax, 16
    xor edx, edx
    mov r9d, [screen_height]
    div r9d
    mov esi, edx                    ; Y = remainder

    ; Twinkling effect for some stars
    push rax
    mov eax, [star_frame]
    add eax, ebx
    and eax, 0x3F
    cmp eax, 3
    pop rax
    je .skip_star                   ; Skip 1/64 stars for twinkle

    ; Draw star pixel (32-bit)
    mov edx, r8d                    ; Color
    call draw_pixel_3d

.skip_star:
    pop rcx
    loop .star_loop

    pop r9
    pop rcx
    ret

; Star animation frame counter
align 4
star_frame: dd 0
saved_node_color: dd 0              ; Now 32-bit color

; ============================================================================
; DRAW_PIXEL_3D - Draw a pixel (supports 24-bit and 32-bit modes)
; Input: EDI = x, ESI = y, EDX = color (32-bit XRGB: 0x00RRGGBB)
; ============================================================================
draw_pixel_3d:
    push rax
    push rbx
    push rcx

    ; Bounds check
    cmp edi, 0
    jl .skip
    cmp edi, [screen_width]
    jge .skip
    cmp esi, 0
    jl .skip
    cmp esi, [screen_height]
    jge .skip

    ; Calculate base offset: y * pitch
    mov eax, esi
    imul eax, [screen_pitch]        ; pitch is in bytes
    mov rbx, [screen_fb]
    add rbx, rax                    ; fb + y * pitch

    ; Check bits per pixel
    mov ecx, [screen_bpp]
    cmp ecx, 32
    je .write_32bit
    cmp ecx, 24
    je .write_24bit
    ; Fallback to 8-bit for old modes
    add rbx, rdi                    ; + x
    mov [rbx], dl
    jmp .skip

.write_32bit:
    ; 32-bit: x * 4
    mov ecx, edi
    shl ecx, 2
    add rbx, rcx
    mov [rbx], edx                  ; Write 4 bytes (BGRA)
    jmp .skip

.write_24bit:
    ; 24-bit: x * 3 - write B, G, R separately
    mov eax, edi
    imul eax, 3                     ; x * 3
    add rbx, rax
    ; EDX = 0x00RRGGBB, write as BGR (little-endian)
    mov [rbx], dl                   ; Blue
    mov [rbx + 1], dh               ; Green
    shr edx, 16
    mov [rbx + 2], dl               ; Red

.skip:
    pop rcx
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

    mov r14d, edx                   ; Save 32-bit color

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
    mov r8d, r14d                   ; 32-bit color
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
; DRAW_LINE_2D - Draw 2D line (Bresenham) - 32-bit color
; Input: EDI = x1, ESI = y1, EDX = x2, ECX = y2, R8D = color (32-bit)
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
    mov r13d, r8d                   ; color (32-bit)

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
    mov edx, r13d                   ; 32-bit color
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
; DRAW_CIRCLE_FILLED - Draw filled circle (simple, stable version)
; Input: EDI = center_x, ESI = center_y, EDX = radius, R8D = base color (32-bit)
; ============================================================================
draw_circle_filled:
    push rax
    push rbx
    push rcx
    push rdx
    push rdi
    push rsi
    push r9
    push r10
    push r11

    mov r9d, edi                    ; center_x
    mov r10d, esi                   ; center_y
    mov r11d, edx                   ; radius

    ; Safety check
    cmp r11d, 0
    jle .circle_done
    cmp r11d, 100
    jg .circle_done                 ; sanity limit

    ; Draw filled circle using horizontal lines
    mov ebx, r11d
    neg ebx                         ; y = -radius

.circle_y_loop:
    cmp ebx, r11d
    jg .circle_done

    ; Calculate x width at this y: sqrt(r^2 - y^2)
    mov eax, r11d
    imul eax, eax                   ; r^2
    mov ecx, ebx
    imul ecx, ecx                   ; y^2
    sub eax, ecx                    ; r^2 - y^2
    js .next_y                      ; Skip if negative

    ; Simple integer sqrt (one iteration)
    mov ecx, eax
    shr ecx, 1                      ; Initial guess
    test ecx, ecx
    jz .draw_single

    xor edx, edx
    div ecx
    add eax, ecx
    shr eax, 1                      ; sqrt result
    mov ecx, eax                    ; width

    ; Draw horizontal line
    mov edi, r9d
    sub edi, ecx                    ; start x = center - width
    mov esi, r10d
    add esi, ebx                    ; y = center + offset

    ; Line width
    shl ecx, 1
    inc ecx                         ; width * 2 + 1

.draw_h_line:
    push rcx
    mov edx, r8d                    ; color
    call draw_pixel_3d
    pop rcx
    inc edi
    dec ecx
    jnz .draw_h_line
    jmp .next_y

.draw_single:
    mov edi, r9d
    mov esi, r10d
    add esi, ebx
    mov edx, r8d
    call draw_pixel_3d

.next_y:
    inc ebx
    jmp .circle_y_loop

.circle_done:
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
; DRAW_GLOW - Draw simple outer glow effect
; Input: EDI = center_x, ESI = center_y, EDX = radius, R8D = glow_color (32-bit)
; ============================================================================
draw_glow:
    push rax
    push rbx
    push rcx
    push rdx
    push rdi
    push rsi
    push r9
    push r10

    mov r9d, edi                    ; center_x
    mov r10d, esi                   ; center_y

    ; Draw 16 glow points around the circle
    mov ecx, 16

.glow_point:
    push rcx

    ; Get position from table
    dec ecx
    and ecx, 15
    shl ecx, 2                      ; * 4 for table offset

    lea rbx, [glow_cos_table]
    movsx eax, word [rbx + rcx]
    lea rbx, [glow_sin_table]
    movsx ebx, word [rbx + rcx]

    ; x = cx + cos * (radius + 2) / 128
    mov edi, edx
    add edi, 2
    imul eax, edi
    sar eax, 7
    add eax, r9d
    mov edi, eax

    ; y = cy + sin * (radius + 2) / 128
    mov esi, edx
    add esi, 2
    imul ebx, esi
    sar ebx, 7
    add ebx, r10d
    mov esi, ebx

    push rdx
    mov edx, r8d
    call draw_pixel_3d
    pop rdx

    pop rcx
    dec ecx
    jnz .glow_point

    pop r10
    pop r9
    pop rsi
    pop rdi
    pop rdx
    pop rcx
    pop rbx
    pop rax
    ret

; Simplified cos/sin table for 16 points (values * 128)
align 2
glow_cos_table: dw 128, 118, 91, 49, 0, -49, -91, -118, -128, -118, -91, -49, 0, 49, 91, 118
glow_sin_table: dw 0, 49, 91, 118, 128, 118, 91, 49, 0, -49, -91, -118, -128, -118, -91, -49

; ============================================================================
; DRAW_NODE_3D - Draw a 3D node with glow effect and icon
; Input: EDI = x (16.16), ESI = y (16.16), EDX = z (16.16)
;        CL = color, CH = size (1-10), R9D = node_index (for icon)
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
    push r15

    mov r12d, edi                   ; Save x
    mov r13d, esi                   ; Save y
    mov r14d, edx                   ; Save z
    ; Get 32-bit color from ECX low byte (node type index)
    movzx eax, cl                   ; node type (0-3)
    call get_node_color_32          ; R8D = 32-bit color
    mov [saved_node_color], r8d     ; Save 32-bit color
    mov r15d, ecx
    shr r15d, 8
    and r15d, 0xFF                  ; size (from CH)

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
    mov r10d, eax                   ; screen_x
    mov r11d, ebx                   ; screen_y

    ; Calculate screen size based on distance
    mov r9d, r15d                   ; node size (from data)
    add r9d, 10                     ; base + size

    ; Draw outer glow effect first (behind the node)
    mov edi, r10d
    mov esi, r11d
    mov edx, r9d
    add edx, 6                      ; glow radius larger
    mov r8d, [saved_node_color]
    call get_glow_color_32          ; R8D = glow color (32-bit)
    call draw_glow

    ; Draw filled circle for node (with gradient)
    mov edi, r10d
    mov esi, r11d
    mov edx, r9d
    mov r8d, [saved_node_color]     ; Restore original 32-bit color
    call draw_circle_filled

    ; Draw simple highlight on top-left
    mov edi, r10d
    mov esi, r11d
    sub esi, 3                      ; move up
    sub edi, 2                      ; move left
    mov edx, COL3D_GLOW_CORE        ; White highlight
    call draw_pixel_3d
    inc edi
    call draw_pixel_3d

.node_not_visible:
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
; GET_NODE_COLOR_32 - Get 32-bit color for a node type
; Input: EAX = node type (0=TERMINAL, 1=FILES, 2=HYPERCUBE, 3=SETTINGS)
;        Bit 7 set = highlighted/hovered
; Output: R8D = 32-bit color
; ============================================================================
get_node_color_32:
    ; Check if highlighted (bit 7 set)
    test eax, 0x80
    jnz .highlighted

    cmp eax, 0
    je .color_terminal
    cmp eax, 1
    je .color_files
    cmp eax, 2
    je .color_hypercube
    cmp eax, 3
    je .color_settings
    mov r8d, COL3D_NODE             ; Default cyan
    ret
.color_terminal:
    mov r8d, COL3D_TERMINAL
    ret
.color_files:
    mov r8d, COL3D_FILES
    ret
.color_hypercube:
    mov r8d, COL3D_HYPERCUBE
    ret
.color_settings:
    mov r8d, COL3D_SETTINGS
    ret
.highlighted:
    mov r8d, COL3D_NODE_HI          ; Bright yellow for highlighted nodes
    ret

; ============================================================================
; GET_GLOW_COLOR_32 - Get glow color for a node color (32-bit)
; Input: R8D = node color (32-bit)
; Output: R8D = glow color (32-bit, dimmer version)
; ============================================================================
get_glow_color_32:
    cmp r8d, COL3D_TERMINAL
    je .glow_terminal
    cmp r8d, COL3D_FILES
    je .glow_files
    cmp r8d, COL3D_HYPERCUBE
    je .glow_hypercube
    cmp r8d, COL3D_SETTINGS
    je .glow_settings
    mov r8d, COL3D_STAR_DIM         ; Default dim glow
    ret
.glow_terminal:
    mov r8d, COL3D_TERMINAL_GLOW
    ret
.glow_files:
    mov r8d, COL3D_FILES_GLOW
    ret
.glow_hypercube:
    mov r8d, COL3D_HYPERCUBE_GLOW
    ret
.glow_settings:
    mov r8d, COL3D_SETTINGS_GLOW
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
    mov edx, r8d
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
    mov edx, r8d
    call draw_pixel_3d
    pop rdx
    inc edi
    loop .top_line

    ; Right line
    sub edi, 1
    mov ecx, r10d
.right_line:
    push rdx
    mov edx, r8d
    call draw_pixel_3d
    pop rdx
    inc esi
    loop .right_line

    ; Bottom line
    sub esi, 1
    mov ecx, r9d
.bottom_line:
    push rdx
    mov edx, r8d
    call draw_pixel_3d
    pop rdx
    dec edi
    loop .bottom_line

    ; Left line
    add edi, 1
    mov ecx, r10d
.left_line:
    push rdx
    mov edx, r8d
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
    push r12
    push r13
    push r14
    push r15

    ; Save parameters in callee-saved registers BEFORE calling camera functions
    mov r14, r8                     ; Save string pointer in R14
    mov r15d, r9d                   ; Save 32-bit color in R15
    mov r12d, edi                   ; Save world X
    mov r13d, esi                   ; Save world Y
    push rdx                        ; Save world Z on stack

    ; Get camera (uses R8, R9, R10, R11)
    call camera_get_pos
    call camera_get_rot

    ; Restore world coordinates for projection
    pop rdx                         ; Z
    mov edi, r12d                   ; X
    mov esi, r13d                   ; Y

    ; Project point
    call project_point
    test ecx, ecx
    jz .text_not_visible

    ; Draw text at screen position (eax, ebx)
    ; Calculate correct screen position for current BPP
    mov rdi, [screen_fb]
    mov ecx, [screen_pitch]
    imul ecx, ebx                   ; y * pitch (pitch already accounts for BPP)
    add rdi, rcx                    ; fb + y * pitch

    ; Add x offset based on BPP
    mov ecx, [screen_bpp]
    cmp ecx, 24
    je .text_24bpp
    cmp ecx, 32
    je .text_32bpp
    ; 8bpp fallback
    add rdi, rax
    jmp .text_draw
.text_24bpp:
    imul eax, 3
    add rdi, rax
    jmp .text_draw
.text_32bpp:
    shl eax, 2                      ; x * 4
    add rdi, rax

.text_draw:
    mov rsi, r14                    ; string (from R14)
    mov r8d, r15d                   ; 32-bit color (from R15)
    call draw_text

.text_not_visible:
    pop r15
    pop r14
    pop r13
    pop r12
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
    mov edx, COL3D_PARTICLE
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

; ============================================================================
; DRAW_GROUND_GRID - Draw a perspective grid on the ground (Y = -2)
; Creates sense of depth and space
; ============================================================================
draw_ground_grid:
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

    ; Draw horizontal lines (parallel to X axis)
    ; Z goes from -12 to -2 in steps of 2
    mov r12d, 0xFFF40000            ; Z = -12.0 (start far)

.grid_z_loop:
    cmp r12d, 0xFFFE0000            ; Z = -2.0 (end near)
    jge .grid_h_done

    ; Draw line from X=-8 to X=8 at current Z, Y=-2
    ; Point 1: (-8, -2, Z)
    mov edi, 0xFFF80000             ; X = -8.0
    mov esi, 0xFFFE0000             ; Y = -2.0
    mov edx, r12d                   ; Z

    call project_point
    test ecx, ecx
    jz .next_z
    mov r13d, eax                   ; screen_x1
    mov r14d, ebx                   ; screen_y1

    ; Point 2: (8, -2, Z)
    mov edi, 0x00080000             ; X = 8.0
    mov esi, 0xFFFE0000             ; Y = -2.0
    mov edx, r12d                   ; Z

    call project_point
    test ecx, ecx
    jz .next_z

    ; Draw line
    mov edi, r13d
    mov esi, r14d
    mov edx, eax
    mov ecx, ebx
    mov r8d, COL3D_GRID
    call draw_line_2d

.next_z:
    add r12d, 0x00020000            ; Z += 2.0
    jmp .grid_z_loop

.grid_h_done:
    ; Draw vertical lines (parallel to Z axis)
    ; X goes from -8 to 8 in steps of 2
    mov r12d, 0xFFF80000            ; X = -8.0

.grid_x_loop:
    cmp r12d, 0x00090000            ; X > 8.0?
    jge .grid_done

    ; Draw line from Z=-12 to Z=-2 at current X, Y=-2
    ; Point 1: (X, -2, -12)
    mov edi, r12d                   ; X
    mov esi, 0xFFFE0000             ; Y = -2.0
    mov edx, 0xFFF40000             ; Z = -12.0

    call project_point
    test ecx, ecx
    jz .next_x
    mov r13d, eax
    mov r14d, ebx

    ; Point 2: (X, -2, -2)
    mov edi, r12d                   ; X
    mov esi, 0xFFFE0000             ; Y = -2.0
    mov edx, 0xFFFE0000             ; Z = -2.0

    call project_point
    test ecx, ecx
    jz .next_x

    ; Draw line
    mov edi, r13d
    mov esi, r14d
    mov edx, eax
    mov ecx, ebx
    ; Highlight center lines
    cmp r12d, 0
    jne .not_center
    mov r8d, COL3D_GRID_HI
    jmp .draw_v_line
.not_center:
    mov r8d, COL3D_GRID
.draw_v_line:
    call draw_line_2d

.next_x:
    add r12d, 0x00020000            ; X += 2.0
    jmp .grid_x_loop

.grid_done:
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
