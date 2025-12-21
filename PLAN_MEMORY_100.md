# Plan Mémoire 100% - Memory Management

## Analyse État Actuel

### ✅ Déjà Fait
| Feature | Fichier | Description |
|---------|---------|-------------|
| kmalloc/kfree | `mm/heap.asm` | Free-list allocator, first-fit, coalescing |
| krealloc/kcalloc | `mm/heap.asm` | Redimensionnement et zero-init |
| Heap tests | `mm/heap_test.asm` | 5 tests unitaires visuels |
| Paging basique | `core/entry64.asm` | Identity mapping 32MB, 2MB pages |
| Allocator service | `services/alloc_svc.asm` | V-table SOLID pour allocation |

### 🔶 Partiel
| Feature | Fichier | Problème |
|---------|---------|----------|
| Physical memory map | `kernel_backup/memory.asm` | E820 code existe mais NON utilisé |
| Heap fragmentation | `mm/heap.asm` | Coalesce basique, pas de compaction |
| VM memory | `vm/memory.asm` | Bump allocator, pas de free réel |

### ❌ À Faire
| Feature | Priorité | Pourquoi |
|---------|----------|----------|
| E820 memory detection | 🟡 | Connaître RAM disponible |
| Slab allocator | 🟡 | Allocations rapides taille fixe |
| Virtual memory (4-level) | 🔴 | Isolement mémoire processus |
| Memory protection | 🔴 | User/Kernel ring separation |
| Page fault handler | 🔴 | Demand paging, COW |

---

## Architecture Actuelle

```
┌─────────────────────────────────────────────────────────────────┐
│                    PHYSICAL MEMORY MAP                          │
├─────────────────────────────────────────────────────────────────┤
│ 0x00000 - 0x00FFF : Real Mode IVT + BIOS Data                  │
│ 0x01000 - 0x04FFF : Page Tables (PML4, PDPT, PD)               │
│ 0x05000 - 0x0FFFF : Stage2 + Variables boot                    │
│ 0x10000 - 0x8FFFF : Kernel Code + Data (512KB)                 │
│ 0x90000 - 0x9FFFF : Kernel Stack (64KB)                        │
│ 0x400000 - 0x13FFFFF : Kernel Heap (16MB)                      │
│ 0xFD000000+       : VESA Framebuffer (MMIO)                    │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                    PAGING STRUCTURE (Actuel)                    │
├─────────────────────────────────────────────────────────────────┤
│ PML4[0] → PDPT[0] → PD[0-15] : 0x00000000 - 0x02000000 (32MB)  │
│ PML4[0] → PDPT[3] → PD[0-23] : 0xFD000000 - 0xFE000000 (MMIO)  │
│                                                                 │
│ Flags: P=1, W=1, U=1, PS=1 (2MB pages, user accessible)        │
│ Mode: Identity mapping (virt = phys)                           │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                    HEAP ALLOCATOR                               │
├─────────────────────────────────────────────────────────────────┤
│ Type: Free-list with first-fit                                 │
│ Block structure:                                                │
│   [size:8][prev:8][next:8][data...]                            │
│   size bit 0 = FREE flag                                        │
│                                                                 │
│ Features:                                                       │
│   ✅ Allocation/Deallocation                                    │
│   ✅ Block splitting                                            │
│   ✅ Coalescing adjacent free blocks                           │
│   ✅ Statistics (alloc count, used size)                       │
│   ❌ Thread safety                                              │
│   ❌ Segregated free lists                                      │
│   ❌ Memory compaction                                          │
└─────────────────────────────────────────────────────────────────┘
```

---

## Architecture Cible

```
┌─────────────────────────────────────────────────────────────────┐
│                    MEMORY MANAGEMENT TARGET                     │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐         │
│  │   E820      │    │   Physical  │    │   Virtual   │         │
│  │   Detect    │───▶│   Allocator │───▶│   Memory    │         │
│  │             │    │   (Pages)   │    │   (Paging)  │         │
│  └─────────────┘    └─────────────┘    └─────────────┘         │
│                            │                  │                 │
│                            ▼                  ▼                 │
│                     ┌─────────────┐    ┌─────────────┐         │
│                     │    Slab     │    │   Page      │         │
│                     │  Allocator  │    │   Fault     │         │
│                     │             │    │  Handler    │         │
│                     └─────────────┘    └─────────────┘         │
│                            │                                    │
│                            ▼                                    │
│                     ┌─────────────┐                            │
│                     │   kmalloc   │  ← API utilisateur         │
│                     │   kfree     │                            │
│                     └─────────────┘                            │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## Étapes d'Implémentation

### Étape 1: E820 Memory Detection
**Fichier**: `mm/e820.asm`
**Priorité**: 🟡 Moyenne

Détecte la mémoire physique disponible via BIOS INT 0x15, EAX=0xE820.

```nasm
; ============================================================================
; E820.ASM - Physical Memory Map Detection
; ============================================================================
; Must be called in REAL MODE (before switch to protected/long mode)
; Stores memory map at E820_MAP_ADDR for later use
; ============================================================================

