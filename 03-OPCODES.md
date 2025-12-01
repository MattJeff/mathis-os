# OpCodes MathisASM - Référence Complète

## 1. Vue d'Ensemble

Les opcodes MathisASM sont organisés en catégories:

| Range | Catégorie | Description |
|-------|-----------|-------------|
| `0x00-0x0F` | Control | NOP, HALT, etc. |
| `0x10-0x1F` | Constants | Chargement de constantes |
| `0x20-0x2F` | Variables | Locals, globals |
| `0x30-0x3F` | Arithmetic | ADD, SUB, MUL, etc. |
| `0x40-0x4F` | Comparison | EQ, LT, GT, etc. |
| `0x50-0x5F` | Logic | AND, OR, NOT, etc. |
| `0x60-0x6F` | Control Flow | JUMP, CALL, RET, etc. |
| `0x70-0x7F` | Stack | DUP, SWAP, POP, etc. |
| `0x80-0x8F` | Objects | GET_FIELD, MAKE_STRUCT, etc. |
| `0x90-0x9F` | Collections | MAKE_LIST, INDEX, etc. |
| `0xA0-0xAF` | AI | AI_CALL, AI_DECIDE, etc. |
| `0xB0-0xBF` | Introspection | GET_META, etc. |
| `0xC0-0xCF` | System | SYSCALL, ALLOC, etc. |
| `0xD0-0xDF` | Async | AWAIT, SPAWN, etc. |
| `0xE0-0xEF` | Debug | BREAKPOINT, TRACE, etc. |
| `0xF0-0xFF` | Reserved | Extensions futures |

---

## 2. Control (0x00-0x0F)

### NOP (0x00)
```
NOP
```
Ne fait rien. Utilisé pour l'alignement ou le patching.

**Stack**: `[] -> []`

---

### HALT (0x01)
```
HALT
```
Arrête l'exécution de la VM.

**Stack**: `[] -> []`

---

### PANIC (0x02)
```
PANIC
```
Arrête avec erreur. Le message est sur la stack.

**Stack**: `[message: str] -> []` (ne retourne jamais)

---

### UNREACHABLE (0x03)
```
UNREACHABLE
```
Indique du code qui ne devrait jamais être atteint. Panic si exécuté.

**Stack**: `[] -> []` (ne retourne jamais)

---

## 3. Constants (0x10-0x1F)

### CONST (0x10)
```
CONST <idx:u16>
```
Charge une constante depuis le pool.

**Stack**: `[] -> [value]`

---

### CONST_NONE (0x11)
```
CONST_NONE
```
Charge `none`.

**Stack**: `[] -> [none]`

---

### CONST_TRUE (0x12)
```
CONST_TRUE
```
Charge `true`.

**Stack**: `[] -> [true]`

---

### CONST_FALSE (0x13)
```
CONST_FALSE
```
Charge `false`.

**Stack**: `[] -> [false]`

---

### CONST_I64 (0x14)
```
CONST_I64 <value:i64>
```
Charge un entier 64-bit inline.

**Stack**: `[] -> [i64]`

---

### CONST_F64 (0x15)
```
CONST_F64 <value:f64>
```
Charge un flottant 64-bit inline.

**Stack**: `[] -> [f64]`

---

### CONST_STR (0x16)
```
CONST_STR <idx:u16>
```
Charge une chaîne depuis le pool.

**Stack**: `[] -> [str]`

---

### CONST_SMALL_INT (0x17)
```
CONST_SMALL_INT <value:i8>
```
Charge un petit entier (-128 à 127). Optimisation.

**Stack**: `[] -> [i64]`

---

## 4. Variables (0x20-0x2F)

### GET_LOCAL (0x20)
```
GET_LOCAL <idx:u8>
```
Charge une variable locale.

**Stack**: `[] -> [value]`

---

### SET_LOCAL (0x21)
```
SET_LOCAL <idx:u8>
```
Stocke dans une variable locale.

**Stack**: `[value] -> []`

---

### GET_GLOBAL (0x22)
```
GET_GLOBAL <idx:u16>
```
Charge une variable globale.

**Stack**: `[] -> [value]`

---

