# Plan Refactorisation Modulaire du Kernel

## Objectif

Passer d'une architecture monolithique (`%include`) à une architecture modulaire avec compilation séparée de chaque module.

---

## Architecture Actuelle (Problématique)

```
boot/
├── boot.asm              → boot.bin (512B)
├── stage2.asm            → stage2.bin (4KB)
└── kernel/
    └── core.asm          → kernel.bin (512KB)
         └── %include go64.asm
              └── %include core/entry64.asm
              └── %include core/main_loop.asm
              └── %include core/isr.asm
              └── %include mm/heap.asm
              └── %include mm/pmm.asm    ← CONFLIT SECTIONS
              └── %include fs/fat32.asm
              └── %include ui/...
              └── ... (50+ fichiers)
```

**Problèmes :**
- `section .data` dans fichiers inclus casse le linker
- Impossible de tester un module isolément
- Recompilation complète à chaque changement
- Dépendances implicites (pas de `extern`)
- Fichier core.asm = 500KB+ après préprocesseur

---

## Architecture Cible (Modulaire)

```
boot/kernel/
├── core/
│   ├── entry64.asm       → entry64.o
│   ├── main_loop.asm     → main_loop.o
│   └── isr.asm           → isr.o
├── mm/
│   ├── heap.asm          → heap.o
│   ├── pmm.asm           → pmm.o
│   ├── vmm.asm           → vmm.o
│   └── slab.asm          → slab.o
├── fs/
│   ├── fat32.asm         → fat32.o
│   └── ata64.asm         → ata64.o
├── ui/
│   └── ...               → ui.o
├── drivers/
│   └── ...               → drivers.o
└── kernel.ld             → Linker script

build.sh:
  nasm -f elf64 entry64.asm -o entry64.o
  nasm -f elf64 heap.asm -o heap.o
  ...
  ld -T kernel.ld *.o -o kernel.elf
  objcopy -O binary kernel.elf kernel.bin
```

---

## Structure des Modules

### Règles par Module

| Règle | Description |
|-------|-------------|
| 1 fichier = 1 tâche | Chaque .asm a une responsabilité unique |
| Max 100 lignes | Découper si plus grand |
| Max 50 lignes/fonction | Fonctions courtes et lisibles |
| `global` exports | Déclarer toutes les fonctions publiques |
| `extern` imports | Déclarer toutes les dépendances |
| Sections explicites | `.text`, `.data`, `.rodata`, `.bss` |
| No magic numbers | Constantes nommées avec `equ` |

### Template de Module

```nasm
; ============================================================================
; MODULE_NAME.ASM - Brief description
; ============================================================================
; Detailed description of what this module does
; ============================================================================

[BITS 64]
[DEFAULT REL]

; ============================================================================
; IMPORTS (extern)
; ============================================================================
extern some_function
extern some_variable

; ============================================================================
; EXPORTS (global)
; ============================================================================
global my_function
global my_init

; ============================================================================
; CONSTANTS
; ============================================================================
MY_CONSTANT     equ 0x1000

; ============================================================================
; CODE SECTION
; ============================================================================
section .text

my_init:
    ; ... code ...
    ret

my_function:
    ; ... code ...
    ret

; ============================================================================
; DATA SECTION
; ============================================================================
section .data
my_variable:    dq 0

; ============================================================================
; BSS SECTION (uninitialized)
; ============================================================================
section .bss
my_buffer:      resb 256
```

---

## Modules à Créer

### Phase 1 : Core (Minimal bootable)

| Module | Fichier | Exports | Imports |
|--------|---------|---------|---------|
| Entry | `core/entry.asm` | `_start`, `long_mode_entry` | - |
| GDT/IDT | `core/tables.asm` | `gdt64`, `idt64`, `setup_idt64` | - |
| ISR | `core/isr.asm` | `timer_isr64`, `keyboard_isr64` | `tick_count`, screen funcs |
| Main Loop | `core/main.asm` | `main_loop` | All UI/input |

### Phase 2 : Memory Management

