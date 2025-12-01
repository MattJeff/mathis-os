; ═══════════════════════════════════════════════════════════════════════════
; MATHIS OS BOOT SECTOR
; 512 bytes - loads stage2 from sectors 1-8
; ═══════════════════════════════════════════════════════════════════════════

[BITS 16]
[ORG 0x7C00]

start:
    ; Setup segments
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7C00

    ; Save boot drive
    mov [boot_drive], dl

    ; Print welcome
    mov si, msg_boot
    call print_string

    ; Load stage2 (8 sectors) at 0x7E00
    mov ax, 0x0000
    mov es, ax
    mov bx, 0x7E00          ; ES:BX = 0x0000:0x7E00

    mov ah, 0x02            ; Read sectors
    mov al, 8               ; 8 sectors (4KB)
    mov ch, 0               ; Cylinder 0
    mov cl, 2               ; Sector 2 (1-based)
    mov dh, 0               ; Head 0
    mov dl, [boot_drive]    ; Drive
    int 0x13
    jc disk_error

    ; Jump to stage2
    jmp 0x0000:0x7E00

disk_error:
    mov si, msg_error
    call print_string
    jmp $

print_string:
    lodsb
    or al, al
    jz .done
    mov ah, 0x0E
    int 0x10
    jmp print_string
.done:
    ret

msg_boot:   db "MATHIS OS", 13, 10, 0
msg_error:  db "Disk error!", 0
boot_drive: db 0

; Padding and signature
times 510-($-$$) db 0
dw 0xAA55
