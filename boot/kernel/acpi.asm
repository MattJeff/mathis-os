; ════════════════════════════════════════════════════════════════════════════
; ACPI.ASM - Advanced Configuration and Power Interface
; Provides system shutdown, reboot, and power management
; ════════════════════════════════════════════════════════════════════════════
; ACPI Tables:
;   RSDP - Root System Description Pointer (found in BIOS area)
;   RSDT - Root System Description Table (32-bit pointers)
;   XSDT - Extended System Description Table (64-bit pointers)
;   FADT - Fixed ACPI Description Table (PM control registers)
;   DSDT - Differentiated System Description Table (AML code)
; ════════════════════════════════════════════════════════════════════════════

; ACPI signature constants
RSDP_SIGNATURE      equ 0x2052545020445352  ; "RSD PTR " (little-endian)
RSDT_SIGNATURE      equ 0x54445352          ; "RSDT"
XSDT_SIGNATURE      equ 0x54445358          ; "XSDT"
FADT_SIGNATURE      equ 0x50434146          ; "FACP"

; ACPI shutdown sleep state (S5 = soft off)
ACPI_SLP_TYPa       equ 0                   ; SLP_TYP value (from _S5 in DSDT)
ACPI_SLP_EN         equ (1 << 13)           ; Sleep enable bit

; PM1a/PM1b control register bits
PM1_SCI_EN          equ (1 << 0)
PM1_BM_RLD          equ (1 << 1)
PM1_GBL_RLS         equ (1 << 2)
PM1_SLP_TYP_SHIFT   equ 10
PM1_SLP_EN          equ (1 << 13)

; FADT offsets
FADT_DSDT           equ 40      ; DSDT address (32-bit)
FADT_SMI_CMD        equ 48      ; SMI Command Port
FADT_ACPI_ENABLE    equ 52      ; ACPI Enable value
FADT_ACPI_DISABLE   equ 53      ; ACPI Disable value
FADT_PM1a_CNT_BLK   equ 64      ; PM1a Control Block address
FADT_PM1b_CNT_BLK   equ 68      ; PM1b Control Block address
FADT_PM1_CNT_LEN    equ 89      ; PM1 Control register length
FADT_RESET_REG      equ 116     ; Reset register (GAS)
FADT_RESET_VALUE    equ 128     ; Reset value
FADT_X_DSDT         equ 140     ; Extended DSDT address (64-bit)
FADT_X_PM1a_CNT_BLK equ 172     ; Extended PM1a Control Block (GAS)
FADT_X_PM1b_CNT_BLK equ 184     ; Extended PM1b Control Block (GAS)

; Generic Address Structure (GAS) - 12 bytes
GAS_ADDR_SPACE      equ 0       ; Address space ID
GAS_BIT_WIDTH       equ 1       ; Register bit width
GAS_BIT_OFFSET      equ 2       ; Register bit offset
GAS_ACCESS_SIZE     equ 3       ; Access size
GAS_ADDRESS         equ 4       ; 64-bit address

; Address space IDs
GAS_SYSTEM_MEMORY   equ 0
GAS_SYSTEM_IO       equ 1

; ════════════════════════════════════════════════════════════════════════════
; ACPI_INIT - Initialize ACPI subsystem
; Output: CF set if ACPI not available
; ════════════════════════════════════════════════════════════════════════════
acpi_init:
    push rax
    push rbx
    push rcx
    push rdx
    push rdi
    push rsi

    ; Search for RSDP in EBDA (Extended BIOS Data Area)
    ; EBDA segment is at 0x40E in BDA
    movzx eax, word [0x40E]
    shl eax, 4              ; Convert segment to linear address
    mov rdi, rax
    mov ecx, 1024           ; Search first 1KB
    call acpi_search_rsdp
    test rax, rax
    jnz .found_rsdp

    ; Search in BIOS ROM area (0xE0000 - 0xFFFFF)
    mov rdi, 0xE0000
    mov ecx, 0x20000
    call acpi_search_rsdp
    test rax, rax
    jz .acpi_not_found

