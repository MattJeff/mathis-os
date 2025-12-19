; ════════════════════════════════════════════════════════════════════════════
; ATA64.ASM - ATA DRIVER (PIO Mode) - 64-bit version
; Read/write disk sectors for FAT32 filesystem in long mode
; ════════════════════════════════════════════════════════════════════════════

[BITS 64]

; ATA I/O Ports (Primary bus)
ATA64_DATA        equ 0x1F0
ATA64_ERROR       equ 0x1F1
ATA64_SECT_CNT    equ 0x1F2
ATA64_LBA_LO      equ 0x1F3
ATA64_LBA_MID     equ 0x1F4
ATA64_LBA_HI      equ 0x1F5
ATA64_DRIVE       equ 0x1F6
ATA64_CMD         equ 0x1F7
ATA64_STATUS      equ 0x1F7

; ATA Commands
ATA64_CMD_READ    equ 0x20
ATA64_CMD_WRITE   equ 0x30
ATA64_CMD_FLUSH   equ 0xE7

; Status bits
ATA64_SR_BSY      equ 0x80
ATA64_SR_DRDY     equ 0x40
ATA64_SR_DRQ      equ 0x08
ATA64_SR_ERR      equ 0x01

; ════════════════════════════════════════════════════════════════════════════
; ATA64_WAIT_BSY - Wait for drive to not be busy (with timeout)
; ════════════════════════════════════════════════════════════════════════════
ata64_wait_bsy:
    push rax
    push rcx
    push rdx
    mov dx, ATA64_STATUS
    mov ecx, 100000             ; Timeout counter
.wait:
    dec ecx
    jz .timeout
    in al, dx
    test al, ATA64_SR_BSY
    jnz .wait
    clc                         ; Success
    jmp .done
.timeout:
    stc                         ; Error - timeout
.done:
    pop rdx
    pop rcx
    pop rax
    ret

; ════════════════════════════════════════════════════════════════════════════
; ATA64_WAIT_DRQ - Wait for data request ready (with timeout)
; ════════════════════════════════════════════════════════════════════════════
ata64_wait_drq:
    push rax
    push rcx
    push rdx
    mov dx, ATA64_STATUS
    mov ecx, 100000             ; Timeout counter
.wait:
    dec ecx
    jz .timeout
    in al, dx
    test al, ATA64_SR_BSY
    jnz .wait
    test al, ATA64_SR_DRQ
    jz .wait
    clc                         ; Success
    jmp .done
.timeout:
    stc                         ; Error - timeout
.done:
    pop rdx
    pop rcx
    pop rax
    ret

; ════════════════════════════════════════════════════════════════════════════
; ATA_READ_SECTOR - Read one sector (512 bytes) - 64-bit version
; Input: EAX = LBA, RDI = buffer address
; Output: CF set on error
; ════════════════════════════════════════════════════════════════════════════
ata_read_sector:
    push rax
    push rbx
    push rcx
    push rdx
    push rdi

    mov ebx, eax                    ; Save LBA

    ; Wait for drive ready
    call ata64_wait_bsy

    ; Select drive 0, LBA mode, with LBA bits 24-27
    mov dx, ATA64_DRIVE
    mov eax, ebx
    shr eax, 24                     ; Get LBA bits 24-31
    and al, 0x0F                    ; Keep only bits 24-27
    or al, 0xE0                     ; LBA mode + master drive
    out dx, al

    ; Sector count = 1
    mov dx, ATA64_SECT_CNT
    mov al, 1
    out dx, al

    ; LBA low byte
    mov dx, ATA64_LBA_LO
    mov al, bl
    out dx, al

    ; LBA mid byte
    mov dx, ATA64_LBA_MID
    mov eax, ebx
    shr eax, 8
    out dx, al

    ; LBA high byte
    mov dx, ATA64_LBA_HI
    mov eax, ebx
    shr eax, 16
    out dx, al

    ; Send read command
    mov dx, ATA64_CMD
    mov al, ATA64_CMD_READ
    out dx, al

    ; Wait for data ready
    call ata64_wait_drq

    ; Check for error
    mov dx, ATA64_STATUS
    in al, dx
    test al, ATA64_SR_ERR
    jnz .rs_error

    ; Read 256 words (512 bytes) - RDI is used by rep insw in 64-bit mode
    mov dx, ATA64_DATA
    mov ecx, 256
    rep insw

    clc                             ; Clear carry (success)
    jmp .rs_done

