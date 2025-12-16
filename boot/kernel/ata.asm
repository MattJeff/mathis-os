; ════════════════════════════════════════════════════════════════════════════
; MATHIS KERNEL - ATA DRIVER (PIO Mode)
; Read/write disk sectors for filesystem persistence
; ════════════════════════════════════════════════════════════════════════════
; Disk layout:
;   LBA 0:       Boot sector
;   LBA 1-8:     Stage2 (4KB)
;   LBA 9-520:   Kernel (256KB)
;   LBA 521+:    Filesystem data
; ════════════════════════════════════════════════════════════════════════════

; ATA I/O Ports (Primary bus)
ATA_DATA        equ 0x1F0
ATA_ERROR       equ 0x1F1
ATA_SECT_CNT    equ 0x1F2
ATA_LBA_LO      equ 0x1F3
ATA_LBA_MID     equ 0x1F4
ATA_LBA_HI      equ 0x1F5
ATA_DRIVE       equ 0x1F6
ATA_CMD         equ 0x1F7
ATA_STATUS      equ 0x1F7

; ATA Commands
ATA_CMD_READ    equ 0x20
ATA_CMD_WRITE   equ 0x30
ATA_CMD_FLUSH   equ 0xE7

; Status bits
ATA_SR_BSY      equ 0x80
ATA_SR_DRDY     equ 0x40
ATA_SR_DRQ      equ 0x08
ATA_SR_ERR      equ 0x01

; Filesystem starts at LBA 1033 (after 512KB kernel)
FS_START_LBA    equ 1033

; ════════════════════════════════════════════════════════════════════════════
; ATA_WAIT_BSY - Wait for drive to not be busy (with timeout)
; ════════════════════════════════════════════════════════════════════════════
ata_wait_bsy:
    push eax
    push ecx
    push edx
    mov dx, ATA_STATUS
    mov ecx, 100000             ; Timeout counter
.wait:
    dec ecx
    jz .timeout
    in al, dx
    test al, ATA_SR_BSY
    jnz .wait
    clc                         ; Success
    jmp .done
.timeout:
    stc                         ; Error - timeout
.done:
    pop edx
    pop ecx
    pop eax
    ret

; ════════════════════════════════════════════════════════════════════════════
; ATA_WAIT_DRQ - Wait for data request ready (with timeout)
; ════════════════════════════════════════════════════════════════════════════
ata_wait_drq:
    push eax
    push ecx
    push edx
    mov dx, ATA_STATUS
    mov ecx, 100000             ; Timeout counter
.wait:
    dec ecx
    jz .timeout
    in al, dx
    test al, ATA_SR_BSY
    jnz .wait
    test al, ATA_SR_DRQ
    jz .wait
    clc                         ; Success
    jmp .done
.timeout:
    stc                         ; Error - timeout
.done:
    pop edx
    pop ecx
    pop eax
    ret

; ════════════════════════════════════════════════════════════════════════════
; ATA_READ_SECTOR - Read one sector (512 bytes)
; Input: EAX = LBA, EDI = buffer address
; Output: CF set on error
; ════════════════════════════════════════════════════════════════════════════
ata_read_sector:
    push eax
    push ebx
    push ecx
    push edx
    push edi

    mov ebx, eax                    ; Save LBA

    ; Wait for drive ready
    call ata_wait_bsy

    ; Select drive 0, LBA mode
    mov dx, ATA_DRIVE
    mov al, 0xE0                    ; Drive 0, LBA mode
    or al, bh                       ; LBA bits 24-27 (0 for now)
    and al, 0xEF                    ; Clear bit 4 (drive 0)
    out dx, al

    ; Sector count = 1
    mov dx, ATA_SECT_CNT
    mov al, 1
    out dx, al

    ; LBA low byte
    mov dx, ATA_LBA_LO
    mov al, bl
    out dx, al

    ; LBA mid byte
    mov dx, ATA_LBA_MID
    mov eax, ebx
    shr eax, 8
    out dx, al

    ; LBA high byte
    mov dx, ATA_LBA_HI
    mov eax, ebx
    shr eax, 16
    out dx, al

    ; Send read command
    mov dx, ATA_CMD
    mov al, ATA_CMD_READ
    out dx, al

    ; Wait for data ready
    call ata_wait_drq

    ; Check for error
    mov dx, ATA_STATUS
    in al, dx
    test al, ATA_SR_ERR
    jnz .error

    ; Read 256 words (512 bytes)
    mov dx, ATA_DATA
    mov ecx, 256
    rep insw

    clc                             ; Clear carry (success)
    jmp .done

.error:
    stc                             ; Set carry (error)

