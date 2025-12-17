; ============================================================================
; MATH3D.ASM - Fixed-point 3D Mathematics for MATHIS OS
; ============================================================================
[BITS 64]

; Fixed-point format: 16.16 (16 bits integer, 16 bits fraction)
FP_SHIFT        equ 16
FP_ONE          equ 0x00010000      ; 1.0
FP_HALF         equ 0x00008000      ; 0.5
FP_TWO          equ 0x00020000      ; 2.0
FP_NEG_ONE      equ 0xFFFF0000      ; -1.0

; Screen constants (now uses dynamic screen_width/height from kernel)
; These are kept as fallbacks but projection uses runtime values
SCREEN_W_DEFAULT  equ 320
SCREEN_H_DEFAULT  equ 200
FOV_FACTOR        equ 200           ; Field of view factor

; ============================================================================
; SIN/COS LOOKUP TABLES (256 entries, pre-calculated)
; Index 0-255 = 0 to 360 degrees
; Values are in fixed-point 16.16
; ============================================================================
align 16
sin3d_table:
    ; 0-15 degrees (entries 0-10)
    dd 0x00000000   ; sin(0) = 0.0
    dd 0x00000648   ; sin(1.4) ~ 0.024
    dd 0x00000C8F   ; sin(2.8) ~ 0.049
    dd 0x000012D5   ; sin(4.2) ~ 0.073
    dd 0x00001917   ; sin(5.6) ~ 0.098
    dd 0x00001F56   ; sin(7.0) ~ 0.122
    dd 0x00002590   ; sin(8.4) ~ 0.146
    dd 0x00002BC4   ; sin(9.8) ~ 0.171
    dd 0x000031F1   ; sin(11.2) ~ 0.195
    dd 0x00003817   ; sin(12.6) ~ 0.219
    dd 0x00003E33   ; sin(14.0) ~ 0.242
    dd 0x00004447   ; sin(15.4) ~ 0.266
    dd 0x00004A50   ; sin(16.8) ~ 0.290
    dd 0x0000504D   ; sin(18.2) ~ 0.313
    dd 0x0000563E   ; sin(19.6) ~ 0.336
    dd 0x00005C22   ; sin(21.0) ~ 0.358
    ; 16-31
    dd 0x000061F7   ; sin(22.5) ~ 0.383
    dd 0x000067BD   ; sin(24)
    dd 0x00006D74   ; sin(25)
    dd 0x0000731A   ; sin(27)
    dd 0x000078AD   ; sin(28)
    dd 0x00007E2E   ; sin(30) ~ 0.5
    dd 0x0000839C   ; sin(31)
    dd 0x000088F5   ; sin(33)
    dd 0x00008E39   ; sin(34)
    dd 0x00009368   ; sin(36)
    dd 0x00009880   ; sin(37)
    dd 0x00009D7F   ; sin(39)
    dd 0x0000A267   ; sin(40)
    dd 0x0000A736   ; sin(42)
    dd 0x0000ABEB   ; sin(43)
    dd 0x0000B085   ; sin(45) ~ 0.707
    ; 32-47
    dd 0x0000B504   ; sin(46)
    dd 0x0000B968   ; sin(48)
    dd 0x0000BDB0   ; sin(49)
    dd 0x0000C1DB   ; sin(51)
    dd 0x0000C5E9   ; sin(52)
    dd 0x0000C9D9   ; sin(54)
    dd 0x0000CDAB   ; sin(55)
    dd 0x0000D15F   ; sin(57)
    dd 0x0000D4F3   ; sin(58)
    dd 0x0000D868   ; sin(60) ~ 0.866
    dd 0x0000DBBE   ; sin(61)
    dd 0x0000DEF4   ; sin(63)
    dd 0x0000E208   ; sin(64)
    dd 0x0000E4FC   ; sin(66)
    dd 0x0000E7CE   ; sin(67)
    dd 0x0000EA7E   ; sin(69)
    ; 48-63
    dd 0x0000ED0B   ; sin(70)
    dd 0x0000EF76   ; sin(72)
    dd 0x0000F1BD   ; sin(73)
    dd 0x0000F3E1   ; sin(75)
    dd 0x0000F5E1   ; sin(76)
    dd 0x0000F7BE   ; sin(78)
    dd 0x0000F976   ; sin(79)
    dd 0x0000FB0A   ; sin(81)
    dd 0x0000FC79   ; sin(82)
    dd 0x0000FDC4   ; sin(84)
    dd 0x0000FEEA   ; sin(85)
    dd 0x0000FFEB   ; sin(87)
    dd 0x0000FFC7   ; sin(88)
    dd 0x0000FFFF   ; sin(90) = 1.0
    dd 0x0000FFC7   ; sin(91)
    dd 0x0000FFEB   ; sin(93)
    ; 64-127 (decreasing from 1 to 0)
    dd 0x0000FEEA, 0x0000FDC4, 0x0000FC79, 0x0000FB0A
    dd 0x0000F976, 0x0000F7BE, 0x0000F5E1, 0x0000F3E1
    dd 0x0000F1BD, 0x0000EF76, 0x0000ED0B, 0x0000EA7E
    dd 0x0000E7CE, 0x0000E4FC, 0x0000E208, 0x0000DEF4
    dd 0x0000DBBE, 0x0000D868, 0x0000D4F3, 0x0000D15F
    dd 0x0000CDAB, 0x0000C9D9, 0x0000C5E9, 0x0000C1DB
    dd 0x0000BDB0, 0x0000B968, 0x0000B504, 0x0000B085
    dd 0x0000ABEB, 0x0000A736, 0x0000A267, 0x00009D7F
    dd 0x00009880, 0x00009368, 0x00008E39, 0x000088F5
    dd 0x0000839C, 0x00007E2E, 0x000078AD, 0x0000731A
    dd 0x00006D74, 0x000067BD, 0x000061F7, 0x00005C22
    dd 0x0000563E, 0x0000504D, 0x00004A50, 0x00004447
    dd 0x00003E33, 0x00003817, 0x000031F1, 0x00002BC4
    dd 0x00002590, 0x00001F56, 0x00001917, 0x000012D5
    dd 0x00000C8F, 0x00000648, 0x00000000
    ; 128 = sin(180) = 0
    dd 0x00000000
    ; 129-191 (negative values, -sin)
    dd 0xFFFFF9B8, 0xFFFFF371, 0xFFFFED2B, 0xFFFFE6E9
    dd 0xFFFFE0AA, 0xFFFFDA70, 0xFFFFD43C, 0xFFFFCE0F
    dd 0xFFFFC7E9, 0xFFFFC1CD, 0xFFFFBBB9, 0xFFFFB5B0
    dd 0xFFFFAFB3, 0xFFFFA9C4, 0xFFFFA3C2, 0xFFFF9DDE
    dd 0xFFFF9809, 0xFFFF9243, 0xFFFF8C8C, 0xFFFF86E6
    dd 0xFFFF8153, 0xFFFF7BD2, 0xFFFF7664, 0xFFFF710B
    dd 0xFFFF6BC7, 0xFFFF6698, 0xFFFF6180, 0xFFFF5C81
    dd 0xFFFF5799, 0xFFFF52CA, 0xFFFF4E15, 0xFFFF497B
    dd 0xFFFF44FC, 0xFFFF4098, 0xFFFF3C50, 0xFFFF3825
    dd 0xFFFF3417, 0xFFFF3027, 0xFFFF2C55, 0xFFFF28A1
    dd 0xFFFF250D, 0xFFFF2198, 0xFFFF1E43, 0xFFFF1B0D
    dd 0xFFFF17F8, 0xFFFF1504, 0xFFFF1232, 0xFFFF0F81
    dd 0xFFFF0CF5, 0xFFFF0A8A, 0xFFFF0843, 0xFFFF061F
    dd 0xFFFF041F, 0xFFFF0242, 0xFFFF008A, 0xFFFEFEF6
    dd 0xFFFEFD87, 0xFFFEFC3C, 0xFFFEFB16, 0xFFFEFA15
    dd 0xFFFEF939, 0xFFFEF882, 0xFFFEF7F2
    ; 192-255 (back towards 0)
    dd 0xFFFEF787, 0xFFFEF843, 0xFFFEF923, 0xFFFEFA27
    dd 0xFFFEFB4E, 0xFFFEFC97, 0xFFFEFE02, 0xFFFEFF8E
    dd 0xFFFF0139, 0xFFFF0304, 0xFFFF04EC, 0xFFFF06F1
    dd 0xFFFF0911, 0xFFFF0B4B, 0xFFFF0D9E, 0xFFFF1009
    dd 0xFFFF128B, 0xFFFF1523, 0xFFFF17CF, 0xFFFF1A8F
    dd 0xFFFF1D61, 0xFFFF2045, 0xFFFF2339, 0xFFFF263C
    dd 0xFFFF294D, 0xFFFF2C6B, 0xFFFF2F95, 0xFFFF32C9
    dd 0xFFFF3606, 0xFFFF394C, 0xFFFF3C98, 0xFFFF3FEB
    dd 0xFFFF4343, 0xFFFF469E, 0xFFFF49FC, 0xFFFF4D5B
    dd 0xFFFF50BA, 0xFFFF5418, 0xFFFF5774, 0xFFFF5ACD
    dd 0xFFFF5E21, 0xFFFF6170, 0xFFFF64B8, 0xFFFF67F9
    dd 0xFFFF6B31, 0xFFFF6E60, 0xFFFF7184, 0xFFFF749C
    dd 0xFFFF77A7, 0xFFFF7AA4, 0xFFFF7D92, 0xFFFF8070
    dd 0xFFFF833D, 0xFFFF85F8, 0xFFFF88A0, 0xFFFF8B34
    dd 0xFFFF8DB3, 0xFFFF901C, 0xFFFF926E, 0xFFFF94A8
    dd 0xFFFF96C9, 0xFFFF98D0, 0xFFFF9ABD, 0xFFFF9C8E
    dd 0xFFFF9E43, 0xFFFFA000, 0x00000000

