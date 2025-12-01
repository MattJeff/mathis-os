; Boot sector for MATHIS OS with JARVIS Graphics
[BITS 16]
[ORG 0x7C00]

start:
    ; Disable interrupts during setup
    cli
    
    ; Setup segments to 0
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7C00
    
    ; Enable interrupts
    sti

    ; Print boot message
    mov si, msg
    call print_str

    ; Reset disk system
    xor ax, ax
    mov dl, 0x00
    int 0x13

    ; Read stage2: 8 sectors starting from sector 2 to 0x7E00
    mov ax, 0x0000
    mov es, ax          ; ES = 0
    mov bx, 0x7E00      ; ES:BX = 0000:7E00
    
    mov ah, 0x02        ; Read sectors
    mov al, 8           ; 8 sectors (4KB)
    mov ch, 0           ; Cylinder 0
    mov cl, 2           ; Sector 2 (1-based)
    mov dh, 0           ; Head 0
    mov dl, 0x00        ; Drive 0 (floppy/first disk)
    int 0x13
    jc disk_error

    ; Print OK
    mov si, ok_msg
    call print_str

    ; Jump to stage2 at 0000:7E00
    ; Stage2 will switch to VGA mode and protected mode
    jmp 0x0000:0x7E00

print_str:
    lodsb
    or al, al
    jz .done
    mov ah, 0x0E
    mov bh, 0
    int 0x10
    jmp print_str
.done:
    ret

disk_error:
    mov si, err_msg
    call print_str
.halt:
    cli
    hlt
    jmp .halt

msg:     db "MATHIS OS v3.0", 13, 10, 0
ok_msg:  db "OK", 13, 10, 0
err_msg: db "DISK ERR", 0

    ; Pad to 510 bytes
    times 510-($-$$) db 0
    ; Boot signature
    dw 0xAA55