.done:
    pop edi
    pop edx
    pop ecx
    pop ebx
    pop eax
    ret

; ════════════════════════════════════════════════════════════════════════════
; ATA_WRITE_SECTOR - Write one sector (512 bytes)
; Input: EAX = LBA, ESI = buffer address
; Output: CF set on error
; ════════════════════════════════════════════════════════════════════════════
ata_write_sector:
    push eax
    push ebx
    push ecx
    push edx
    push esi

    mov ebx, eax                    ; Save LBA

    ; Wait for drive ready
    call ata_wait_bsy

    ; Select drive 0, LBA mode
    mov dx, ATA_DRIVE
    mov al, 0xE0
    or al, bh
    and al, 0xEF
    out dx, al

    ; Sector count = 1
    mov dx, ATA_SECT_CNT
    mov al, 1
    out dx, al

    ; LBA bytes
    mov dx, ATA_LBA_LO
    mov al, bl
    out dx, al

    mov dx, ATA_LBA_MID
    mov eax, ebx
    shr eax, 8
    out dx, al

    mov dx, ATA_LBA_HI
    mov eax, ebx
    shr eax, 16
    out dx, al

    ; Send write command
    mov dx, ATA_CMD
    mov al, ATA_CMD_WRITE
    out dx, al

    ; Wait for DRQ
    call ata_wait_drq

    ; Write 256 words (512 bytes)
    mov dx, ATA_DATA
    mov ecx, 256
    rep outsw

    ; Flush cache
    mov dx, ATA_CMD
    mov al, ATA_CMD_FLUSH
    out dx, al
    call ata_wait_bsy

    ; Check for error
    mov dx, ATA_STATUS
    in al, dx
    test al, ATA_SR_ERR
    jnz .error

    clc
    jmp .done

.error:
    stc

.done:
    pop esi
    pop edx
    pop ecx
    pop ebx
    pop eax
    ret

; ════════════════════════════════════════════════════════════════════════════
; ATA_READ_SECTORS - Read multiple sectors
; Input: EAX = start LBA, ECX = count, EDI = buffer
; ════════════════════════════════════════════════════════════════════════════
ata_read_sectors:
    push eax
    push ecx
    push edi

.read_loop:
    test ecx, ecx
    jz .done
    call ata_read_sector
    jc .done                        ; Stop on error
    inc eax                         ; Next LBA
    add edi, 512                    ; Next buffer position
    dec ecx
    jmp .read_loop

.done:
    pop edi
    pop ecx
    pop eax
    ret

; ════════════════════════════════════════════════════════════════════════════
; ATA_WRITE_SECTORS - Write multiple sectors
; Input: EAX = start LBA, ECX = count, ESI = buffer
; ════════════════════════════════════════════════════════════════════════════
ata_write_sectors:
    push eax
    push ecx
    push esi

.write_loop:
    test ecx, ecx
    jz .done
    call ata_write_sector
    jc .done
    inc eax
    add esi, 512
    dec ecx
    jmp .write_loop

.done:
    pop esi
    pop ecx
    pop eax
    ret

; ════════════════════════════════════════════════════════════════════════════
; FS_SAVE - Save RAM filesystem to disk
; Saves 64KB (128 sectors) starting at LBA 521
; ════════════════════════════════════════════════════════════════════════════
fs_save_to_disk:
    push eax
    push ecx
    push esi

    mov eax, FS_START_LBA           ; Start at LBA 521
    mov ecx, 128                    ; 128 sectors = 64KB
    mov esi, FS_BASE                ; RAM filesystem at 0x30000
    call ata_write_sectors

    pop esi
    pop ecx
    pop eax
    ret

; ════════════════════════════════════════════════════════════════════════════
; FS_LOAD - Load filesystem from disk to RAM
; Loads 64KB (128 sectors) from LBA 521
; ════════════════════════════════════════════════════════════════════════════
fs_load_from_disk:
    push eax
    push ecx
    push edi

    mov eax, FS_START_LBA           ; Start at LBA 521
    mov ecx, 128                    ; 128 sectors = 64KB
    mov edi, FS_BASE                ; RAM filesystem at 0x30000
    call ata_read_sectors

    ; Check if valid FS was loaded (magic = "MTHSFS")
    cmp dword [FS_BASE], 'MTHS'
    jne .no_fs
    cmp word [FS_BASE + 4], 'FS'
    jne .no_fs

    ; Valid filesystem loaded
    clc
    jmp .done

.no_fs:
    ; No valid FS, initialize empty one
    call fs_initialize
    stc

.done:
    pop edi
    pop ecx
    pop eax
    ret
