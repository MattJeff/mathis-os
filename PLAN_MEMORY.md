# PLAN MEMORY MANAGEMENT - MathisOS

## Architecture Cible

```
┌────────────────────────────────────────────────────────────────┐
│                    VIRTUAL ADDRESS SPACE                        │
├────────────────────────────────────────────────────────────────┤
│ 0x0000000000000000 - 0x00007FFFFFFFFFFF : User Space (128TB)   │
│ 0xFFFF800000000000 - 0xFFFFFFFFFFFFFFFF : Kernel Space (128TB) │
└────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                    4-LEVEL PAGING (x86-64)                      │
├─────────────────────────────────────────────────────────────────┤
│ PML4 (512 entries) → PDPT (512) → PD (512) → PT (512 × 4KB)    │
│                                                                 │
│ Virtual Address: [PML4:9][PDPT:9][PD:9][PT:9][Offset:12]       │
└─────────────────────────────────────────────────────────────────┘
```

---

## PHASE 1: Physical Memory Manager (PMM)

### 1.1 Fichiers à créer

```
boot/kernel/mm/
├── pmm_const.asm      # Constants (PAGE_SIZE, etc.)
├── pmm_bitmap.asm     # Bitmap for frame tracking
├── pmm_init.asm       # Parse E820, init bitmap
├── pmm_alloc.asm      # Allocate physical frame
├── pmm_free.asm       # Free physical frame
└── pmm_stats.asm      # Memory statistics
```

### 1.2 pmm_const.asm (~30 lignes)
```asm
; Physical page size
PAGE_SIZE           equ 4096
PAGE_SHIFT          equ 12

; Memory regions
PMM_BITMAP_ADDR     equ 0x200000        ; 2MB - bitmap location
PMM_USABLE_START    equ 0x400000        ; 4MB - first usable page
PMM_MAX_PAGES       equ 262144          ; 1GB / 4KB = 256K pages

; E820 memory types
E820_USABLE         equ 1
E820_RESERVED       equ 2
E820_ACPI_RECLAIM   equ 3
E820_ACPI_NVS       equ 4

; Bitmap macros
BITS_PER_QWORD      equ 64
```

### 1.3 pmm_bitmap.asm (~80 lignes)
```asm
; Exports: pmm_bitmap_set, pmm_bitmap_clear, pmm_bitmap_test
;
; pmm_bitmap_set(frame_index) - Mark frame as used
; pmm_bitmap_clear(frame_index) - Mark frame as free
; pmm_bitmap_test(frame_index) -> AL=1 if used
```

### 1.4 pmm_init.asm (~100 lignes)
```asm
; Exports: pmm_init
;
; 1. Clear bitmap (all frames "used")
; 2. Parse E820 map at 0x500
; 3. Mark usable regions as free
; 4. Reserve kernel memory (0-4MB)
; 5. Store total/free frame counts
```

### 1.5 pmm_alloc.asm (~60 lignes)
```asm
; Exports: pmm_alloc_frame
;
; Input: None
; Output: RAX = physical address (0 if OOM)
;
; 1. Scan bitmap for first free bit
; 2. Mark as used
; 3. Return physical address
```

### 1.6 pmm_free.asm (~40 lignes)
```asm
; Exports: pmm_free_frame
;
; Input: RDI = physical address
; Output: None
;
; 1. Calculate frame index
; 2. Clear bit in bitmap
; 3. Increment free count
```

---

## PHASE 2: Virtual Memory Manager (VMM)

### 2.1 Fichiers à créer

```
boot/kernel/mm/
├── vmm_const.asm      # Page table flags
├── vmm_init.asm       # Create kernel page tables
├── vmm_map.asm        # Map virtual -> physical
├── vmm_unmap.asm      # Unmap virtual page
├── vmm_alloc.asm      # Allocate virtual region
├── vmm_switch.asm     # Switch address space (CR3)
└── vmm_fault.asm      # Page fault handler
```

### 2.2 vmm_const.asm (~40 lignes)
```asm
; Page table entry flags
PTE_PRESENT         equ (1 << 0)
PTE_WRITABLE        equ (1 << 1)
PTE_USER            equ (1 << 2)
PTE_WRITE_THROUGH   equ (1 << 3)
PTE_CACHE_DISABLE   equ (1 << 4)
PTE_ACCESSED        equ (1 << 5)
PTE_DIRTY           equ (1 << 6)
PTE_HUGE            equ (1 << 7)    ; 2MB page
PTE_GLOBAL          equ (1 << 8)
PTE_NX              equ (1 << 63)   ; No execute

; Address masks
PTE_ADDR_MASK       equ 0x000FFFFFFFFFF000
PML4_SHIFT          equ 39
PDPT_SHIFT          equ 30
PD_SHIFT            equ 21
PT_SHIFT            equ 12
PAGE_OFFSET_MASK    equ 0xFFF

; Kernel space base
KERNEL_BASE         equ 0xFFFF800000000000
```

