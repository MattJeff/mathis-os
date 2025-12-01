# Format Bytecode (.mbc) - Spécification

## 1. Vue d'Ensemble

Le format `.mbc` (Mathis ByteCode) est le format binaire compilé de MathisASM. Il est conçu pour:

- **Chargement rapide**: Structure optimisée pour le parsing
- **Portabilité**: Indépendant de l'architecture
- **Introspection**: Metadata IA préservées
- **Debug**: Mapping source optionnel
- **Sécurité**: Checksums et validation

---

## 2. Structure du Fichier

```
┌────────────────────────────────────────────────────────────────────┐
│                         FILE HEADER                                │
│                         (32 bytes)                                 │
├────────────────────────────────────────────────────────────────────┤
│                       SECTION TABLE                                │
│                    (variable size)                                 │
├────────────────────────────────────────────────────────────────────┤
│                                                                    │
│                         SECTIONS                                   │
│                                                                    │
│  ┌──────────────────────────────────────────────────────────────┐ │
│  │ .constants - Pool de constantes                              │ │
│  ├──────────────────────────────────────────────────────────────┤ │
│  │ .types - Définitions de types                                │ │
│  ├──────────────────────────────────────────────────────────────┤ │
│  │ .globals - Variables globales                                │ │
│  ├──────────────────────────────────────────────────────────────┤ │
│  │ .functions - Table des fonctions                             │ │
│  ├──────────────────────────────────────────────────────────────┤ │
│  │ .code - Instructions bytecode                                │ │
│  ├──────────────────────────────────────────────────────────────┤ │
│  │ .ai_meta - Metadata IA (optionnel)                           │ │
│  ├──────────────────────────────────────────────────────────────┤ │
│  │ .debug - Info de debug (optionnel)                           │ │
│  ├──────────────────────────────────────────────────────────────┤ │
│  │ .symbols - Table des symboles (optionnel)                    │ │
│  └──────────────────────────────────────────────────────────────┘ │
│                                                                    │
├────────────────────────────────────────────────────────────────────┤
│                         CHECKSUM                                   │
│                         (4 bytes)                                  │
└────────────────────────────────────────────────────────────────────┘
```

---

## 3. File Header (32 bytes)

```rust
struct FileHeader {
    magic: [u8; 4],           // "MASM" (0x4D 0x41 0x53 0x4D)
    version_major: u16,       // Version majeure (little-endian)
    version_minor: u16,       // Version mineure (little-endian)
    flags: u32,               // Flags du fichier
    section_count: u16,       // Nombre de sections
    entry_point: u32,         // Offset de la fonction main (0 si pas de main)
    module_name_offset: u32,  // Offset du nom du module dans .constants
    timestamp: u64,           // Unix timestamp de compilation
    reserved: [u8; 2],        // Réservé pour usage futur
}
```

### 3.1 Magic Number

```
Offset 0x00: 0x4D 0x41 0x53 0x4D ("MASM")
```

### 3.2 Flags

```rust
bitflags! {
    struct FileFlags: u32 {
        const HAS_DEBUG_INFO    = 0b0000_0001;  // Section .debug présente
        const HAS_AI_METADATA   = 0b0000_0010;  // Section .ai_meta présente
        const HAS_SYMBOLS       = 0b0000_0100;  // Section .symbols présente
        const IS_LIBRARY        = 0b0000_1000;  // C'est une bibliothèque
        const IS_VERIFIED       = 0b0001_0000;  // Vérifié par l'IA
        const IS_OPTIMIZED      = 0b0010_0000;  // Optimisé
        const IS_SIGNED         = 0b0100_0000;  // Signé cryptographiquement
        const REQUIRES_AI       = 0b1000_0000;  // Nécessite AI runtime
    }
}
```

---

## 4. Section Table

```rust
struct SectionHeader {
    section_type: u8,         // Type de section (enum)
    flags: u8,                // Flags de la section
    reserved: u16,            // Alignement/padding
    offset: u32,              // Offset dans le fichier
    size: u32,                // Taille en bytes
    checksum: u32,            // CRC32 de la section
}
```

### 4.1 Types de Sections

```rust
#[repr(u8)]
enum SectionType {
    Constants   = 0x01,
    Types       = 0x02,
    Globals     = 0x03,
    Functions   = 0x04,
    Code        = 0x05,
    AiMeta      = 0x06,
    Debug       = 0x07,
    Symbols     = 0x08,
    Imports     = 0x09,
    Exports     = 0x0A,
    Custom      = 0xFF,
}
```

### 4.2 Section Flags

```rust
bitflags! {
    struct SectionFlags: u8 {
        const COMPRESSED = 0b0001;  // Section compressée (zstd)
        const ENCRYPTED  = 0b0010;  // Section chiffrée
        const RELOCATABLE = 0b0100; // Contient des relocations
    }
}
```

