# LINKER SCRIPT — Guide Complet (Sans Code)

---

## C'EST QUOI UN LINKER ?

Quand tu écris du code, il y a 2 étapes :

```
ÉTAPE 1: ASSEMBLEUR (NASM)
──────────────────────────
Ton fichier .asm → Fichier .o (objet)

L'assembleur traduit tes instructions en bytes.
MAIS il ne sait pas encore OÙ le code sera en mémoire.
Il laisse des "trous" pour les adresses.


ÉTAPE 2: LINKER (LD)
────────────────────
Fichiers .o → Fichier final (kernel.bin)

Le linker :
1. Prend tous tes fichiers .o
2. Les assemble en UN fichier
3. Remplit les "trous" avec les vraies adresses
4. Place chaque morceau à la bonne adresse en mémoire
```

---

## LE PROBLÈME ACTUEL

Avec NASM seul et `%include`, tout est dans UN fichier :

```
┌─────────────────────────────────────────┐
│                                         │
│   NASM lit tout d'un coup               │
│   ↓                                     │
│   Il génère les bytes dans l'ordre      │
│   ↓                                     │
│   Il calcule les offsets au fur         │
│   et à mesure                           │
│   ↓                                     │
│   Si tu ajoutes du code au milieu       │
│   ↓                                     │
│   TOUS les offsets après changent       │
│   ↓                                     │
│   💥 CRASH                              │
│                                         │
└─────────────────────────────────────────┘
```

**C'est comme écrire un livre où chaque page référence les autres par numéro de page. Si tu ajoutes une page au milieu, TOUTES les références sont fausses.**

---

## LA SOLUTION : LINKER SCRIPT

Le linker script c'est un **plan d'architecte** pour ta mémoire.

Tu lui dis :

```
"Le kernel commence à 0x10000"
"Mets le code d'entrée en premier"
"Ensuite mets les drivers"
"Ensuite mets l'UI"
"Ensuite mets les données"
```

**Le linker s'occupe de TOUT le reste.**

---

## COMMENT ÇA MARCHE

### Sans Linker Script (ton problème actuel)

```
TON CODE:                      EN MÉMOIRE:
─────────                      ───────────

fichier1.asm  ─┐
fichier2.asm  ─┼──► NASM ──► kernel.bin ──► 0x10000: [tout mélangé]
fichier3.asm  ─┘                              0x10050: [dans l'ordre]
                                              0x10200: [du %include]
                                              
PROBLÈME: L'ordre dépend de l'ordre des %include.
          Si tu changes quelque chose, tout bouge.
```

### Avec Linker Script

```
TON CODE:                      LINKER SCRIPT:           EN MÉMOIRE:
─────────                      ──────────────           ───────────

core.asm ────► core.o ──┐      "0x10000: entry"         0x10000: [entry]
                        │      "0x11000: core"          0x11000: [core]
drivers.asm ─► drivers.o┼──►   "0x20000: drivers"  ──►  0x20000: [drivers]
                        │      "0x30000: ui"            0x30000: [ui]
ui.asm ──────► ui.o ────┘      "0x40000: data"          0x40000: [data]


AVANTAGE: Chaque section a une adresse FIXE.
          Tu peux ajouter 10000 lignes dans ui.asm,
          ça ne change PAS l'adresse de drivers.
```

---

## LES SECTIONS

Tu divises ton code en "sections" logiques :

```
┌─────────────────────────────────────────────────────────────────┐
│                                                                 │
│   SECTION "entry"    →  Le point d'entrée du kernel            │
│                         Toujours en premier                     │
│                         Adresse fixe : 0x10000                  │
│                                                                 │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│   SECTION "core"     →  Fonctions de base                       │
│                         draw_text, draw_rect, etc.              │
│                         Adresse fixe : 0x11000                  │
│                                                                 │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│   SECTION "drivers"  →  E1000, USB, ACPI                        │
│                         Adresse fixe : 0x20000                  │
│                                                                 │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│   SECTION "ui"       →  Files, Shell, Desktop                   │
│                         Adresse fixe : 0x30000                  │
│                                                                 │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│   SECTION "data"     →  Strings, tables, buffers                │
│                         Adresse fixe : 0x40000                  │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

**Chaque section peut grossir INDÉPENDAMMENT des autres.**

---

## POURQUOI C'EST MIEUX

### Problème 1 : Tu ajoutes du code dans l'UI

```
SANS LINKER SCRIPT:
───────────────────
UI était à 0x15000
Tu ajoutes 500 lignes
UI est maintenant à 0x15000 mais plus longue
→ Data qui était à 0x16000 est écrasée
→ CRASH


