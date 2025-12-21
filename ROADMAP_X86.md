# MathisOS x86 - Roadmap Complet

## Légende
- ✅ Fait
- 🔶 Partiel
- ❌ À faire
- 🔴 Priorité haute
- 🟡 Priorité moyenne
- 🟢 Priorité basse

---

## 1. KERNEL / CORE

### 1.1 Boot
| Feature | Status | Priorité | Notes |
|---------|--------|----------|-------|
| Boot sector | ✅ | - | MBR 512 bytes |
| Stage2 bootloader | ✅ | - | Charge le kernel |
| Mode 64-bit | ✅ | - | Long mode activé |
| GDT | ✅ | - | Global Descriptor Table |
| IDT | ✅ | - | Interrupt Descriptor Table |
| Multiboot support | ❌ | 🟢 | Compatible GRUB |

### 1.2 Interrupts
| Feature | Status | Priorité | Notes |
|---------|--------|----------|-------|
| IRQ0 Timer | ✅ | - | PIT 100Hz |
| IRQ1 Keyboard | ✅ | - | PS/2 |
| IRQ12 Mouse | ✅ | - | PS/2 |
| Exceptions (div0, etc) | 🔶 | 🟡 | BSOD basique |
| Double fault handler | ❌ | 🟡 | Éviter triple fault |
| Page fault handler | ❌ | 🔴 | Pour mémoire virtuelle |

### 1.3 Mémoire
| Feature | Status | Priorité | Notes |
|---------|--------|----------|-------|
| Physical memory map | 🔶 | 🟡 | E820 map |
| kmalloc/kfree | ✅ | - | Allocateur basique |
| Memory pools | ❌ | 🟡 | Slab allocator |
| Virtual memory | ❌ | 🔴 | Paging 4-level |
| Memory protection | ❌ | 🔴 | User/Kernel séparation |
| Heap management | 🔶 | 🟡 | Améliorer fragmentation |

### 1.4 Processus
| Feature | Status | Priorité | Notes |
|---------|--------|----------|-------|
| Process structure (PCB) | ✅ | - | Basique |
| Context switch | ✅ | - | Timer-based |
| Scheduler round-robin | ✅ | - | Préemptif |
| Priority scheduler | ❌ | 🟡 | Multi-level queue |
| Process creation | ❌ | 🔴 | fork/exec |
| Process termination | ❌ | 🔴 | exit/kill |
| Threads | ❌ | 🟡 | Kernel threads |
| User threads | ❌ | 🟢 | pthread-like |
| IPC (pipes) | ❌ | 🟡 | Inter-process comm |
| IPC (shared memory) | ❌ | 🟡 | mmap |
| IPC (signals) | ❌ | 🟡 | SIGTERM, SIGKILL |

### 1.5 System Calls
| Feature | Status | Priorité | Notes |
|---------|--------|----------|-------|
| Syscall interface | 🔶 | 🔴 | int 0x80 ou syscall |
| File syscalls | ❌ | 🔴 | open, read, write, close |
| Process syscalls | ❌ | 🔴 | fork, exec, exit, wait |
| Memory syscalls | ❌ | 🟡 | mmap, brk |
| Time syscalls | ❌ | 🟡 | time, sleep |

---

## 2. DRIVERS

### 2.1 Storage
| Feature | Status | Priorité | Notes |
|---------|--------|----------|-------|
| ATA PIO | ✅ | - | Disque dur basique |
| ATA DMA | ❌ | 🟡 | Plus rapide |
| AHCI (SATA) | ❌ | 🟡 | Disques modernes |
| NVMe | ❌ | 🟢 | SSD rapides |
| USB Mass Storage | ❌ | 🟡 | Clés USB |
| CD/DVD | ❌ | 🟢 | ATAPI |

### 2.2 Input
| Feature | Status | Priorité | Notes |
|---------|--------|----------|-------|
| PS/2 Keyboard | ✅ | - | Fonctionne |
| PS/2 Mouse | ✅ | - | Fonctionne |
| USB Keyboard | ❌ | 🔴 | UHCI/EHCI/xHCI |
| USB Mouse | ❌ | 🔴 | UHCI/EHCI/xHCI |
| Touchpad | ❌ | 🟢 | Synaptics |

