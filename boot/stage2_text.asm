; Stage 2 Bootloader - TEXT MODE - Loads 48 sectors (24KB kernel)
[BITS 16]
[ORG 0x7E00]

start:
    mov si, loading_msg
.print:
    lodsb
    or al, al
    jz .done_print
    mov ah, 0x0E
    int 0x10
    jmp .print
.done_print:

    ; Read 1: 9 sectors from Track 0, Head 0, Sector 10 -> 0x10000
    mov ax, 0x1000
    mov es, ax
    xor bx, bx
    mov ah, 0x02
    mov al, 9
    mov ch, 0
    mov cl, 10
    mov dh, 0
    mov dl, 0
    int 0x13
    jc disk_error

    ; Read 2: 18 sectors from Track 0, Head 1 -> 0x11200
    mov bx, 0x1200
    mov ah, 0x02
    mov al, 18
    mov ch, 0
    mov cl, 1
    mov dh, 1
    mov dl, 0
    int 0x13
    jc disk_error

    ; Read 3: 18 sectors from Track 1, Head 0 -> 0x13600
    mov bx, 0x3600
    mov ah, 0x02
    mov al, 18
    mov ch, 1
    mov cl, 1
    mov dh, 0
    mov dl, 0
    int 0x13
    jc disk_error

    ; Read 4: 3 sectors from Track 1, Head 1 -> 0x15A00 (pour 48 total)
    mov bx, 0x5A00
    mov ah, 0x02
    mov al, 3
    mov ch, 1
    mov cl, 1
    mov dh, 1
    mov dl, 0
    int 0x13
    jc disk_error

    ; NO VGA MODE - Stay in text mode
    jmp enable_a20

disk_error:
    mov ax, 0xB800
    mov es, ax
    mov word [es:0], 0x4F45
    cli
    hlt

enable_a20:
    in al, 0x92
    or al, 2
    and al, 0xFE
    out 0x92, al
    cli
    lgdt [gdt_ptr]
    mov eax, cr0
    or eax, 1
    mov cr0, eax
    jmp 0x08:pm_entry

[BITS 32]
pm_entry:
    mov ax, 0x10
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov esp, 0x90000
    jmp 0x08:0x10000

; GDT
gdt:
    dq 0
    dw 0xFFFF, 0x0000
    db 0x00, 0x9A, 0xCF, 0x00
    dw 0xFFFF, 0x0000
    db 0x00, 0x92, 0xCF, 0x00
gdt_end:

gdt_ptr:
    dw gdt_end - gdt - 1
    dd gdt

loading_msg: db "Loading...", 0

times 4096 - ($ - $$) db 0