.found_rsdp:
    mov [acpi_rsdp], rax

    ; Validate RSDP checksum
    mov rsi, rax
    call acpi_verify_rsdp
    test eax, eax
    jnz .acpi_not_found

    ; Get ACPI revision
    mov rsi, [acpi_rsdp]
    movzx eax, byte [rsi + 15]  ; Revision at offset 15
    mov [acpi_revision], al

    ; Get RSDT/XSDT address
    cmp al, 2
    jge .use_xsdt

    ; ACPI 1.0 - use RSDT (32-bit address at offset 16)
    mov eax, [rsi + 16]
    mov [acpi_rsdt], rax
    mov byte [acpi_use_xsdt], 0
    jmp .parse_sdt

.use_xsdt:
    ; ACPI 2.0+ - use XSDT (64-bit address at offset 24)
    mov rax, [rsi + 24]
    mov [acpi_xsdt], rax
    mov byte [acpi_use_xsdt], 1

.parse_sdt:
    ; Find FADT in RSDT/XSDT
    call acpi_find_fadt
    test rax, rax
    jz .acpi_not_found
    mov [acpi_fadt], rax

    ; Parse FADT for PM registers
    call acpi_parse_fadt

    ; Parse DSDT for S5 sleep type values
    call acpi_parse_s5

    mov byte [acpi_available], 1
    clc
    jmp .acpi_init_done

.acpi_not_found:
    mov byte [acpi_available], 0
    stc

.acpi_init_done:
    pop rsi
    pop rdi
    pop rdx
    pop rcx
    pop rbx
    pop rax
    ret

; ════════════════════════════════════════════════════════════════════════════
; ACPI_SEARCH_RSDP - Search for RSDP signature
; Input: RDI = start address, ECX = length (must be multiple of 16)
; Output: RAX = RSDP address or 0
; ════════════════════════════════════════════════════════════════════════════
acpi_search_rsdp:
    push rcx
    push rdi

    shr ecx, 4              ; Divide by 16 (RSDP is 16-byte aligned)

.search_loop:
    ; Check for "RSD PTR " signature
    mov rax, [rdi]
    cmp rax, RSDP_SIGNATURE
    je .found

    add rdi, 16
    dec ecx
    jnz .search_loop

    xor eax, eax
    jmp .search_done

.found:
    mov rax, rdi

.search_done:
    pop rdi
    pop rcx
    ret

; ════════════════════════════════════════════════════════════════════════════
; ACPI_VERIFY_RSDP - Verify RSDP checksum
; Input: RSI = RSDP address
; Output: EAX = 0 if valid, non-zero if invalid
; ════════════════════════════════════════════════════════════════════════════
acpi_verify_rsdp:
    push rbx
    push rcx

    ; Checksum first 20 bytes (RSDP 1.0 structure)
    xor eax, eax
    xor ebx, ebx
    mov ecx, 20

.sum_loop:
    movzx ebx, byte [rsi]
    add eax, ebx
    inc rsi
    dec ecx
    jnz .sum_loop

    and eax, 0xFF           ; Checksum should be 0

    pop rcx
    pop rbx
    ret

; ════════════════════════════════════════════════════════════════════════════
; ACPI_FIND_FADT - Find FADT in RSDT/XSDT
; Output: RAX = FADT address or 0
; ════════════════════════════════════════════════════════════════════════════
acpi_find_fadt:
    push rbx
    push rcx
    push rdx
    push rsi

    ; Get SDT (RSDT or XSDT)
    cmp byte [acpi_use_xsdt], 1
    je .use_xsdt_search

    ; RSDT - 32-bit pointers
    mov rsi, [acpi_rsdt]
    mov eax, [rsi + 4]      ; Length at offset 4
    sub eax, 36             ; Subtract header size
    shr eax, 2              ; Divide by 4 (32-bit pointers)
    mov ecx, eax            ; Entry count
    add rsi, 36             ; Skip header
    mov bl, 4               ; Pointer size
    jmp .search_fadt

