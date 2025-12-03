; ════════════════════════════════════════════════════════════════════════════
; MATHIS MEMORY MODULE - EXTERNAL AT 0x80000
; Standalone module loaded separately to avoid kernel disruption
; ════════════════════════════════════════════════════════════════════════════

[BITS 32]
[ORG 0x80000]    ; Fixed high address - won't interfere with kernel

; ════════════════════════════════════════════════════════════════════════════
; JUMP TABLE (Fixed offsets for kernel to call)
; Use near jumps (5 bytes each) for consistent offsets
; ════════════════════════════════════════════════════════════════════════════
memory_module_entry:
    jmp near init_paging        ; +0x00: Initialize paging
    jmp near enable_long_mode   ; +0x05: Enable 64-bit mode  
    jmp near alloc_page        ; +0x0A: Allocate page
    jmp near parse_e820_map    ; +0x0F: Parse memory map
    jmp near get_memory_info   ; +0x14: Return memory info

; ════════════════════════════════════════════════════════════════════════════
; MEMORY LAYOUT CONSTANTS
; ════════════════════════════════════════════════════════════════════════════
PAGE_SIZE           equ 4096
HUGE_PAGE_SIZE      equ 2097152         ; 2MB

; Page table addresses (in our free memory zone)
PML4_ADDR           equ 0x40000         ; Page Map Level 4
PDPT_ADDR           equ 0x41000         ; Page Directory Pointer Table
PD_ADDR             equ 0x42000         ; Page Directory
PT_ADDR             equ 0x43000         ; Page Table (if needed)

; Page flags
PAGE_PRESENT        equ 0x001           ; P bit
PAGE_WRITE          equ 0x002           ; R/W bit
PAGE_USER           equ 0x004           ; U/S bit (user accessible)
PAGE_HUGE           equ 0x080           ; PS bit (2MB page)
PAGE_NX             equ 0x8000000000000000  ; No-Execute (64-bit only)

; Kernel virtual base (Higher-Half)
KERNEL_VIRT_BASE    equ 0xFFFF800000000000

; ════════════════════════════════════════════════════════════════════════════
; E820 MEMORY MAP DETECTION
; Call from real mode (stage2.asm) before entering protected mode
; ════════════════════════════════════════════════════════════════════════════
; This must be called in REAL MODE before switching to protected mode!
; Store results at E820_MAP_ADDR

E820_MAP_ADDR       equ 0x8000          ; Where to store memory map
E820_MAP_COUNT      equ 0x8004          ; Entry count

; E820 entry structure (20 or 24 bytes):
;   uint64_t base_addr
;   uint64_t length  
;   uint32_t type (1=usable, 2=reserved, 3=ACPI, 4=NVS, 5=bad)
;   uint32_t attributes (optional)

; ════════════════════════════════════════════════════════════════════════════
; DETECT MEMORY (call from real mode in stage2.asm)
; ════════════════════════════════════════════════════════════════════════════
; [BITS 16]
; detect_memory:
;     xor ebx, ebx                    ; Continuation value
;     mov di, E820_MAP_ADDR + 8       ; Start storing after header
;     xor bp, bp                      ; Entry counter
; .e820_loop:
;     mov eax, 0xE820
;     mov ecx, 24                     ; Ask for 24 bytes
;     mov edx, 0x534D4150             ; 'SMAP' signature
;     int 0x15
;     jc .e820_done                   ; Carry = error or done
;     cmp eax, 0x534D4150             ; Verify signature returned
;     jne .e820_done
;     inc bp                          ; Count entry
;     add di, 24                      ; Next entry
;     test ebx, ebx                   ; EBX=0 means done
;     jnz .e820_loop
; .e820_done:
;     mov [E820_MAP_COUNT], bp        ; Store count
;     ret

; ════════════════════════════════════════════════════════════════════════════
; INITIALIZE PAGING (32-bit, prepares for 64-bit)
; ════════════════════════════════════════════════════════════════════════════
[BITS 32]

