# MATHIS OS - Architecture Complète

## Vue d'ensemble

MATHIS OS est un système d'exploitation bare-metal écrit en 100% Assembly x86, avec une VM intégrée et un assistant IA (JARVIS).

```
┌─────────────────────────────────────────────────────────────────┐
│                         MATHIS OS v2.1                          │
├─────────────────────────────────────────────────────────────────┤
│  Shell Interactif  │  JARVIS AI  │  Compilateur MathisC        │
├─────────────────────────────────────────────────────────────────┤
│                    VM (60+ opcodes)                             │
├─────────────────────────────────────────────────────────────────┤
│  Keyboard Driver  │  VGA Text  │  Serial Port  │  RAM Disk     │
├─────────────────────────────────────────────────────────────────┤
│                    Kernel (24KB, 32-bit)                        │
├─────────────────────────────────────────────────────────────────┤
│  Stage2 Loader (4KB)  │  Boot Sector (512B)                     │
└─────────────────────────────────────────────────────────────────┘
```

---

## 1. Processus de Boot

### Boot Sector (512 bytes)
```
Fichier: boot/boot.asm
Adresse: 0x7C00
Mode: 16-bit Real Mode
```
- Chargé par le BIOS
- Configure les segments (DS, ES, SS)
- Charge Stage2 (8 secteurs) à 0x7E00
- Affiche "MATHIS OS"

### Stage2 Loader (4KB)
```
Fichier: boot/stage2.asm
Adresse: 0x7E00
Mode: 16-bit → 32-bit
```
- Affiche "Loading..."
- Charge le kernel (48 secteurs) à 0x10000
- Active A20 line
- Configure GDT (Global Descriptor Table)
- Passe en Protected Mode (32-bit)
- Jump vers kernel_entry

### Kernel (24KB)
```
Fichier: boot/kernel.asm
Adresse: 0x10000
Mode: 32-bit Protected Mode
```
- Configure la stack à 0x2FFFF
- Initialise le PIC (Programmable Interrupt Controller)
- Charge l'IDT (Interrupt Descriptor Table)
- Initialise le port série (COM1)
- Affiche le banner ASCII "MATHIS OS"
- Entre dans la boucle principale du shell

---

## 2. Memory Map

```
0x00000 - 0x003FF : IVT (Interrupt Vector Table) - BIOS
0x00400 - 0x004FF : BDA (BIOS Data Area)
0x00500 - 0x07BFF : Libre (utilisable)
0x07C00 - 0x07DFF : Boot sector (512 bytes)
0x07E00 - 0x0FFFF : Stage 2 loader
0x10000 - 0x15FFF : Kernel (24KB)
0x16000 - 0x1FFFF : Libre
0x20000 - 0x20FFF : Bytecode chargé
0x21000 - 0x24FFF : Bytecode compilé (output)
0x25000 - 0x2FFFF : VM Stack
0x30000 - 0x3FFFF : RAM Disk (64KB filesystem)
0xB8000 - 0xB8FA0 : VGA Text Buffer (80x25x2)
```

---

## 3. VM (Virtual Machine)

### Architecture Stack-Based
```
EBP = Stack Pointer (grandit vers le bas depuis 0x25000)
ESI = Instruction Pointer (pointe vers le bytecode)
```

### 60+ Opcodes Implémentés

| Range | Catégorie | Opcodes |
|-------|-----------|---------|
| 0x00-0x0F | Control | NOP, HALT, PANIC |
| 0x10-0x1F | Constants | CONST, CONST_NONE, CONST_TRUE, CONST_FALSE, CONST_I64, CONST_F64, CONST_STR, CONST_SMALL |
| 0x20-0x2F | Variables | GET_LOCAL, SET_LOCAL, GET_GLOBAL, SET_GLOBAL |
| 0x30-0x3F | Arithmetic | ADD, SUB, MUL, DIV, MOD, NEG |
| 0x40-0x4F | Comparison | EQ, NE, LT, LE, GT, GE |
| 0x50-0x5F | Logic | AND, OR, NOT, BIT_AND, BIT_OR, BIT_XOR, BIT_NOT, SHL, SHR |
| 0x60-0x6F | Control Flow | JUMP, JUMP_IF_TRUE, JUMP_IF_FALSE, CALL, RET |
| 0x70-0x7F | Stack | POP, DUP, DUP2, SWAP, ROT, OVER |
| 0x80-0x8F | Objects | GET_FIELD, SET_FIELD, MAKE_STRUCT |
| 0x90-0x9F | Collections | MAKE_LIST, INDEX, INDEX_SET, LEN, PUSH |
| 0xA0-0xAF | AI | AI_BREAK, AI_CALL, AI_DECIDE, AI_LEARN |
| 0xC0-0xCF | System | SYSCALL, ALLOC, FREE, PRINT, READ |

### Format Bytecode (.mbc)
```
Offset  Size  Description
0x00    4     Magic "MASM"
0x04    2     Version
0x06    2     Flags
0x08    56    Reserved
0x40    ...   Code section
```

---

## 4. Shell Interactif

### Commandes Disponibles