.use_xsdt_search:
    ; XSDT - 64-bit pointers
    mov rsi, [acpi_xsdt]
    mov eax, [rsi + 4]
    sub eax, 36
    shr eax, 3              ; Divide by 8 (64-bit pointers)
    mov ecx, eax
    add rsi, 36
    mov bl, 8

.search_fadt:
    test ecx, ecx
    jz .fadt_not_found

.fadt_loop:
    ; Read table address
    cmp bl, 8
    je .read_64
    movzx rax, dword [rsi]
    jmp .check_sig
.read_64:
    mov rax, [rsi]

.check_sig:
    ; Check signature
    cmp dword [rax], FADT_SIGNATURE
    je .found_fadt

    ; Next entry
    movzx edx, bl
    add rsi, rdx
    dec ecx
    jnz .fadt_loop

.fadt_not_found:
    xor eax, eax
    jmp .find_done

.found_fadt:
    ; RAX already contains FADT address

.find_done:
    pop rsi
    pop rdx
    pop rcx
    pop rbx
    ret

; ════════════════════════════════════════════════════════════════════════════
; ACPI_PARSE_FADT - Parse FADT for PM control registers
; ════════════════════════════════════════════════════════════════════════════
acpi_parse_fadt:
    push rax
    push rbx
    push rsi

    mov rsi, [acpi_fadt]

    ; Get PM1a control block
    ; Try extended address first (ACPI 2.0+)
    mov eax, [rsi + 4]      ; FADT length
    cmp eax, FADT_X_PM1a_CNT_BLK + 12
    jl .use_legacy_pm1a

    ; Check if X_PM1a_CNT_BLK is valid
    mov al, [rsi + FADT_X_PM1a_CNT_BLK + GAS_ADDR_SPACE]
    cmp al, GAS_SYSTEM_IO
    jne .use_legacy_pm1a

    mov rax, [rsi + FADT_X_PM1a_CNT_BLK + GAS_ADDRESS]
    test rax, rax
    jz .use_legacy_pm1a
    mov [acpi_pm1a_cnt], ax
    jmp .get_pm1b

.use_legacy_pm1a:
    mov eax, [rsi + FADT_PM1a_CNT_BLK]
    mov [acpi_pm1a_cnt], ax

.get_pm1b:
    ; Get PM1b control block (optional)
    mov eax, [rsi + 4]
    cmp eax, FADT_X_PM1b_CNT_BLK + 12
    jl .use_legacy_pm1b

    mov al, [rsi + FADT_X_PM1b_CNT_BLK + GAS_ADDR_SPACE]
    cmp al, GAS_SYSTEM_IO
    jne .use_legacy_pm1b

    mov rax, [rsi + FADT_X_PM1b_CNT_BLK + GAS_ADDRESS]
    test rax, rax
    jz .use_legacy_pm1b
    mov [acpi_pm1b_cnt], ax
    jmp .get_reset

.use_legacy_pm1b:
    mov eax, [rsi + FADT_PM1b_CNT_BLK]
    mov [acpi_pm1b_cnt], ax

.get_reset:
    ; Get reset register if available
    mov eax, [rsi + 4]
    cmp eax, FADT_RESET_VALUE + 1
    jl .parse_done

    mov al, [rsi + FADT_RESET_REG + GAS_ADDR_SPACE]
    mov [acpi_reset_type], al
    mov rax, [rsi + FADT_RESET_REG + GAS_ADDRESS]
    mov [acpi_reset_addr], rax
    mov al, [rsi + FADT_RESET_VALUE]
    mov [acpi_reset_value], al

.parse_done:
    pop rsi
    pop rbx
    pop rax
    ret