init_paging:
    push eax
    push ebx
    push ecx
    push edi
    
    ; ═══════════════════════════════════════════════════════════════════════
    ; STEP 1: Clear page tables
    ; ═══════════════════════════════════════════════════════════════════════
    mov edi, PML4_ADDR
    xor eax, eax
    mov ecx, 4096                   ; Clear 4 pages (16KB)
    rep stosd
    
    ; ═══════════════════════════════════════════════════════════════════════
    ; STEP 2: Set up PML4 (Page Map Level 4)
    ; Entry 0: Identity map (low memory)
    ; Entry 256: Higher-half kernel mapping
    ; ═══════════════════════════════════════════════════════════════════════
    mov edi, PML4_ADDR
    
    ; PML4[0] -> PDPT (identity mapping for first 512GB)
    mov eax, PDPT_ADDR
    or eax, PAGE_PRESENT | PAGE_WRITE
    mov [edi], eax
    mov dword [edi + 4], 0          ; High 32 bits = 0
    
    ; PML4[256] -> PDPT (higher-half kernel at 0xFFFF800000000000)
    ; Entry 256 = offset 256 * 8 = 2048
    mov eax, PDPT_ADDR
    or eax, PAGE_PRESENT | PAGE_WRITE
    mov [edi + 256*8], eax
    mov dword [edi + 256*8 + 4], 0
    
    ; ═══════════════════════════════════════════════════════════════════════
    ; STEP 3: Set up PDPT (Page Directory Pointer Table)
    ; Using 1GB pages if supported, otherwise 2MB pages
    ; ═══════════════════════════════════════════════════════════════════════
    mov edi, PDPT_ADDR
    
    ; PDPT[0] -> PD (for first 1GB, using 2MB pages)
    mov eax, PD_ADDR
    or eax, PAGE_PRESENT | PAGE_WRITE
    mov [edi], eax
    mov dword [edi + 4], 0
    
    ; ═══════════════════════════════════════════════════════════════════════
    ; STEP 4: Set up PD with 2MB Huge Pages (identity map first 1GB)
    ; Each entry maps 2MB, 512 entries = 1GB
    ; ═══════════════════════════════════════════════════════════════════════
    mov edi, PD_ADDR
    mov eax, PAGE_PRESENT | PAGE_WRITE | PAGE_HUGE  ; 2MB page flags
    mov ecx, 512                    ; 512 entries
    
.fill_pd:
    mov [edi], eax
    mov dword [edi + 4], 0          ; High bits
    add eax, HUGE_PAGE_SIZE         ; Next 2MB
    add edi, 8                      ; Next entry
    loop .fill_pd
    
    ; ═══════════════════════════════════════════════════════════════════════
    ; STEP 5: Enable PAE (Physical Address Extension) - Required for 64-bit
    ; ═══════════════════════════════════════════════════════════════════════
    mov eax, cr4
    or eax, 1 << 5                  ; Set PAE bit (bit 5)
    mov cr4, eax
    
    ; ═══════════════════════════════════════════════════════════════════════
    ; STEP 6: Load PML4 address into CR3
    ; ═══════════════════════════════════════════════════════════════════════
    mov eax, PML4_ADDR
    mov cr3, eax
    
    ; ═══════════════════════════════════════════════════════════════════════
    ; Note: To enable 64-bit mode, we also need to:
    ; 1. Set EFER.LME (Long Mode Enable) via MSR 0xC0000080
    ; 2. Enable paging in CR0
    ; 3. Far jump to 64-bit code segment
    ; This will be done in enable_long_mode
    ; ═══════════════════════════════════════════════════════════════════════
    
    pop edi
    pop ecx
    pop ebx
    pop eax
    ret

; ════════════════════════════════════════════════════════════════════════════
; ENABLE LONG MODE (64-bit)
; Call after init_paging
; ════════════════════════════════════════════════════════════════════════════
enable_long_mode:
    ; Set EFER.LME (Long Mode Enable)
    mov ecx, 0xC0000080             ; EFER MSR
    rdmsr
    or eax, 1 << 8                  ; Set LME bit
    wrmsr
    
    ; Enable Paging (this activates Long Mode since LME is set)
    mov eax, cr0
    or eax, 1 << 31                 ; Set PG bit
    mov cr0, eax
    
    ; Far jump to 64-bit code (need 64-bit GDT segment)
    ; jmp 0x18:long_mode_entry      ; Will be implemented
    
    ret

