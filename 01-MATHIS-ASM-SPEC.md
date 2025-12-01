# MathisASM - Spécification du Langage

## 1. Introduction

**MathisASM** (MASM) est un langage assembleur intermédiaire conçu pour être:
- **Lisible** par les humains ET les IA
- **Portable** vers différentes architectures
- **Introspectable** avec metadata préservées
- **Évolutif** avec instructions IA natives

---

## 2. Structure d'un Fichier .masm

```masm
; ════════════════════════════════════════════════════════════════════
; HEADER - Informations sur le module
; ════════════════════════════════════════════════════════════════════
.module "module-name"
.version "1.0.0"
.author "Author Name"
.description "Description du module"

; ════════════════════════════════════════════════════════════════════
; IMPORTS - Dépendances externes
; ════════════════════════════════════════════════════════════════════
.import "other-module" as other
.import "std:io" as io

; ════════════════════════════════════════════════════════════════════
; EXPORTS - Symboles publics
; ════════════════════════════════════════════════════════════════════
.export "main"
.export "calculateTotal"

; ════════════════════════════════════════════════════════════════════
; CONSTANTS - Pool de constantes
; ════════════════════════════════════════════════════════════════════
.constants:
    0: i64 42
    1: f64 3.14159
    2: str "Hello, World!"
    3: bool true
    4: none

; ════════════════════════════════════════════════════════════════════
; TYPES - Définitions de types (structs, enums)
; ════════════════════════════════════════════════════════════════════
.types:
    .struct Point
        x: f64
        y: f64
    .end

    .struct Invoice
        subtotal: f64
        discount: f64
        total: f64
    .end

    .enum Status
        Pending = 0
        Active = 1
        Completed = 2
    .end

; ════════════════════════════════════════════════════════════════════
; GLOBALS - Variables globales
; ════════════════════════════════════════════════════════════════════
.globals:
    counter: i64 = 0
    config: Map<str, str>

; ════════════════════════════════════════════════════════════════════
; FUNCTIONS - Définitions de fonctions
; ════════════════════════════════════════════════════════════════════

.func functionName
    ; Metadata de la fonction
    .arity 2                          ; Nombre de paramètres
    .locals 3                         ; Nombre de variables locales
    .returns f64                      ; Type de retour
    
    ; Metadata IA (optionnel mais recommandé)
    .ai_block "block-name"            ; Nom du block MATHIS source
    .ai_intent "Description de l'intent"
    .ai_pure true                     ; Fonction pure (pas d'effets de bord)
    .ai_depends []                    ; Dépendances
    .ai_effects []                    ; Effets de bord
    
    ; Corps de la fonction (instructions)
    GET_LOCAL 0
    GET_LOCAL 1
    ADD
    RET
.end
```

---

## 3. Types de Données

### 3.1 Types Primitifs

| Type | Taille | Description | Exemple |
|------|--------|-------------|---------|
| `i8` | 1 byte | Entier signé 8-bit | `-128` à `127` |
| `i16` | 2 bytes | Entier signé 16-bit | `-32768` à `32767` |
| `i32` | 4 bytes | Entier signé 32-bit | `-2^31` à `2^31-1` |
| `i64` | 8 bytes | Entier signé 64-bit | `-2^63` à `2^63-1` |
| `u8` | 1 byte | Entier non-signé 8-bit | `0` à `255` |
| `u16` | 2 bytes | Entier non-signé 16-bit | `0` à `65535` |
| `u32` | 4 bytes | Entier non-signé 32-bit | `0` à `2^32-1` |
| `u64` | 8 bytes | Entier non-signé 64-bit | `0` à `2^64-1` |
| `f32` | 4 bytes | Flottant 32-bit (IEEE 754) | `3.14` |
| `f64` | 8 bytes | Flottant 64-bit (IEEE 754) | `3.14159265359` |
| `bool` | 1 byte | Booléen | `true`, `false` |
| `char` | 4 bytes | Caractère Unicode | `'a'`, `'é'`, `'中'` |
| `none` | 0 bytes | Absence de valeur | `none` |