[BITS 16]

; Constants
E820_MAP_ADDR       equ 0x8000      ; Where to store the map
E820_MAX_ENTRIES    equ 32          ; Maximum entries
E820_MAGIC          equ 0x534D4150  ; 'SMAP' signature

; E820 entry structure (24 bytes each)
; Offset 0:  base_low (4 bytes)
; Offset 4:  base_high (4 bytes)
; Offset 8:  length_low (4 bytes)
; Offset 12: length_high (4 bytes)
; Offset 16: type (4 bytes)
;            1 = Usable RAM
;            2 = Reserved
;            3 = ACPI Reclaimable
;            4 = ACPI NVS
;            5 = Bad memory
; Offset 20: extended attributes (4 bytes, optional)

section .text

e820_detect:
    push bp
    mov bp, sp
    push es
    push di
    push ebx
    push ecx
    push edx

    ; Setup destination
    mov ax, 0
    mov es, ax
    mov di, E820_MAP_ADDR + 4       ; Skip entry count at start
    xor ebx, ebx                     ; Continuation value (0 = first call)
    xor bp, bp                       ; Entry counter

.loop:
    mov eax, 0xE820
    mov ecx, 24                      ; Buffer size
    mov edx, E820_MAGIC              ; 'SMAP'
    int 0x15

    jc .done                         ; Carry = error or end
    cmp eax, E820_MAGIC              ; Verify signature
    jne .done

    ; Valid entry - increment counter
    inc bp
    add di, 24

    ; Check for more entries
    test ebx, ebx
    jz .done                         ; EBX=0 means last entry

    ; Check max entries
    cmp bp, E820_MAX_ENTRIES
    jge .done

    jmp .loop

.done:
    ; Store entry count at start of map
    mov [E820_MAP_ADDR], bp

    pop edx
    pop ecx
    pop ebx
    pop di
    pop es
    pop bp
    ret

; ============================================================================
; E820_GET_TOTAL_RAM - Calculate total usable RAM
; ============================================================================
; Called from 64-bit mode
; Returns: RAX = total usable RAM in bytes
; ============================================================================

[BITS 64]

e820_get_total_ram:
    push rbx
    push rcx
    push rsi

    xor rax, rax                    ; Total RAM
    movzx ecx, word [E820_MAP_ADDR] ; Entry count
    test ecx, ecx
    jz .done

    lea rsi, [E820_MAP_ADDR + 4]    ; First entry

.loop:
    ; Check type (offset 16)
    cmp dword [rsi + 16], 1         ; Type 1 = usable RAM
    jne .next

    ; Add length to total
    mov rbx, [rsi + 8]              ; length (64-bit)
    add rax, rbx

.next:
    add rsi, 24
    dec ecx
    jnz .loop

.done:
    pop rsi
    pop rcx
    pop rbx
    ret
```

**Tâches**:
- [ ] Créer `mm/e820.asm`
- [ ] Appeler `e820_detect` depuis stage2.asm (mode réel)
- [ ] Stocker map à 0x8000
- [ ] Ajouter `e820_get_total_ram` pour 64-bit

---

### Étape 2: Physical Page Allocator
**Fichier**: `mm/pmm.asm` (Physical Memory Manager)
**Priorité**: 🟡 Moyenne

Gère les pages physiques (4KB) via un bitmap.

```nasm
; ============================================================================
; PMM.ASM - Physical Memory Manager
; ============================================================================
; Bitmap-based page frame allocator
; Each bit represents one 4KB page frame
; ============================================================================

[BITS 64]