### SET_GLOBAL (0x23)
```
SET_GLOBAL <idx:u16>
```
Stocke dans une variable globale.

**Stack**: `[value] -> []`

---

### GET_UPVALUE (0x24)
```
GET_UPVALUE <idx:u8>
```
Charge une valeur capturée (closures).

**Stack**: `[] -> [value]`

---

### SET_UPVALUE (0x25)
```
SET_UPVALUE <idx:u8>
```
Stocke dans une valeur capturée.

**Stack**: `[value] -> []`

---

### CLOSE_UPVALUE (0x26)
```
CLOSE_UPVALUE <idx:u8>
```
Ferme un upvalue (le déplace sur le heap).

**Stack**: `[] -> []`

---

## 5. Arithmetic (0x30-0x3F)

### ADD (0x30)
```
ADD
```
Addition. Fonctionne sur i64, f64, str (concat).

**Stack**: `[a, b] -> [a + b]`

---

### SUB (0x31)
```
SUB
```
Soustraction.

**Stack**: `[a, b] -> [a - b]`

---

### MUL (0x32)
```
MUL
```
Multiplication.

**Stack**: `[a, b] -> [a * b]`

---

### DIV (0x33)
```
DIV
```
Division.

**Stack**: `[a, b] -> [a / b]`

---

### MOD (0x34)
```
MOD
```
Modulo.

**Stack**: `[a, b] -> [a % b]`

---

### NEG (0x35)
```
NEG
```
Négation.

**Stack**: `[a] -> [-a]`

---

### POW (0x36)
```
POW
```
Puissance.

**Stack**: `[base, exp] -> [base ^ exp]`

---

### FLOOR_DIV (0x37)
```
FLOOR_DIV
```
Division entière.

**Stack**: `[a, b] -> [floor(a / b)]`

---

### I64_ADD (0x38)
```
I64_ADD
```
Addition spécifique i64 (plus rapide).

**Stack**: `[a: i64, b: i64] -> [i64]`

---

### F64_ADD (0x39)
```
F64_ADD
```
Addition spécifique f64 (plus rapide).

**Stack**: `[a: f64, b: f64] -> [f64]`

---

### I64_TO_F64 (0x3A)
```
I64_TO_F64
```
Conversion i64 vers f64.

**Stack**: `[i64] -> [f64]`

---

### F64_TO_I64 (0x3B)
```
F64_TO_I64
```
Conversion f64 vers i64 (truncate).

**Stack**: `[f64] -> [i64]`

---

## 6. Comparison (0x40-0x4F)

### EQ (0x40)
```
EQ
```
Égalité.

**Stack**: `[a, b] -> [a == b]`

---

### NE (0x41)
```
NE
```
Différence.

**Stack**: `[a, b] -> [a != b]`

---

### LT (0x42)
```
LT
```
Inférieur strict.

**Stack**: `[a, b] -> [a < b]`

---

### LE (0x43)
```
LE
```
Inférieur ou égal.

**Stack**: `[a, b] -> [a <= b]`

---

### GT (0x44)
```
GT
```
Supérieur strict.

**Stack**: `[a, b] -> [a > b]`

---

### GE (0x45)
```
GE
```
Supérieur ou égal.

**Stack**: `[a, b] -> [a >= b]`

---

### CMP (0x46)
```
CMP
```
Comparaison trois-voies.

**Stack**: `[a, b] -> [-1 | 0 | 1]`

---

### IS_NONE (0x47)
```
IS_NONE
```
Vérifie si la valeur est none.

**Stack**: `[value] -> [bool]`

---

### IS_SOME (0x48)
```
IS_SOME
```
Vérifie si la valeur n'est pas none.

**Stack**: `[value] -> [bool]`

---

### TYPE_EQ (0x49)
```
TYPE_EQ <type_id:u16>
```
Vérifie si la valeur est du type donné.

**Stack**: `[value] -> [bool]`

---

## 7. Logic (0x50-0x5F)

### AND (0x50)
```
AND
```
ET logique.

**Stack**: `[a, b] -> [a && b]`

---

### OR (0x51)
```
OR
```
OU logique.

**Stack**: `[a, b] -> [a || b]`

---

### NOT (0x52)
```
NOT
```
NON logique.

