; ============================================================================
; EFFECTS3D.ASM - Advanced Visual Effects for MATHIS OS
; ============================================================================
; Implements: Metaballs, Perlin Noise, Glow/Bloom
; ============================================================================
[BITS 64]

; Effect constants
METABALL_THRESHOLD  equ 180         ; Threshold for metaball surface (0-255)
METABALL_FALLOFF    equ 8000        ; Falloff factor for distance
GLOW_RADIUS         equ 3           ; Blur radius for glow effect
NOISE_OCTAVES       equ 3           ; Number of noise octaves

; ============================================================================
; RENDER_METABALLS - Render metaballs for all nodes
; Creates organic blob shapes that merge when close
; ============================================================================
render_metaballs:
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

    ; We'll render in a region around the projected node centers
    ; First, project all nodes to get their screen positions
    call project_all_nodes

    ; Get bounding box of all projected nodes
    mov r12d, [metaball_min_x]
    mov r13d, [metaball_min_y]
    mov r14d, [metaball_max_x]
    mov r15d, [metaball_max_y]

    ; Expand bounding box for glow
    sub r12d, 40
    sub r13d, 40
    add r14d, 40
    add r15d, 40

    ; Clamp to screen bounds
    cmp r12d, 0
    jge .min_x_ok
    xor r12d, r12d
.min_x_ok:
    cmp r13d, 0
    jge .min_y_ok
    xor r13d, r13d
.min_y_ok:
    cmp r14d, [screen_width]
    jl .max_x_ok
    mov r14d, [screen_width]
    dec r14d
.max_x_ok:
    cmp r15d, [screen_height]
    jl .max_y_ok
    mov r15d, [screen_height]
    dec r15d
.max_y_ok:

    ; For each pixel in bounding box
    mov esi, r13d                   ; y = min_y

.metaball_y_loop:
    cmp esi, r15d
    jge .metaball_done

    mov edi, r12d                   ; x = min_x

.metaball_x_loop:
    cmp edi, r14d
    jge .next_metaball_y

    ; Calculate metaball field value at (edi, esi)
    call calc_metaball_field
    ; Returns: EAX = field value (0-255), EBX = dominant node color

    ; Check if above threshold (inside metaball)
    cmp eax, METABALL_THRESHOLD
    jl .outside_metaball

    ; Inside metaball - calculate color with gradient
    push rdi
    push rsi
    mov ecx, eax                    ; field value
    mov edx, ebx                    ; base color
    call calc_metaball_color
    ; Returns EDX = final color

    pop rsi
    pop rdi
    call draw_pixel_3d

.outside_metaball:
    inc edi
    jmp .metaball_x_loop

.next_metaball_y:
    inc esi
    jmp .metaball_y_loop

.metaball_done:
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
; PROJECT_ALL_NODES - Project all world nodes to screen coordinates
; Stores results in projected_nodes array
; ============================================================================
project_all_nodes:
    push rax
    push rbx
    push rcx
    push rdx
    push rdi
    push rsi
    push r8
    push r9
    push r10

    ; Initialize bounding box to extreme values
    mov dword [metaball_min_x], 10000
    mov dword [metaball_min_y], 10000
    mov dword [metaball_max_x], 0
    mov dword [metaball_max_y], 0

    mov ecx, NODE_COUNT
    lea r8, [world_nodes]
    lea r9, [projected_nodes]
    xor r10d, r10d                  ; node index