| Module | Fichier | Exports | Imports |
|--------|---------|---------|---------|
| Heap | `mm/heap.asm` | `heap_init`, `kmalloc`, `kfree` | - |
| PMM | `mm/pmm.asm` | `pmm_init`, `pmm_alloc_page`, `pmm_free_page` | `e820_*` |
| VMM | `mm/vmm.asm` | `vmm_init`, `vmm_map_page`, `vmm_unmap_page` | `pmm_alloc_page` |
| Slab | `mm/slab.asm` | `slab_init`, `slab_alloc`, `slab_free` | `pmm_alloc_page`, `kmalloc` |

### Phase 3 : Filesystem

| Module | Fichier | Exports | Imports |
|--------|---------|---------|---------|
| ATA | `fs/ata64.asm` | `ata_read_sector`, `ata_write_sector` | - |
| FAT32 | `fs/fat32.asm` | `fat32_init`, `fat32_read_file` | `ata_*`, `kmalloc` |

### Phase 4 : UI/Graphics

| Module | Fichier | Exports | Imports |
|--------|---------|---------|---------|
| Video | `ui/video.asm` | `video_init`, `draw_pixel`, `draw_rect`, `draw_char` | `screen_*` vars |
| Desktop | `ui/desktop.asm` | `desktop_draw`, `desktop_input` | `video_*`, `input_*` |
| WM | `ui/wm.asm` | `wm_draw`, `wm_input` | `video_*` |

### Phase 5 : Input

| Module | Fichier | Exports | Imports |
|--------|---------|---------|---------|
| Keyboard | `input/keyboard.asm` | `keyboard_handler` | - |
| Mouse | `input/mouse.asm` | `mouse_init`, `mouse_handler` | - |
| Manager | `input/manager.asm` | `input_manager_init`, `input_dispatch` | `keyboard_*`, `mouse_*` |

---

## Linker Script (kernel.ld)

```ld
OUTPUT_FORMAT(elf64-x86-64)
OUTPUT_ARCH(i386:x86-64)
ENTRY(_start)

KERNEL_BASE = 0x10000;

SECTIONS
{
    . = KERNEL_BASE;

    /* Multiboot header must be first */
    .multiboot : {
        *(.multiboot)
    }

    /* Entry point */
    .entry : {
        *core/entry*.o(.text)
    }

    /* All code */
    .text : {
        *(.text)
        *(.text.*)
    }

    /* Read-only data */
    .rodata : {
        *(.rodata)
        *(.rodata.*)
    }

    /* Initialized data */
    .data : {
        *(.data)
        *(.data.*)
    }

    /* Uninitialized data */
    .bss : {
        *(.bss)
        *(.bss.*)
        *(COMMON)
    }

    /* Padding to 512KB */
    . = KERNEL_BASE + 0x80000;
}
```

---

## Build System (build.sh)

```bash
#!/bin/bash
set -e

BUILD_DIR="build"
KERNEL_DIR="boot/kernel"
NASM_FLAGS="-f elf64 -g -F dwarf"
LD_FLAGS="-T ${KERNEL_DIR}/kernel.ld --no-warn-rwx-segments"

# Create build directory
mkdir -p ${BUILD_DIR}

# Compile all .asm files to .o
echo "[1/4] Compiling modules..."

OBJECTS=""
for asm in $(find ${KERNEL_DIR} -name "*.asm" -type f); do
    obj="${BUILD_DIR}/$(basename ${asm%.asm}).o"
    echo "  NASM $asm"
    nasm ${NASM_FLAGS} "$asm" -o "$obj"
    OBJECTS="$OBJECTS $obj"
done

# Link all objects
echo "[2/4] Linking kernel..."
x86_64-elf-ld ${LD_FLAGS} ${OBJECTS} -o ${BUILD_DIR}/kernel.elf

# Convert to binary
echo "[3/4] Creating binary..."
x86_64-elf-objcopy -O binary ${BUILD_DIR}/kernel.elf ${BUILD_DIR}/kernel.bin

# Create disk image
echo "[4/4] Creating disk image..."
# ... (existing disk image code)
```

---

## Plan d'Implémentation

### Étape 1 : Préparation (30 min)
- [ ] Créer `build/` directory structure
- [ ] Backup current working kernel
- [ ] Update `.gitignore` for build artifacts

### Étape 2 : Module Core (1h)
- [ ] Extraire `core/entry.asm` avec `global _start`
- [ ] Extraire `core/tables.asm` (GDT, IDT, TSS)
- [ ] Extraire `core/isr.asm` avec ISR handlers
- [ ] Tester boot minimal

