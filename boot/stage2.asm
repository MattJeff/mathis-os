; Stage 2 Bootloader - Loads kernel using INT 13h extensions (LBA mode)
; Loads at 0x7E00, jumps to protected mode, then to kernel at 0x10000
; Uses LBA mode for reliable multi-sector reads

[BITS 16]
[ORG 0x7E00]

start:
    ; Print "Loading..."
    mov si, loading_msg
.print:
    lodsb
    or al, al
    jz .done_print
    mov ah, 0x0E
    int 0x10
    jmp .print
.done_print:

    ; ═══════════════════════════════════════════════════════════════════
    ; E820 MEMORY DETECTION (must be done in real mode!)
    ; Stores memory map at 0x8000 for kernel to use
    ; ═══════════════════════════════════════════════════════════════════
    ; call detect_memory  ; DISABLED - not used without memory module

    ; ═══════════════════════════════════════════════════════════════════
    ; Load kernel using CHS mode (LBA mode unreliable in QEMU floppy)
    ; kernel.bin is at LBA sector 9 (0-indexed), which is disk offset 0x1200
    ; boot.bin = sector 0, stage2.bin = sectors 1-8, kernel = sectors 9+
    ; Need to load 32 sectors (16KB kernel)
    ; ═══════════════════════════════════════════════════════════════════

    ; Skip LBA detection and go straight to CHS mode
    jmp no_lba

    ; (LBA code below is kept but not used)
    ; First, check if INT 13h extensions are available
    mov ah, 0x41
    mov bx, 0x55AA
    mov dl, 0x00            ; Drive 0 (floppy A)
    int 0x13
    jc no_lba               ; Extensions not available
    cmp bx, 0xAA55
    jne no_lba              ; Extensions not available

    ; Use LBA mode to load 32 sectors starting from LBA 9
    mov si, dap
    mov ah, 0x42
    mov dl, 0x00            ; Drive 0 (floppy A)
    int 0x13
    jc disk_error

    jmp enable_a20

no_lba:
    ; ═══════════════════════════════════════════════════════════════════
    ; LOAD 64KB KERNEL (128 sectors) - Explicit reads for reliability
    ; ═══════════════════════════════════════════════════════════════════

    ; Read 1: 9 sectors C0/H0/S10 -> 0x10000
    mov ax, 0x1000
    mov es, ax
    xor bx, bx
    mov ah, 0x02
    mov al, 9
    mov cx, 0x000A          ; C=0, S=10
    mov dx, 0x0000          ; H=0, Drive=0
    int 0x13
    jc disk_error

    ; Read 2: 18 sectors C0/H1/S1 -> 0x11200
    mov bx, 0x1200
    mov ah, 0x02
    mov al, 18
    mov cx, 0x0001          ; C=0, S=1
    mov dx, 0x0100          ; H=1
    int 0x13
    jc disk_error

    ; Read 3: 18 sectors C1/H0/S1 -> 0x13600
    mov bx, 0x3600
    mov ah, 0x02
    mov al, 18
    mov cx, 0x0101          ; C=1, S=1
    mov dx, 0x0000          ; H=0
    int 0x13
    jc disk_error

    ; Read 4: 18 sectors C1/H1/S1 -> 0x15A00
    mov bx, 0x5A00
    mov ah, 0x02
    mov al, 18
    mov cx, 0x0101          ; C=1, S=1
    mov dx, 0x0100          ; H=1
    int 0x13
    jc disk_error

    ; Read 5: 18 sectors C2/H0/S1 -> 0x17E00
    mov bx, 0x7E00
    mov ah, 0x02
    mov al, 18
    mov cx, 0x0201          ; C=2, S=1
    mov dx, 0x0000          ; H=0
    int 0x13
    jc disk_error

    ; Read 6: 18 sectors C2/H1/S1 -> 0x1A200
    mov ax, 0x1A20
    mov es, ax
    xor bx, bx
    mov ah, 0x02
    mov al, 18
    mov cx, 0x0201          ; C=2, S=1
    mov dx, 0x0100          ; H=1
    int 0x13
    jc disk_error

    ; Read 7: 18 sectors C3/H0/S1 -> 0x1C600
    mov ax, 0x1C60
    mov es, ax
    xor bx, bx
    mov ah, 0x02
    mov al, 18
    mov cx, 0x0301          ; C=3, S=1
    mov dx, 0x0000          ; H=0
    int 0x13
    jc disk_error

    ; Read 8: 11 sectors C3/H1/S1 -> 0x1EA00 (128 total = 64KB)
    mov ax, 0x1EA0
    mov es, ax
    xor bx, bx
    mov ah, 0x02
    mov al, 11
    mov cx, 0x0301          ; C=3, S=1
    mov dx, 0x0100          ; H=1
    int 0x13
    jc disk_error

    ; 64KB loaded!
    mov ah, 0x0E
    mov al, '6'
    int 0x10
    mov al, '4'
    int 0x10
    mov al, 'K'
    int 0x10

    ; LOAD KERNEL64 to 0x30000 (no copy yet)
    mov ax, 0x3000
    mov es, ax
    xor bx, bx
    mov ah, 0x02
    mov al, 8               ; 8 sectors = 4KB
    mov cx, 0x030C          ; C=3, S=12
    mov dx, 0x0100          ; H=1
    int 0x13
    jc disk_error

    mov ah, 0x0E
    mov al, '+'
    int 0x10

    jmp enable_a20

