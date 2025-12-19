; ============================================================================
; CAMERA3D.ASM - First-Person Camera for MATHIS OS 3D
; ============================================================================
[BITS 64]

; ============================================================================
; CAMERA DATA
; ============================================================================
align 8
camera_x:       dd 0                ; Position X (16.16 fixed-point)
camera_y:       dd 0                ; Position Y
camera_z:       dd 0x00050000       ; Position Z = 5.0 (start back)
camera_rot_y:   dd 0                ; Rotation Y (yaw) 0-255
camera_rot_x:   dd 0                ; Rotation X (pitch) 0-255 - not used yet
camera_speed:   dd 0x00004000       ; Movement speed (0.25)
camera_rot_spd: dd 3                ; Rotation speed

; Direction vectors (computed from rotation)
cam_forward_x:  dd 0
cam_forward_z:  dd 0xFFFF0000       ; -1.0 (looking towards -Z initially)
cam_right_x:    dd 0x00010000       ; 1.0
cam_right_z:    dd 0

; ============================================================================
; CAMERA_INIT - Initialize camera to default position
; ============================================================================
camera_init:
    ; Position: (0, 0, 5)
    mov dword [camera_x], 0
    mov dword [camera_y], 0
    mov dword [camera_z], 0x00050000    ; z = 5.0

    ; Rotation: looking towards -Z (angle 0)
    mov dword [camera_rot_y], 0
    mov dword [camera_rot_x], 0

    call camera_update_vectors
    ret

; ============================================================================
; CAMERA_UPDATE_VECTORS - Update direction vectors from rotation
; Must be called after changing camera_rot_y
; ============================================================================
camera_update_vectors:
    push rax
    push rbx

    ; Forward vector = (sin(rot), 0, -cos(rot))
    mov eax, [camera_rot_y]
    call fast_sin
    mov [cam_forward_x], eax

    mov eax, [camera_rot_y]
    call fast_cos
    neg eax                         ; -cos
    mov [cam_forward_z], eax

    ; Right vector = (cos(rot), 0, sin(rot))
    mov eax, [camera_rot_y]
    call fast_cos
    mov [cam_right_x], eax

    mov eax, [camera_rot_y]
    call fast_sin
    mov [cam_right_z], eax

    pop rbx
    pop rax
    ret

; ============================================================================
; CAMERA_MOVE_FORWARD - Move camera forward
; ============================================================================
camera_move_forward:
    push rax
    push rbx

    ; pos += forward * speed
    mov eax, [cam_forward_x]
    mov ebx, [camera_speed]
    call fp_mul
    add [camera_x], eax

    mov eax, [cam_forward_z]
    mov ebx, [camera_speed]
    call fp_mul
    add [camera_z], eax

    pop rbx
    pop rax
    ret

; ============================================================================
; CAMERA_MOVE_BACKWARD - Move camera backward
; ============================================================================
camera_move_backward:
    push rax
    push rbx

    ; pos -= forward * speed
    mov eax, [cam_forward_x]
    mov ebx, [camera_speed]
    call fp_mul
    sub [camera_x], eax

    mov eax, [cam_forward_z]
    mov ebx, [camera_speed]
    call fp_mul
    sub [camera_z], eax

    pop rbx
    pop rax
    ret

; ============================================================================
; CAMERA_STRAFE_LEFT - Strafe left
; ============================================================================
camera_strafe_left:
    push rax
    push rbx

    ; pos -= right * speed
    mov eax, [cam_right_x]
    mov ebx, [camera_speed]
    call fp_mul
    sub [camera_x], eax

    mov eax, [cam_right_z]
    mov ebx, [camera_speed]
    call fp_mul
    sub [camera_z], eax

    pop rbx
    pop rax
    ret

; ============================================================================
; CAMERA_STRAFE_RIGHT - Strafe right
; ============================================================================
camera_strafe_right:
    push rax
    push rbx

    ; pos += right * speed
    mov eax, [cam_right_x]
    mov ebx, [camera_speed]
    call fp_mul
    add [camera_x], eax

    mov eax, [cam_right_z]
    mov ebx, [camera_speed]
    call fp_mul
    add [camera_z], eax

    pop rbx
    pop rax
    ret

; ============================================================================
; CAMERA_MOVE_UP - Move camera up (Y+)
; ============================================================================
camera_move_up:
    mov eax, [camera_speed]
    add [camera_y], eax
    ret

; ============================================================================
; CAMERA_MOVE_DOWN - Move camera down (Y-)
; ============================================================================
camera_move_down:
    mov eax, [camera_speed]
    sub [camera_y], eax
    ret

; ============================================================================
; CAMERA_ROTATE_LEFT - Rotate camera left (decrease yaw)
; ============================================================================
camera_rotate_left:
    mov eax, [camera_rot_spd]
    sub [camera_rot_y], eax
    and dword [camera_rot_y], 0xFF  ; Wrap 0-255
    call camera_update_vectors
    ret

; ============================================================================
; CAMERA_ROTATE_RIGHT - Rotate camera right (increase yaw)
; ============================================================================
camera_rotate_right:
    mov eax, [camera_rot_spd]
    add [camera_rot_y], eax
    and dword [camera_rot_y], 0xFF
    call camera_update_vectors
    ret

; ============================================================================
; CAMERA_GET_POS - Get camera position in R8, R9, R10
; Output: R8D = x, R9D = y, R10D = z
; ============================================================================
camera_get_pos:
    mov r8d, [camera_x]
    mov r9d, [camera_y]
    mov r10d, [camera_z]
    ret

; ============================================================================
; CAMERA_GET_ROT - Get camera rotation
; Output: R11D = rot_y
; ============================================================================
camera_get_rot:
    mov r11d, [camera_rot_y]
    ret