; Constants
PAGE_SIZE           equ 4096
PMM_BITMAP_ADDR     equ 0x100000    ; 1MB mark (after kernel)
PMM_BITMAP_SIZE     equ 0x20000     ; 128KB = 1M pages = 4GB addressable

section .text

; ============================================================================
; PMM_INIT - Initialize physical memory manager
; ============================================================================
; Uses E820 map to mark usable regions
; ============================================================================
pmm_init:
    push rax
    push rbx
    push rcx
    push rdi

    ; Clear bitmap (all pages marked as used)
    mov rdi, PMM_BITMAP_ADDR
    mov rcx, PMM_BITMAP_SIZE / 8
    xor rax, rax
    not rax                         ; All 1s = all used
    rep stosq

    ; Mark usable regions from E820 map as free
    movzx ecx, word [E820_MAP_ADDR]
    test ecx, ecx
    jz .done

    lea rsi, [E820_MAP_ADDR + 4]

.parse_e820:
    ; Check type (offset 16) = 1 (usable)
    cmp dword [rsi + 16], 1
    jne .next_entry

    ; Get base and length
    mov rdi, [rsi]                  ; base address
    mov rbx, [rsi + 8]              ; length

    ; Mark pages as free
    call pmm_mark_region_free

.next_entry:
    add rsi, 24
    dec ecx
    jnz .parse_e820

    ; Reserve kernel memory (0 - 2MB)
    xor rdi, rdi
    mov rbx, 0x200000
    call pmm_mark_region_used

.done:
    pop rdi
    pop rcx
    pop rbx
    pop rax
    ret

; ============================================================================
; PMM_ALLOC_PAGE - Allocate single physical page
; ============================================================================
; Returns: RAX = physical address, or 0 if out of memory
; ============================================================================
pmm_alloc_page:
    push rbx
    push rcx
    push rdi

    mov rdi, PMM_BITMAP_ADDR
    mov rcx, PMM_BITMAP_SIZE / 8

.search:
    mov rax, [rdi]
    not rax                         ; Invert: 0 = used, 1 = free
    test rax, rax
    jnz .found_free

    add rdi, 8
    dec rcx
    jnz .search

    ; No free pages
    xor rax, rax
    jmp .done

.found_free:
    ; Find first set bit
    bsf rbx, rax                    ; rbx = bit index

    ; Mark as used
    mov rax, [rdi]
    bts rax, rbx                    ; Set bit (mark used)
    mov [rdi], rax

    ; Calculate physical address
    sub rdi, PMM_BITMAP_ADDR
    shl rdi, 3                      ; * 8 bits per byte
    add rdi, rbx                    ; Total bit index
    shl rdi, 12                     ; * 4096 = page address
    mov rax, rdi

.done:
    pop rdi
    pop rcx
    pop rbx
    ret

; ============================================================================
; PMM_FREE_PAGE - Free single physical page
; ============================================================================
; Input: RDI = physical address (must be page-aligned)
; ============================================================================
pmm_free_page:
    push rax
    push rbx
    push rdi

    ; Convert address to bit index
    shr rdi, 12                     ; / 4096 = page index
    mov rbx, rdi
    and rbx, 7                      ; Bit within byte
    shr rdi, 3                      ; Byte index in bitmap

    ; Clear bit (mark free)
    add rdi, PMM_BITMAP_ADDR
    mov rax, [rdi]
    btr rax, rbx                    ; Clear bit
    mov [rdi], rax

    pop rdi
    pop rbx
    pop rax
    ret
```

**Tâches**:
- [ ] Créer `mm/pmm.asm`
- [ ] Implémenter bitmap (128KB = 4GB addressable)
- [ ] Parser E820 pour marquer régions usables
- [ ] `pmm_alloc_page` / `pmm_free_page`

---

### Étape 3: Slab Allocator
**Fichier**: `mm/slab.asm`
**Priorité**: 🟡 Moyenne

Allocations rapides pour objets de taille fixe courante.

```nasm
; ============================================================================
; SLAB.ASM - Slab Allocator for Fixed-Size Objects
; ============================================================================
; Fast allocation for common object sizes: 32, 64, 128, 256, 512, 1024, 2048
; Each slab = one physical page (4KB) divided into fixed-size slots
; ============================================================================

[BITS 64]

; Slab sizes (7 caches)
SLAB_SIZE_32        equ 0
SLAB_SIZE_64        equ 1
SLAB_SIZE_128       equ 2
SLAB_SIZE_256       equ 3
SLAB_SIZE_512       equ 4
SLAB_SIZE_1024      equ 5
SLAB_SIZE_2048      equ 6
SLAB_CACHE_COUNT    equ 7

