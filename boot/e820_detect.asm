; ============================================================================
; E820_DETECT.ASM - E820 Memory Detection (Real Mode)
; ============================================================================
; Call this in real mode before switching to protected mode
; Stores memory map at E820_MAP_ADDR (0x8000)
; ============================================================================

[BITS 16]

; ============================================================================
; CONSTANTS
; ============================================================================
E820_MAP_ADDR       equ 0x8000          ; Where to store the map
E820_MAX_ENTRIES    equ 32              ; Maximum entries
E820_MAGIC          equ 0x534D4150      ; 'SMAP' signature
E820_ENTRY_SIZE     equ 24              ; Bytes per entry

; ============================================================================
; E820_DETECT - Detect physical memory map via BIOS
; ============================================================================
; Output: Memory map stored at E820_MAP_ADDR
;         First word = entry count
; Clobbers: EAX, EBX, ECX, EDX, ES, DI, BP
; ============================================================================
e820_detect:
    push ds
    pop es

    lea di, [E820_MAP_ADDR + 4]         ; Skip entry count field
    xor ebx, ebx                         ; Continuation = 0 (first call)
    xor bp, bp                           ; Entry counter

.loop:
    mov eax, 0xE820                      ; E820 function
    mov ecx, E820_ENTRY_SIZE             ; Buffer size
    mov edx, E820_MAGIC                  ; 'SMAP'
    int 0x15

    jc .done                             ; Carry = error or end
    cmp eax, E820_MAGIC                  ; Verify signature returned
    jne .done

    ; Valid entry received
    inc bp
    add di, E820_ENTRY_SIZE

    ; Check for more entries
    test ebx, ebx
    jz .done                             ; EBX=0 means last entry

    ; Check max entries limit
    cmp bp, E820_MAX_ENTRIES
    jge .done

    jmp .loop

.done:
    ; Store entry count at map start
    mov [E820_MAP_ADDR], bp
    ret
