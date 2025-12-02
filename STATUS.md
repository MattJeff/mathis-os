# MATHIS OS - État Actuel du Projet

> **Dernière mise à jour** : 2 décembre 2025  
> **Version** : v3.1 - Edit Mode fonctionnel + Shell interactif

---

## ✅ Fonctionnalités Implémentées

### 🖥️ Kernel & Boot
- ✅ **Boot Sector** : Chargement via BIOS (mode floppy)
- ✅ **Stage 2 Bootloader** : Passage en mode protégé 32-bit, chargement du kernel (64 KB)
- ✅ **GDT** : Global Descriptor Table configurée (Code/Data segments plats 4GB)
- ✅ **IDT** : Interrupt Descriptor Table avec patchage dynamique pour le clavier
- ✅ **PIC** : Programmable Interrupt Controller configuré (IRQ1 = clavier)

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
  - `compile` : Compilateur MATHIS → Bytecode
  - `runmbc` : Machine virtuelle pour exécuter le bytecode
  - `jarvis` : Assistant IA (placeholder)

### 🎨 Affichage VGA
- ✅ **Mode Texte** : 80x25 caractères (VGA buffer @ 0xB8000)
- ✅ **Banner ASCII** : Logo "MATHIS OS v3.0"
- ✅ **Couleurs** : Support complet (0x00-0xFF)
- ✅ **Newline & Scroll** : Gestion via `vga.asm`

### 💾 Système de Fichiers
- ✅ **RAM Disk** : 64KB @ 0x30000
- ✅ **Magic Signature** : "MTHSFS" pour identifier le FS
- ✅ **Commands** :
  - `fs init` : Initialise le RAM disk
  - `fs list` : Liste les fichiers (placeholder)
  - `fs write` : **Issue connue** (voir ci-dessous)
  - `fs read` : Lit le contenu du fichier

### 🔧 Compilateur & VM
- ✅ **Parser MATHIS** : Analyse lexicale et syntaxique basique
- ✅ **Bytecode Generator** : Génère du bytecode `.mbc` à partir de MATHIS ASM
- ✅ **VM Exécution** : Interpréteur bytecode (instructions add, mul, etc.)
- ✅ **Embedded Program** : Programme de test intégré au kernel

---

## ⚠️ Problèmes Connus

### ⚠️ Mémoire & Paging
**Statut** : Désactivé  
**Module** : `memory.asm` (commenté dans `core.asm`)  
**Raison** : Conflit d'adresses lors du chargement à 0x80000  
**Impact** : Pas de pagination, pas de mode 64-bit pour l'instant

### 🐛 Keyboard Data Access Bug (RÉSOLU v3.0)
**Symptôme** : Reboot immédiat lors de la frappe  
**Cause** : Accès à `cmd_buffer` et `scancode_table` situés dans `data.asm` (trop loin en mémoire)  
**Fix** : Déplacement de toutes les variables vers `keyboard.asm` (local data)  
**Résultat** : Shell stable et fonctionnel

### 🐛 Edit Mode Bug (RÉSOLU v3.1)
**Symptôme** : Reboot lors de la frappe en mode `fs write`  
**Cause** : Appels à des fonctions helper non testées (`print_string_local`, etc.)  
**Fix** : Version simplifiée avec appels directs à `vga_newline` et `shell_prompt`  
**Résultat** : Edit mode 100% fonctionnel (affichage jaune + sauvegarde + backspace)

---

## 🚧 En Cours

### 🔨 Architecture
- [ ] **Paging** : Réimplémenter le module mémoire avec une meilleure architecture
- [ ] **64-bit Mode** : Passage en Long Mode pour plus de puissance
- [ ] **Multi-tasking** : Scheduler basique pour exécuter plusieurs programmes

### 🧠 IA Runtime
- [ ] **JARVIS Integration** : Connexion avec le runtime IA (LLML-Mathis)
- [ ] **Dynamic Compilation** : JIT pour optimiser le bytecode
- [ ] **Neural Core** : Module d'inférence IA embarqué