; Slab header (at start of each slab page)
; [next_slab:8][free_list:8][used_count:4][obj_size:4] = 24 bytes
SLAB_HEADER_SIZE    equ 24

section .data

; Slab cache heads (one per size class)
slab_caches:        times SLAB_CACHE_COUNT dq 0

; Object sizes for each cache
slab_sizes:         dd 32, 64, 128, 256, 512, 1024, 2048

section .text

; ============================================================================
; SLAB_ALLOC - Allocate object from slab cache
; ============================================================================
; Input:  EDI = size (will be rounded up to nearest slab size)
; Output: RAX = pointer to object, or 0 if failed
; ============================================================================
slab_alloc:
    push rbx
    push rcx
    push rdx

    ; Find appropriate cache
    call slab_get_cache_index
    test eax, eax
    js .use_heap                    ; Size too large, use heap

    ; Get slab cache head
    mov ecx, eax
    lea rbx, [slab_caches]
    mov rax, [rbx + rcx * 8]
    test rax, rax
    jz .new_slab                    ; No slab available

    ; Get object from free list
    mov rdx, [rax + 8]              ; free_list pointer
    test rdx, rdx
    jz .new_slab                    ; Slab full

    ; Pop from free list
    mov rbx, [rdx]                  ; Next free object
    mov [rax + 8], rbx              ; Update free list
    inc dword [rax + 16]            ; used_count++
    mov rax, rdx                    ; Return object pointer
    jmp .done

.new_slab:
    ; Allocate new slab page
    call pmm_alloc_page
    test rax, rax
    jz .done                        ; Out of memory

    ; Initialize slab header
    mov qword [rax], 0              ; next_slab = NULL
    mov dword [rax + 16], 0         ; used_count = 0

    ; Get object size
    lea rbx, [slab_sizes]
    mov edx, [rbx + rcx * 4]        ; Object size
    mov [rax + 20], edx             ; Store in header

    ; Build free list
    lea rbx, [rax + SLAB_HEADER_SIZE]
    mov [rax + 8], rbx              ; free_list = first slot

    ; Calculate slots per page
    mov edi, 4096
    sub edi, SLAB_HEADER_SIZE
    xor edx, edx
    push rax
    mov eax, edi
    mov ecx, [rsp + 8]              ; Object size from stack
    ; ... (chain free list)
    pop rax

    jmp .done

.use_heap:
    ; Fall back to heap for large allocations
    call kmalloc

.done:
    pop rdx
    pop rcx
    pop rbx
    ret

; ============================================================================
; SLAB_FREE - Return object to slab cache
; ============================================================================
; Input: RDI = pointer to object
; ============================================================================
slab_free:
    push rax
    push rbx

    ; Find slab header (page-aligned address)
    mov rax, rdi
    and rax, ~0xFFF                 ; Clear lower 12 bits

    ; Add to free list
    mov rbx, [rax + 8]              ; Current free list head
    mov [rdi], rbx                  ; Object->next = old head
    mov [rax + 8], rdi              ; free_list = object
    dec dword [rax + 16]            ; used_count--

    pop rbx
    pop rax
    ret
```

**Tâches**:
- [ ] Créer `mm/slab.asm`
- [ ] 7 caches pour tailles: 32, 64, 128, 256, 512, 1024, 2048
- [ ] `slab_alloc` / `slab_free`
- [ ] Fallback vers kmalloc pour grandes allocations

---

### Étape 4: Virtual Memory Manager (4-Level Paging)
**Fichier**: `mm/vmm.asm`
**Priorité**: 🔴 Haute

Gestion de la mémoire virtuelle avec mapping dynamique.

```nasm
; ============================================================================
; VMM.ASM - Virtual Memory Manager
; ============================================================================
; 4-Level paging for x86-64:
;   PML4 (512 entries) → PDPT (512) → PD (512) → PT (512) → Page (4KB)
;
; Virtual address layout (48-bit canonical):
;   [PML4:9][PDPT:9][PD:9][PT:9][Offset:12]
;
; Kernel virtual space: 0xFFFF800000000000 - 0xFFFFFFFFFFFFFFFF (upper half)
; User virtual space:   0x0000000000000000 - 0x00007FFFFFFFFFFF (lower half)
; ============================================================================

