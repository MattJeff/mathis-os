# Bugs Résolus - MathisOS

Ce document liste les bugs rencontrés et leurs solutions pour éviter de les refaire.

---

## BUG #1: Boot Loop "OK!" avec registry_init

### Symptômes
- Écran noir avec "OK!" affiché brièvement
- Reboot immédiat (Triple Fault)
- Le message "OK!" vient de `stage2.asm:270` (initialisation VESA)

### Contexte
- L'include de `services/registry.asm` à la FIN de `go64.asm` fonctionne (boot OK)
- Mais l'appel `call registry_init` dans `entry64.asm` provoque le boot loop
- Même un simple `registry_init: ret` cause le crash

### Tentatives échouées
1. **RIP-relative addressing** (`lea rdi, [rel service_table]`) - échec
2. **Alignement stack** (`and rsp, -16`) - échec
3. **Call absolu via registre** (`mov rax, registry_init; call rax`) - échec
4. **Déplacer l'include après heap.asm** - échec (boot loop persiste)
5. **Adresses mémoire fixes** (REGISTRY_BASE = 0x300000) - non testé complètement

### Analyse du problème
- `registry_init` se trouve à offset ~0x21030 dans le kernel (~132KB)
- Autres fonctions _init sont à ~0x157DA (~87KB)
- La différence de ~45KB pourrait causer des problèmes de:
  - Relocation RIP-relative incorrecte dans le binaire linké
  - Alignement de section
  - Distance de saut trop grande (peu probable en 64-bit)

### Hypothèse principale
Le kernel est compilé en ELF64 puis linké en binaire plat (`OUTPUT_FORMAT(binary)`).
Les instructions `lea reg, [rel label]` génèrent des offsets relatifs au RIP.
Quand le code et les données sont trop éloignés, le linker pourrait ne pas
corriger correctement ces relocations pour un format binaire pur.

### Solution temporaire actuelle
```asm
; Dans entry64.asm
; TODO: call registry_init cause boot loop - à investiguer
; call alloc_svc_init
```
L'appel est commenté. L'include fonctionne, l'initialisation est différée.

### Pistes à explorer
1. Utiliser des adresses absolues (comme heap.asm avec `HEAP_START equ 0x400000`)
2. Créer une section `.data` séparée dans le linker script
3. Utiliser QEMU debug logs (`-d int,cpu_reset -D /tmp/qemu.log`)
4. Vérifier que la mémoire 0x30000+ est bien accessible au moment du call

---

## BUG #2: Label collision avec .clear_loop

### Symptômes
Erreur de compilation ou comportement inattendu

### Cause
Plusieurs modules utilisent le même label local `.clear_loop`

### Solution
En NASM, les labels locaux (commençant par `.`) sont scopés au label global précédent.
Donc `.clear_loop` dans `registry_init:` est différent de `.clear_loop` dans `heap_init:`.
Pas de collision réelle, mais attention lors du debugging.

---

## BUG #3: [BITS 64] dans les includes

### Symptômes
Code 32-bit généré dans un contexte 64-bit

### Cause
Ajouter `[BITS 64]` dans un fichier inclus après que le contexte soit déjà 64-bit

### Solution
Ne PAS ajouter `[BITS 64]` dans les fichiers inclus.
Le contexte est hérité du fichier principal.

---

## Règles de debug importantes

1. **Je ne vois pas l'écran graphique** - L'utilisateur doit confirmer si boot loop ou pas
2. **Un seul changement à la fois** - Suivre regles.text
3. **Toujours rebuild après modification** - `./build.sh`
4. **Tester avant de continuer** - Ne pas accumuler les changements

---

## Commandes utiles

```bash
# Voir l'adresse d'un symbole
cd boot/kernel && nasm -f elf64 core.asm -o /tmp/core.o && nm /tmp/core.o | grep registry_init

# Désassembler le kernel binaire
ndisasm -b 64 boot/kernel.bin | grep -A 20 "^00021030"

# Debug QEMU avec logs
qemu-system-x86_64 -hda boot/mathis.img -m 128M -d int,cpu_reset -D /tmp/qemu.log

# Voir les 5 derniers commits
git log --oneline -5
```