**Stack**: `[a] -> [!a]`

---

### BIT_AND (0x53)
```
BIT_AND
```
ET bit-à-bit.

**Stack**: `[a, b] -> [a & b]`

---

### BIT_OR (0x54)
```
BIT_OR
```
OU bit-à-bit.

**Stack**: `[a, b] -> [a | b]`

---

### BIT_XOR (0x55)
```
BIT_XOR
```
XOR bit-à-bit.

**Stack**: `[a, b] -> [a ^ b]`

---

### BIT_NOT (0x56)
```
BIT_NOT
```
Complément bit-à-bit.

**Stack**: `[a] -> [~a]`

---

### SHL (0x57)
```
SHL
```
Décalage à gauche.

**Stack**: `[value, shift] -> [value << shift]`

---

### SHR (0x58)
```
SHR
```
Décalage à droite (arithmétique).

**Stack**: `[value, shift] -> [value >> shift]`

---

### USHR (0x59)
```
USHR
```
Décalage à droite (logique, non-signé).

**Stack**: `[value, shift] -> [value >>> shift]`

---

## 8. Control Flow (0x60-0x6F)

### JUMP (0x60)
```
JUMP <offset:i32>
```
Saut inconditionnel (relatif).

**Stack**: `[] -> []`

---

### JUMP_IF_TRUE (0x61)
```
JUMP_IF_TRUE <offset:i32>
```
Saut si vrai.

**Stack**: `[condition] -> []`

---

### JUMP_IF_FALSE (0x62)
```
JUMP_IF_FALSE <offset:i32>
```
Saut si faux.

**Stack**: `[condition] -> []`

---

### JUMP_IF_NONE (0x63)
```
JUMP_IF_NONE <offset:i32>
```
Saut si none.

**Stack**: `[value] -> []`

---

### JUMP_IF_SOME (0x64)
```
JUMP_IF_SOME <offset:i32>
```
Saut si non-none.

**Stack**: `[value] -> []` (garde la valeur si some)

---

### CALL (0x65)
```
CALL <func_idx:u16> <argc:u8>
```
Appel de fonction.

**Stack**: `[arg1, arg2, ..., argN] -> [result]`

---

### CALL_INDIRECT (0x66)
```
CALL_INDIRECT <argc:u8>
```
Appel indirect via référence de fonction.

**Stack**: `[func_ref, arg1, ..., argN] -> [result]`

---

### TAIL_CALL (0x67)
```
TAIL_CALL <func_idx:u16> <argc:u8>
```
Appel terminal optimisé.

**Stack**: `[arg1, ..., argN] -> [result]`

---

### RET (0x68)
```
RET
```
Retourne de la fonction. La valeur de retour est sur la stack.