.project_loop:
    push rcx

    ; Load node world coordinates
    mov edx, [r8 + 8]               ; Z
    mov esi, [r8 + 4]               ; Y
    mov edi, [r8]                   ; X

    ; Project to screen
    call project_point
    test ecx, ecx
    jz .node_not_visible

    ; Store projected position
    mov [r9], eax                   ; screen_x
    mov [r9 + 4], ebx               ; screen_y
    mov dword [r9 + 8], 1           ; visible flag

    ; Get node size for radius calculation
    movzx ecx, byte [r8 + 13]       ; size
    add ecx, 12                     ; base radius
    mov [r9 + 12], ecx              ; screen radius

    ; Get node color
    movzx eax, byte [r8 + 12]       ; node type
    call get_node_color_32
    mov [r9 + 16], r8d              ; store color

    ; Update bounding box
    mov eax, [r9]                   ; screen_x
    mov ebx, [r9 + 4]               ; screen_y
    mov ecx, [r9 + 12]              ; radius

    ; min_x
    mov edx, eax
    sub edx, ecx
    cmp edx, [metaball_min_x]
    jge .no_update_min_x
    mov [metaball_min_x], edx
.no_update_min_x:

    ; min_y
    mov edx, ebx
    sub edx, ecx
    cmp edx, [metaball_min_y]
    jge .no_update_min_y
    mov [metaball_min_y], edx
.no_update_min_y:

    ; max_x
    mov edx, eax
    add edx, ecx
    cmp edx, [metaball_max_x]
    jle .no_update_max_x
    mov [metaball_max_x], edx
.no_update_max_x:

    ; max_y
    mov edx, ebx
    add edx, ecx
    cmp edx, [metaball_max_y]
    jle .no_update_max_y
    mov [metaball_max_y], edx
.no_update_max_y:

    jmp .next_node

.node_not_visible:
    mov dword [r9 + 8], 0           ; not visible

.next_node:
    add r8, NODE_SIZE
    add r9, 24                      ; sizeof projected node struct
    inc r10d
    pop rcx
    dec ecx
    jnz .project_loop

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
; CALC_METABALL_FIELD - Calculate metaball field at screen position
; Input: EDI = screen_x, ESI = screen_y
; Output: EAX = field value (0-255), EBX = dominant node color
; ============================================================================
calc_metaball_field:
    push rcx
    push rdx
    push r8
    push r9
    push r10
    push r11
    push r12
    push r13

    xor r10d, r10d                  ; total field value
    xor r11d, r11d                  ; dominant color
    xor r12d, r12d                  ; max contribution

    mov r13d, NODE_COUNT
    lea r8, [projected_nodes]

.field_loop:
    ; Check if node is visible
    cmp dword [r8 + 8], 0
    je .next_field_node

    ; Calculate distance squared to this node
    mov eax, edi
    sub eax, [r8]                   ; dx = x - node_x
    imul eax, eax                   ; dx^2

    mov ecx, esi
    sub ecx, [r8 + 4]               ; dy = y - node_y
    imul ecx, ecx                   ; dy^2

    add eax, ecx                    ; dist^2 = dx^2 + dy^2

    ; Avoid division by zero
    cmp eax, 1
    jge .dist_ok
    mov eax, 1
.dist_ok:

    ; Calculate contribution: radius^2 * FALLOFF / dist^2
    mov r9d, [r8 + 12]              ; radius
    imul r9d, r9d                   ; radius^2
    imul r9d, METABALL_FALLOFF      ; radius^2 * FALLOFF

    ; Division: r9d / eax
    push rdx
    push rax                        ; save dist^2
    mov eax, r9d                    ; dividend = radius^2 * FALLOFF
    xor edx, edx
    pop rcx                         ; divisor = dist^2 (was in eax)
    push rcx
    div ecx                         ; eax = result
    add rsp, 8                      ; discard saved dist^2
    pop rdx

    ; Clamp contribution to reasonable range
    cmp eax, 255
    jle .contrib_ok
    mov eax, 255
.contrib_ok:

    ; Add to total field
    add r10d, eax

    ; Track dominant color (node with highest contribution)
    cmp eax, r12d
    jle .not_dominant
    mov r12d, eax
    mov r11d, [r8 + 16]             ; this node's color
.not_dominant:

.next_field_node:
    add r8, 24
    dec r13d
    jnz .field_loop

    ; Clamp total field to 255
    cmp r10d, 255
    jle .field_ok
    mov r10d, 255
