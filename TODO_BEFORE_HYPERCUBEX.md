# MATHIS OS - TODO Avant HyperCubeX

> **Objectif**: OS 100% complet avant d'implémenter l'IA

---

## Priorité HAUTE (Bloquant)

### 1. FAT32 Filesystem
**Pourquoi**: Lire/écrire sur disque réel (clé USB, SD card, HDD)

```
[ ] Lecture MBR et table de partitions
[ ] Parsing Boot Sector FAT32
[ ] Lecture FAT (File Allocation Table)
[ ] Parcours répertoires (root + sous-dossiers)
[ ] Lecture fichiers (chaîne de clusters)
[ ] Écriture fichiers
[ ] Création/suppression fichiers
[ ] Création/suppression dossiers
[ ] Noms longs (LFN - Long File Names)
```

**Fichiers à créer**:
- `boot/kernel/fs/fat32.asm`
- `boot/kernel/fs/fat32_read.asm`
- `boot/kernel/fs/fat32_write.asm`

---

### 2. ELF Loader
**Pourquoi**: Exécuter des programmes externes compilés

```
[ ] Parser ELF header (64-bit)
[ ] Valider magic number et architecture
[ ] Charger program headers (PT_LOAD)
[ ] Mapper segments en mémoire
[ ] Relocation (si PIE)
[ ] Configurer stack utilisateur
[ ] Jump to entry point
[ ] Support .bss (zero-initialized)
```

**Fichiers à créer**:
- `boot/kernel/exec/elf.asm`
- `boot/kernel/exec/loader.asm`

---

### 3. DHCP Client
**Pourquoi**: Obtenir IP automatiquement sur n'importe quel réseau

```
[ ] Envoyer DHCP Discover (broadcast)
[ ] Recevoir DHCP Offer
[ ] Envoyer DHCP Request
[ ] Recevoir DHCP ACK
[ ] Parser options (IP, mask, gateway, DNS)
[ ] Configurer stack réseau avec les infos
[ ] Renouvellement lease (timer)
```

**Fichiers à créer**:
- `boot/kernel/net/dhcp.asm`

---

### 4. DNS Resolver
**Pourquoi**: Résoudre noms de domaine (google.com → IP)

```
[ ] Construire requête DNS (type A)
[ ] Envoyer via UDP port 53
[ ] Parser réponse DNS
[ ] Cache DNS local
[ ] Support CNAME
[ ] Timeout et retry
```

**Fichiers à créer**:
- `boot/kernel/net/dns.asm`

---

## Priorité MOYENNE (Important)

### 5. VESA High Resolution
**Pourquoi**: Meilleur affichage pour GUI et HyperCubeX

```
[ ] Énumérer modes VESA disponibles
[ ] Sélectionner mode (1024x768 ou 1280x720)
[ ] Linear framebuffer mapping
[ ] Adapter GUI au nouveau mode
[ ] Double buffering (anti-flicker)
[ ] Font rendering haute résolution
```

**Fichiers à créer**:
- `boot/kernel/vesa_hires.asm`
- `boot/kernel/font8x16.asm`

---

### 6. Heap Allocator (malloc/free)
**Pourquoi**: Allocation mémoire dynamique propre

```
[ ] Structure heap (liste de blocs libres)
[ ] malloc() - first-fit ou best-fit
[ ] free() - fusion blocs adjacents
[ ] realloc()
[ ] Gestion fragmentation
[ ] Debug: détection leaks
```

**Fichiers à créer**:
- `boot/kernel/mm/heap.asm`

---

### 7. Process Management Complet
**Pourquoi**: Vrais processus isolés

```
[ ] fork() réel (copie espace mémoire)
[ ] exec() réel (charge ELF)
[ ] wait()/waitpid()
[ ] exit() avec cleanup
[ ] Signaux basiques (SIGKILL, SIGTERM)
[ ] Process groups
[ ] Environnement (env vars)
```

**Fichiers à modifier**:
- `boot/kernel/scheduler.asm`
- `boot/kernel/syscalls.asm`

---

## Priorité BASSE (Nice to have)

### 8. Audio Driver (AC97)
```
[ ] Détecter AC97 sur PCI
[ ] Initialiser codec
[ ] Buffer audio (ring buffer)
[ ] Playback PCM
[ ] Mixer (volume)
```

### 9. USB Mass Storage
```
[ ] SCSI over USB (BOT protocol)
[ ] READ(10) / WRITE(10) commands
[ ] Monter comme block device
[ ] Intégrer avec FAT32
```

### 10. RTC (Real Time Clock)
```
[ ] Lire date/heure CMOS
[ ] Formater date/heure
[ ] Commande 'date' dans shell
```

### 11. Serial Console (Debug)
```
[ ] UART 16550 driver
[ ] printf vers serial
[ ] Input depuis serial
[ ] Utile pour debug sans écran
```

---

## Checklist Résumé

```
BLOQUANT:
[ ] FAT32 Filesystem
[ ] ELF Loader
[ ] DHCP Client
[ ] DNS Resolver

IMPORTANT:
[ ] VESA High-Res
[ ] Heap Allocator
[ ] Process Management

BONUS:
[ ] Audio AC97
[ ] USB Mass Storage
[ ] RTC
[ ] Serial Console
```

---

## Ordre d'implémentation suggéré

```
1. DHCP Client      (~200 lignes)   - Réseau fonctionnel partout
2. DNS Resolver     (~150 lignes)   - Peut résoudre des noms
3. Heap Allocator   (~300 lignes)   - Fondation pour le reste
4. FAT32 Read       (~400 lignes)   - Lire fichiers depuis disque
5. ELF Loader       (~300 lignes)   - Exécuter programmes
6. FAT32 Write      (~300 lignes)   - Écrire fichiers
7. VESA High-Res    (~200 lignes)   - Meilleur affichage
8. Process Mgmt     (~400 lignes)   - Fork/exec complet

TOTAL ESTIMÉ: ~2250 lignes ASM
```

---

## Une fois tout ça fait...

```
┌─────────────────────────────────────────────────────────────────┐
│                                                                 │
│   MATHIS OS sera un OS COMPLET avec:                           │
│                                                                 │
│   ✓ Boot depuis disque                                         │
│   ✓ Filesystem FAT32                                           │
│   ✓ Réseau TCP/IP + DHCP + DNS                                │
│   ✓ USB                                                        │
│   ✓ GUI Desktop                                                │
│   ✓ Multitâche                                                 │
│   ✓ Programmes externes (ELF)                                  │
│   ✓ Gestion mémoire complète                                   │
│                                                                 │
│   → PRÊT pour HyperCubeX                                       │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

*Créé: 2025-12-16*
*Objectif: Terminer avant de commencer HyperCubeX*