---

## 5. Section .constants

Pool de toutes les constantes du module.

### 5.1 Structure

```rust
struct ConstantsSection {
    count: u32,                      // Nombre de constantes
    entries: [ConstantEntry; count], // Entrées
    data: [u8],                      // Données brutes
}

struct ConstantEntry {
    type_tag: u8,        // Type de la constante
    flags: u8,           // Flags (ex: interned string)
    data_offset: u32,    // Offset dans la zone data
    data_size: u32,      // Taille des données
}
```

### 5.2 Type Tags

```rust
#[repr(u8)]
enum ConstantType {
    None    = 0x00,
    Bool    = 0x01,
    I8      = 0x02,
    I16     = 0x03,
    I32     = 0x04,
    I64     = 0x05,
    U8      = 0x06,
    U16     = 0x07,
    U32     = 0x08,
    U64     = 0x09,
    F32     = 0x0A,
    F64     = 0x0B,
    Char    = 0x0C,
    String  = 0x10,
    Bytes   = 0x11,
    List    = 0x20,
    Map     = 0x21,
    Set     = 0x22,
    Tuple   = 0x23,
    Struct  = 0x30,
    Enum    = 0x31,
}
```

### 5.3 Encodage des Données

```
; None
[aucune donnée]

; Bool
[0x00 = false, 0x01 = true]

; Integers (little-endian)
I8:  [byte]
I16: [byte, byte]
I32: [byte, byte, byte, byte]
I64: [byte, byte, byte, byte, byte, byte, byte, byte]

; Floats (IEEE 754, little-endian)
F32: [4 bytes]
F64: [8 bytes]

; String (UTF-8)
[length: u32] [utf8_bytes...]

; List
[element_type: u8] [count: u32] [elements...]

; Map
[key_type: u8] [value_type: u8] [count: u32] [key, value, key, value...]

; Struct
[type_id: u32] [field_count: u8] [field_values...]
```

---

## 6. Section .types

Définitions de tous les types custom.

### 6.1 Structure

```rust
struct TypesSection {
    count: u32,
    entries: [TypeEntry; count],
}

struct TypeEntry {
    type_id: u32,           // ID unique du type
    kind: u8,               // Struct, Enum, Alias
    name_const_idx: u32,    // Index du nom dans .constants
    flags: u8,              // Public, Sealed, etc.
    data_offset: u32,       // Offset des données
    data_size: u32,
}
```

### 6.2 Struct Definition

```rust
struct StructDef {
    field_count: u16,
    fields: [FieldDef; field_count],
}

struct FieldDef {
    name_const_idx: u32,    // Index du nom
    type_sig: TypeSig,      // Signature de type
    flags: u8,              // Mutable, Optional, etc.
    default_const_idx: u32, // Index de la valeur par défaut (0xFFFFFFFF si none)
}
```

### 6.3 Enum Definition

```rust
struct EnumDef {
    variant_count: u16,
    variants: [VariantDef; variant_count],
}

struct VariantDef {
    name_const_idx: u32,
    discriminant: i64,      // Valeur du discriminant
    has_data: bool,
    data_type_sig: TypeSig, // Si has_data
}
```

### 6.4 Type Signature

```rust
struct TypeSig {
    kind: u8,               // Primitive, Struct, Generic, etc.
    data: [u8],             // Dépend du kind
}

// Exemples:
// i64          -> [0x05]
// List<i64>    -> [0x20, 0x05]
// Map<str,i64> -> [0x21, 0x10, 0x05]
// Option<T>    -> [0x40, TypeSig(T)]
// CustomType   -> [0x30, type_id: u32]
```

---

## 7. Section .functions

Table de toutes les fonctions.

### 7.1 Structure

```rust
struct FunctionsSection {
    count: u32,
    entries: [FunctionEntry; count],
}

struct FunctionEntry {
    name_const_idx: u32,    // Index du nom dans .constants
    flags: u16,             // Public, Async, Pure, etc.
    arity: u8,              // Nombre de paramètres
    locals_count: u8,       // Nombre de variables locales
    return_type: TypeSig,   // Type de retour
    param_types: [TypeSig], // Types des paramètres
    code_offset: u32,       // Offset dans .code
    code_size: u32,         // Taille du code
    ai_meta_idx: u32,       // Index dans .ai_meta (0xFFFFFFFF si none)
}
```

### 7.2 Function Flags

```rust
bitflags! {
    struct FunctionFlags: u16 {
        const PUBLIC     = 0b0000_0001;
        const PRIVATE    = 0b0000_0010;
        const ASYNC      = 0b0000_0100;
        const PURE       = 0b0000_1000;
        const INLINE     = 0b0001_0000;
        const NO_THROW   = 0b0010_0000;
        const VARIADIC   = 0b0100_0000;
        const NATIVE     = 0b1000_0000;
    }
}
```