### Étape 3 : Module MM (1h)
- [ ] Refactorer `mm/heap.asm` avec extern/global
- [ ] Refactorer `mm/pmm.asm`
- [ ] Refactorer `mm/vmm.asm`
- [ ] Refactorer `mm/slab.asm`
- [ ] Tester allocations

### Étape 4 : Module FS (30 min)
- [ ] Refactorer `fs/ata64.asm`
- [ ] Refactorer `fs/fat32.asm`
- [ ] Tester lecture fichiers

### Étape 5 : Module UI (1h)
- [ ] Refactorer modules vidéo
- [ ] Refactorer desktop/wm
- [ ] Tester affichage

### Étape 6 : Finalisation (30 min)
- [ ] Nettoyer anciens fichiers
- [ ] Mettre à jour documentation
- [ ] Tests complets

---

## Tests de Validation

### Test 1 : Boot Minimal
```bash
# Kernel démarre et affiche quelque chose
qemu-system-x86_64 -hda mathis.img -m 128M
# Attendre écran non-noir
```

### Test 2 : Timer Interrupts
```bash
# Vérifier 100+ timer IRQs en 2 secondes
timeout 2 qemu-system-x86_64 -hda mathis.img -d int 2>&1 | grep "v=20" | wc -l
# Résultat attendu: > 100
```

### Test 3 : Memory Allocation
```bash
# Pas de crash sur kmalloc/kfree
# Vérifier via debug output ou test intégré
```

### Test 4 : Full Desktop
```bash
# Desktop s'affiche, souris fonctionne
qemu-system-x86_64 -hda mathis.img -m 128M
# Vérifier visuellement
```

---

## Risques et Mitigations

| Risque | Mitigation |
|--------|------------|
| Symbols non résolus | Vérifier `nm kernel.elf` pour undefined |
| Sections mal placées | Utiliser `objdump -h kernel.elf` |
| Ordre d'initialisation | Entry.asm appelle init dans le bon ordre |
| Régression fonctionnelle | Tests après chaque étape |

---

## Ordre des Dépendances

```
entry.asm
    ├── tables.asm (GDT, IDT)
    ├── heap.asm (aucune dépendance)
    ├── pmm.asm → e820.asm
    ├── vmm.asm → pmm.asm
    ├── slab.asm → pmm.asm, heap.asm
    ├── ata64.asm (aucune dépendance)
    ├── fat32.asm → ata64.asm, heap.asm
    ├── video.asm (aucune dépendance)
    ├── keyboard.asm (aucune dépendance)
    ├── mouse.asm (aucune dépendance)
    ├── desktop.asm → video.asm, input.asm
    └── main.asm → tout
```

---

## Résultat Final

Après refactorisation :

```
boot/kernel/
├── core/
│   ├── entry.asm        (50 lignes)
│   ├── tables.asm       (80 lignes)
│   ├── isr.asm          (60 lignes)
│   └── main.asm         (40 lignes)
├── mm/
│   ├── heap.asm         (100 lignes)
│   ├── pmm.asm          (80 lignes)
│   ├── vmm.asm          (90 lignes)
│   └── slab.asm         (80 lignes)
├── fs/
│   ├── ata64.asm        (60 lignes)
│   └── fat32.asm        (100 lignes)
├── ui/
│   ├── video.asm        (80 lignes)
│   └── desktop.asm      (100 lignes)
├── input/
│   ├── keyboard.asm     (50 lignes)
│   └── mouse.asm        (60 lignes)
├── kernel.ld
└── Makefile             (optionnel)

Total: ~15 modules, ~1000 lignes
vs actuel: 1 blob de 10000+ lignes
```

---

## Commandes Utiles

```bash
# Voir les symboles exportés
nm build/kernel.elf | grep " T "

# Voir les symboles non résolus
nm build/kernel.elf | grep " U "

# Voir les sections
objdump -h build/kernel.elf

# Désassembler une fonction
objdump -d build/kernel.elf | grep -A 20 "pmm_alloc_page"

# Taille de chaque section
size build/kernel.elf
```

---

*Plan créé pour MathisOS - Décembre 2024*
