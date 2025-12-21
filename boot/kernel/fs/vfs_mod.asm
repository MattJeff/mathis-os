; ============================================================================
; VFS_MOD.ASM - Virtual File System
; ============================================================================
; Basic VFS abstraction layer
; ============================================================================

[BITS 64]
[DEFAULT REL]

; ============================================================================
; CONSTANTS
; ============================================================================
VFS_MAX_PATH            equ 256
VFS_MAX_FILES           equ 32
VFS_TYPE_FILE           equ 0
VFS_TYPE_DIR            equ 1

; File entry structure
VFS_ENTRY_NAME          equ 0       ; 64 bytes
VFS_ENTRY_TYPE          equ 64      ; 1 byte
VFS_ENTRY_SIZE          equ 68      ; 4 bytes
VFS_ENTRY_DATA          equ 72      ; 8 bytes (pointer)
VFS_ENTRY_SIZE_TOTAL    equ 80

; ============================================================================
; EXPORTS
; ============================================================================
global vfs_init
global vfs_list_dir
global vfs_get_entry
global vfs_entry_count

; ============================================================================
; CODE
; ============================================================================
section .text

; ----------------------------------------------------------------------------
; vfs_init - Initialize VFS with demo entries
; ----------------------------------------------------------------------------
vfs_init:
    ; Add root entries
    mov dword [vfs_entry_count], 3

    ; Entry 0: Documents/
    lea rdi, [vfs_entries]
    lea rsi, [str_documents]
    call .copy_name
    mov byte [rdi + VFS_ENTRY_TYPE], VFS_TYPE_DIR
    mov dword [rdi + VFS_ENTRY_SIZE], 0

    ; Entry 1: README.txt
    lea rdi, [vfs_entries + VFS_ENTRY_SIZE_TOTAL]
    lea rsi, [str_readme]
    call .copy_name
    mov byte [rdi + VFS_ENTRY_TYPE], VFS_TYPE_FILE
    mov dword [rdi + VFS_ENTRY_SIZE], 128

    ; Entry 2: kernel.bin
    lea rdi, [vfs_entries + VFS_ENTRY_SIZE_TOTAL * 2]
    lea rsi, [str_kernel]
    call .copy_name
    mov byte [rdi + VFS_ENTRY_TYPE], VFS_TYPE_FILE
    mov dword [rdi + VFS_ENTRY_SIZE], 32768

    ret

; Copy name helper (rdi=dest, rsi=src)
.copy_name:
    push rdi
    mov ecx, 63
.copy:
    lodsb
    stosb
    test al, al
    jz .done
    dec ecx
    jnz .copy
.done:
    mov byte [rdi], 0
    pop rdi
    ret

; ----------------------------------------------------------------------------
; vfs_list_dir - List directory contents
; Input: RDI = path (unused, always root)
; Output: RAX = entry count
; ----------------------------------------------------------------------------
vfs_list_dir:
    mov eax, [vfs_entry_count]
    ret

; ----------------------------------------------------------------------------
; vfs_get_entry - Get entry by index
; Input: EDI = index
; Output: RAX = entry pointer (0 if invalid)
; ----------------------------------------------------------------------------
vfs_get_entry:
    cmp edi, [vfs_entry_count]
    jge .invalid

    mov eax, VFS_ENTRY_SIZE_TOTAL
    imul eax, edi
    lea rax, [vfs_entries + rax]
    ret

.invalid:
    xor eax, eax
    ret

; ============================================================================
; DATA
; ============================================================================
section .rodata

str_documents:          db "Documents", 0
str_readme:             db "README.txt", 0
str_kernel:             db "kernel.bin", 0

section .data

vfs_entry_count:        dd 0

section .bss

vfs_entries:            resb VFS_MAX_FILES * VFS_ENTRY_SIZE_TOTAL