.rs_error:
    stc                             ; Set carry (error)

.rs_done:
    pop rdi
    pop rdx
    pop rcx
    pop rbx
    pop rax
    ret

; ════════════════════════════════════════════════════════════════════════════
; ATA_WRITE_SECTOR - Write one sector (512 bytes) - 64-bit version
; Input: EAX = LBA, RSI = buffer address
; Output: CF set on error
; ════════════════════════════════════════════════════════════════════════════
ata_write_sector:
    push rax
    push rbx
    push rcx
    push rdx
    push rsi

    mov ebx, eax                    ; Save LBA

    ; Wait for drive ready
    call ata64_wait_bsy

    ; Select drive 0, LBA mode, with LBA bits 24-27
    mov dx, ATA64_DRIVE
    mov eax, ebx
    shr eax, 24                     ; Get LBA bits 24-31
    and al, 0x0F                    ; Keep only bits 24-27
    or al, 0xE0                     ; LBA mode + master drive
    out dx, al

    ; Sector count = 1
    mov dx, ATA64_SECT_CNT
    mov al, 1
    out dx, al

    ; LBA bytes
    mov dx, ATA64_LBA_LO
    mov al, bl
    out dx, al

    mov dx, ATA64_LBA_MID
    mov eax, ebx
    shr eax, 8
    out dx, al

    mov dx, ATA64_LBA_HI
    mov eax, ebx
    shr eax, 16
    out dx, al

    ; Send write command
    mov dx, ATA64_CMD
    mov al, ATA64_CMD_WRITE
    out dx, al

    ; Wait for DRQ
    call ata64_wait_drq

    ; Write 256 words (512 bytes) - RSI is used by rep outsw in 64-bit mode
    mov dx, ATA64_DATA
    mov ecx, 256
    rep outsw

    ; Flush cache
    mov dx, ATA64_CMD
    mov al, ATA64_CMD_FLUSH
    out dx, al
    call ata64_wait_bsy

    ; Check for error
    mov dx, ATA64_STATUS
    in al, dx
    test al, ATA64_SR_ERR
    jnz .ws_error

    clc
    jmp .ws_done

.ws_error:
    stc

.ws_done:
    pop rsi
    pop rdx
    pop rcx
    pop rbx
    pop rax
    ret

; ════════════════════════════════════════════════════════════════════════════
; ATA_READ_SECTORS - Read multiple sectors - 64-bit version
; Input: EAX = start LBA, ECX = count, RDI = buffer
; ════════════════════════════════════════════════════════════════════════════
ata_read_sectors:
    push rax
    push rcx
    push rdi

.rss_loop:
    test ecx, ecx
    jz .rss_done
    call ata_read_sector
    jc .rss_done                    ; Stop on error
    inc eax                         ; Next LBA
    add rdi, 512                    ; Next buffer position
    dec ecx
    jmp .rss_loop

.rss_done:
    pop rdi
    pop rcx
    pop rax
    ret

; ════════════════════════════════════════════════════════════════════════════
; ATA_WRITE_SECTORS - Write multiple sectors - 64-bit version
; Input: EAX = start LBA, ECX = count, RSI = buffer
; ════════════════════════════════════════════════════════════════════════════
ata_write_sectors:
    push rax
    push rcx
    push rsi

.wss_loop:
    test ecx, ecx
    jz .wss_done
    call ata_write_sector
    jc .wss_done
    inc eax
    add rsi, 512
    dec ecx
    jmp .wss_loop

.wss_done:
    pop rsi
    pop rcx
    pop rax
    ret