---

## 8. Section .code

Instructions bytecode brutes.

### 8.1 Structure

```rust
struct CodeSection {
    size: u32,              // Taille totale
    instructions: [u8],     // Instructions encodées
}
```

### 8.2 Encodage des Instructions

Chaque instruction commence par un opcode (1 byte), suivi de ses opérandes:

```
[opcode: u8] [operand1] [operand2] ...
```

Formats d'opérandes:
- **Aucun**: `OPCODE`
- **u8**: `OPCODE [u8]`
- **u16**: `OPCODE [u16 little-endian]`
- **u32**: `OPCODE [u32 little-endian]`
- **i32**: `OPCODE [i32 little-endian]` (pour jumps relatifs)

Exemples:
```
NOP                  -> 0x00
CONST_I64 42         -> 0x10 0x2A 0x00 0x00 0x00 0x00 0x00 0x00 0x00
GET_LOCAL 0          -> 0x20 0x00
SET_LOCAL 5          -> 0x21 0x05
JUMP -10             -> 0x40 0xF6 0xFF 0xFF 0xFF (i32 = -10)
CALL "func" 3        -> 0x50 [func_idx: u32] 0x03
```

---

## 9. Section .ai_meta

Metadata IA pour l'introspection.

### 9.1 Structure

```rust
struct AiMetaSection {
    count: u32,
    entries: [AiMetaEntry; count],
}

struct AiMetaEntry {
    target_type: u8,            // Function, Block, etc.
    target_id: u32,             // ID de la cible
    data_offset: u32,
    data_size: u32,
}

struct AiMetaData {
    block_name_idx: u32,        // Index dans .constants
    intent_idx: u32,            // Description de l'intent
    is_pure: bool,
    complexity_idx: u32,        // "O(n)", "O(1)", etc.
    depends_count: u16,
    depends: [u32],             // Indices des dépendances
    effects_count: u16,
    effects: [u32],             // Indices des effets
    examples_count: u16,
    examples: [AiExample],      // Exemples d'utilisation
    tags_count: u16,
    tags: [u32],                // Tags pour recherche
}

struct AiExample {
    input_const_idx: u32,       // Entrée (dans .constants)
    output_const_idx: u32,      // Sortie attendue
    description_idx: u32,       // Description optionnelle
}
```

---

## 10. Section .debug

Informations de debug pour le mapping source.

### 10.1 Structure

```rust
struct DebugSection {
    source_files_count: u32,
    source_files: [SourceFile],
    line_mappings_count: u32,
    line_mappings: [LineMapping],
    local_names_count: u32,
    local_names: [LocalName],
}

struct SourceFile {
    path_const_idx: u32,        // Chemin du fichier source
    checksum: [u8; 32],         // SHA-256 du contenu
}

struct LineMapping {
    code_offset: u32,           // Offset dans .code
    source_file_idx: u16,       // Index du fichier source
    line: u32,                  // Numéro de ligne
    column: u16,                // Numéro de colonne
}

struct LocalName {
    function_idx: u32,          // Index de la fonction
    local_idx: u8,              // Index de la variable locale
    name_const_idx: u32,        // Nom de la variable
    type_sig: TypeSig,          // Type de la variable
}
```

---

## 11. Section .symbols

Table des symboles pour le linking.

### 11.1 Structure

```rust
struct SymbolsSection {
    count: u32,
    entries: [SymbolEntry],
}

struct SymbolEntry {
    name_const_idx: u32,
    kind: u8,                   // Function, Type, Global, Const
    visibility: u8,             // Public, Private, Internal
    target_section: u8,         // Section où le symbole est défini
    target_offset: u32,         // Offset dans la section
}

#[repr(u8)]
enum SymbolKind {
    Function = 0x01,
    Type     = 0x02,
    Global   = 0x03,
    Constant = 0x04,
    Import   = 0x10,
    Export   = 0x11,
}
```

---

## 12. Sections .imports et .exports

### 12.1 Imports

```rust
struct ImportsSection {
    count: u32,
    entries: [ImportEntry],
}

struct ImportEntry {
    module_name_idx: u32,       // "std:io"
    symbol_name_idx: u32,       // "println"
    alias_name_idx: u32,        // "io_println" (ou même que symbol_name)
    kind: u8,                   // Function, Type, etc.
}
```

### 12.2 Exports

```rust
struct ExportsSection {
    count: u32,
    entries: [ExportEntry],
}

struct ExportEntry {
    internal_name_idx: u32,     // Nom interne
    export_name_idx: u32,       // Nom exporté (peut être différent)
    kind: u8,
    target_idx: u32,            // Index dans la section appropriée
}
```