; ════════════════════════════════════════════════════════════════════════════
; 64-BIT CODE SECTION (for future use)
; ════════════════════════════════════════════════════════════════════════════
; [BITS 64]
; long_mode_entry:
;     ; We're now in 64-bit mode!
;     ; Set up 64-bit stack and segments
;     mov ax, 0x20                  ; 64-bit data segment
;     mov ds, ax
;     mov es, ax
;     mov fs, ax
;     mov gs, ax
;     mov ss, ax
;     
;     ; Jump to kernel main
;     mov rsp, 0xFFFF800000100000   ; Stack in higher-half
;     call kernel_main_64
;     
;     ; Should never return
;     cli
;     hlt

; ════════════════════════════════════════════════════════════════════════════
; PAGE ALLOCATOR (Simple bump allocator for bootstrap)
; ════════════════════════════════════════════════════════════════════════════
ALLOC_BASE          equ 0x100000        ; Start allocating at 1MB
alloc_next:         dd ALLOC_BASE       ; Next free page

; Allocate one 4KB page, returns address in EAX
alloc_page:
    push ebx
    mov eax, [alloc_next]
    mov ebx, eax
    add ebx, PAGE_SIZE
    mov [alloc_next], ebx
    pop ebx
    ret

; Allocate N pages (ECX = count), returns start address in EAX
alloc_pages:
    push ebx
    push ecx
    mov eax, [alloc_next]
    mov ebx, ecx
    shl ebx, 12                     ; Multiply by 4096
    add ebx, eax
    mov [alloc_next], ebx
    pop ecx
    pop ebx
    ret

; ════════════════════════════════════════════════════════════════════════════
; MEMORY INFO (for debugging)
; ════════════════════════════════════════════════════════════════════════════
total_memory:       dd 0                ; Total detected RAM
usable_memory:      dd 0                ; Usable RAM

; Parse E820 map and calculate total memory
parse_e820_map:
    push eax
    push ebx
    push ecx
    push esi
    
    xor ebx, ebx                    ; Total counter
    movzx ecx, word [E820_MAP_COUNT]
    mov esi, E820_MAP_ADDR + 8      ; First entry
    
.parse_loop:
    test ecx, ecx
    jz .parse_done
    
    ; Check if type == 1 (usable)
    cmp dword [esi + 16], 1
    jne .next_entry
    
    ; Add length to total (low 32 bits only for now)
    add ebx, [esi + 8]
    
.next_entry:
    add esi, 24
    dec ecx
    jmp .parse_loop
    
.parse_done:
    mov [usable_memory], ebx
    
    pop esi
    pop ecx
    pop ebx
    pop eax
    ret

; ════════════════════════════════════════════════════════════════════════════
; GET MEMORY INFO - Returns memory stats in EAX (total) and EBX (usable)
; ════════════════════════════════════════════════════════════════════════════
get_memory_info:
    mov eax, [total_memory]
    mov ebx, [usable_memory]
    ret

; ════════════════════════════════════════════════════════════════════════════
; GDT FOR 64-BIT MODE
; ════════════════════════════════════════════════════════════════════════════
gdt64:
    ; Null descriptor
    dq 0
    
    ; 64-bit code segment (selector 0x08)
    dw 0xFFFF                       ; Limit low
    dw 0x0000                       ; Base low
    db 0x00                         ; Base middle
    db 0x9A                         ; Access: Present, Ring 0, Code
    db 0xAF                         ; Flags: Long mode, Limit high
    db 0x00                         ; Base high
    
    ; 64-bit data segment (selector 0x10)
    dw 0xFFFF                       ; Limit low
    dw 0x0000                       ; Base low
    db 0x00                         ; Base middle
    db 0x92                         ; Access: Present, Ring 0, Data
    db 0xCF                         ; Flags: 32-bit compatible
    db 0x00                         ; Base high
    
    ; 64-bit user code segment (selector 0x18) - for AGI sandboxing
    dw 0xFFFF
    dw 0x0000
    db 0x00
    db 0xFA                         ; Access: Present, Ring 3, Code
    db 0xAF
    db 0x00
    
    ; 64-bit user data segment (selector 0x20)
    dw 0xFFFF
    dw 0x0000
    db 0x00
    db 0xF2                         ; Access: Present, Ring 3, Data
    db 0xCF
    db 0x00

gdt64_end:

gdt64_ptr:
    dw gdt64_end - gdt64 - 1        ; Limit
    dd gdt64                        ; Base (32-bit for now)
    dd 0                            ; High bits (for 64-bit)