### 2.3 Display
| Feature | Status | Priorité | Notes |
|---------|--------|----------|-------|
| VBE Framebuffer | ✅ | - | Mode graphique |
| Mode switching | 🔶 | 🟡 | Changer résolution |
| Double buffering | 🔶 | 🟡 | Éviter flicker |
| Hardware cursor | ❌ | 🟢 | Curseur GPU |
| GPU 2D accel | ❌ | 🟢 | Rectangles rapides |

### 2.4 Audio
| Feature | Status | Priorité | Notes |
|---------|--------|----------|-------|
| PC Speaker | ❌ | 🔴 | Beep basique |
| Sound Blaster 16 | ❌ | 🟡 | Audio legacy |
| AC97 | ❌ | 🟡 | Audio codec |
| Intel HDA | ❌ | 🟡 | Audio moderne |
| Mixer | ❌ | 🟡 | Volume control |

### 2.5 Network
| Feature | Status | Priorité | Notes |
|---------|--------|----------|-------|
| RTL8139 | ❌ | 🟡 | NIC simple |
| E1000 | 🔶 | 🟡 | Intel NIC |
| Virtio-net | ❌ | 🟢 | QEMU virtuel |

### 2.6 Autres
| Feature | Status | Priorité | Notes |
|---------|--------|----------|-------|
| RTC | ✅ | - | Horloge temps réel |
| PCI enumeration | 🔶 | 🟡 | Détecter périphériques |
| ACPI | 🔶 | 🔴 | Power management |
| Serial port (COM) | ❌ | 🟢 | Debug output |
| Parallel port (LPT) | ❌ | 🟢 | Imprimante legacy |

---

## 3. FILESYSTEM

### 3.1 FAT32
| Feature | Status | Priorité | Notes |
|---------|--------|----------|-------|
| Read files | ✅ | - | Fonctionne |
| Write files | ✅ | - | Fonctionne |
| Create files | ✅ | - | Fonctionne |
| Delete files | ✅ | - | Fonctionne |
| Create directories | ✅ | - | Fonctionne |
| Delete directories | ❌ | 🔴 | Récursif |
| Rename | 🔶 | 🔴 | Fichiers et dossiers |
| Long filenames (LFN) | ❌ | 🔴 | VFAT |
| File attributes | ❌ | 🟡 | Hidden, system, etc |
| Timestamps | ❌ | 🟡 | Created, modified |

### 3.2 VFS (Virtual File System)
| Feature | Status | Priorité | Notes |
|---------|--------|----------|-------|
| VFS layer | 🔶 | 🟡 | Abstraction |
| Mount points | ❌ | 🟡 | /mnt/usb etc |
| Path resolution | ✅ | - | /DESKTOP/file.txt |
| File descriptors | ❌ | 🔴 | fd table per process |
| File permissions | ❌ | 🟢 | rwx |

### 3.3 Autres FS
| Feature | Status | Priorité | Notes |
|---------|--------|----------|-------|
| ext2 | ❌ | 🟢 | Linux FS simple |
| ISO9660 | ❌ | 🟢 | CD-ROM |
| ramfs | ❌ | 🟡 | RAM filesystem |
| devfs | ❌ | 🟡 | /dev/... |
| procfs | ❌ | 🟢 | /proc/... |

---

## 4. USER INTERFACE

### 4.1 Desktop
| Feature | Status | Priorité | Notes |
|---------|--------|----------|-------|
| Background | ✅ | - | Couleur unie |
| Wallpaper (BMP) | ❌ | 🟡 | Image de fond |
| Icons | ✅ | - | Terminal, Files, Calc, Clock |
| Icon drag & drop | ✅ | - | Déplacer icônes |
| Icon grid snap | ❌ | 🟢 | Aligner sur grille |
| Desktop context menu | ❌ | 🟡 | Clic droit |
| Create file/folder on desktop | ✅ | - | Dialog |
| Recycle bin | ❌ | 🟢 | Corbeille |