---

## 13. Checksum

À la fin du fichier:

```rust
struct FileChecksum {
    algorithm: u8,              // 0x01 = CRC32
    checksum: u32,              // Checksum de tout le fichier (sauf ces 5 bytes)
}
```

---

## 14. Exemple de Fichier Binaire

Pour le code MathisASM suivant:

```masm
.module "simple"
.func add
    .arity 2
    .locals 0
    GET_LOCAL 0
    GET_LOCAL 1
    ADD
    RET
.end
```

Le fichier .mbc ressemblerait à (en hex):

```
; === FILE HEADER (32 bytes) ===
4D 41 53 4D                 ; Magic: "MASM"
01 00                       ; Version major: 1
00 00                       ; Version minor: 0
02 00 00 00                 ; Flags: HAS_AI_METADATA
04 00                       ; Section count: 4
00 00 00 00                 ; Entry point: 0 (pas de main)
00 00 00 00                 ; Module name offset
XX XX XX XX XX XX XX XX     ; Timestamp
00 00                       ; Reserved

; === SECTION TABLE (4 * 16 = 64 bytes) ===
; Section 0: .constants
01                          ; Type: Constants
00                          ; Flags
00 00                       ; Reserved
40 00 00 00                 ; Offset: 64
XX XX XX XX                 ; Size
XX XX XX XX                 ; Checksum

; Section 1: .functions
04                          ; Type: Functions
00 00 00
XX XX XX XX                 ; Offset
XX XX XX XX                 ; Size
XX XX XX XX                 ; Checksum

; Section 2: .code
05                          ; Type: Code
00 00 00
XX XX XX XX                 ; Offset
XX XX XX XX                 ; Size
XX XX XX XX                 ; Checksum

; Section 3: .ai_meta
06                          ; Type: AiMeta
00 00 00
XX XX XX XX                 ; Offset
XX XX XX XX                 ; Size
XX XX XX XX                 ; Checksum

; === .constants SECTION ===
02 00 00 00                 ; Count: 2
; Entry 0: module name "simple"
10                          ; Type: String
00                          ; Flags
00 00 00 00                 ; Data offset
06 00 00 00                 ; Data size
; Entry 1: function name "add"
10                          ; Type: String
00
06 00 00 00                 ; Data offset
03 00 00 00                 ; Data size
; Data:
06 00 00 00 73 69 6D 70 6C 65   ; "simple"
03 00 00 00 61 64 64            ; "add"

; === .functions SECTION ===
01 00 00 00                 ; Count: 1
; Function "add"
01 00 00 00                 ; Name const idx: 1
08 00                       ; Flags: PURE
02                          ; Arity: 2
00                          ; Locals: 0
05                          ; Return type: i64
05 05                       ; Param types: i64, i64
00 00 00 00                 ; Code offset
04 00 00 00                 ; Code size: 4 bytes
FF FF FF FF                 ; AI meta idx: none

; === .code SECTION ===
04 00 00 00                 ; Size: 4 bytes
20 00                       ; GET_LOCAL 0
20 01                       ; GET_LOCAL 1
30                          ; ADD
60                          ; RET

; === CHECKSUM ===
01                          ; Algorithm: CRC32
XX XX XX XX                 ; Checksum value
```

---

## 15. Outils

### 15.1 Commandes CLI

```bash
# Assembler .masm vers .mbc
masm assemble input.masm -o output.mbc

# Désassembler .mbc vers .masm
masm disassemble input.mbc -o output.masm

# Valider un fichier .mbc
masm validate input.mbc

# Afficher les informations d'un .mbc
masm info input.mbc

# Dump hex du bytecode
masm dump input.mbc

# Extraire une section
masm extract input.mbc --section code -o code.bin
```

### 15.2 Options

```bash
# Avec debug info
masm assemble input.masm -o output.mbc --debug

# Sans AI metadata (plus petit)
masm assemble input.masm -o output.mbc --no-ai-meta

# Optimisé
masm assemble input.masm -o output.mbc --optimize

# Compressé
masm assemble input.masm -o output.mbc --compress
```

---

## 16. Validation

### 16.1 Vérifications à l'assemblage

1. **Magic number** correct
2. **Version** supportée
3. **Sections** bien formées
4. **Références** valides (indices dans les limites)
5. **Types** cohérents
6. **Stack** équilibrée à la fin de chaque fonction
7. **Checksum** correct

### 16.2 Vérifications au chargement

1. **Signature** si IS_SIGNED
2. **Imports** disponibles
3. **Version** du runtime compatible
4. **Mémoire** suffisante

---

*Bytecode Format Specification v1.0.0*