### 2.3 vmm_init.asm (~100 lignes)
```asm
; Exports: vmm_init
;
; 1. Allocate PML4 from PMM
; 2. Identity map first 4MB (kernel)
; 3. Map kernel to high half (0xFFFF8000...)
; 4. Map framebuffer
; 5. Load CR3 with new PML4
```

### 2.4 vmm_map.asm (~100 lignes)
```asm
; Exports: vmm_map_page
;
; Input: RDI = virtual addr, RSI = physical addr, RDX = flags
; Output: RAX = 0 success, -1 error
;
; 1. Extract PML4/PDPT/PD/PT indices
; 2. Walk page tables, allocate if needed
; 3. Set PT entry with physical + flags
```

### 2.5 vmm_unmap.asm (~60 lignes)
```asm
; Exports: vmm_unmap_page
;
; Input: RDI = virtual addr
; Output: RAX = physical addr that was mapped
;
; 1. Walk page tables
; 2. Clear PT entry
; 3. Invalidate TLB (invlpg)
```

### 2.6 vmm_switch.asm (~30 lignes)
```asm
; Exports: vmm_switch_space
;
; Input: RDI = PML4 physical address
; Output: None
;
; 1. mov cr3, rdi
```

### 2.7 vmm_fault.asm (~80 lignes)
```asm
; Exports: vmm_page_fault_handler
;
; Input: Error code on stack, CR2 = fault address
;
; 1. Check if valid fault (demand paging)
; 2. If valid: allocate frame, map page
; 3. If invalid: kill process or panic
```

---

## PHASE 3: Memory Protection (Ring 3)

### 3.1 Fichiers à créer

```
boot/kernel/sys/
├── ring3_const.asm    # Ring 3 segment selectors
├── ring3_gdt.asm      # GDT with user segments
├── ring3_tss.asm      # TSS setup for ring switch
├── syscall_entry.asm  # Syscall dispatcher
├── syscall_table.asm  # Syscall handlers
└── ring3_switch.asm   # Jump to Ring 3
```

### 3.2 ring3_const.asm (~30 lignes)
```asm
; GDT selectors
GDT_KERNEL_CODE     equ 0x08
GDT_KERNEL_DATA     equ 0x10
GDT_USER_CODE       equ 0x18 | 3    ; RPL=3
GDT_USER_DATA       equ 0x20 | 3    ; RPL=3
GDT_TSS             equ 0x28

; Syscall numbers
SYS_EXIT            equ 0
SYS_READ            equ 1
SYS_WRITE           equ 2
SYS_OPEN            equ 3
SYS_CLOSE           equ 4
SYS_MMAP            equ 5
SYS_MUNMAP          equ 6
SYS_FORK            equ 7
SYS_EXEC            equ 8
SYS_YIELD           equ 9
```

### 3.3 ring3_gdt.asm (~60 lignes)
```asm
; Exports: gdt64_setup_user
;
; Add user code/data segments to GDT:
; - User Code: 0x18 (DPL=3, long mode)
; - User Data: 0x20 (DPL=3)
; - TSS: 0x28
```

### 3.4 ring3_tss.asm (~80 lignes)
```asm
; Exports: tss_init, tss_set_rsp0
;
; TSS structure for x86-64:
; - RSP0: Kernel stack for Ring 0
; - IST1-7: Interrupt stacks
;
; tss_set_rsp0(stack) - Set kernel stack for process
```

### 3.5 syscall_entry.asm (~100 lignes)
```asm
; Exports: syscall_handler
;
; Entry point for int 0x80 or syscall instruction
;
; 1. Save user registers
; 2. Switch to kernel stack
; 3. Look up syscall in table
; 4. Call handler
; 5. Restore user registers
; 6. sysret or iret
```

### 3.6 syscall_table.asm (~80 lignes)
```asm
; Syscall dispatch table
;
; syscall_table:
;   dq sys_exit
;   dq sys_read
;   dq sys_write
;   ...
;
; Each syscall: RDI, RSI, RDX, R10, R8, R9
```

### 3.7 ring3_switch.asm (~50 lignes)
```asm
; Exports: ring3_enter
;
; Input: RDI = user RIP, RSI = user RSP
;
; 1. Setup iret frame
; 2. iretq to user mode
```

---

## PHASE 4: Per-Process Address Space

### 4.1 Fichiers à créer

```
boot/kernel/process/
├── proc_const.asm     # PCB structure offsets
├── proc_create.asm    # Create process + address space
├── proc_destroy.asm   # Destroy process
├── proc_fork.asm      # Fork (copy-on-write)
├── proc_exec.asm      # Load executable
└── proc_switch.asm    # Context switch
```

### 4.2 proc_const.asm (~50 lignes)
```asm
; Process Control Block
PCB_PID             equ 0
PCB_STATE           equ 4
PCB_PML4            equ 8       ; Physical addr of page tables
PCB_RSP             equ 16      ; User stack
PCB_RIP             equ 24      ; User instruction pointer
PCB_REGS            equ 32      ; Saved registers (128 bytes)
PCB_KSTACK          equ 160     ; Kernel stack for this process
PCB_SIZE            equ 256

; Process states
PROC_UNUSED         equ 0
PROC_READY          equ 1
PROC_RUNNING        equ 2
PROC_BLOCKED        equ 3
PROC_ZOMBIE         equ 4
```