; Cosine table = sin table shifted by 64 entries (90 degrees)
; cos(x) = sin(x + 64)

; ============================================================================
; FP_MUL - Fixed-point multiplication
; Input:  EAX = a (16.16), EBX = b (16.16)
; Output: EAX = a * b (16.16)
; ============================================================================
fp_mul:
    push rdx
    imul ebx                        ; EDX:EAX = EAX * EBX (64-bit result)
    shrd eax, edx, FP_SHIFT         ; Shift right by 16 to get 16.16 result
    pop rdx
    ret

; ============================================================================
; FP_DIV - Fixed-point division
; Input:  EAX = dividend (16.16), EBX = divisor (16.16)
; Output: EAX = dividend / divisor (16.16)
; ============================================================================
fp_div:
    push rdx
    push rcx
    test ebx, ebx
    jz .div_zero

    mov ecx, ebx                    ; Save divisor
    cdq                             ; Sign-extend EAX to EDX:EAX
    shld edx, eax, FP_SHIFT         ; Shift left by 16
    shl eax, FP_SHIFT
    idiv ecx                        ; EAX = EDX:EAX / ECX

    pop rcx
    pop rdx
    ret

.div_zero:
    mov eax, 0x7FFFFFFF             ; Return max on divide by zero
    pop rcx
    pop rdx
    ret

