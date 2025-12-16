; ════════════════════════════════════════════════════════════════════════════
; ELF.ASM - ELF64 Executable Loader
; Load and execute ELF64 binaries
; ════════════════════════════════════════════════════════════════════════════
;
; ELF64 Header (64 bytes):
;   +0:  e_ident[16]   - Magic number and info
;   +16: e_type        - Object file type (2 bytes)
;   +18: e_machine     - Architecture (2 bytes)
;   +20: e_version     - Object file version (4 bytes)
;   +24: e_entry       - Entry point (8 bytes)
;   +32: e_phoff       - Program header offset (8 bytes)
;   +40: e_shoff       - Section header offset (8 bytes)
;   +48: e_flags       - Processor flags (4 bytes)
;   +52: e_ehsize      - ELF header size (2 bytes)
;   +54: e_phentsize   - Program header entry size (2 bytes)
;   +56: e_phnum       - Program header count (2 bytes)
;   +58: e_shentsize   - Section header entry size (2 bytes)
;   +60: e_shnum       - Section header count (2 bytes)
;   +62: e_shstrndx    - Section name string table index (2 bytes)
;
; Program Header (56 bytes):
;   +0:  p_type        - Segment type (4 bytes)
;   +4:  p_flags       - Segment flags (4 bytes)
;   +8:  p_offset      - Offset in file (8 bytes)
;   +16: p_vaddr       - Virtual address (8 bytes)
;   +24: p_paddr       - Physical address (8 bytes)
;   +32: p_filesz      - Size in file (8 bytes)
;   +40: p_memsz       - Size in memory (8 bytes)
;   +48: p_align       - Alignment (8 bytes)
;
; ════════════════════════════════════════════════════════════════════════════

; ELF Magic
ELF_MAGIC           equ 0x464C457F          ; 0x7F 'E' 'L' 'F'

; ELF Class (e_ident[4])
ELFCLASS64          equ 2

; ELF Data encoding (e_ident[5])
ELFDATA2LSB         equ 1                   ; Little endian

; ELF Type (e_type)
ET_EXEC             equ 2                   ; Executable
ET_DYN              equ 3                   ; Shared object (PIE)

; ELF Machine (e_machine)
EM_X86_64           equ 62                  ; AMD x86-64

; Program header types (p_type)
PT_NULL             equ 0                   ; Unused
PT_LOAD             equ 1                   ; Loadable segment
PT_DYNAMIC          equ 2                   ; Dynamic linking info
PT_INTERP           equ 3                   ; Interpreter path
PT_NOTE             equ 4                   ; Note section
PT_PHDR             equ 6                   ; Program header table

; Program header flags (p_flags)
PF_X                equ 1                   ; Execute
PF_W                equ 2                   ; Write
PF_R                equ 4                   ; Read

; ELF header offsets
ELF_IDENT           equ 0
ELF_TYPE            equ 16
ELF_MACHINE         equ 18
ELF_VERSION         equ 20
ELF_ENTRY           equ 24
ELF_PHOFF           equ 32
ELF_SHOFF           equ 40
ELF_FLAGS           equ 48
ELF_EHSIZE          equ 52
ELF_PHENTSIZE       equ 54
ELF_PHNUM           equ 56
ELF_SHENTSIZE       equ 58
ELF_SHNUM           equ 60
ELF_SHSTRNDX        equ 62

; Program header offsets
PH_TYPE             equ 0
PH_FLAGS            equ 4
PH_OFFSET           equ 8
PH_VADDR            equ 16
PH_PADDR            equ 24
PH_FILESZ           equ 32
PH_MEMSZ            equ 40
PH_ALIGN            equ 48
PH_SIZE             equ 56

; Load address for user programs
ELF_LOAD_BASE       equ 0x800000            ; 8MB - user space starts here
ELF_STACK_TOP       equ 0x1000000           ; 16MB - stack top

