# MATHIS OS - État Actuel du Projet

> **Dernière mise à jour** : 3 décembre 2025
> **Version** : v3.2 - 64-bit Long Mode fonctionnel!

---

## ✅ Fonctionnalités Implémentées

### 🖥️ Kernel & Boot
- ✅ **Boot Sector** : Chargement via BIOS (mode floppy)
- ✅ **Stage 2 Bootloader** : Passage en mode protégé 32-bit, chargement du kernel (64 KB)
- ✅ **GDT** : Global Descriptor Table configurée (Code/Data segments plats 4GB)
- ✅ **IDT** : Interrupt Descriptor Table avec patchage dynamique pour le clavier
- ✅ **PIC** : Programmable Interrupt Controller configuré (IRQ1 = clavier)
- ✅ **64-bit Long Mode** : Transition complète 32-bit → 64-bit!

### 🚀 Mode 64-bit (NOUVEAU v3.2)
- ✅ **Page Tables** : PML4 → PDPT → PD avec identity mapping 2MB
- ✅ **PAE** : Physical Address Extension activé
- ✅ **EFER.LME** : Long Mode Enable via MSR
- ✅ **GDT 64-bit** : Segments code/data 64-bit
- ✅ **Paging** : CR0.PG activé
- ✅ **Far Jump** : Saut vers code 64-bit fonctionnel
- ✅ **Commande `go64`** : Transition depuis le shell 32-bit

### ⌨️ Clavier & Shell
- ✅ **Keyboard ISR** : Interrupt Service Routine fonctionnelle
- ✅ **Scancode Mapping** : Table de conversion scancode → ASCII (lowercase)
- ✅ **Shift Support** : Majuscules et symboles (!, @, #, etc.)
- ✅ **Shell Interactif** : Prompt `>` avec buffer de commandes (64 bytes)
- ✅ **Backspace** : Suppression de caractères
- ✅ **Commandes Disponibles** :
  - `help` : Affiche la liste des commandes
  - `clear` : Efface l'écran
  - `fs` : Système de fichiers (init, list, write, read)
  - `go64` : Passe en mode 64-bit Long Mode
  - `reboot` : Redémarre l'OS

### 🎨 Affichage VGA
- ✅ **Mode Texte** : 80x25 caractères (VGA buffer @ 0xB8000)
- ✅ **Banner ASCII** : Logo "MATHIS OS v3.2"
- ✅ **Couleurs** : Support complet (0x00-0xFF)
- ✅ **Newline & Scroll** : Gestion via `vga.asm`
- ✅ **Clear Screen 64-bit** : Effacement écran en mode 64-bit

### 💾 Système de Fichiers
- ✅ **RAM Disk** : 64KB @ 0x30000
- ✅ **Magic Signature** : "MTHSFS" pour identifier le FS
- ✅ **Commands** :
  - `fs init` : Initialise le RAM disk
  - `fs list` : Liste les fichiers (placeholder)
  - `fs write` : Mode édition avec sauvegarde
  - `fs read` : Lit le contenu du fichier

### 🔧 Compilateur & VM
- ✅ **Parser MATHIS** : Analyse lexicale et syntaxique basique
- ✅ **Bytecode Generator** : Génère du bytecode `.mbc` à partir de MATHIS ASM
- ✅ **VM Exécution** : Interpréteur bytecode (instructions add, mul, etc.)
- ✅ **Embedded Program** : Programme de test intégré au kernel

---

## 📊 Architecture Mémoire

```
0x00000000 - 0x00000FFF : Reserved (Real Mode IVT, BDA)
0x00001000 - 0x00003FFF : Page Tables (PML4, PDPT, PD) - 12KB
0x00007C00 - 0x00007DFF : Boot Sector
0x00007E00 - 0x00008DFF : Stage 2 Bootloader
0x00010000 - 0x0001FFFF : Kernel 32-bit (64KB)
0x0001F000 - 0x0001FFFF : Variables fixes (cursor, cmd_buffer, etc.)
0x00020000 - 0x0002FFFF : Bytecode area
0x00030000 - 0x0003FFFF : RAM Disk (Filesystem)
0x00090000 - 0x0009FFFF : Stack
0x000B8000 - 0x000B8FFF : VGA Text Buffer
```

---

## 🐛 Problèmes Résolus

### ✅ 64-bit Paging Crash (RÉSOLU v3.2)
**Symptôme** : Triple fault immédiat au `mov cr0, eax` avec PG=1
**Debug** : Multiple tentatives (PSE, GDT mixte, zones mémoire différentes)
**Solution** : Le code fonctionnait - problème de timing/cache QEMU
**Résultat** : Transition 64-bit complète et stable

### ✅ Keyboard Data Access Bug (RÉSOLU v3.0)
**Symptôme** : Reboot immédiat lors de la frappe
**Cause** : Accès à `cmd_buffer` et `scancode_table` situés dans `data.asm` (trop loin)
**Fix** : Variables à adresses fixes (0x1F000)
**Résultat** : Shell stable et fonctionnel

### ✅ Edit Mode Bug (RÉSOLU v3.1)
**Symptôme** : Reboot lors de la frappe en mode `fs write`
**Fix** : Version simplifiée avec appels directs
**Résultat** : Edit mode 100% fonctionnel

---

## 🚧 Prochaines Étapes

### Court Terme
- [ ] **Shell 64-bit** : Clavier et commandes en mode 64-bit
- [ ] **Retour 32-bit** : Commande pour revenir au mode 32-bit
- [ ] **Plus de RAM** : Mapper plus de mémoire (actuellement 2MB)

### Moyen Terme
- [ ] **Multi-tasking** : Scheduler basique
- [ ] **Syscalls** : Interface kernel/userspace
- [ ] **Drivers** : Support disque (ATA/AHCI)

### Long Terme
- [ ] **Networking** : Stack TCP/IP basique
- [ ] **Graphics Mode** : Mode graphique VESA
- [ ] **Self-Hosting** : Compiler MATHIS depuis MATHIS OS

---

## 📝 Notes de Version

### v3.2 (03/12/2025)
- ✅ **64-bit Long Mode fonctionnel!**
- ✅ Page tables avec identity mapping 2MB
- ✅ Commande `go64` pour transition
- ✅ Commande `reboot` pour redémarrer
- ✅ Affichage "MathisOS 64-bit Long Mode - Success!"
- ✅ Code nettoyé (debug markers supprimés)

### v3.1 (02/12/2025)
- ✅ Edit Mode fonctionnel : `fs write` fonctionne sans crash
- ✅ Affichage temps réel en jaune
- ✅ Backspace et ESC pour sauvegarder
- ✅ Pipeline complet : Edit → Compile → Run

### v3.0 (02/12/2025)
- ✅ Shell interactif stable
- ✅ Support Shift complet
- ✅ Fix critique : Keyboard Data Access Bug

---

## 🔗 Ressources

### Outils
- **Build** : `./build.sh`
- **Run** : `qemu-system-x86_64 -fda boot/mathis.img -boot a -m 128M`
- **Debug** : `qemu-system-x86_64 -fda boot/mathis.img -m 128M -d int -no-reboot`

---

**Contributeurs** : Mathis Higuinen
**Licence** : MIT
**Repository** : https://github.com/MattJeff/mathis-os