disk_error:
    ; Print 'E' on error and halt
    mov ax, 0xB800
    mov es, ax
    mov word [es:0], 0x4F45  ; 'E' in red
    cli
    hlt

; ═══════════════════════════════════════════════════════════════════════════
; E820 MEMORY DETECTION FUNCTION
; Stores memory map at 0x8000, count at 0x8004
; ═══════════════════════════════════════════════════════════════════════════
E820_MAP        equ 0x8000
E820_COUNT      equ 0x8004

detect_memory:
    push es
    push di
    push bp
    
    ; Set ES:DI to point to our buffer
    xor ax, ax
    mov es, ax
    mov di, E820_MAP + 8        ; Start storing entries after header
    xor ebx, ebx                ; Continuation value (must be 0 for first call)
    xor bp, bp                  ; Entry counter
    
.e820_loop:
    mov eax, 0xE820             ; E820 function
    mov ecx, 24                 ; Ask for 24 bytes per entry
    mov edx, 0x534D4150         ; 'SMAP' magic number
    int 0x15
    
    jc .e820_done               ; Carry set = error or done
    cmp eax, 0x534D4150         ; EAX should contain 'SMAP'
    jne .e820_done
    
    ; Valid entry
    inc bp                      ; Count this entry
    add di, 24                  ; Move to next entry slot
    
    test ebx, ebx               ; EBX = 0 means we're done
    jz .e820_done
    
    cmp bp, 20                  ; Max 20 entries (safety limit)
    jl .e820_loop
    
.e820_done:
    ; Store entry count
    mov [E820_COUNT], bp
    
    ; Print memory detection status
    mov ah, 0x0E
    mov al, 'M'
    int 0x10
    mov al, '0'
    add al, bl                  ; Show count (rough)
    int 0x10
    mov al, ' '
    int 0x10
    
    pop bp
    pop di
    pop es
    ret

enable_a20:
    ; Enable A20 line (fast method)
    in al, 0x92
    or al, 2
    and al, 0xFE            ; Don't reset
    out 0x92, al

    ; Disable interrupts
    cli

    ; Load GDT
    lgdt [gdt_ptr]

    ; Enable protected mode
    mov eax, cr0
    or eax, 1
    mov cr0, eax

    ; Far jump to 32-bit code
    jmp 0x08:pm_entry

; DAP (Disk Address Packet) for INT 13h AH=42h - placed AFTER the jump
dap:
    db 0x10                 ; Size of DAP (16 bytes)
    db 0                    ; Reserved
    dw 48                   ; Number of sectors to read
    dw 0x0000               ; Offset (destination)
    dw 0x1000               ; Segment (destination) = 0x1000:0 = 0x10000
    dq 9                    ; Starting LBA (sector 9 = kernel start)

[BITS 32]
pm_entry:
    ; Set up segment registers
    mov ax, 0x10
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov esp, 0x90000

    ; Jump to kernel at 0x10000
    jmp 0x08:0x10000

; GDT Pointer
gdt_ptr:
    dw gdt_end - gdt - 1    ; GDT limit
    dd gdt                  ; GDT base (will be 0x7F06)

; GDT at offset 0x106 (address 0x7F06)
gdt:
    ; Null descriptor
    dq 0

    ; Code segment: base=0, limit=4GB, 32-bit, ring 0
    dw 0xFFFF               ; Limit low
    dw 0x0000               ; Base low
    db 0x00                 ; Base middle
    db 0x9A                 ; Access: present, ring 0, code, exec/read
    db 0xCF                 ; Flags: 4KB granularity, 32-bit + limit high
    db 0x00                 ; Base high

    ; Data segment: base=0, limit=4GB, 32-bit, ring 0
    dw 0xFFFF               ; Limit low
    dw 0x0000               ; Base low
    db 0x00                 ; Base middle
    db 0x92                 ; Access: present, ring 0, data, read/write
    db 0xCF                 ; Flags: 4KB granularity, 32-bit + limit high
    db 0x00                 ; Base high
gdt_end:

loading_msg: db "Loading...", 13, 10, 0

    ; Pad to 4096 bytes
    times 4096 - ($ - $$) db 0
