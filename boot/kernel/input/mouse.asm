; ============================================================================
; MathisOS - Mouse Handler
; ============================================================================
; Gestion souris PS/2
; - mouse_init
; - mouse_isr64
; ============================================================================

; ════════════════════════════════════════════════════════════════════════════
; MOUSE INIT - Initialize PS/2 Mouse (simplified)
; ════════════════════════════════════════════════════════════════════════════
mouse_init:
    push rax

    ; Enable auxiliary device (mouse port)
    call .wait_write
    mov al, 0xA8
    out 0x64, al

    ; Get compaq status byte
    call .wait_write
    mov al, 0x20
    out 0x64, al
    call .wait_read
    in al, 0x60
    or al, 2                        ; Enable IRQ12
    and al, 0xDF                    ; Enable mouse clock
    mov ah, al

    ; Set compaq status byte
    call .wait_write
    mov al, 0x60
    out 0x64, al
    call .wait_write
    mov al, ah
    out 0x60, al

    ; Send "set defaults" to mouse
    call .wait_write
    mov al, 0xD4
    out 0x64, al
    call .wait_write
    mov al, 0xF6                    ; Set defaults
    out 0x60, al
    call .wait_read
    in al, 0x60                     ; Read ACK

    ; Enable mouse data reporting
    call .wait_write
    mov al, 0xD4
    out 0x64, al
    call .wait_write
    mov al, 0xF4                    ; Enable
    out 0x60, al
    call .wait_read
    in al, 0x60                     ; Read ACK

    pop rax
    ret

.wait_write:
    in al, 0x64
    test al, 2
    jnz .wait_write
    ret

.wait_read:
    in al, 0x64
    test al, 1
    jz .wait_read
    ret