### 4.2 Taskbar
| Feature | Status | Priorité | Notes |
|---------|--------|----------|-------|
| Taskbar | ✅ | - | En bas |
| Start button | 🔶 | 🔴 | Menu basique |
| Start menu | ❌ | 🔴 | Liste d'apps |
| Window buttons | ✅ | - | Fenêtres ouvertes |
| System tray | ❌ | 🟡 | Icônes système |
| Clock in taskbar | ✅ | - | Heure affichée |
| Volume icon | ❌ | 🟡 | Contrôle son |
| Network icon | ❌ | 🟢 | Status réseau |
| Battery icon | ❌ | 🟢 | Laptops |

### 4.3 Window Manager
| Feature | Status | Priorité | Notes |
|---------|--------|----------|-------|
| Create windows | ✅ | - | Fonctionne |
| Move windows | ✅ | - | Drag title bar |
| Resize windows | ✅ | - | Coin bas-droite |
| Close button | ✅ | - | Rouge macOS style |
| Minimize button | ✅ | - | Jaune |
| Maximize button | ✅ | - | Vert |
| Window focus | ✅ | - | Click to focus |
| Z-order | 🔶 | 🟡 | Bring to front |
| Alt+Tab | ❌ | 🔴 | Switch windows |
| Window snapping | ❌ | 🟡 | Snap to edges |
| Minimize to taskbar | 🔶 | 🟡 | Restore from taskbar |
| Window animations | ❌ | 🟢 | Open/close anim |

### 4.4 Menus & Dialogs
| Feature | Status | Priorité | Notes |
|---------|--------|----------|-------|
| Dialog boxes | 🔶 | 🟡 | Message, input |
| Context menus | ❌ | 🔴 | Clic droit |
| Dropdown menus | ❌ | 🟡 | Menu bar |
| File picker | ❌ | 🔴 | Open/Save dialog |
| Color picker | ❌ | 🟢 | Choisir couleur |
| Alert/Confirm | ❌ | 🔴 | OK/Cancel |

### 4.5 Widgets
| Feature | Status | Priorité | Notes |
|---------|--------|----------|-------|
| Button | 🔶 | 🟡 | Clickable |
| Label | ✅ | - | Text display |
| Text input | 🔶 | 🟡 | Single line |
| Text area | 🔶 | 🟡 | Multi line |
| Checkbox | ❌ | 🟡 | Toggle |
| Radio button | ❌ | 🟡 | Select one |
| Slider | ❌ | 🟡 | Volume etc |
| Progress bar | ❌ | 🟡 | Loading |
| List view | 🔶 | 🟡 | File list |
| Tree view | ❌ | 🟢 | Folder tree |
| Tabs | ❌ | 🟡 | Tab control |
| Scrollbar | ❌ | 🔴 | Scroll content |

---

## 5. APPLICATIONS

### 5.1 Apps existantes
| App | Status | À améliorer |
|-----|--------|-------------|
| File Manager | ✅ | Navigation, preview, copier/coller |
| Text Editor | ✅ | Scroll, sélection, save dialog |
| Calculator | ✅ | Historique, fonctions scientifiques |
| Clock | ✅ | Alarme, timer, stopwatch |
| Terminal | 🔶 | Commandes, historique, couleurs |

### 5.2 Apps à créer
| App | Priorité | Description |
|-----|----------|-------------|
| Settings | 🔴 | Wallpaper, couleurs, résolution |
| Image Viewer | 🟡 | BMP, peut-être PNG |
| Music Player | 🟡 | WAV, interface simple |
| Snake | 🔴 | Jeu classique |
| Tetris | 🟡 | Jeu classique |
| Minesweeper | 🟡 | Jeu classique |
| Paint | 🟡 | Dessin simple |
| Notepad+ | 🟡 | Éditeur amélioré |
| Task Manager | 🟡 | Liste processus |
| System Info | 🟢 | CPU, RAM, disque |
| Help | 🟢 | Documentation |
| About | 🟢 | À propos de MathisOS |