.field_ok:

    mov eax, r10d                   ; field value
    mov ebx, r11d                   ; dominant color

    pop r13
    pop r12
    pop r11
    pop r10
    pop r9
    pop r8
    pop rdx
    pop rcx
    ret

; ============================================================================
; CALC_METABALL_COLOR - Calculate metaball pixel color with effects
; Input: ECX = field value (0-255), EDX = base color
; Output: EDX = final color with glow/gradient
; ============================================================================
calc_metaball_color:
    push rax
    push rbx
    push rcx
    push r8

    ; Field value determines brightness/glow
    ; Higher field = brighter (closer to center)

    ; Extract RGB from base color
    mov eax, edx
    movzx r8d, al                   ; Blue
    shr eax, 8
    movzx ebx, al                   ; Green
    shr eax, 8
    movzx eax, al                   ; Red

    ; Calculate glow factor based on field strength
    ; Edge (threshold) = darker, center (255) = brighter with white core
    sub ecx, METABALL_THRESHOLD
    ; ecx now 0 at edge, ~75 at center

    ; Brighten colors toward center
    cmp ecx, 50
    jl .no_white_core

    ; White/bright core effect
    mov edx, ecx
    sub edx, 50
    shl edx, 2                      ; amplify

    add eax, edx
    add ebx, edx
    add r8d, edx

    ; Clamp
    cmp eax, 255
    jle .r_ok
    mov eax, 255
.r_ok:
    cmp ebx, 255
    jle .g_ok
    mov ebx, 255
.g_ok:
    cmp r8d, 255
    jle .b_ok
    mov r8d, 255
.b_ok:

.no_white_core:
    ; Add subtle noise for organic feel
    push rdi
    push rsi
    call get_noise_value            ; returns eax = noise (0-15)
    pop rsi
    pop rdi
    sub eax, 8                      ; -8 to +7

    ; Apply noise to brightness
    add r8d, eax
    add ebx, eax
    ; Don't apply to red (keeps color identity)

    ; Clamp after noise
    cmp r8d, 0
    jge .b_pos
    xor r8d, r8d
.b_pos:
    cmp r8d, 255
    jle .b_ok2
    mov r8d, 255
.b_ok2:
    cmp ebx, 0
    jge .g_pos
    xor ebx, ebx
.g_pos:
    cmp ebx, 255
    jle .g_ok2
    mov ebx, 255
.g_ok2:

    ; Reassemble color
    shl eax, 8
    or eax, ebx
    shl eax, 8
    or eax, r8d
    mov edx, eax

    pop r8
    pop rcx
    pop rbx
    pop rax
    ret

; ============================================================================
; GET_NOISE_VALUE - Get pseudo-random noise value
; Input: EDI = x, ESI = y (screen position)
; Output: EAX = noise value (0-15)
; ============================================================================
get_noise_value:
    push rbx
    push rcx

    ; Simple hash-based noise
    mov eax, edi
    imul eax, 374761393
    add eax, esi
    imul eax, 668265263
    add eax, [noise_seed]
    xor eax, [frame_counter]

    ; Take low bits for noise
    and eax, 0xF

    pop rcx
    pop rbx
    ret

; ============================================================================
; APPLY_BLOOM - Apply bloom/glow post-processing effect
; Works on the framebuffer after main rendering
; ============================================================================
apply_bloom:
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

    ; Simple bloom: find bright pixels, blur them, add back
    ; For performance, only process the metaball region

    mov r10d, [metaball_min_x]
    mov r11d, [metaball_min_y]
    mov r12d, [metaball_max_x]

    ; Expand for bloom radius
    sub r10d, GLOW_RADIUS
    sub r11d, GLOW_RADIUS
    add r12d, GLOW_RADIUS

    ; Clamp
    cmp r10d, GLOW_RADIUS
    jge .bloom_x_ok
    mov r10d, GLOW_RADIUS