; ════════════════════════════════════════════════════════════════════════════
; ELF_VALIDATE - Validate ELF header
; Input: RSI = pointer to ELF file in memory
; Output: CF clear if valid, set if invalid
; ════════════════════════════════════════════════════════════════════════════
elf_validate:
    push rax
    push rbx

    ; Check magic number
    mov eax, [rsi]
    cmp eax, ELF_MAGIC
    jne .invalid

    ; Check 64-bit
    cmp byte [rsi + 4], ELFCLASS64
    jne .invalid

    ; Check little-endian
    cmp byte [rsi + 5], ELFDATA2LSB
    jne .invalid

    ; Check x86-64
    movzx eax, word [rsi + ELF_MACHINE]
    cmp eax, EM_X86_64
    jne .invalid

    ; Check executable type
    movzx eax, word [rsi + ELF_TYPE]
    cmp eax, ET_EXEC
    je .valid
    cmp eax, ET_DYN                     ; PIE executables
    je .valid
    jmp .invalid

.valid:
    clc
    jmp .validate_done

.invalid:
    stc

.validate_done:
    pop rbx
    pop rax
    ret

; ════════════════════════════════════════════════════════════════════════════
; ELF_LOAD - Load ELF into memory
; Input: RSI = pointer to ELF file, RDI = optional load base (0 = use default)
; Output: RAX = entry point (or 0 on error)
; ════════════════════════════════════════════════════════════════════════════
elf_load:
    push rbx
    push rcx
    push rdx
    push rdi
    push rsi
    push r8
    push r9
    push r10
    push r11
    push r12

    mov r12, rsi                        ; Save ELF pointer

    ; Validate ELF
    call elf_validate
    jc .load_error

    ; Get load base
    test rdi, rdi
    jnz .have_base
    mov rdi, ELF_LOAD_BASE

.have_base:
    mov r8, rdi                         ; R8 = load base

    ; Get entry point
    mov rax, [r12 + ELF_ENTRY]
    mov [elf_entry_point], rax

    ; Get program header info
    mov rax, [r12 + ELF_PHOFF]          ; Program header offset
    add rax, r12                        ; RAX = program header start
    mov r9, rax                         ; R9 = current program header

    movzx r10d, word [r12 + ELF_PHNUM]  ; R10 = number of program headers
    movzx r11d, word [r12 + ELF_PHENTSIZE] ; R11 = program header size

    ; Process each program header
.process_phdr:
    test r10d, r10d
    jz .load_done

    ; Check if PT_LOAD
    mov eax, [r9 + PH_TYPE]
    cmp eax, PT_LOAD
    jne .next_phdr

    ; Load this segment
    ; Get file offset
    mov rcx, [r9 + PH_OFFSET]
    add rcx, r12                        ; RCX = source in file

    ; Get destination address
    mov rdi, [r9 + PH_VADDR]
    ; For PIE, add base. For fixed address, use as-is
    cmp rdi, ELF_LOAD_BASE
    jae .no_relocate
    add rdi, r8                         ; Add base for low addresses

.no_relocate:
    ; Get sizes
    mov rdx, [r9 + PH_FILESZ]           ; File size
    mov rbx, [r9 + PH_MEMSZ]            ; Memory size

    ; Copy file content
    push rdi
    push rcx
    mov rsi, rcx
    mov rcx, rdx
    rep movsb
    pop rcx
    pop rdi

    ; Zero BSS (memsz - filesz)
    sub rbx, rdx                        ; BSS size
    jle .next_phdr                      ; No BSS

    ; Zero the BSS area
    add rdi, rdx                        ; Start of BSS
    mov rcx, rbx
    xor al, al
    rep stosb

.next_phdr:
    add r9, r11                         ; Next program header
    dec r10d
    jmp .process_phdr

.load_done:
    ; Return entry point (possibly relocated)
    mov rax, [elf_entry_point]
    cmp rax, ELF_LOAD_BASE
    jae .entry_ok
    add rax, r8                         ; Relocate entry point

.entry_ok:
    jmp .load_exit

.load_error:
    xor eax, eax

.load_exit:
    pop r12
    pop r11
    pop r10
    pop r9
    pop r8
    pop rsi
    pop rdi
    pop rdx
    pop rcx
    pop rbx
    ret