; ════════════════════════════════════════════════════════════════════════════
; ACPI_PARSE_S5 - Parse DSDT for _S5 sleep type values
; Sets default values if _S5 not found (QEMU compatible)
; ════════════════════════════════════════════════════════════════════════════
acpi_parse_s5:
    push rax
    push rbx
    push rcx
    push rdi
    push rsi

    ; Get DSDT address from FADT
    mov rsi, [acpi_fadt]

    ; Try X_DSDT first
    mov eax, [rsi + 4]
    cmp eax, FADT_X_DSDT + 8
    jl .use_legacy_dsdt

    mov rax, [rsi + FADT_X_DSDT]
    test rax, rax
    jnz .have_dsdt

.use_legacy_dsdt:
    mov eax, [rsi + FADT_DSDT]
    movzx rax, eax

.have_dsdt:
    test rax, rax
    jz .use_default_s5

    mov [acpi_dsdt], rax

    ; Search DSDT for "_S5_" (0x5F35535F in reverse)
    mov rdi, rax
    add rdi, 36             ; Skip DSDT header
    mov eax, [rax + 4]      ; DSDT length
    sub eax, 36
    mov ecx, eax

.search_s5:
    cmp ecx, 4
    jl .use_default_s5

    ; Look for "_S5_" or "\._S5"
    cmp dword [rdi], 0x5F35535F     ; "_S5_"
    je .found_s5

    inc rdi
    dec ecx
    jmp .search_s5

.found_s5:
    ; Parse _S5 package (simplified - assumes common format)
    ; Skip "_S5_" and find package contents
    add rdi, 4

    ; Skip to package data (usually: Name, Package, byte, byte)
    ; This is highly simplified - real parsing would need AML interpreter

    ; Look for package opcode (0x12)
    mov ecx, 20
.find_pkg:
    cmp byte [rdi], 0x12
    je .found_pkg
    inc rdi
    dec ecx
    jnz .find_pkg
    jmp .use_default_s5

.found_pkg:
    ; Skip package opcode and length
    inc rdi
    movzx eax, byte [rdi]
    cmp al, 0x40
    jl .single_byte_len
    ; Multi-byte length - skip extra bytes
    and eax, 0x0F
    add rdi, rax
.single_byte_len:
    inc rdi

    ; Skip element count
    inc rdi

    ; Read SLP_TYPa value (first integer)
    cmp byte [rdi], 0x0A        ; BytePrefix
    jne .check_zero
    inc rdi
    movzx eax, byte [rdi]
    jmp .store_slp_typ
.check_zero:
    cmp byte [rdi], 0x00
    jne .use_default_s5
    xor eax, eax

.store_slp_typ:
    mov [acpi_slp_typa], al

    ; Read SLP_TYPb (second integer, usually same)
    inc rdi
    cmp byte [rdi], 0x0A
    jne .check_zero_b
    inc rdi
    movzx eax, byte [rdi]
    jmp .store_slp_typb
.check_zero_b:
    xor eax, eax
.store_slp_typb:
    mov [acpi_slp_typb], al
    jmp .s5_done

.use_default_s5:
    ; Use QEMU default values (SLP_TYP = 5 for S5)
    mov byte [acpi_slp_typa], 5
    mov byte [acpi_slp_typb], 5

.s5_done:
    pop rsi
    pop rdi
    pop rcx
    pop rbx
    pop rax
    ret

; ════════════════════════════════════════════════════════════════════════════
; ACPI_SHUTDOWN - Perform ACPI shutdown (enter S5 state)
; ════════════════════════════════════════════════════════════════════════════
acpi_shutdown:
    push rax
    push rdx

    cmp byte [acpi_available], 0
    je .shutdown_fallback

    ; Calculate PM1 control value
    ; SLP_TYP << 10 | SLP_EN (bit 13)
    movzx eax, byte [acpi_slp_typa]
    shl eax, PM1_SLP_TYP_SHIFT
    or eax, PM1_SLP_EN

    ; Write to PM1a control register
    mov dx, [acpi_pm1a_cnt]
    test dx, dx
    jz .try_pm1b
    out dx, ax