### 4.3 proc_create.asm (~100 lignes)
```asm
; Exports: proc_create
;
; Input: RDI = entry point
; Output: RAX = PID
;
; 1. Find free PCB slot
; 2. Allocate PML4 (new address space)
; 3. Map kernel to high half
; 4. Allocate user stack
; 5. Setup initial register state
; 6. Add to scheduler
```

### 4.4 proc_fork.asm (~100 lignes)
```asm
; Exports: sys_fork
;
; 1. Create new PCB
; 2. Copy parent's page tables (COW)
; 3. Mark all pages read-only
; 4. Return 0 to child, PID to parent
```

---

## PHASE 5: Slab Allocator

### 5.1 Fichiers à créer

```
boot/kernel/mm/
├── slab_const.asm     # Slab structures
├── slab_init.asm      # Initialize caches
├── slab_cache.asm     # Create/destroy caches
├── slab_alloc.asm     # Allocate object
└── slab_free.asm      # Free object
```

### 5.2 slab_const.asm (~40 lignes)
```asm
; Slab cache structure
CACHE_NAME          equ 0       ; 16 bytes
CACHE_OBJ_SIZE      equ 16      ; Object size
CACHE_OBJ_PER_SLAB  equ 20      ; Objects per slab
CACHE_SLABS_FULL    equ 24      ; List head
CACHE_SLABS_PARTIAL equ 32      ; List head
CACHE_SLABS_FREE    equ 40      ; List head
CACHE_SIZE          equ 48

; Slab header (at start of each slab page)
SLAB_CACHE          equ 0       ; Pointer to cache
SLAB_FREE_LIST      equ 8       ; First free object
SLAB_IN_USE         equ 16      ; Objects in use
SLAB_NEXT           equ 20      ; Next slab in list
SLAB_HEADER_SIZE    equ 32

; Standard caches
SLAB_32             equ 0
SLAB_64             equ 1
SLAB_128            equ 2
SLAB_256            equ 3
SLAB_512            equ 4
SLAB_1024           equ 5
SLAB_2048           equ 6
SLAB_CACHE_COUNT    equ 7
```

### 5.3 slab_init.asm (~60 lignes)
```asm
; Exports: slab_init
;
; Create standard size caches:
; - 32, 64, 128, 256, 512, 1024, 2048 bytes
```

### 5.4 slab_alloc.asm (~80 lignes)
```asm
; Exports: slab_alloc
;
; Input: RDI = size
; Output: RAX = pointer
;
; 1. Find appropriate cache
; 2. Get slab with free object
; 3. Pop from free list
; 4. Return pointer
```

### 5.5 slab_free.asm (~60 lignes)
```asm
; Exports: slab_free
;
; Input: RDI = pointer
; Output: None
;
; 1. Find slab from pointer
; 2. Push to free list
; 3. Move slab between lists if needed
```

---

## ORDRE D'IMPLÉMENTATION

```
Week 1: PMM
  ├── Day 1: pmm_const, pmm_bitmap
  ├── Day 2: pmm_init (E820 parsing)
  └── Day 3: pmm_alloc, pmm_free, tests

Week 2: VMM
  ├── Day 1: vmm_const, vmm_init
  ├── Day 2: vmm_map, vmm_unmap
  └── Day 3: vmm_fault, vmm_switch, tests

Week 3: Ring 3
  ├── Day 1: ring3_gdt, ring3_tss
  ├── Day 2: syscall_entry, syscall_table
  └── Day 3: ring3_switch, tests

Week 4: Process
  ├── Day 1: proc_const, proc_create
  ├── Day 2: proc_switch, integration
  └── Day 3: proc_fork (optional)

Week 5: Slab
  ├── Day 1: slab_const, slab_init
  ├── Day 2: slab_alloc, slab_free
  └── Day 3: Integration, replace kmalloc
```

---

## TESTS À CHAQUE PHASE

### PMM Tests
```asm
; Allocate 10 frames, free 5, allocate 3
; Verify no duplicates
; Verify free count correct
```

### VMM Tests
```asm
; Map page, write to it, unmap
; Access unmapped -> page fault
; Switch address space
```

### Ring 3 Tests
```asm
; Simple user program that calls syscall
; Verify return to kernel works
; Verify stack switch works
```

### Process Tests
```asm
; Create 2 processes
; Verify separate address spaces
; Context switch between them
```

---

## DÉPENDANCES

```
                    ┌─────────┐
                    │   PMM   │
                    └────┬────┘
                         │
                    ┌────▼────┐
                    │   VMM   │
                    └────┬────┘
                         │
        ┌────────────────┼────────────────┐
        │                │                │
   ┌────▼────┐      ┌────▼────┐      ┌────▼────┐
   │  Ring3  │      │ Process │      │  Slab   │
   └────┬────┘      └────┬────┘      └─────────┘
        │                │
        └───────┬────────┘
                │
           ┌────▼────┐
           │User Apps│
           └─────────┘
```

---

*Prêt à coder. Commencer par Phase 1: PMM ?*
