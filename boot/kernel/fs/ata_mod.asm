; ============================================================================
; ATA_MOD.ASM - ATA PIO Disk Driver
; ============================================================================
; Sector-level read/write for primary ATA disk
; Uses PIO mode (no DMA) for simplicity
; ============================================================================

[BITS 64]
[DEFAULT REL]

; ============================================================================
; CONSTANTS
; ============================================================================
ATA_PRIMARY_DATA        equ 0x1F0
ATA_PRIMARY_ERROR       equ 0x1F1
ATA_PRIMARY_SECCOUNT    equ 0x1F2
ATA_PRIMARY_LBA_LO      equ 0x1F3
ATA_PRIMARY_LBA_MID     equ 0x1F4
ATA_PRIMARY_LBA_HI      equ 0x1F5
ATA_PRIMARY_DRIVE       equ 0x1F6
ATA_PRIMARY_STATUS      equ 0x1F7
ATA_PRIMARY_COMMAND     equ 0x1F7

ATA_CMD_READ_PIO        equ 0x20
ATA_CMD_WRITE_PIO       equ 0x30
ATA_CMD_IDENTIFY        equ 0xEC

ATA_STATUS_BSY          equ 0x80
ATA_STATUS_DRQ          equ 0x08
ATA_STATUS_ERR          equ 0x01

SECTOR_SIZE             equ 512

; ============================================================================
; EXPORTS
; ============================================================================
global ata_read_sector
global ata_write_sector
global ata_wait_ready

; ============================================================================
; CODE
; ============================================================================
section .text

; ----------------------------------------------------------------------------
; ata_wait_ready - Wait for drive to be ready
; Output: AL = status, CF set on error
; ----------------------------------------------------------------------------
ata_wait_ready:
    push rcx
    mov ecx, 100000

.wait:
    in al, ATA_PRIMARY_STATUS
    test al, ATA_STATUS_BSY
    jz .not_busy
    dec ecx
    jnz .wait
    stc
    jmp .done

.not_busy:
    test al, ATA_STATUS_ERR
    jz .ok
    stc
    jmp .done

.ok:
    clc

.done:
    pop rcx
    ret

; ----------------------------------------------------------------------------
; ata_read_sector - Read single sector
; Input:  RDI = LBA (sector number)
;         RSI = buffer address
; Output: CF clear on success, set on error
; ----------------------------------------------------------------------------
ata_read_sector:
    push rax
    push rcx
    push rdx

    ; Wait for drive ready
    call ata_wait_ready
    jc .error

    ; Select drive + LBA mode + high LBA bits
    mov eax, edi
    shr eax, 24
    and al, 0x0F
    or al, 0xE0             ; LBA mode, drive 0
    mov dx, ATA_PRIMARY_DRIVE
    out dx, al

    ; Sector count = 1
    mov dx, ATA_PRIMARY_SECCOUNT
    mov al, 1
    out dx, al

    ; LBA low byte
    mov eax, edi
    mov dx, ATA_PRIMARY_LBA_LO
    out dx, al

    ; LBA mid byte
    shr eax, 8
    mov dx, ATA_PRIMARY_LBA_MID
    out dx, al

    ; LBA high byte
    shr eax, 8
    mov dx, ATA_PRIMARY_LBA_HI
    out dx, al

    ; Send read command
    mov dx, ATA_PRIMARY_COMMAND
    mov al, ATA_CMD_READ_PIO
    out dx, al

    ; Wait for data ready
    call ata_wait_ready
    jc .error

    ; Check DRQ
    in al, ATA_PRIMARY_STATUS
    test al, ATA_STATUS_DRQ
    jz .error

    ; Read 256 words (512 bytes)
    mov rdi, rsi
    mov dx, ATA_PRIMARY_DATA
    mov ecx, SECTOR_SIZE / 2
    rep insw

    clc
    jmp .done

.error:
    stc

.done:
    pop rdx
    pop rcx
    pop rax
    ret

; ----------------------------------------------------------------------------
; ata_write_sector - Write single sector
; Input:  RDI = LBA
;         RSI = buffer address
; Output: CF clear on success
; ----------------------------------------------------------------------------
ata_write_sector:
    push rax
    push rcx
    push rdx

    call ata_wait_ready
    jc .error

    mov eax, edi
    shr eax, 24
    and al, 0x0F
    or al, 0xE0
    mov dx, ATA_PRIMARY_DRIVE
    out dx, al

    mov dx, ATA_PRIMARY_SECCOUNT
    mov al, 1
    out dx, al

    mov eax, edi
    mov dx, ATA_PRIMARY_LBA_LO
    out dx, al

    shr eax, 8
    mov dx, ATA_PRIMARY_LBA_MID
    out dx, al

    shr eax, 8
    mov dx, ATA_PRIMARY_LBA_HI
    out dx, al

    mov dx, ATA_PRIMARY_COMMAND
    mov al, ATA_CMD_WRITE_PIO
    out dx, al

    call ata_wait_ready
    jc .error

    mov rsi, rsi            ; Source buffer
    mov dx, ATA_PRIMARY_DATA
    mov ecx, SECTOR_SIZE / 2
    rep outsw

    clc
    jmp .done

.error:
    stc

.done:
    pop rdx
    pop rcx
    pop rax
    ret

; ============================================================================
; DATA
; ============================================================================
section .data

section .bss