| Commande | Description |
|----------|-------------|
| `help` | Liste les commandes |
| `clear` | Efface l'écran |
| `run <file>` | Exécute un programme |
| `jarvis <cmd>` | Assistant IA |
| `fs <cmd>` | Commandes filesystem |
| `mathisc` | Info compilateur |
| `compile <file>` | Compile .mhs → .mbc |
| `runmbc` | Exécute le bytecode compilé |

### JARVIS Commands

| Commande | Description |
|----------|-------------|
| `jarvis help` | Liste des commandes JARVIS |
| `jarvis self` | Mode self-awareness |
| `jarvis code` | Info sur le kernel |
| `jarvis evolve` | Mode évolution |
| `jarvis learn` | Mode apprentissage |
| `jarvis think` | Mode réflexion |
| `jarvis build` | Construction de features |
| `jarvis spawn` | Création d'instances IA |
| `jarvis memory` | État mémoire |
| `jarvis goal` | Objectifs |
| `jarvis status` | État système |

---

## 5. Filesystem (RAM Disk)

```
Adresse: 0x30000
Taille: 64KB
```

### Commandes FS

| Commande | Description |
|----------|-------------|
| `fs ls` | Liste les fichiers |
| `fs cat <file>` | Affiche le contenu |
| `fs write <file>` | Écrit un fichier |
| `fs mkdir <dir>` | Crée un dossier |

---

## 6. Compilateur MathisC

Le compilateur intégré compile MathisScript (.mhs) en bytecode (.mbc).

### Pipeline
```
Source (.mhs) → Lexer → Parser → CodeGen → Bytecode (.mbc)
```

### Exemple
```
Source: let x = 42 + 58; print(x);
Output: 23 bytes de bytecode
Result: 100
```

### Fichiers du Compilateur
```
mathisc/
├── lexer.masm      # Tokenization
├── parser.masm     # Parsing
├── codegen.masm    # Code generation
├── mathisc_v7.masm # Compilateur complet
└── mathisc.mhs     # Source en MathisScript
```

---

## 7. Drivers

### Keyboard (IRQ1)
- Interrupt handler à IDT[0x21]
- Scancode → ASCII conversion
- Buffer de commande (256 bytes max)
- Gère Enter, Backspace, caractères

### VGA Text Mode
- Buffer à 0xB8000
- 80x25 caractères
- Format: [char][attr] par cellule
- Couleurs: 0x0A (vert), 0x07 (gris), 0x0E (jaune)

### Serial Port (COM1)
- Port: 0x3F8
- Baud: 9600
- Pour communication avec JARVIS externe (Python)

---

## 8. Structure du Projet

```
mathis-os/
├── boot/
│   ├── boot.asm          # Boot sector source
│   ├── boot.bin          # Boot sector compilé
│   ├── stage2.asm        # Stage 2 source
│   ├── stage2.bin        # Stage 2 compilé
│   ├── kernel.asm        # Kernel source (1982 lignes)
│   ├── kernel.bin        # Kernel compilé (24KB)
│   └── mathis.img        # Image disque bootable
│
├── mathisc/              # Compilateur MathisC
│   ├── lexer.masm
│   ├── parser.masm
│   ├── codegen.masm
│   ├── mathisc_v7.masm
│   ├── main.masm
│   └── mathisc.mhs
│
├── examples/             # Programmes démo
│   ├── hello.masm
│   ├── calculator.masm
│   ├── ai_demo.masm
│   ├── crypto_demo.masm
│   └── simple_math.masm
│
├── programs/             # Programmes test
│   ├── hello.masm
│   └── test.masm
│
├── jarvis/               # Bridge Python (optionnel)
│   ├── jarvis.py
│   └── serial_bridge.py
│
├── llml-mathis/          # Future stdlib
│   ├── core/             # Types, memory, strings
│   ├── stdlib/           # IO, math, collections
│   ├── ai/               # Neural, inference
│   ├── agi/              # Consciousness, learning
│   ├── compiler/         # Lexer, parser, codegen
│   ├── runtime/          # VM, scheduler, GC
│   ├── database/         # SQL, storage
│   └── network/          # HTTP, TCP, WebSocket
│
└── docs/                 # Spécifications (00-08)
```

---

## 9. Build & Run

### Compiler le Kernel
```bash
cd boot
nasm -f bin boot.asm -o boot.bin
nasm -f bin stage2.asm -o stage2.bin
nasm -f bin kernel.asm -o kernel.bin
cat boot.bin stage2.bin kernel.bin > mathis.img
```

### Lancer dans QEMU
```bash
qemu-system-i386 -fda boot/mathis.img -boot a -m 32M
```

### Avec JARVIS Bridge
```bash
./run_with_jarvis.sh
```

---

## 10. Statistiques

| Métrique | Valeur |
|----------|--------|
| Taille kernel.asm | 50KB (1982 lignes) |
| Taille kernel.bin | 24KB |
| Taille mathis.img | 29KB |
| Opcodes VM | 60+ |
| Commandes JARVIS | 15+ |
| RAM Disk | 64KB |
