# Debug Go64 - Transition 32-bit vers 64-bit

## Problème
Triple fault immédiat au `mov cr0, eax` avec PG=1

## État actuel
- CR0 avant paging = **0x11** (PE=1, ET=1) ✓
- Toutes les étapes jusqu'au paging fonctionnent (affiche "64PA3LGX")
- Kernel à 0x10000, Stack à 0x90000, VGA à 0xB8000

## Tests effectués

| # | Test | Résultat |
|---|------|----------|
| 1 | Pages 2MB avec PS=1 | ❌ crash |
| 2 | Pages 4KB avec PT | ❌ crash |
| 3 | Entrées 8-byte (high bits = 0) | ❌ crash |
| 4 | PSE=0 dans CR4 | ❌ crash |
| 5 | Zone mémoire 0x1000 pour tables | ❌ crash |
| 6 | Zone mémoire 0x70000 pour tables | ❌ crash |
| 7 | `or eax, 0x80000001` (PG+PE) | ❌ crash |
| 8 | Séquence CR3 avant PAE (comme autre IA) | ❌ crash |
| 9 | GDT mixte 32-bit + 64-bit | ⏳ à tester |
| 10 | Cache désactivé (CD=1, wbinvd) | ⏳ à tester |
| 11 | NMI désactivé | ⏳ à tester |
| 12 | Tables à 0x70000 + pages 4KB + GDT mixte | ⏳ à tester |
| 13 | QEMU avec `-d int,cpu_reset` pour voir exception | ⏳ à tester |
| 14 | QEMU avec `-cpu pentium3` | ⏳ à tester |

## Hypothèses restantes

### 1. GDT mixte (PRIORITÉ HAUTE)
Le CPU en "compatibility mode" après PG=1 a besoin de segments 32-bit valides.
La GDT actuelle n'a que des segments 64-bit (L=1).

**Solution:** GDT avec:
- 0x00: Null
- 0x08: Code 32-bit (pour mode compatibilité)
- 0x10: Data 32-bit
- 0x18: Code 64-bit (pour far jump)
- 0x20: Data 64-bit

### 2. Cache/TLB
Le cache pourrait avoir des données stale qui interfèrent avec les nouvelles page tables.

**Solution:**
```asm
wbinvd          ; Flush cache
mov eax, cr3
mov cr3, eax    ; Flush TLB
```

### 3. NMI (Non-Maskable Interrupt)
Une NMI pourrait survenir pendant la transition et causer un triple fault.

**Solution:**
```asm
mov al, 0x80
out 0x70, al
```

### 4. IDT invalide
Si une exception survient et l'IDT n'est pas mappée, triple fault.

**Solution:** S'assurer que l'IDT est dans les 2MB mappés ou créer un IDT minimal.

## Commandes debug QEMU

```bash
# Voir les exceptions
qemu-system-x86_64 -fda boot/mathis.img -m 128M -d int,cpu_reset -no-reboot -D qemu.log

# Debug avec GDB
qemu-system-x86_64 -fda boot/mathis.img -m 128M -s -S
# Puis: gdb -> target remote localhost:1234

# CPU minimal
qemu-system-x86_64 -fda boot/mathis.img -m 128M -cpu pentium3
```

## Code qui marche (sans paging)
```asm
do_go64:
    ; Clear tables, setup PAE, CR3, EFER.LME, GDT64
    ; Affiche "64PA3LGX" puis halt
    cli
    hlt
```

## Prochaine étape
Tester GDT mixte avec segments 32-bit ET 64-bit