### 📝 Edit Mode
- [ ] **Debug & Fix** : Résoudre le crash du mode éditeur
- [ ] **Syntax Highlighting** : Coloration syntaxique MATHIS
- [ ] **Multi-line Support** : Éditeur avec plusieurs lignes

---

## 📊 Statistiques du Code

| Composant | Fichier | Lignes | Taille |
|-----------|---------|--------|--------|
| Kernel Core | `core.asm` | 186 | 7.6 KB |
| Keyboard | `keyboard.asm` | 250 | 7.4 KB |
| Shell | `shell.asm` | 127 | 3.1 KB |
| VGA | `vga.asm` | ~80 | 1.6 KB |
| Filesystem | `fs.asm` | 101 | 2.2 KB |
| VM | `vm.asm` | ~200 | 1.1 KB |
| Parser | `parser.asm` | ~150 | 4.8 KB |
| Data | `data.asm` | 100 | 5.9 KB |
| **Total Kernel** | `kernel.bin` | **~1200** | **64 KB** |

---

## 🎯 Prochaines Étapes

### Court Terme (Sprint 1)
1. **Fixer Edit Mode** : Déboguer et réactiver `fs write`
2. **Tests** : Créer des tests pour chaque commande shell
3. **Documentation** : Compléter le guide utilisateur

### Moyen Terme (Sprint 2)
4. **Améliorer Parser** : Support complet de la syntaxe MATHIS
5. **Étendre VM** : Ajouter les instructions manquantes (branches, loops)
6. **Persistance** : Sauvegarder le filesystem sur disque

### Long Terme (Roadmap)
7. **Networking** : Stack TCP/IP basique
8. **Graphics Mode** : Passage en mode graphique (VGA 320x200 ou VESA)
9. **Self-Hosting** : Compiler MATHIS depuis MATHIS OS

---

## 🔗 Ressources

### Documentation
- [00-OVERVIEW.md](00-OVERVIEW.md) - Vue d'ensemble du projet
- [01-MATHIS-ASM-SPEC.md](01-MATHIS-ASM-SPEC.md) - Spécification MASM
- [02-BYTECODE-FORMAT.md](02-BYTECODE-FORMAT.md) - Format du bytecode
- [03-OPCODES.md](03-OPCODES.md) - Liste des opcodes
- [04-KERNEL-SPEC.md](04-KERNEL-SPEC.md) - Architecture kernel
- [08-IMPLEMENTATION-GUIDE.md](08-IMPLEMENTATION-GUIDE.md) - Guide d'implémentation

### Outils
- **Build** : `./build.sh` (NASM + concat)
- **Run** : `qemu-system-i386 -fda boot/mathis.img -boot a -m 32M`
- **Debug** : `qemu-system-i386 -fda boot/mathis.img -boot a -m 32M -s -S` (+ GDB)

---

## 📝 Notes de Version

### v3.1 (02/12/2025 - 11:55)
- ✅ **Edit Mode fonctionnel** : `fs write` fonctionne sans crash
- ✅ Affichage temps réel en jaune
- ✅ Backspace et ESC pour sauvegarder
- ✅ Pipeline complet : Edit → Compile → Run
- 🔧 Fix : Version simplifiée sans helpers buggés

### v3.0 (02/12/2025)
- ✅ Shell interactif stable
- ✅ Support Shift complet
- ✅ Fix critique : Keyboard Data Access Bug
- ⚠️ Edit Mode temporairement désactivé

### v2.5 (01/12/2025)
- ✅ Commandes shell de base
- ✅ Compilateur MATHIS → Bytecode
- ✅ VM avec exécution basique

### v2.0 (Précédent)
- ✅ Boot sector + Stage2
- ✅ Mode protégé 32-bit
- ✅ IDT/PIC configuration

---

**Contributeurs** : Mathis Higuinen  
**Licence** : MIT  
**Repository** : https://github.com/MattJeff/mathis-os (à vérifier)
