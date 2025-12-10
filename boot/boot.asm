; ═══════════════════════════════════════════════════════════════════════════
; MATHIS OS BOOT SECTOR - Hard Disk Edition
; Uses LBA mode for reliable large kernel loading
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

    ; Save boot drive (0x80 = first hard disk)
    mov [boot_drive], dl

    ; Print welcome
    mov si, msg_boot
    call print_string

    ; Load stage2 using LBA (8 sectors from LBA 1)
    mov si, dap
    mov ah, 0x42            ; Extended read
    mov dl, [boot_drive]
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

; Disk Address Packet for LBA read
align 4
dap:
    db 0x10             ; Size of DAP (16 bytes)
    db 0                ; Reserved
    dw 8                ; Number of sectors to read
    dw 0x7E00           ; Offset
    dw 0x0000           ; Segment
    dd 1                ; LBA low (start at sector 1)
    dd 0                ; LBA high

msg_boot:   db "MATHIS OS", 13, 10, 0
msg_error:  db "Disk err", 0
boot_drive: db 0

; Padding and signature
times 510-($-$$) db 0
dw 0xAA55