[BITS 64]

; Page table entry flags
PTE_PRESENT         equ (1 << 0)    ; Page is present
PTE_WRITE           equ (1 << 1)    ; Writable
PTE_USER            equ (1 << 2)    ; User accessible
PTE_PWT             equ (1 << 3)    ; Write-through
PTE_PCD             equ (1 << 4)    ; Cache disable
PTE_ACCESSED        equ (1 << 5)    ; Has been accessed
PTE_DIRTY           equ (1 << 6)    ; Has been written
PTE_HUGE            equ (1 << 7)    ; 2MB/1GB page (PS bit)
PTE_GLOBAL          equ (1 << 8)    ; Global page (not flushed on CR3 reload)
PTE_NX              equ (1 << 63)   ; No execute (requires NX in EFER)

; Kernel virtual base (higher half)
KERNEL_VIRT_BASE    equ 0xFFFF800000000000

; Current PML4 address (from CR3)
section .data
vmm_pml4:           dq 0

section .text

; ============================================================================
; VMM_INIT - Initialize virtual memory manager
; ============================================================================
vmm_init:
    push rax

    ; Get current PML4 from CR3
    mov rax, cr3
    mov [vmm_pml4], rax

    pop rax
    ret

; ============================================================================
; VMM_MAP_PAGE - Map virtual address to physical address
; ============================================================================
; Input:  RDI = virtual address
;         RSI = physical address
;         RDX = flags (PTE_PRESENT | PTE_WRITE | ...)
; Output: RAX = 0 on success, -1 on failure
; ============================================================================
vmm_map_page:
    push rbx
    push rcx
    push r8
    push r9

    mov r8, rdi                     ; Save virtual address
    mov r9, rsi                     ; Save physical address

    ; Get PML4 entry
    mov rax, [vmm_pml4]
    mov rcx, r8
    shr rcx, 39
    and rcx, 0x1FF                  ; PML4 index
    lea rbx, [rax + rcx * 8]

    ; Check if PDPT exists
    mov rax, [rbx]
    test rax, PTE_PRESENT
    jnz .have_pdpt

    ; Allocate new PDPT
    call pmm_alloc_page
    test rax, rax
    jz .fail

    ; Zero the new PDPT
    push rdi
    mov rdi, rax
    push rcx
    mov rcx, 512
    xor rax, rax
    rep stosq
    pop rcx
    pop rdi

    ; Store PDPT pointer with flags
    or rax, PTE_PRESENT | PTE_WRITE | PTE_USER
    mov [rbx], rax

.have_pdpt:
    ; Get PDPT entry
    mov rax, [rbx]
    and rax, ~0xFFF                 ; Clear flags, get address
    mov rcx, r8
    shr rcx, 30
    and rcx, 0x1FF                  ; PDPT index
    lea rbx, [rax + rcx * 8]

    ; Check if PD exists (similar pattern)
    ; ... (repeat for PD and PT levels)

    ; Finally, store the page mapping
    ; [PT entry] = physical_addr | flags
    and r9, ~0xFFF                  ; Align physical address
    or r9, rdx                      ; Add flags
    mov [rbx], r9

    xor rax, rax                    ; Success
    jmp .done

.fail:
    mov rax, -1

.done:
    pop r9
    pop r8
    pop rcx
    pop rbx
    ret

; ============================================================================
; VMM_UNMAP_PAGE - Unmap virtual address
; ============================================================================
; Input: RDI = virtual address
; ============================================================================
vmm_unmap_page:
    push rax
    push rbx
    push rcx

    ; Walk page tables to find PT entry
    ; Set entry to 0 (not present)
    ; Invalidate TLB entry
    invlpg [rdi]

    pop rcx
    pop rbx
    pop rax
    ret

; ============================================================================
; VMM_GET_PHYS - Get physical address for virtual address
; ============================================================================
; Input:  RDI = virtual address
; Output: RAX = physical address, or 0 if not mapped
; ============================================================================
vmm_get_phys:
    ; Walk page tables, return physical address
    ret