.bloom_x_ok:
    cmp r11d, GLOW_RADIUS
    jge .bloom_y_ok
    mov r11d, GLOW_RADIUS
.bloom_y_ok:

    mov esi, r11d                   ; y

.bloom_y_loop:
    cmp esi, [metaball_max_y]
    jge .bloom_done

    mov edi, r10d                   ; x

.bloom_x_loop:
    cmp edi, r12d
    jge .bloom_next_y

    ; Read center pixel
    call read_pixel_3d
    ; EAX = pixel color

    ; Check if bright enough for bloom (any channel > 200)
    mov ecx, eax
    and ecx, 0xFF                   ; blue
    cmp ecx, 200
    jge .do_bloom

    mov ecx, eax
    shr ecx, 8
    and ecx, 0xFF                   ; green
    cmp ecx, 200
    jge .do_bloom

    mov ecx, eax
    shr ecx, 16
    and ecx, 0xFF                   ; red
    cmp ecx, 200
    jge .do_bloom

    jmp .bloom_next_x

.do_bloom:
    ; Add glow to surrounding pixels (simple star pattern)
    mov r8d, eax                    ; save bright color

    ; Dim the glow color
    mov eax, r8d
    call dim_color
    mov r9d, eax                    ; dimmed glow color

    ; Add glow to 4 neighbors
    push rdi
    push rsi

    ; Right
    add edi, 1
    mov edx, r9d
    call blend_pixel

    ; Left
    sub edi, 2
    call blend_pixel

    ; Up
    add edi, 1
    sub esi, 1
    call blend_pixel

    ; Down
    add esi, 2
    call blend_pixel

    pop rsi
    pop rdi

.bloom_next_x:
    inc edi
    jmp .bloom_x_loop

.bloom_next_y:
    inc esi
    jmp .bloom_y_loop

.bloom_done:
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
; READ_PIXEL_3D - Read a pixel from framebuffer
; Input: EDI = x, ESI = y
; Output: EAX = pixel color (32-bit)
; ============================================================================
read_pixel_3d:
    push rbx
    push rcx

    ; Bounds check
    cmp edi, 0
    jl .read_black
    cmp edi, [screen_width]
    jge .read_black
    cmp esi, 0
    jl .read_black
    cmp esi, [screen_height]
    jge .read_black

    ; Calculate address
    mov eax, esi
    imul eax, [screen_pitch]
    mov rbx, [screen_fb]
    add rbx, rax

    ; Check BPP
    mov ecx, [screen_bpp]
    cmp ecx, 32
    je .read_32
    cmp ecx, 24
    je .read_24
    ; 8-bit fallback
    movzx eax, byte [rbx + rdi]
    jmp .read_done

.read_32:
    mov ecx, edi
    shl ecx, 2
    add rbx, rcx
    mov eax, [rbx]
    jmp .read_done

.read_24:
    mov eax, edi
    imul eax, 3
    add rbx, rax
    movzx eax, byte [rbx]           ; B
    movzx ecx, byte [rbx + 1]       ; G
    shl ecx, 8
    or eax, ecx
    movzx ecx, byte [rbx + 2]       ; R
    shl ecx, 16
    or eax, ecx
    jmp .read_done

.read_black:
    xor eax, eax

.read_done:
    pop rcx
    pop rbx
    ret

; ============================================================================
; BLEND_PIXEL - Blend color with existing pixel (additive)
; Input: EDI = x, ESI = y, EDX = color to blend
; ============================================================================
blend_pixel:
    push rax
    push rbx
    push rcx
    push r8

    ; Read existing pixel
    call read_pixel_3d
    mov r8d, eax                    ; existing color

    ; Additive blend each channel
    ; Blue
    mov eax, r8d
    and eax, 0xFF
    mov ebx, edx
    and ebx, 0xFF
    add eax, ebx
    cmp eax, 255
    jle .b_blend_ok
    mov eax, 255