### 3.2 Types Composés

| Type | Description | Exemple en .masm |
|------|-------------|------------------|
| `str` | Chaîne UTF-8 | `str "hello"` |
| `List<T>` | Liste dynamique | `List<i64>` |
| `Map<K,V>` | Dictionnaire | `Map<str, i64>` |
| `Set<T>` | Ensemble | `Set<str>` |
| `Tuple<...>` | Tuple | `Tuple<i64, str, bool>` |
| `Option<T>` | Valeur optionnelle | `Option<i64>` |
| `Result<T,E>` | Résultat ou erreur | `Result<i64, str>` |
| `Func<...>` | Référence de fonction | `Func<(i64, i64) -> i64>` |

### 3.3 Types Spéciaux (Kernel Mode)

| Type | Description | Usage |
|------|-------------|-------|
| `ptr` | Pointeur raw | Accès mémoire direct |
| `usize` | Taille/index (dépend de l'arch) | Indexation |
| `block_ref` | Référence à un block | Introspection |
| `type_id` | Identifiant de type | RTTI |

---

## 4. Syntaxe des Instructions

### 4.1 Format Général

```masm
OPCODE                    ; Instruction sans opérande
OPCODE operand            ; Instruction avec 1 opérande
OPCODE operand1, operand2 ; Instruction avec 2 opérandes
```

### 4.2 Commentaires

```masm
; Commentaire sur une ligne

;; Commentaire de documentation
;; sur plusieurs lignes

; TODO: à implémenter
; FIXME: bug connu
; NOTE: remarque importante
```

### 4.3 Labels

```masm
.label_name:              ; Définition d'un label
    JUMP .label_name      ; Saut vers un label
    JUMP_IF_TRUE .label   ; Saut conditionnel
```

### 4.4 Constantes Inline

```masm
CONST_I64 42              ; Entier 64-bit
CONST_F64 3.14            ; Flottant 64-bit
CONST_STR "hello"         ; Chaîne
CONST_BOOL true           ; Booléen
CONST_NONE                ; None
```

### 4.5 Références au Pool de Constantes

```masm
.constants:
    0: str "Hello"
    1: f64 3.14

; Dans le code:
CONST 0                   ; Charge "Hello" depuis le pool
CONST 1                   ; Charge 3.14 depuis le pool
```

---

## 5. Sections du Fichier

### 5.1 Section `.module`

```masm
.module "math-utils"
```

Définit le nom unique du module. Utilisé pour:
- Les imports/exports
- Le namespacing
- L'identification dans les erreurs

### 5.2 Section `.version`

```masm
.version "1.0.0"
```

Version sémantique du module (MAJOR.MINOR.PATCH).

### 5.3 Section `.import`

```masm
.import "other-module" as other           ; Module externe
.import "std:io" as io                    ; Module standard
.import "std:collections" as col          ; Module standard
```

Imports avec alias pour éviter les conflits.

### 5.4 Section `.export`

```masm
.export "main"                            ; Fonction publique
.export "Point"                           ; Type public
.export "VERSION"                         ; Constante publique
```

Symboles accessibles depuis d'autres modules.

### 5.5 Section `.constants`

```masm
.constants:
    ; Index: Type Valeur
    0: i64 42
    1: f64 3.14159265359
    2: str "Hello, World!"
    3: str "error: invalid input"
    4: bool true
    5: List<i64> [1, 2, 3, 4, 5]
    6: Map<str, i64> {"a": 1, "b": 2}
```

Pool de constantes indexé. Avantages:
- Déduplication automatique
- Référence par index (compact)
- Accessible à l'IA pour analyse

### 5.6 Section `.types`

```masm
.types:
    ; Struct
    .struct Point
        x: f64
        y: f64
    .end

    ; Struct avec valeurs par défaut
    .struct Config
        host: str = "localhost"
        port: i64 = 8080
        debug: bool = false
    .end

    ; Enum simple
    .enum Color
        Red = 0
        Green = 1
        Blue = 2
    .end

    ; Enum avec données (tagged union)
    .enum Result
        Ok(value: any)
        Err(message: str)
    .end

    ; Alias de type
    .alias UserId = i64
    .alias UserMap = Map<UserId, User>
```

### 5.7 Section `.globals`

```masm
.globals:
    ; Variable globale avec type et valeur initiale
    counter: i64 = 0
    
    ; Variable globale mutable
    .mut state: State
    
    ; Constante globale (immutable)
    .const PI: f64 = 3.14159265359
    .const VERSION: str = "1.0.0"
```

### 5.8 Section `.func`

```masm
.func functionName
    ; === METADATA OBLIGATOIRES ===
    .arity 2                    ; Nombre de paramètres
    .locals 3                   ; Nombre de variables locales
    
    ; === METADATA OPTIONNELLES ===
    .returns f64                ; Type de retour (défaut: any)
    .params (i64, str)          ; Types des paramètres
    .throws                     ; Peut lever une exception
    .async                      ; Fonction asynchrone
    
    ; === METADATA IA ===
    .ai_block "calculate-total"
    .ai_intent "Calculer le total avec taxe"
    .ai_pure true
    .ai_complexity O(n)
    .ai_depends ["tax-rate", "discount"]
    .ai_effects []
    .ai_examples [
        { input: [100, 0.2], output: 120 },
        { input: [50, 0.1], output: 55 }
    ]
    
    ; === CORPS ===
    ; Instructions...
    
    RET
.end
```

---

## 6. Conventions de Nommage

### 6.1 Modules

```
snake_case ou kebab-case
Exemples: math_utils, http-client, ai_runtime
```

### 6.2 Fonctions

```
camelCase
Exemples: calculateTotal, getUserById, parseJson
```

### 6.3 Types

```
PascalCase
Exemples: Point, UserProfile, HttpRequest
```

### 6.4 Constantes

```
SCREAMING_SNAKE_CASE
Exemples: MAX_SIZE, DEFAULT_PORT, API_VERSION
```

### 6.5 Labels

```
.snake_case avec préfixe point
Exemples: .loop_start, .error_handler, .cleanup
```

---

## 7. Exemple Complet

```masm
; ════════════════════════════════════════════════════════════════════
; Module: invoice-calculator
; Description: Calcul de factures avec remises et taxes
; ════════════════════════════════════════════════════════════════════

.module "invoice-calculator"
.version "1.0.0"
.author "MATHIS"
.description "Module de calcul de factures"

; ════════════════════════════════════════════════════════════════════
; IMPORTS
; ════════════════════════════════════════════════════════════════════
.import "std:math" as math
.import "std:io" as io

; ════════════════════════════════════════════════════════════════════
; EXPORTS
; ════════════════════════════════════════════════════════════════════
.export "calculateInvoice"
.export "Invoice"

; ════════════════════════════════════════════════════════════════════
; CONSTANTS
; ════════════════════════════════════════════════════════════════════
.constants:
    0: f64 0.0
    1: f64 1.0
    2: str "subtotal"
    3: str "discount"
    4: str "tax"
    5: str "total"
    6: str "Calcul du sous-total"
    7: str "Application de la remise"
    8: str "Calcul de la taxe"
    9: str "Calcul du total final"

; ════════════════════════════════════════════════════════════════════
; TYPES
; ════════════════════════════════════════════════════════════════════
.types:
    .struct Item
        name: str
        price: f64
        quantity: i64
    .end

    .struct Invoice
        subtotal: f64
        discount: f64
        tax: f64
        total: f64
    .end

; ════════════════════════════════════════════════════════════════════
; GLOBALS
; ════════════════════════════════════════════════════════════════════
.globals:
    .const DEFAULT_TAX_RATE: f64 = 0.2
    .const MAX_DISCOUNT: f64 = 0.5

; ════════════════════════════════════════════════════════════════════
; FUNCTION: calculateInvoice
; ════════════════════════════════════════════════════════════════════
.func calculateInvoice
    .arity 3                            ; items, discountRate, taxRate
    .locals 4                           ; subtotal, discountAmount, taxAmount, total
    .params (List<Item>, f64, f64)
    .returns Invoice
    
    .ai_block "calculate-invoice"
    .ai_intent "Calculer une facture complète avec remise et taxe"
    .ai_pure true
    .ai_complexity O(n)
    .ai_depends []
    .ai_effects []
    
    ; ──────────────────────────────────────────────────────────────
    ; ÉTAPE 1: Calculer le sous-total
    ; ──────────────────────────────────────────────────────────────
    AI_EXPLAIN_START 6                  ; "Calcul du sous-total"
    
    ; subtotal = 0.0
    CONST 0                             ; 0.0
    SET_LOCAL 3                         ; local[3] = subtotal
    
    ; Boucle sur les items
    GET_LOCAL 0                         ; items (param 0)
    ITER_START                          ; Démarre l'itération
    
.loop_items:
    ITER_NEXT                           ; Prochain item ou jump à .loop_end
    JUMP_IF_DONE .loop_items_end
    
    ; item.price * item.quantity
    DUP                                 ; Dupliquer l'item
    GET_FIELD "price"                   ; item.price
    SWAP
    GET_FIELD "quantity"                ; item.quantity
    I64_TO_F64                          ; Convertir quantity en f64
    MUL                                 ; price * quantity
    
    ; subtotal += result
    GET_LOCAL 3                         ; subtotal
    ADD
    SET_LOCAL 3                         ; subtotal = subtotal + (price * quantity)
    
    JUMP .loop_items

.loop_items_end:
    ITER_END
    AI_EXPLAIN_END
    
    ; ──────────────────────────────────────────────────────────────
    ; ÉTAPE 2: Appliquer la remise
    ; ──────────────────────────────────────────────────────────────
    AI_EXPLAIN_START 7                  ; "Application de la remise"
    
    ; discountAmount = subtotal * discountRate
    GET_LOCAL 3                         ; subtotal
    GET_LOCAL 1                         ; discountRate (param 1)
    MUL
    SET_LOCAL 4                         ; local[4] = discountAmount
    
    AI_EXPLAIN_END
    
    ; ──────────────────────────────────────────────────────────────
    ; ÉTAPE 3: Calculer la taxe (sur le montant après remise)
    ; ──────────────────────────────────────────────────────────────
    AI_EXPLAIN_START 8                  ; "Calcul de la taxe"
    
    ; taxableAmount = subtotal - discountAmount
    GET_LOCAL 3                         ; subtotal
    GET_LOCAL 4                         ; discountAmount
    SUB                                 ; subtotal - discountAmount
    
    ; taxAmount = taxableAmount * taxRate
    GET_LOCAL 2                         ; taxRate (param 2)
    MUL
    SET_LOCAL 5                         ; local[5] = taxAmount
    
    AI_EXPLAIN_END
    
    ; ──────────────────────────────────────────────────────────────
    ; ÉTAPE 4: Calculer le total final
    ; ──────────────────────────────────────────────────────────────
    AI_EXPLAIN_START 9                  ; "Calcul du total final"
    
    ; total = subtotal - discountAmount + taxAmount
    GET_LOCAL 3                         ; subtotal
    GET_LOCAL 4                         ; discountAmount
    SUB                                 ; subtotal - discountAmount
    GET_LOCAL 5                         ; taxAmount
    ADD                                 ; + taxAmount
    SET_LOCAL 6                         ; local[6] = total
    
    AI_EXPLAIN_END
    
    ; ──────────────────────────────────────────────────────────────
    ; ÉTAPE 5: Construire l'objet Invoice
    ; ──────────────────────────────────────────────────────────────
    
    ; Invoice { subtotal, discount, tax, total }
    CONST 2                             ; "subtotal"
    GET_LOCAL 3                         ; subtotal value
    CONST 3                             ; "discount"
    GET_LOCAL 4                         ; discount value
    CONST 4                             ; "tax"
    GET_LOCAL 5                         ; tax value
    CONST 5                             ; "total"
    GET_LOCAL 6                         ; total value
    MAKE_STRUCT "Invoice" 4             ; Créer Invoice avec 4 champs
    
    RET
.end

; ════════════════════════════════════════════════════════════════════
; FUNCTION: main (point d'entrée pour test)
; ════════════════════════════════════════════════════════════════════
.func main
    .arity 0
    .locals 1
    .returns none
    
    .ai_block "main"
    .ai_intent "Point d'entrée pour tester le calculateur"
    
    ; Créer une liste d'items de test
    ; Item { name: "Widget", price: 25.0, quantity: 4 }
    CONST_STR "Widget"
    CONST_F64 25.0
    CONST_I64 4
    MAKE_STRUCT "Item" 3
    
    ; Item { name: "Gadget", price: 15.0, quantity: 2 }
    CONST_STR "Gadget"
    CONST_F64 15.0
    CONST_I64 2
    MAKE_STRUCT "Item" 3
    
    ; Créer la liste [item1, item2]
    MAKE_LIST 2
    
    ; calculateInvoice(items, 0.1, 0.2)
    CONST_F64 0.1                       ; 10% discount
    CONST_F64 0.2                       ; 20% tax
    CALL "calculateInvoice" 3
    
    ; Afficher le résultat
    CALL "io:println" 1
    POP
    
    CONST_NONE
    RET
.end
```

---

## 8. Validation et Erreurs

### 8.1 Erreurs de Syntaxe

```
ERROR [MASM001]: Invalid instruction at line 42
  |
42|     INVALID_OP 123
  |     ^^^^^^^^^^ Unknown opcode
  |
  = help: Did you mean 'CONST_I64'?
```

### 8.2 Erreurs de Type

```
ERROR [MASM002]: Type mismatch at line 56
  |
56|     ADD              ; Expected (i64, i64) or (f64, f64)
  |     ^^^
  |
  = note: Stack contains (str, i64)
  = help: Use I64_TO_STR to convert
```

### 8.3 Erreurs de Référence

```
ERROR [MASM003]: Undefined label at line 78
  |
78|     JUMP .undefined_label
  |          ^^^^^^^^^^^^^^^^ Label not found
  |
  = note: Available labels: .loop_start, .loop_end, .error
```

### 8.4 Warnings

```
WARNING [MASM100]: Unused local variable
  |
15|     .locals 5           ; Only 3 are used
  |             ^
  |
  = help: Consider reducing to '.locals 3'

WARNING [MASM101]: Missing AI metadata
  |
20| .func processData
  |       ^^^^^^^^^^^
  |
  = help: Add '.ai_intent' for better AI introspection
```

---

## 9. Extensions de Fichier

| Extension | Description | Contenu |
|-----------|-------------|---------|
| `.mhs` | MATHIS Source | Code MATHIS haut niveau |
| `.masm` | MathisASM | Assembleur texte lisible |
| `.mbc` | Mathis ByteCode | Bytecode binaire compilé |
| `.mdb` | Mathis Debug | Informations de debug |
| `.mlib` | Mathis Library | Bibliothèque compilée |

---

## 10. Compatibilité

### 10.1 Versioning

Le format .masm suit le versioning sémantique:
- **MAJOR**: Changements incompatibles
- **MINOR**: Nouvelles features rétrocompatibles  
- **PATCH**: Corrections de bugs

### 10.2 Rétrocompatibilité

- Les fichiers .masm v1.x sont compatibles avec le runtime v1.x
- Le runtime v1.y peut exécuter du bytecode v1.x (où y >= x)
- Les nouvelles instructions sont ignorées par les anciens runtimes (graceful degradation)

---

*MathisASM Specification v1.0.0*