```

**Tâches**:
- [ ] Créer `mm/vmm.asm`
- [ ] Implémenter 4-level page table walking
- [ ] `vmm_map_page` / `vmm_unmap_page`
- [ ] Allocations dynamiques de page tables
- [ ] Support higher-half kernel mapping

---

### Étape 5: Page Fault Handler
**Fichier**: `mm/page_fault.asm`
**Priorité**: 🔴 Haute

Gère les page faults pour demand paging et COW.

```nasm
; ============================================================================
; PAGE_FAULT.ASM - Page Fault Handler (#PF, INT 0x0E)
; ============================================================================
; Error code bits:
;   Bit 0 (P):    0 = non-present, 1 = protection violation
;   Bit 1 (W):    0 = read, 1 = write
;   Bit 2 (U):    0 = supervisor, 1 = user
;   Bit 3 (RSVD): 1 = reserved bit set in page table
;   Bit 4 (I):    1 = instruction fetch
;
; CR2 contains the faulting virtual address
; ============================================================================

[BITS 64]

PF_ERR_PRESENT      equ (1 << 0)
PF_ERR_WRITE        equ (1 << 1)
PF_ERR_USER         equ (1 << 2)
PF_ERR_RSVD         equ (1 << 3)
PF_ERR_IFETCH       equ (1 << 4)

section .text

; ============================================================================
; PAGE_FAULT_HANDLER - Main page fault handler
; ============================================================================
page_fault_handler:
    push rax
    push rbx
    push rcx
    push rdx
    push rsi
    push rdi

    ; Get faulting address from CR2
    mov rdi, cr2
    mov [pf_fault_addr], rdi

    ; Get error code (on stack before registers)
    mov rsi, [rsp + 48]             ; Error code (after 6 pushes)
    mov [pf_error_code], rsi

    ; ═══════════════════════════════════════════════════════════════
    ; CASE 1: Non-present page (demand paging)
    ; ═══════════════════════════════════════════════════════════════
    test rsi, PF_ERR_PRESENT
    jnz .protection_fault

    ; Check if address is in valid range
    ; If in heap range: allocate page and map
    ; If in stack range: grow stack
    ; Otherwise: BSOD

    ; For now: allocate and map new page
    call pmm_alloc_page
    test rax, rax
    jz .out_of_memory

    ; Map the new page
    mov rsi, rax                    ; Physical address
    mov rdi, [pf_fault_addr]
    and rdi, ~0xFFF                 ; Page-align
    mov rdx, PTE_PRESENT | PTE_WRITE | PTE_USER
    call vmm_map_page

    ; Zero the new page
    mov rdi, [pf_fault_addr]
    and rdi, ~0xFFF
    mov rcx, 512
    xor rax, rax
    rep stosq

    jmp .done

    ; ═══════════════════════════════════════════════════════════════
    ; CASE 2: Protection violation (COW or access violation)
    ; ═══════════════════════════════════════════════════════════════
.protection_fault:
    ; Check for COW page
    ; If COW: copy page, remap as writable
    ; Otherwise: access violation → BSOD

    jmp .access_violation

    ; ═══════════════════════════════════════════════════════════════
    ; ERROR CASES
    ; ═══════════════════════════════════════════════════════════════
.out_of_memory:
    ; Out of physical memory
    jmp .fatal

.access_violation:
    ; Invalid memory access
    jmp .fatal

.fatal:
    ; Unrecoverable: jump to BSOD
    pop rdi
    pop rsi
    pop rdx
    pop rcx
    pop rbx
    pop rax

    ; Push exception info and jump to BSOD
    push qword 14                   ; Exception number
    jmp exc_common

.done:
    pop rdi
    pop rsi
    pop rdx
    pop rcx
    pop rbx
    pop rax
    add rsp, 8                      ; Remove error code
    iretq

section .data
pf_fault_addr:      dq 0
pf_error_code:      dq 0
```

**Tâches**:
- [ ] Créer `mm/page_fault.asm`
- [ ] Demand paging (allocate on access)
- [ ] Validation des plages d'adresses
- [ ] Fallback vers BSOD pour accès invalides
- [ ] (Future) Copy-on-Write support

---

### Étape 6: Memory Protection (User/Kernel)
**Fichier**: `mm/protection.asm`
**Priorité**: 🔴 Haute

Séparation des espaces mémoire kernel et user.

```nasm
; ============================================================================
; PROTECTION.ASM - Memory Protection Setup
; ============================================================================
; Kernel space: 0xFFFF800000000000+ (upper half, ring 0 only)
; User space:   0x0000000000000000 - 0x00007FFFFFFFFFFF (ring 3)
; ============================================================================

[BITS 64]

section .text

; ============================================================================
; PROTECTION_INIT - Setup memory protection
; ============================================================================
protection_init:
    push rax
    push rbx
    push rcx

    ; Get current PML4
    mov rax, cr3

    ; Kernel half (entries 256-511): Clear U bit
    lea rbx, [rax + 256 * 8]
    mov rcx, 256
.kernel_half:
    mov rax, [rbx]
    test rax, rax
    jz .next_kernel
    and rax, ~PTE_USER              ; Remove user access
    mov [rbx], rax
.next_kernel:
    add rbx, 8
    dec rcx
    jnz .kernel_half

    ; User half (entries 0-255): Keep U bit
    ; (Already set during normal mapping)

    ; Reload CR3 to flush TLB
    mov rax, cr3
    mov cr3, rax

    pop rcx
    pop rbx
    pop rax
    ret

; ============================================================================
; CHECK_USER_ACCESS - Verify user buffer is accessible
; ============================================================================
; Input:  RDI = address
;         RSI = length
; Output: RAX = 1 if valid user buffer, 0 if kernel memory
; ============================================================================
check_user_access:
    push rbx

    ; Check address is in user space (< 0x00007FFFFFFFFFFF)
    mov rax, 0x00007FFFFFFFFFFF
    cmp rdi, rax
    ja .invalid

    ; Check end address
    lea rbx, [rdi + rsi]
    cmp rbx, rax
    ja .invalid

    mov rax, 1
    jmp .done

.invalid:
    xor rax, rax

.done:
    pop rbx
    ret
```

**Tâches**:
- [ ] Créer `mm/protection.asm`
- [ ] Séparer kernel/user space dans PML4
- [ ] `check_user_access` pour syscalls
- [ ] Protéger le kernel contre accès user

---

### Étape 7: Améliorer Heap (Fragmentation)
**Fichier**: `mm/heap.asm` (modifier existant)
**Priorité**: 🟡 Moyenne

Réduire la fragmentation avec segregated free lists.

```nasm
; ============================================================================
; ADDITIONS TO HEAP.ASM - Segregated Free Lists
; ============================================================================

; Size classes for segregated lists
HEAP_CLASS_32       equ 0           ; 0-32 bytes
HEAP_CLASS_64       equ 1           ; 33-64 bytes
HEAP_CLASS_128      equ 2           ; 65-128 bytes
HEAP_CLASS_256      equ 3           ; 129-256 bytes
HEAP_CLASS_512      equ 4           ; 257-512 bytes
HEAP_CLASS_1K       equ 5           ; 513-1024 bytes
HEAP_CLASS_2K       equ 6           ; 1025-2048 bytes
HEAP_CLASS_LARGE    equ 7           ; > 2048 bytes
HEAP_CLASS_COUNT    equ 8

section .data
; Segregated free list heads (one per size class)
heap_free_lists:    times HEAP_CLASS_COUNT dq 0

section .text

; ============================================================================
; HEAP_GET_CLASS - Determine size class for allocation
; ============================================================================
; Input:  RDI = requested size
; Output: RAX = class index (0-7)
; ============================================================================
heap_get_class:
    cmp rdi, 32
    jbe .class_32
    cmp rdi, 64
    jbe .class_64
    cmp rdi, 128
    jbe .class_128
    cmp rdi, 256
    jbe .class_256
    cmp rdi, 512
    jbe .class_512
    cmp rdi, 1024
    jbe .class_1k
    cmp rdi, 2048
    jbe .class_2k
    jmp .class_large

.class_32:
    xor eax, eax
    ret
.class_64:
    mov eax, 1
    ret
.class_128:
    mov eax, 2
    ret
.class_256:
    mov eax, 3
    ret
.class_512:
    mov eax, 4
    ret
.class_1k:
    mov eax, 5
    ret
.class_2k:
    mov eax, 6
    ret
.class_large:
    mov eax, 7
    ret

; Modified malloc to use segregated lists:
; 1. Get size class
; 2. Search class-specific free list first
; 3. If empty, try larger classes
; 4. If still empty, use original first-fit on main list
```

**Tâches**:
- [ ] Ajouter 8 free lists (32, 64, 128, 256, 512, 1K, 2K, large)
- [ ] Modifier `malloc` pour chercher dans la bonne classe
- [ ] Modifier `free` pour ranger dans la bonne classe
- [ ] Améliorer `coalesce` pour fusionner classes adjacentes

---

## Fichiers à Créer

| Fichier | Lignes | Description |
|---------|--------|-------------|
| `mm/e820.asm` | ~80 | E820 memory map detection |
| `mm/pmm.asm` | ~150 | Physical page allocator (bitmap) |
| `mm/slab.asm` | ~200 | Slab allocator pour tailles fixes |
| `mm/vmm.asm` | ~250 | Virtual memory manager |
| `mm/page_fault.asm` | ~120 | Page fault handler |
| `mm/protection.asm` | ~80 | Memory protection setup |

---

## Fichiers à Modifier

| Fichier | Modification |
|---------|--------------|
| `stage2.asm` | Appeler `e820_detect` en mode réel |
| `core/entry64.asm` | Initialiser pmm, vmm, protection |
| `mm/heap.asm` | Ajouter segregated free lists |
| `sys/setup.asm` | Connecter page_fault_handler à IDT |
| `go64.asm` | Inclure nouveaux fichiers mm/ |

---

## Ordre d'Exécution Recommandé

```
1. [ ] E820 detection dans stage2 (mode réel)
2. [ ] Physical Memory Manager (pmm.asm)
3. [ ] Virtual Memory Manager (vmm.asm)
4. [ ] Page Fault Handler (page_fault.asm)
5. [ ] Memory Protection (protection.asm)
6. [ ] Slab Allocator (slab.asm)
7. [ ] Améliorer Heap (segregated lists)
8. [ ] Tests et validation
```

---

## Estimation Complexité

| Tâche | Difficulté | Lignes de code |
|-------|------------|----------------|
| E820 detection | 🟢 Facile | ~80 lignes |
| Physical allocator | 🟡 Moyen | ~150 lignes |
| Virtual memory | 🔴 Difficile | ~250 lignes |
| Page fault handler | 🟡 Moyen | ~120 lignes |
| Memory protection | 🟡 Moyen | ~80 lignes |
| Slab allocator | 🟡 Moyen | ~200 lignes |
| Heap improvements | 🟢 Facile | ~100 lignes |
| **TOTAL** | | **~980 lignes** |

---

## Tests Requis

### Test 1: E820 Detection
```nasm
; Vérifier que la map est correcte
; Afficher total RAM détectée
call e820_get_total_ram
; rax devrait contenir ~128MB pour QEMU par défaut
```

### Test 2: Physical Allocator
```nasm
; Allouer plusieurs pages
call pmm_alloc_page     ; rax = page1
call pmm_alloc_page     ; rax = page2 (différent de page1)
call pmm_free_page      ; Libérer page1
call pmm_alloc_page     ; rax = page1 (réutilisé)
```

### Test 3: Virtual Memory
```nasm
; Mapper une page virtuelle
mov rdi, 0x1000000      ; Virtual address
mov rsi, 0x500000       ; Physical address
mov rdx, PTE_PRESENT | PTE_WRITE
call vmm_map_page
; Écrire à l'adresse virtuelle
mov byte [0x1000000], 0x42
```

### Test 4: Page Fault
```nasm
; Accéder à une adresse non mappée
mov rax, [0x2000000]
; Devrait déclencher page fault → allocation automatique
```

### Test 5: Protection
```nasm
; En ring 3, essayer d'accéder au kernel
mov rax, [0xFFFF800000000000]
; Devrait déclencher #GP ou #PF
```

---

## Ressources

- [OSDev Paging](https://wiki.osdev.org/Paging)
- [OSDev Memory Management](https://wiki.osdev.org/Memory_management)
- [OSDev E820](https://wiki.osdev.org/Detecting_Memory_(x86))
- [Intel SDM Vol 3 - Memory Management](https://www.intel.com/sdm)
- [Linux Slab Allocator](https://www.kernel.org/doc/gorman/html/understand/understand011.html)

---

## Résultat Final

Après implémentation :

| Feature | Status |
|---------|--------|
| E820 memory map | ✅ |
| Physical allocator | ✅ |
| kmalloc/kfree | ✅ |
| Memory pools (slab) | ✅ |
| Virtual memory | ✅ |
| Memory protection | ✅ |
| Heap (no fragmentation) | ✅ |

**Section 1.3 Mémoire : 100% ✅**

---

*Plan généré pour MathisOS - Décembre 2024*