.try_pm1b:
    ; Write to PM1b if present
    mov dx, [acpi_pm1b_cnt]
    test dx, dx
    jz .shutdown_wait

    movzx eax, byte [acpi_slp_typb]
    shl eax, PM1_SLP_TYP_SHIFT
    or eax, PM1_SLP_EN
    out dx, ax

.shutdown_wait:
    ; Wait for shutdown (shouldn't return)
    hlt
    jmp .shutdown_wait

.shutdown_fallback:
    ; Try QEMU-specific shutdown via I/O port 0x604
    mov dx, 0x604
    mov ax, 0x2000
    out dx, ax

    ; Try Bochs/older QEMU method
    mov dx, 0xB004
    mov ax, 0x2000
    out dx, ax

    ; If still running, halt
    cli
    hlt
    jmp .shutdown_fallback

    pop rdx
    pop rax
    ret

; ════════════════════════════════════════════════════════════════════════════
; ACPI_REBOOT - Perform ACPI reboot
; ════════════════════════════════════════════════════════════════════════════
acpi_reboot:
    push rax
    push rdx

    cmp byte [acpi_available], 0
    je .reboot_fallback

    ; Try ACPI reset register
    cmp qword [acpi_reset_addr], 0
    je .reboot_fallback

    mov al, [acpi_reset_type]
    cmp al, GAS_SYSTEM_IO
    je .reset_io
    cmp al, GAS_SYSTEM_MEMORY
    je .reset_mem
    jmp .reboot_fallback

.reset_io:
    mov dx, word [acpi_reset_addr]
    mov al, [acpi_reset_value]
    out dx, al
    jmp .reboot_wait

.reset_mem:
    mov rax, [acpi_reset_addr]
    mov bl, [acpi_reset_value]
    mov [rax], bl

.reboot_wait:
    ; Wait a bit and then try fallback if still running
    mov ecx, 1000000
.wait_loop:
    pause
    dec ecx
    jnz .wait_loop

.reboot_fallback:
    ; Keyboard controller reset (classic method)
    ; Wait for keyboard controller ready
    mov ecx, 100000
.wait_kbd:
    in al, 0x64
    test al, 0x02
    jz .kbd_ready
    dec ecx
    jnz .wait_kbd

.kbd_ready:
    ; Send reset command (0xFE)
    mov al, 0xFE
    out 0x64, al

    ; If that didn't work, triple fault
    lidt [null_idt_ptr]
    int 0

    ; Should never reach here
    cli
    hlt
    jmp .reboot_fallback

    pop rdx
    pop rax
    ret

; ════════════════════════════════════════════════════════════════════════════
; ACPI_STATUS - Check if ACPI is available
; Output: AL = 1 if available, 0 otherwise
; ════════════════════════════════════════════════════════════════════════════
acpi_status:
    mov al, [acpi_available]
    ret

; ════════════════════════════════════════════════════════════════════════════
; ACPI DATA
; ════════════════════════════════════════════════════════════════════════════
align 8

acpi_available:     db 0
acpi_revision:      db 0
acpi_use_xsdt:      db 0
acpi_reset_type:    db 0
acpi_slp_typa:      db 5        ; Default for QEMU
acpi_slp_typb:      db 5
                    dw 0        ; padding

acpi_rsdp:          dq 0
acpi_rsdt:          dq 0
acpi_xsdt:          dq 0
acpi_fadt:          dq 0
acpi_dsdt:          dq 0

acpi_pm1a_cnt:      dw 0
acpi_pm1b_cnt:      dw 0
                    dd 0        ; padding

acpi_reset_addr:    dq 0
acpi_reset_value:   db 0
                    times 7 db 0

; Null IDT for triple fault reboot
null_idt_ptr:
    dw 0
    dq 0