**Stack**: `[return_value] -> []` (dans l'appelant: `[] -> [return_value]`)

---

### THROW (0x69)
```
THROW
```
Lance une exception.

**Stack**: `[error] -> []` (ne retourne pas normalement)

---

### TRY_START (0x6A)
```
TRY_START <handler_offset:i32>
```
Début d'un bloc try. Enregistre le handler.

**Stack**: `[] -> []`

---

### TRY_END (0x6B)
```
TRY_END
```
Fin d'un bloc try. Désactive le handler.

**Stack**: `[] -> []`

---

### CATCH (0x6C)
```
CATCH
```
Début du handler. L'erreur est sur la stack.

**Stack**: `[] -> [error]`

---

## 9. Stack Operations (0x70-0x7F)

### POP (0x70)
```
POP
```
Supprime le sommet de la stack.

**Stack**: `[value] -> []`

---

### DUP (0x71)
```
DUP
```
Duplique le sommet.

**Stack**: `[a] -> [a, a]`

---

### DUP2 (0x72)
```
DUP2
```
Duplique les deux sommets.

**Stack**: `[a, b] -> [a, b, a, b]`

---

### SWAP (0x73)
```
SWAP
```
Échange les deux sommets.

**Stack**: `[a, b] -> [b, a]`

---

### ROT (0x74)
```
ROT
```
Rotation (a, b, c -> b, c, a).

**Stack**: `[a, b, c] -> [b, c, a]`

---

### OVER (0x75)
```
OVER
```
Copie le second élément.

**Stack**: `[a, b] -> [a, b, a]`

---

### DROP_N (0x76)
```
DROP_N <n:u8>
```
Supprime N éléments.

**Stack**: `[...n values...] -> []`

---

## 10. Objects (0x80-0x8F)

### GET_FIELD (0x80)
```
GET_FIELD <field_idx:u16>
```
Accède à un champ d'une struct.

**Stack**: `[object] -> [field_value]`

---

### SET_FIELD (0x81)
```
SET_FIELD <field_idx:u16>
```
Modifie un champ.

**Stack**: `[object, value] -> [object]`

---

### GET_FIELD_DYN (0x82)
```
GET_FIELD_DYN
```
Accès dynamique (nom sur la stack).

**Stack**: `[object, field_name] -> [field_value]`

---

### SET_FIELD_DYN (0x83)
```
SET_FIELD_DYN
```
Modification dynamique.

**Stack**: `[object, field_name, value] -> [object]`

---

### MAKE_STRUCT (0x84)
```
MAKE_STRUCT <type_id:u16> <field_count:u8>
```
Crée une nouvelle struct.

**Stack**: `[field1, field2, ..., fieldN] -> [struct]`

---

### MAKE_TUPLE (0x85)
```
MAKE_TUPLE <count:u8>
```
Crée un tuple.

**Stack**: `[elem1, ..., elemN] -> [tuple]`

---

### UNPACK_TUPLE (0x86)
```
UNPACK_TUPLE <count:u8>
```
Décompresse un tuple.

**Stack**: `[tuple] -> [elem1, ..., elemN]`

---

### INSTANCE_OF (0x87)
```
INSTANCE_OF <type_id:u16>
```
Vérifie le type.

**Stack**: `[value] -> [bool]`

---

### CAST (0x88)
```
CAST <type_id:u16>
```
Conversion de type.

**Stack**: `[value] -> [casted_value]`

---

## 11. Collections (0x90-0x9F)

### MAKE_LIST (0x90)
```
MAKE_LIST <count:u16>
```
Crée une liste.

**Stack**: `[elem1, ..., elemN] -> [list]`

---

### MAKE_MAP (0x91)
```
MAKE_MAP <count:u16>
```
Crée un map (dictionnaire).

**Stack**: `[key1, val1, key2, val2, ...] -> [map]`

---

### MAKE_SET (0x92)
```
MAKE_SET <count:u16>
```
Crée un set.

**Stack**: `[elem1, ..., elemN] -> [set]`

---

### INDEX (0x93)
```
INDEX
```
Accès par index.

**Stack**: `[collection, index] -> [value]`

---

### INDEX_SET (0x94)
```
INDEX_SET
```
Modification par index.

**Stack**: `[collection, index, value] -> [collection]`

---

### LEN (0x95)
```
LEN
```
Longueur de la collection.

**Stack**: `[collection] -> [i64]`

---

### PUSH (0x96)
```
PUSH
```
Ajoute à la fin d'une liste.

**Stack**: `[list, value] -> [list]`

---

### POP_BACK (0x97)
```
POP_BACK
```
Retire le dernier élément.

**Stack**: `[list] -> [list, value]`

---

### CONTAINS (0x98)
```
CONTAINS
```
Vérifie la présence d'un élément.

**Stack**: `[collection, value] -> [bool]`

---

### ITER_START (0x99)
```
ITER_START
```
Démarre une itération.

**Stack**: `[iterable] -> [iterator]`

---

### ITER_NEXT (0x9A)
```
ITER_NEXT
```
Élément suivant. Met `done` flag.

**Stack**: `[iterator] -> [iterator, value]` ou `[iterator] -> [iterator]` (done)

---

### ITER_END (0x9B)
```
ITER_END
```
Termine l'itération.

**Stack**: `[iterator] -> []`

---

### SLICE (0x9C)
```
SLICE
```
Extrait une sous-collection.

**Stack**: `[collection, start, end] -> [slice]`

---

### CONCAT (0x9D)
```
CONCAT
```
Concatène deux collections.

**Stack**: `[a, b] -> [a + b]`

---

## 12. AI Instructions (0xA0-0xAF) ⭐

### AI_BREAKPOINT (0xA0)
```
AI_BREAKPOINT
```
Pause pour introspection IA. L'IA peut inspecter la stack et les variables.

**Stack**: `[] -> []`

---

### AI_LOG (0xA1)
```
AI_LOG <severity:u8>
```
Log sémantique pour l'IA. Le message est sur la stack.

**Stack**: `[message: str] -> []`

Severity: 0=trace, 1=debug, 2=info, 3=warn, 4=error

---

### AI_ASSERT (0xA2)
```
AI_ASSERT <description_idx:u16>
```
Assertion vérifiable par IA.

**Stack**: `[condition: bool] -> []`

---

### AI_DECIDE (0xA3)
```
AI_DECIDE <options_count:u8>
```
Demande à l'IA de choisir parmi les options sur la stack.

**Stack**: `[option1, option2, ..., optionN] -> [chosen_index: i64]`

---

### AI_EXPLAIN_START (0xA4)
```
AI_EXPLAIN_START <label_idx:u16>
```
Début d'un bloc explicable.

**Stack**: `[] -> []`

---

### AI_EXPLAIN_END (0xA5)
```
AI_EXPLAIN_END
```
Fin d'un bloc explicable.

**Stack**: `[] -> []`

---

### AI_CALL (0xA6)
```
AI_CALL <model_idx:u8>
```
Appel à un modèle IA. Le prompt est sur la stack.

**Stack**: `[prompt: str] -> [response: str]`

Models: 0=default, 1=fast, 2=smart, 3=local

---

### AI_EMBED (0xA7)
```
AI_EMBED
```
Génère un embedding du texte.

**Stack**: `[text: str] -> [embedding: List<f64>]`

---

### AI_SIMILARITY (0xA8)
```
AI_SIMILARITY
```
Calcule la similarité entre deux embeddings.

**Stack**: `[emb1, emb2] -> [score: f64]`

---

### AI_CONTRACT (0xA9)
```
AI_CONTRACT <pre_idx:u16> <post_idx:u16>
```
Définit un contrat vérifié par IA.

**Stack**: `[] -> []`

---

### AI_INVARIANT (0xAA)
```
AI_INVARIANT <desc_idx:u16>
```
Définit un invariant.

**Stack**: `[condition: bool] -> []`

---

### AI_LEARN (0xAB)
```
AI_LEARN <pattern_idx:u16>
```
Logger des données pour l'apprentissage.

**Stack**: `[data] -> []`

---

### AI_OPTIMIZE (0xAC)
```
AI_OPTIMIZE <hint_idx:u16>
```
Indique que ce bloc peut être optimisé par l'IA.

**Stack**: `[] -> []`

---

### AI_FORK (0xAD)
```
AI_FORK <branch_count:u8>
```
L'IA explore plusieurs branches.

**Stack**: `[] -> []`

---

### AI_MERGE (0xAE)
```
AI_MERGE
```
L'IA choisit la meilleure branche.

**Stack**: `[results...] -> [best_result]`

---

## 13. Introspection (0xB0-0xBF)

### GET_TYPE (0xB0)
```
GET_TYPE
```
Obtient le type d'une valeur.

**Stack**: `[value] -> [type_id: i64]`

---

### GET_TYPE_NAME (0xB1)
```
GET_TYPE_NAME
```
Obtient le nom du type.

**Stack**: `[value] -> [type_name: str]`

---

### GET_BLOCK_META (0xB2)
```
GET_BLOCK_META
```
Obtient les metadata du bloc courant.

**Stack**: `[] -> [metadata: Map]`

---

### GET_INTENT (0xB3)
```
GET_INTENT
```
Obtient l'intent du bloc courant.

**Stack**: `[] -> [intent: str]`

---

### GET_DEPENDS (0xB4)
```
GET_DEPENDS
```
Obtient les dépendances.

**Stack**: `[] -> [depends: List<str>]`

---

### GET_EFFECTS (0xB5)
```
GET_EFFECTS
```
Obtient les effets de bord.

**Stack**: `[] -> [effects: List<str>]`

---

### GET_CALLSTACK (0xB6)
```
GET_CALLSTACK
```
Obtient la pile d'appels.

**Stack**: `[] -> [frames: List<Frame>]`

---

### GET_LOCALS_INFO (0xB7)
```
GET_LOCALS_INFO
```
Obtient les infos sur les variables locales.

**Stack**: `[] -> [locals: Map<str, any>]`

---

### REFLECT_CALL (0xB8)
```
REFLECT_CALL
```
Appel par réflexion.

**Stack**: `[func_name: str, args: List] -> [result]`

---

## 14. System (0xC0-0xCF)

### SYSCALL (0xC0)
```
SYSCALL <syscall_id:u16>
```
Appel système.

**Stack**: `[args...] -> [result]`

---

### ALLOC (0xC1)
```
ALLOC
```
Alloue de la mémoire.

**Stack**: `[size: i64] -> [ptr]`

---

### FREE (0xC2)
```
FREE
```
Libère de la mémoire.

**Stack**: `[ptr] -> []`

---

### MEM_LOAD (0xC3)
```
MEM_LOAD <size:u8>
```
Charge depuis la mémoire (unsafe).

**Stack**: `[ptr] -> [value]`

---

### MEM_STORE (0xC4)
```
MEM_STORE <size:u8>
```
Stocke dans la mémoire (unsafe).

**Stack**: `[ptr, value] -> []`

---

### MEM_COPY (0xC5)
```
MEM_COPY
```
Copie un bloc mémoire.

**Stack**: `[dest, src, len] -> []`

---

### MEM_ZERO (0xC6)
```
MEM_ZERO
```
Met à zéro un bloc mémoire.

**Stack**: `[ptr, len] -> []`

---

### NATIVE_CALL (0xC7)
```
NATIVE_CALL <func_idx:u16>
```
Appel à une fonction native (FFI).

**Stack**: `[args...] -> [result]`

---

## 15. Async (0xD0-0xDF)

### AWAIT (0xD0)
```
AWAIT
```
Attend une valeur async.

**Stack**: `[future] -> [result]`

---

### SPAWN (0xD1)
```
SPAWN <func_idx:u16>
```
Lance une tâche async.

**Stack**: `[args...] -> [task_handle]`

---

### YIELD (0xD2)
```
YIELD
```
Rend le contrôle (coroutine/generator).

**Stack**: `[value] -> []`

---

### RESUME (0xD3)
```
RESUME
```
Reprend une coroutine.

**Stack**: `[coroutine, value] -> [yielded_value]`

---

### CHANNEL_SEND (0xD4)
```
CHANNEL_SEND
```
Envoie sur un channel.

**Stack**: `[channel, value] -> []`

---

### CHANNEL_RECV (0xD5)
```
CHANNEL_RECV
```
Reçoit d'un channel.

**Stack**: `[channel] -> [value]`

---

### SELECT (0xD6)
```
SELECT <count:u8>
```
Attend sur plusieurs channels.

**Stack**: `[channel1, ..., channelN] -> [index, value]`

---

## 16. Debug (0xE0-0xEF)

### BREAKPOINT (0xE0)
```
BREAKPOINT
```
Point d'arrêt debugger.

**Stack**: `[] -> []`

---

### TRACE (0xE1)
```
TRACE
```
Affiche la valeur pour debug.

**Stack**: `[value] -> [value]` (ne consomme pas)

---

### ASSERT (0xE2)
```
ASSERT <msg_idx:u16>
```
Assertion (panic si faux).

**Stack**: `[condition] -> []`

---

### PROFILE_START (0xE3)
```
PROFILE_START <label_idx:u16>
```
Début d'une section profilée.

**Stack**: `[] -> []`

---

### PROFILE_END (0xE4)
```
PROFILE_END
```
Fin d'une section profilée.

**Stack**: `[] -> []`

---

### SOURCE_LOC (0xE5)
```
SOURCE_LOC <file_idx:u16> <line:u32> <col:u16>
```
Information de localisation source (pour debug/errors).

**Stack**: `[] -> []`

---

## 17. Résumé par Byte

```
0x00 NOP                    0x40 EQ                     0x80 GET_FIELD
0x01 HALT                   0x41 NE                     0x81 SET_FIELD
0x02 PANIC                  0x42 LT                     0x82 GET_FIELD_DYN
0x03 UNREACHABLE            0x43 LE                     0x83 SET_FIELD_DYN
                            0x44 GT                     0x84 MAKE_STRUCT
0x10 CONST                  0x45 GE                     0x85 MAKE_TUPLE
0x11 CONST_NONE             0x46 CMP                    0x86 UNPACK_TUPLE
0x12 CONST_TRUE             0x47 IS_NONE                0x87 INSTANCE_OF
0x13 CONST_FALSE            0x48 IS_SOME                0x88 CAST
0x14 CONST_I64              0x49 TYPE_EQ
0x15 CONST_F64                                          0x90 MAKE_LIST
0x16 CONST_STR              0x50 AND                    0x91 MAKE_MAP
0x17 CONST_SMALL_INT        0x51 OR                     0x92 MAKE_SET
                            0x52 NOT                    0x93 INDEX
0x20 GET_LOCAL              0x53 BIT_AND                0x94 INDEX_SET
0x21 SET_LOCAL              0x54 BIT_OR                 0x95 LEN
0x22 GET_GLOBAL             0x55 BIT_XOR                0x96 PUSH
0x23 SET_GLOBAL             0x56 BIT_NOT                0x97 POP_BACK
0x24 GET_UPVALUE            0x57 SHL                    0x98 CONTAINS
0x25 SET_UPVALUE            0x58 SHR                    0x99 ITER_START
0x26 CLOSE_UPVALUE          0x59 USHR                   0x9A ITER_NEXT
                                                        0x9B ITER_END
0x30 ADD                    0x60 JUMP                   0x9C SLICE
0x31 SUB                    0x61 JUMP_IF_TRUE           0x9D CONCAT
0x32 MUL                    0x62 JUMP_IF_FALSE
0x33 DIV                    0x63 JUMP_IF_NONE           0xA0 AI_BREAKPOINT
0x34 MOD                    0x64 JUMP_IF_SOME           0xA1 AI_LOG
0x35 NEG                    0x65 CALL                   0xA2 AI_ASSERT
0x36 POW                    0x66 CALL_INDIRECT          0xA3 AI_DECIDE
0x37 FLOOR_DIV              0x67 TAIL_CALL              0xA4 AI_EXPLAIN_START
0x38 I64_ADD                0x68 RET                    0xA5 AI_EXPLAIN_END
0x39 F64_ADD                0x69 THROW                  0xA6 AI_CALL
0x3A I64_TO_F64             0x6A TRY_START              0xA7 AI_EMBED
0x3B F64_TO_I64             0x6B TRY_END                0xA8 AI_SIMILARITY
                            0x6C CATCH                  0xA9 AI_CONTRACT
                                                        0xAA AI_INVARIANT
0x70 POP                                                0xAB AI_LEARN
0x71 DUP                    0xB0 GET_TYPE               0xAC AI_OPTIMIZE
0x72 DUP2                   0xB1 GET_TYPE_NAME          0xAD AI_FORK
0x73 SWAP                   0xB2 GET_BLOCK_META         0xAE AI_MERGE
0x74 ROT                    0xB3 GET_INTENT
0x75 OVER                   0xB4 GET_DEPENDS            0xC0 SYSCALL
0x76 DROP_N                 0xB5 GET_EFFECTS            0xC1 ALLOC
                            0xB6 GET_CALLSTACK          0xC2 FREE
                            0xB7 GET_LOCALS_INFO        0xC3 MEM_LOAD
                            0xB8 REFLECT_CALL           0xC4 MEM_STORE
                                                        0xC5 MEM_COPY
0xD0 AWAIT                  0xE0 BREAKPOINT             0xC6 MEM_ZERO
0xD1 SPAWN                  0xE1 TRACE                  0xC7 NATIVE_CALL
0xD2 YIELD                  0xE2 ASSERT
0xD3 RESUME                 0xE3 PROFILE_START
0xD4 CHANNEL_SEND           0xE4 PROFILE_END
0xD5 CHANNEL_RECV           0xE5 SOURCE_LOC
0xD6 SELECT

0xF0-0xFF RESERVED
```

---

*OpCodes Reference v1.0.0*