AVEC LINKER SCRIPT:
───────────────────
UI est à 0x30000 (fixe)
Tu ajoutes 500 lignes
UI va de 0x30000 à 0x30XXX (plus longue)
→ Data est à 0x40000 (fixe, pas affectée)
→ TOUT MARCHE
```

### Problème 2 : Jump trop loin

```
SANS LINKER SCRIPT:
───────────────────
NASM essaie de calculer les offsets
Il utilise des short jumps quand il peut
Tu ajoutes du code
L'offset dépasse 127 bytes
→ CRASH


AVEC LINKER SCRIPT:
───────────────────
Le LINKER calcule les adresses finales
Il sait que draw_text est à 0x11500
Il sait que files_mode est à 0x30200
Il utilise TOUJOURS les bonnes adresses
→ JAMAIS de problème d'offset
```

### Problème 3 : Maintenance

```
SANS LINKER SCRIPT:
───────────────────
Tu dois gérer l'ordre des %include
Tu dois faire attention aux tailles
Tu dois prier pour que ça marche


AVEC LINKER SCRIPT:
───────────────────
Tu écris ton code
Tu le mets dans la bonne section
Le linker fait le reste
Tu t'en fous de l'ordre
Tu t'en fous des tailles
```

---

## C'EST CE QUE FONT LES PROS

| OS | Utilise un Linker Script ? |
|----|----------------------------|
| Linux | OUI |
| Windows | OUI (format différent mais même concept) |
| macOS | OUI |
| FreeBSD | OUI |
| Tous les OS sérieux | OUI |

**Il n'existe AUCUN OS professionnel qui fait tout avec des `%include`.**

---

## LES AVANTAGES

```
┌─────────────────────────────────────────────────────────────────┐
│                                                                 │
│   1. ZÉRO OVERHEAD                                              │
│      Pas de trampolines                                         │
│      Pas de jump table                                          │
│      Pas d'indirection                                          │
│      Le code final est EXACTEMENT comme tu l'as écrit           │
│                                                                 │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│   2. ZÉRO MAINTENANCE                                           │
│      Tu n'as pas à gérer les adresses                           │
│      Tu n'as pas à calculer les offsets                         │
│      Tu n'as pas à vérifier les tailles                         │
│      Le linker fait TOUT                                        │
│                                                                 │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│   3. SCALABLE À L'INFINI                                        │
│      Tu peux ajouter 100 fichiers                               │
│      Tu peux ajouter 1 million de lignes                        │
│      Chaque section grandit indépendamment                      │
│      Jamais de conflit                                          │
│                                                                 │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│   4. DEBUGGING FACILE                                           │
│      Chaque fonction a une adresse stable                       │
│      Tu peux créer une symbol table                             │
│      Les crashs sont faciles à tracer                           │
│                                                                 │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│   5. COMPILATION SÉPARÉE                                        │
│      Tu peux compiler chaque fichier séparément                 │
│      Si tu changes un fichier, tu recompiles SEULEMENT lui      │
│      Compilation 10x plus rapide sur gros projets               │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## LE WORKFLOW

```
AVANT (ce que tu fais):
───────────────────────

1. Tu modifies un fichier
2. NASM recompile TOUT (parce que %include)
3. Tu pries pour que ça marche
4. Ça crash
5. Tu debug pendant 2 heures
6. C'était un problème d'offset


APRÈS (avec linker script):
───────────────────────────

1. Tu modifies un fichier
2. NASM compile SEULEMENT ce fichier → .o
3. LD link tous les .o ensemble
4. Ça marche
5. Toujours
```

---

## RÉSUMÉ

```
┌─────────────────────────────────────────────────────────────────┐
│                                                                 │
│   LINKER SCRIPT = Le plan d'architecte de ta mémoire           │
│                                                                 │
│   Tu définis :                                                  │
│   - Où commence chaque section                                  │
│   - Dans quel ordre elles sont                                  │
│   - Combien d'espace elles ont                                  │
│                                                                 │
│   Le linker s'occupe de :                                       │
│   - Placer le code aux bonnes adresses                          │
│   - Calculer tous les offsets                                   │
│   - Résoudre tous les symboles                                  │
│   - Générer le binaire final                                    │
│                                                                 │
│   Toi tu t'occupes de :                                         │
│   - Écrire ton code                                             │
│   - Le mettre dans la bonne section                             │
│   - C'est tout                                                  │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

**C'est la fondation que TOUS les vrais OS utilisent. Une fois que tu l'as, tu n'as plus JAMAIS de problème de layout mémoire.**

---

Tu veux que je te montre comment l'implémenter pour MATHIS OS ?