; ============================================================================
; FAST_SIN - Fast sine lookup
; Input:  EAX = angle (0-255 maps to 0-360 degrees)
; Output: EAX = sin(angle) in 16.16 fixed-point
; ============================================================================
fast_sin:
    and eax, 0xFF                   ; Wrap to 0-255
    lea rdx, [sin3d_table]
    mov eax, [rdx + rax*4]
    ret

; ============================================================================
; FAST_COS - Fast cosine lookup
; Input:  EAX = angle (0-255)
; Output: EAX = cos(angle) in 16.16 fixed-point
; ============================================================================
fast_cos:
    add eax, 64                     ; cos(x) = sin(x + 90)
    and eax, 0xFF
    lea rdx, [sin3d_table]
    mov eax, [rdx + rax*4]
    ret

; ============================================================================
; PROJECT_POINT - Project 3D point to 2D screen
; Input:  EDI = x (16.16), ESI = y (16.16), EDX = z (16.16)
;         R8  = camera_x, R9 = camera_y, R10 = camera_z
;         R11 = camera_rot_y (0-255)
; Output: EAX = screen_x, EBX = screen_y, ECX = 1 if visible, 0 if behind
; ============================================================================
project_point:
    push r12
    push r13
    push r14
    push r15

    ; Translate relative to camera
    sub edi, r8d                    ; x -= cam_x
    sub esi, r9d                    ; y -= cam_y
    sub edx, r10d                   ; z -= cam_z

    ; Save original values
    mov r12d, edi                   ; x
    mov r13d, esi                   ; y
    mov r14d, edx                   ; z

    ; Rotate around Y axis (yaw)
    ; new_x = x * cos(rot) - z * sin(rot)
    ; new_z = x * sin(rot) + z * cos(rot)
    mov eax, r11d
    call fast_cos
    mov r15d, eax                   ; cos(rot)

    mov eax, r11d
    call fast_sin
    push rax                        ; sin(rot) on stack

    ; new_x = x * cos - z * sin
    mov eax, r12d                   ; x
    mov ebx, r15d                   ; cos
    call fp_mul
    mov edi, eax                    ; x * cos

    mov eax, r14d                   ; z
    pop rbx                         ; sin
    push rbx
    call fp_mul
    sub edi, eax                    ; new_x = x*cos - z*sin

    ; new_z = x * sin + z * cos
    mov eax, r12d                   ; x
    pop rbx                         ; sin
    call fp_mul
    mov edx, eax                    ; x * sin

    mov eax, r14d                   ; z
    mov ebx, r15d                   ; cos
    call fp_mul
    add edx, eax                    ; new_z = x*sin + z*cos

    ; Camera looks at -Z, so objects in front have negative z
    ; Negate z to make "forward" positive for projection math
    neg edx

    ; Check if point is in front of camera (z > 1.0 after negation)
    cmp edx, FP_ONE                 ; z > 1.0?
    jl .behind_camera

    ; Perspective projection
    ; screen_x = (x / z) * FOV + SCREEN_CX
    ; screen_y = (y / z) * FOV + SCREEN_CY

    mov eax, edi                    ; x
    mov ebx, edx                    ; z (now positive)
    call fp_div
    imul eax, FOV_FACTOR
    sar eax, FP_SHIFT
    add eax, [screen_centerx]       ; Use dynamic center X
    mov r12d, eax                   ; screen_x

    mov eax, r13d                   ; y (unchanged, no pitch rotation)
    neg eax                         ; Invert Y (screen Y goes down)
    mov ebx, edx                    ; z
    call fp_div
    imul eax, FOV_FACTOR
    sar eax, FP_SHIFT
    add eax, [screen_centery]       ; Use dynamic center Y
    mov r13d, eax                   ; screen_y

    ; Clamp to screen bounds (use dynamic dimensions)
    cmp r12d, 0
    jl .off_screen
    cmp r12d, [screen_width]
    jge .off_screen
    cmp r13d, 0
    jl .off_screen
    cmp r13d, [screen_height]
    jge .off_screen

    ; Return values
    mov eax, r12d                   ; screen_x
    mov ebx, r13d                   ; screen_y
    mov ecx, 1                      ; visible
    jmp .done

.behind_camera:
.off_screen:
    xor eax, eax
    xor ebx, ebx
    xor ecx, ecx                    ; not visible

.done:
    pop r15
    pop r14
    pop r13
    pop r12
    ret
