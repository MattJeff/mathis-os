# MATHIS OS - Roadmap

## État Actuel (v2.1) ✅

```
╔═══════════════════════════════════════════════════════════════════╗
║                        MATHIS OS v2.1                             ║
╠═══════════════════════════════════════════════════════════════════╣
║  ✅ Boot 16-bit → 32-bit Protected Mode                          ║
║  ✅ Kernel 24KB avec shell interactif                            ║
║  ✅ VM avec 60+ opcodes                                          ║
║  ✅ JARVIS AI Assistant (15+ commandes)                          ║
║  ✅ Compilateur MathisC intégré                                  ║
║  ✅ Compilation + Exécution dans l'OS                            ║
║  ✅ RAM Disk (64KB)                                              ║
║  ✅ Keyboard + VGA + Serial drivers                              ║
╚═══════════════════════════════════════════════════════════════════╝
```

---

## Phase 1: Consolidation (Semaine 1-2)

### 1.1 Stabilité Boot
- [ ] Synchroniser boot.asm/stage2.asm avec l'image fonctionnelle
- [ ] Documenter le processus de build exact
- [ ] Créer script de build automatique

### 1.2 Tests
- [ ] Créer suite de tests pour la VM
- [ ] Tester tous les 60+ opcodes
- [ ] Valider le compilateur avec différents programmes

### 1.3 Documentation
- [x] ARCHITECTURE.md
- [x] ROADMAP.md
- [ ] Documenter chaque opcode en détail
- [ ] Tutoriel "Écrire son premier programme"

---

## Phase 2: Filesystem Persistant (Semaine 3-4)

### 2.1 FAT12 Support
- [ ] Parser FAT12 depuis disquette
- [ ] Lecture de fichiers depuis le disque
- [ ] Écriture sur disque (sauvegarde)

### 2.2 Commandes FS Étendues
- [ ] `fs rm <file>` - Supprimer
- [ ] `fs cp <src> <dst>` - Copier
- [ ] `fs mv <src> <dst>` - Déplacer
- [ ] `fs edit <file>` - Éditeur simple

---

## Phase 3: Porter MathisScript vers l'OS (Semaine 5-8)

> **Note**: Le langage MathisScript existe déjà dans `llml/` (87K+ lignes, Rust).
> L'objectif est de porter progressivement le compilateur vers l'OS Assembly.

### Syntaxe MathisScript (déjà définie)
```javascript
@block("create-user")
@intent("Create a new user")
@pure
func createUser(email: String, password: String) -> Result<User, String> {
    let hashedPassword = crypto.hashPassword(password)
    let user = store.create("User", {
        email: email,
        password: hashedPassword
    })
    return Ok(user)
}
```

### 3.1 Porter le Lexer
- [ ] Tokenizer en Assembly (basé sur `llml/parser/`)
- [ ] Support: keywords, identifiers, strings, numbers
- [ ] Support: annotations (@block, @intent, @pure)

### 3.2 Porter le Parser
- [ ] AST en Assembly
- [ ] Fonctions avec types
- [ ] Expressions complexes
- [ ] Structures de contrôle

### 3.3 Porter le CodeGen
- [ ] Génération bytecode depuis AST
- [ ] Optimisations basiques
- [ ] Support des built-ins

---

## Phase 4: Multitasking (Semaine 9-12)

### 4.1 Scheduler
- [ ] Timer interrupt (IRQ0)
- [ ] Context switching
- [ ] Round-robin scheduler
- [ ] Process table

### 4.2 Processus
- [ ] Création de processus
- [ ] Terminaison propre
- [ ] Communication inter-processus
- [ ] `ps` - Liste des processus
- [ ] `kill <pid>` - Terminer un processus

---

## Phase 5: Réseau (Semaine 13-16)

### 5.1 Driver NE2000/RTL8139
- [ ] Détection carte réseau
- [ ] Envoi/réception de paquets

### 5.2 Stack TCP/IP
- [ ] Ethernet frames
- [ ] ARP
- [ ] IP
- [ ] ICMP (ping)
- [ ] UDP
- [ ] TCP

### 5.3 Applications
- [ ] `ping <ip>`
- [ ] Client HTTP simple
- [ ] Serveur HTTP basique

---

## Phase 6: IA Avancée (Semaine 17-20)

### 6.1 Neural Network
- [ ] Perceptron simple
- [ ] Forward propagation
- [ ] Backpropagation (entraînement)
- [ ] Sauvegarde/chargement des poids

### 6.2 JARVIS Évolué
- [ ] Pattern matching avancé
- [ ] Apprentissage de commandes
- [ ] Suggestions contextuelles
- [ ] Historique et mémoire persistante

### 6.3 Opcodes IA
- [ ] `AI_PREDICT` - Prédiction
- [ ] `AI_TRAIN` - Entraînement
- [ ] `AI_SAVE` - Sauvegarde modèle
- [ ] `AI_LOAD` - Chargement modèle

---

## Phase 7: GUI (Semaine 21-24)

### 7.1 Mode Graphique
- [ ] VGA Mode 13h (320x200, 256 couleurs)
- [ ] Double buffering
- [ ] Primitives (ligne, rectangle, cercle)
- [ ] Fonts bitmap

### 7.2 Window Manager
- [ ] Fenêtres draggables
- [ ] Boutons cliquables
- [ ] Mouse driver
- [ ] Événements souris/clavier

### 7.3 Applications GUI
- [ ] Terminal graphique
- [ ] Éditeur de texte
- [ ] File manager
- [ ] JARVIS UI visuel

---

## Phase 8: Self-Hosting (Semaine 25-28)

### 8.1 Assembler dans l'OS
- [ ] Parser NASM syntax
- [ ] Génération de code machine
- [ ] `asm <file.asm>` - Assembler

### 8.2 Compiler dans l'OS
- [ ] Compiler MathisScript → bytecode entièrement dans l'OS
- [ ] Sans dépendance externe
- [ ] Auto-compilation du compilateur

### 8.3 OS Modifiable
- [ ] Modifier le kernel depuis le kernel
- [ ] Hot-patching
- [ ] Self-evolution

---

## Vision Long Terme

```
┌─────────────────────────────────────────────────────────────────┐
│                    MATHIS OS - Vision 2025                      │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│   🧠 IA Autonome                                                │
│      └── Apprentissage continu                                  │
│      └── Prise de décision                                      │
│      └── Auto-amélioration                                      │
│                                                                 │
│   🌐 Connecté                                                   │
│      └── Stack TCP/IP complète                                  │
│      └── Serveur web intégré                                    │
│      └── API REST                                               │
│                                                                 │
│   🖥️ GUI Moderne                                                │
│      └── Window manager                                         │
│      └── Applications natives                                   │
│      └── Thèmes personnalisables                                │
│                                                                 │
│   🔄 Self-Hosting                                               │
│      └── Compile son propre code                                │
│      └── Modifie son kernel                                     │
│      └── Évolue de manière autonome                             │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## Priorités Immédiates

1. **Script de build** - Automatiser la création de mathis.img
2. **Tests VM** - Valider tous les opcodes
3. **Filesystem** - Ajouter persistance disque
4. **MathisScript** - Étendre le langage

---

## Contribution

Le projet est 100% Assembly. Pour contribuer:

1. Lire ARCHITECTURE.md
2. Étudier kernel.asm
3. Choisir une tâche dans ce ROADMAP
4. Implémenter et tester
5. Pull request

---

*"One person, one OS, one language, one vision."*