; ════════════════════════════════════════════════════════════════════════════
; ELF_EXEC - Load and execute ELF file
; Input: RSI = pointer to ELF file
; Output: RAX = exit code (or -1 on error)
; ════════════════════════════════════════════════════════════════════════════
elf_exec:
    push rbx
    push rcx
    push rdx
    push rdi
    push rsi
    push rbp
    push r12
    push r13
    push r14
    push r15

    ; Load ELF
    xor edi, edi                        ; Use default base
    call elf_load
    test rax, rax
    jz .exec_error

    mov r12, rax                        ; Save entry point

    ; Setup stack for user program
    mov r13, rsp                        ; Save kernel stack
    mov rsp, ELF_STACK_TOP              ; Switch to user stack

    ; Push argc, argv (minimal - no arguments)
    push qword 0                        ; envp terminator
    push qword 0                        ; argv terminator
    push qword 0                        ; argc = 0
    mov rdi, 0                          ; argc
    mov rsi, rsp                        ; argv
    add rsi, 8

    ; Call entry point
    call r12

    ; Restore kernel stack
    mov rsp, r13

    ; RAX contains exit code
    jmp .exec_done

.exec_error:
    mov rax, -1

.exec_done:
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbp
    pop rsi
    pop rdi
    pop rdx
    pop rcx
    pop rbx
    ret

; ════════════════════════════════════════════════════════════════════════════
; ELF_LOAD_FILE - Load ELF from FAT32 filesystem and execute
; Input: RSI = filename (8.3 format)
; Output: RAX = exit code (or -1 on error)
; ════════════════════════════════════════════════════════════════════════════
elf_load_file:
    push rbx
    push rcx
    push rdx
    push rdi
    push rsi

    ; Check if FAT32 is mounted
    call fat32_is_mounted
    test al, al
    jz .file_error

    ; Read file into buffer
    mov rdi, elf_file_buffer
    mov edx, ELF_MAX_FILE_SIZE
    call fat32_read_file

    test eax, eax
    jz .file_error

    ; Execute the loaded ELF
    mov rsi, elf_file_buffer
    call elf_exec
    jmp .file_done

.file_error:
    mov rax, -1

.file_done:
    pop rsi
    pop rdi
    pop rdx
    pop rcx
    pop rbx
    ret

; ════════════════════════════════════════════════════════════════════════════
; ELF_GET_SYMBOL - Find symbol in loaded ELF (for dynamic linking)
; Input: RSI = ELF base, RDI = symbol name
; Output: RAX = symbol address (or 0 if not found)
; Note: This is a simplified version - full implementation would parse .dynsym
; ════════════════════════════════════════════════════════════════════════════
elf_get_symbol:
    ; Stub - would need to parse section headers and symbol tables
    xor eax, eax
    ret

; ════════════════════════════════════════════════════════════════════════════
; ELF_INFO - Get ELF information
; Input: RSI = ELF file pointer
; Output: RAX = entry point, RBX = program header count, RCX = type
; ════════════════════════════════════════════════════════════════════════════
elf_info:
    push rdx

    ; Validate first
    call elf_validate
    jc .info_invalid

    mov rax, [rsi + ELF_ENTRY]
    movzx ebx, word [rsi + ELF_PHNUM]
    movzx ecx, word [rsi + ELF_TYPE]
    jmp .info_done

.info_invalid:
    xor eax, eax
    xor ebx, ebx
    xor ecx, ecx

.info_done:
    pop rdx
    ret

; ════════════════════════════════════════════════════════════════════════════
; ELF_DUMP_HEADERS - Debug: print ELF header info
; Input: RSI = ELF file pointer
; ════════════════════════════════════════════════════════════════════════════
elf_dump_headers:
    ; Stub for debug printing
    ret

; ════════════════════════════════════════════════════════════════════════════
; ELF DATA SECTION
; ════════════════════════════════════════════════════════════════════════════
align 8

; Entry point storage
elf_entry_point:    dq 0

; Maximum ELF file size (64KB - larger files use heap)
ELF_MAX_FILE_SIZE   equ 0x10000             ; 64KB max

; File buffer for loading from disk
align 4096
elf_file_buffer:    times ELF_MAX_FILE_SIZE db 0