### 5.3 Terminal / Shell
| Feature | Status | Priorité | Notes |
|---------|--------|----------|-------|
| Command prompt | ✅ | - | Basique |
| Command history | ❌ | 🔴 | Flèches haut/bas |
| ls | ❌ | 🔴 | List files |
| cd | ❌ | 🔴 | Change directory |
| pwd | ❌ | 🔴 | Print working dir |
| cat | ❌ | 🔴 | Show file content |
| mkdir | ❌ | 🔴 | Create directory |
| rm | ❌ | 🔴 | Remove file |
| cp | ❌ | 🟡 | Copy file |
| mv | ❌ | 🟡 | Move file |
| echo | ❌ | 🟡 | Print text |
| clear | ❌ | 🔴 | Clear screen |
| help | ❌ | 🔴 | List commands |
| reboot | ❌ | 🔴 | Restart system |
| shutdown | ❌ | 🔴 | Power off |
| date | ❌ | 🟡 | Show date/time |
| whoami | ❌ | 🟢 | Current user |

---

## 6. INPUT / OUTPUT

### 6.1 Keyboard
| Feature | Status | Priorité | Notes |
|---------|--------|----------|-------|
| Basic input | ✅ | - | Fonctionne |
| Shift/Caps | ✅ | - | Majuscules |
| Ctrl combinations | 🔶 | 🔴 | Ctrl+C, Ctrl+V |
| Alt combinations | ❌ | 🔴 | Alt+Tab, Alt+F4 |
| Function keys | 🔶 | 🟡 | F1-F12 |
| Numpad | ❌ | 🟡 | Pavé numérique |
| Dead keys | ❌ | 🟢 | Accents ^ ` |
| Keyboard layouts | ❌ | 🟡 | AZERTY, QWERTZ |
| Key repeat | ✅ | - | Hold key |

### 6.2 Mouse
| Feature | Status | Priorité | Notes |
|---------|--------|----------|-------|
| Movement | ✅ | - | Fonctionne |
| Left click | ✅ | - | Fonctionne |
| Right click | 🔶 | 🔴 | Context menu |
| Middle click | ❌ | 🟢 | Paste |
| Scroll wheel | ❌ | 🔴 | Scroll content |
| Double click | 🔶 | 🟡 | Open items |
| Drag & drop | ✅ | - | Windows, icons |
| Cursor themes | ❌ | 🟢 | Different cursors |

### 6.3 Clipboard
| Feature | Status | Priorité | Notes |
|---------|--------|----------|-------|
| Text clipboard | ❌ | 🔴 | Copy/paste text |
| Ctrl+C | ❌ | 🔴 | Copy |
| Ctrl+V | ❌ | 🔴 | Paste |
| Ctrl+X | ❌ | 🔴 | Cut |
| File clipboard | ❌ | 🟡 | Copy/paste files |
| Clipboard history | ❌ | 🟢 | Multiple items |

---

## 7. AUDIO

| Feature | Status | Priorité | Notes |
|---------|--------|----------|-------|
| PC Speaker beep | ❌ | 🔴 | Fréquence simple |
| System sounds | ❌ | 🟡 | Startup, error |
| WAV playback | ❌ | 🟡 | Audio basique |
| Volume control | ❌ | 🟡 | Mixer |
| Mute | ❌ | 🟡 | Toggle |

---

## 8. NETWORKING (Optionnel)

### 8.1 Stack
| Feature | Status | Priorité | Notes |
|---------|--------|----------|-------|
| Ethernet driver | 🔶 | 🟡 | E1000 |
| ARP | ❌ | 🟡 | Address resolution |
| IP | ❌ | 🟡 | Internet Protocol |
| ICMP | ❌ | 🟡 | Ping |
| UDP | ❌ | 🟡 | Datagram |
| TCP | ❌ | 🟢 | Connection |
| DHCP client | ❌ | 🟢 | Auto IP |
| DNS client | ❌ | 🟢 | Name resolution |

### 8.2 Apps réseau
| Feature | Status | Priorité | Notes |
|---------|--------|----------|-------|
| ping | ❌ | 🟡 | Test connectivité |
| Simple HTTP | ❌ | 🟢 | Fetch web pages |

---

## 9. POWER MANAGEMENT

| Feature | Status | Priorité | Notes |
|---------|--------|----------|-------|
| ACPI init | 🔶 | 🔴 | Détecter ACPI |
| Shutdown | ❌ | 🔴 | Power off propre |
| Reboot | ❌ | 🔴 | Restart |
| Sleep | ❌ | 🟢 | S3 suspend |
| CPU idle | ❌ | 🟡 | HLT quand idle |

---

## 10. SÉCURITÉ (Basique)

| Feature | Status | Priorité | Notes |
|---------|--------|----------|-------|
| Ring 3 user mode | 🔶 | 🟡 | Séparation |
| User accounts | ❌ | 🟢 | Login |
| Password | ❌ | 🟢 | Hash passwords |
| File permissions | ❌ | 🟢 | rwx |
| Secure boot | ❌ | 🟢 | Vérifier kernel |

---

## 11. FONTS & GRAPHICS

| Feature | Status | Priorité | Notes |
|---------|--------|----------|-------|
| Bitmap font 8x16 | ✅ | - | Fonctionne |
| Multiple font sizes | ❌ | 🟡 | 8x8, 16x16, etc |
| Anti-aliased fonts | ❌ | 🟢 | Smooth text |
| TTF support | ❌ | 🟢 | TrueType |
| Icons (sprites) | 🔶 | 🟡 | Meilleurs icônes |
| BMP loading | ❌ | 🟡 | Images |
| PNG loading | ❌ | 🟢 | Images avec alpha |
| Alpha blending | ❌ | 🟡 | Transparence |

---

## 12. INTERNATIONALISATION

| Feature | Status | Priorité | Notes |
|---------|--------|----------|-------|
| UTF-8 support | ❌ | 🟡 | Unicode |
| Keyboard layouts | ❌ | 🟡 | AZERTY, etc |
| Date formats | ❌ | 🟢 | DD/MM/YYYY |
| Language selection | ❌ | 🟢 | UI multilingue |

---

## 13. DOCUMENTATION & DEBUG

| Feature | Status | Priorité | Notes |
|---------|--------|----------|-------|
| Serial debug output | ❌ | 🟡 | COM1 logging |
| Kernel panic screen | 🔶 | 🟡 | BSOD info |
| Stack trace | ❌ | 🟡 | Debug crashes |
| Debug console | ❌ | 🟢 | In-OS debug |
| Help system | ❌ | 🟢 | F1 help |
| Man pages | ❌ | 🟢 | Command help |

---

## STATISTIQUES

### Par catégorie
| Catégorie | Fait | Partiel | À faire |
|-----------|------|---------|---------|
| Kernel/Core | 8 | 4 | 18 |
| Drivers | 5 | 3 | 15 |
| Filesystem | 5 | 2 | 12 |
| UI | 15 | 8 | 25 |
| Applications | 5 | 2 | 15 |
| Input/Output | 8 | 5 | 15 |
| Audio | 0 | 0 | 5 |
| Network | 0 | 1 | 10 |
| Power | 0 | 1 | 4 |
| **TOTAL** | **~46** | **~26** | **~120** |

### Estimation temps
- 🔴 Priorité haute : ~30 features = 2-3 mois
- 🟡 Priorité moyenne : ~50 features = 3-4 mois
- 🟢 Priorité basse : ~40 features = 2-3 mois
- **TOTAL estimé : 6-12 mois**

---

## ORDRE RECOMMANDÉ

### Phase 1 - Core (1-2 mois)
1. ✅ Finir bugs actuels
2. Alt+Tab switch windows
3. Ctrl+C/V clipboard
4. Start menu fonctionnel
5. Scrollbar pour listes
6. Context menu (clic droit)
7. Shutdown/Reboot (ACPI)

### Phase 2 - Apps (1-2 mois)
1. Settings app
2. Snake game
3. Image viewer (BMP)
4. Terminal commands (ls, cd, cat)
5. Tetris
6. PC Speaker son

### Phase 3 - Polish (1-2 mois)
1. Long filenames (LFN)
2. File picker dialog
3. Better icons/fonts
4. Keyboard layouts
5. System tray
6. Task manager

### Phase 4 - Advanced (2-4 mois)
1. Virtual memory
2. USB support basique
3. Network stack
4. ELF loader
5. User mode apps

---

*Document généré pour MathisOS - Roadmap vers un OS complet*
*Dernière mise à jour : Décembre 2024*
