; ============================================================================
; E820.ASM - Physical Memory Map Detection
; ============================================================================
; Detects available RAM via BIOS INT 0x15, EAX=0xE820
; Must be called from REAL MODE (16-bit) before protected mode switch
; ============================================================================

[BITS 64]

section .text

; ============================================================================
; CONSTANTS
; ============================================================================
E820_MAP_ADDR       equ 0x8000          ; Memory map storage location
E820_MAX_ENTRIES    equ 32              ; Maximum entries supported
E820_ENTRY_SIZE     equ 24              ; Bytes per entry

; E820 memory types
E820_TYPE_USABLE    equ 1               ; Available RAM
E820_TYPE_RESERVED  equ 2               ; Reserved by system
E820_TYPE_ACPI_RECL equ 3               ; ACPI reclaimable
E820_TYPE_ACPI_NVS  equ 4               ; ACPI non-volatile
E820_TYPE_BAD       equ 5               ; Bad memory

; ============================================================================
; E820_GET_ENTRY_COUNT - Get number of E820 entries
; ============================================================================
; Output: EAX = number of entries
; ============================================================================
e820_get_entry_count:
    movzx eax, word [E820_MAP_ADDR]
    ret

; ============================================================================
; E820_GET_TOTAL_RAM - Calculate total usable RAM
; ============================================================================
; Output: RAX = total usable RAM in bytes
; ============================================================================
e820_get_total_ram:
    push rbx
    push rcx
    push rsi

    xor rax, rax
    movzx ecx, word [E820_MAP_ADDR]
    test ecx, ecx
    jz .done

    lea rsi, [E820_MAP_ADDR + 4]

.loop:
    cmp dword [rsi + 16], E820_TYPE_USABLE
    jne .next

    ; Add length (64-bit value at offset 8)
    mov rbx, [rsi + 8]
    add rax, rbx

.next:
    add rsi, E820_ENTRY_SIZE
    dec ecx
    jnz .loop

.done:
    pop rsi
    pop rcx
    pop rbx
    ret

; ============================================================================
; E820_GET_ENTRY - Get specific E820 entry
; ============================================================================
; Input:  EDI = entry index
; Output: RAX = base address, RDX = length, ECX = type (0 if invalid)
; ============================================================================
e820_get_entry:
    push rsi

    xor eax, eax
    xor edx, edx
    xor ecx, ecx

    ; Validate index
    cmp edi, [E820_MAP_ADDR]
    jge .done

    ; Calculate entry offset
    imul esi, edi, E820_ENTRY_SIZE
    add esi, E820_MAP_ADDR + 4

    ; Read entry fields
    mov rax, [rsi]                      ; base address
    mov rdx, [rsi + 8]                  ; length
    mov ecx, [rsi + 16]                 ; type

.done:
    pop rsi
    ret