.b_blend_ok:
    mov ecx, eax

    ; Green
    mov eax, r8d
    shr eax, 8
    and eax, 0xFF
    mov ebx, edx
    shr ebx, 8
    and ebx, 0xFF
    add eax, ebx
    cmp eax, 255
    jle .g_blend_ok
    mov eax, 255
.g_blend_ok:
    shl eax, 8
    or ecx, eax

    ; Red
    mov eax, r8d
    shr eax, 16
    and eax, 0xFF
    mov ebx, edx
    shr ebx, 16
    and ebx, 0xFF
    add eax, ebx
    cmp eax, 255
    jle .r_blend_ok
    mov eax, 255
.r_blend_ok:
    shl eax, 16
    or ecx, eax

    ; Write blended pixel
    mov edx, ecx
    call draw_pixel_3d

    pop r8
    pop rcx
    pop rbx
    pop rax
    ret

; ============================================================================
; DIM_COLOR - Reduce color brightness for glow
; Input: EAX = color
; Output: EAX = dimmed color (50%)
; ============================================================================
dim_color:
    push rbx
    push rcx

    ; Dim each channel by 50%
    mov ebx, eax
    and ebx, 0xFF                   ; B
    shr ebx, 1

    mov ecx, eax
    shr ecx, 8
    and ecx, 0xFF                   ; G
    shr ecx, 1
    shl ecx, 8
    or ebx, ecx

    mov ecx, eax
    shr ecx, 16
    and ecx, 0xFF                   ; R
    shr ecx, 1
    shl ecx, 16
    or ebx, ecx

    mov eax, ebx

    pop rcx
    pop rbx
    ret

; ============================================================================
; DRAW_INTERNAL_PARTICLES - Draw animated noise particles inside metaballs
; ============================================================================
draw_internal_particles:
    push rax
    push rbx
    push rcx
    push rdx
    push rdi
    push rsi
    push r8
    push r9

    ; For each visible node, draw some internal particles
    mov ecx, NODE_COUNT
    lea r8, [projected_nodes]

.particle_node_loop:
    push rcx

    cmp dword [r8 + 8], 0           ; visible?
    je .next_particle_node

    ; Draw particles inside this node
    mov r9d, 20                     ; particle count per node

.particle_loop:
    ; Generate pseudo-random position inside node
    mov eax, r9d
    add eax, [frame_counter]
    imul eax, 1103515245
    add eax, [r8]                   ; node x

    ; X offset from center
    mov ebx, eax
    and ebx, 0x1F                   ; 0-31
    sub ebx, 16                     ; -16 to +15

    imul eax, 1103515245
    ; Y offset
    mov ecx, eax
    and ecx, 0x1F
    sub ecx, 16

    ; Check if inside node radius
    mov edi, ebx
    imul edi, edi
    mov esi, ecx
    imul esi, esi
    add edi, esi                    ; dist^2

    mov esi, [r8 + 12]              ; radius
    sub esi, 4                      ; inner radius
    imul esi, esi
    cmp edi, esi
    jge .skip_particle

    ; Draw particle
    mov edi, [r8]                   ; node center x
    add edi, ebx
    mov esi, [r8 + 4]               ; node center y
    add ecx, esi
    mov esi, ecx

    ; Particle color (bright white/cyan)
    mov edx, 0x00AAFFFF
    call draw_pixel_3d

.skip_particle:
    dec r9d
    jnz .particle_loop

.next_particle_node:
    add r8, 24
    pop rcx
    dec ecx
    jnz .particle_node_loop

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
; Data section
; ============================================================================
align 8
projected_nodes:    times NODE_COUNT * 24 db 0  ; x, y, visible, radius, color, padding
metaball_min_x:     dd 0
metaball_min_y:     dd 0
metaball_max_x:     dd 0
metaball_max_y:     dd 0
noise_seed:         dd 12345
frame_counter:      dd 0
