# MATHIS OS - Quick Start

## 🚀 TL;DR - Par où commencer?

Tu as **65 modules** et **2200+ tests**. Tu es **prêt**.

```
╔══════════════════════════════════════════════════════════════════════════════╗
║                                                                              ║
║   TON AVANCEMENT:                                                            ║
║   ───────────────                                                            ║
║   ✅ Parser/Compiler MATHIS     → Devient l'entrée du pipeline              ║
║   ✅ Runtime existant           → Devient la base du Kernel VM               ║
║   ✅ 65 modules                 → Deviennent les SYSCALLS                    ║
║   ✅ mathis-ai module           → Devient le AI Runtime                      ║
║   ✅ mathis-async               → Devient le Scheduler                       ║
║                                                                              ║
║   CE QUI MANQUE (à créer):                                                   ║
║   ────────────────────────                                                   ║
║   ⬜ MathisASM parser           → ~500-800 lignes de Rust                   ║
║   ⬜ Assembler (.masm → .mbc)   → ~400-600 lignes                           ║
║   ⬜ Refactoring VM             → Adapter ton runtime                        ║
║   ⬜ Syscall wrappers           → Exposer tes modules                        ║
║                                                                              ║
╚══════════════════════════════════════════════════════════════════════════════╝
```

---

## 📁 Structure à Créer

```
mathis/                          # Ton repo actuel
├── llml/                        # TON CODE ACTUEL (65 modules)
│   ├── parser/
│   ├── compiler/
│   ├── runtime/                 # → À refactorer vers kernel
│   ├── crypto/                  # → Syscalls 0x0900
│   ├── http/                    # → Syscalls 0x0100
│   ├── database/                # → Syscalls 0x0700
│   ├── ai/                      # → Syscalls 0x0A00 + AI Runtime
│   └── ...
│
└── mathis-os/                   # NOUVEAU - À créer
    ├── masm/                    # MathisASM toolchain
    │   ├── src/
    │   │   ├── lexer.rs         # ← COMMENCE ICI (Day 1)
    │   │   ├── parser.rs        # (Day 2-3)
    │   │   ├── ast.rs           # (Day 2)
    │   │   ├── assembler.rs     # (Day 4-5)
    │   │   └── disasm.rs        # (Day 6)
    │   └── Cargo.toml
    │
    ├── kernel/                  # Mathis Kernel
    │   ├── src/
    │   │   ├── vm/              # Refacto de ton runtime
    │   │   ├── syscalls/        # Wrappers de tes modules
    │   │   └── ai/              # AI Runtime
    │   └── Cargo.toml
    │
    └── spec/                    # Cette documentation
```

---

## 🎯 Semaine 1: MathisASM Parser

### Jour 1-2: Lexer

Fichier: `mathis-os/masm/src/lexer.rs`

```rust
// Token types pour MathisASM
pub enum Token {
    Directive(String),    // .module, .func, .arity
    Opcode(String),       // ADD, SUB, CALL
    Label(String),        // .loop_start:
    LabelRef(String),     // .loop_start (dans JUMP)
    Ident(String),
    String(String),
    Int(i64),
    Float(f64),
    // ...
}
```

**Test de validation:**
```bash
# Doit tokenizer ce fichier sans erreur
cargo test --package masm -- lexer
```

### Jour 3-4: Parser

Fichier: `mathis-os/masm/src/parser.rs`

**Test de validation:**
```rust
let input = r#"
.module "test"
.func add
    .arity 2
    GET_LOCAL 0
    GET_LOCAL 1
    ADD
    RET
.end
"#;

let module = Parser::parse(input)?;
assert_eq!(module.functions[0].name, "add");
```

### Jour 5-6: Assembler

Fichier: `mathis-os/masm/src/assembler.rs`

**Test de validation:**
```rust
let module = Parser::parse(input)?;
let bytecode = Assembler::assemble(&module)?;

// Vérifier le header
assert_eq!(&bytecode[0..4], b"MASM");
```

---

## 🎯 Semaine 2: Kernel VM

### Refactorer ton Runtime

Ton `runtime/` actuel devient `kernel/vm/`:

```rust
// kernel/src/vm/engine.rs
pub struct VmEngine {
    stack: Vec<Value>,
    frames: Vec<CallFrame>,
    // ...
}

impl VmEngine {
    pub fn run(&mut self) -> Result<Value, VmError> {
        loop {
            let opcode = self.fetch();
            match opcode {
                0x30 => self.op_add()?,
                0xC0 => self.op_syscall()?,  // NOUVEAU!
                0xA6 => self.op_ai_call()?,  // NOUVEAU!
                // ...
            }
        }
    }
}
```

---

## 🎯 Semaine 3: Syscalls

### Wrapper un Module Existant

Exemple avec `mathis-http`:

```rust
// kernel/src/syscalls/net.rs
use mathis_http::Client;

pub fn syscall_http_get(args: Vec<Value>) -> Result<Value, SyscallError> {
    let url = args[0].as_str()?;
    
    // Utilise TON module existant!
    let response = Client::new().get(&url).send()?;
    
    Ok(response.into())
}
```

### Dispatcher

```rust
// kernel/src/syscalls/mod.rs
pub fn dispatch(id: u16, args: Vec<Value>) -> Result<Value, SyscallError> {
    match id {
        0x0120 => net::syscall_http_get(args),
        0x0900 => crypto::syscall_sha256(args),
        0x0A01 => ai::syscall_complete(args),
        // ...
    }
}
```

---

## 📊 Mapping Modules → Syscalls

| Ton Module | Syscall Range | Priorité |
|------------|---------------|----------|
| `mathis-crypto` | `0x0900-0x09FF` | ⭐⭐⭐ |
| `mathis-http` | `0x0120-0x013F` | ⭐⭐⭐ |
| `mathis-database` | `0x0700-0x07FF` | ⭐⭐⭐ |
| `mathis-ai` | `0x0A00-0x0AFF` | ⭐⭐⭐ |
| `mathis-redis` | `0x0740-0x074F` | ⭐⭐ |
| `mathis-websocket` | `0x0140-0x014F` | ⭐⭐ |
| `mathis-storage` | `0x0600-0x06FF` | ⭐⭐ |
| `mathis-email` | `0x0180-0x018F` | ⭐ |
| `mathis-fts` | `0x0E00-0x0EFF` | ⭐ |

---

## 🔥 Commande de Démarrage

```bash
# 1. Créer la structure
mkdir -p mathis-os/{masm,kernel,spec}/src

# 2. Initialiser le workspace Cargo
cd mathis-os
cat > Cargo.toml << 'EOF'
[workspace]
members = ["masm", "kernel"]
resolver = "2"
EOF

# 3. Créer masm
cd masm
cargo init --lib
cd ..

# 4. Créer kernel
cd kernel
cargo init --lib

# 5. Ajouter les dépendances vers LLML
cat >> Cargo.toml << 'EOF'
[dependencies]
mathis-crypto = { path = "../../llml/crypto" }
mathis-http = { path = "../../llml/http" }
mathis-database = { path = "../../llml/database" }
mathis-ai = { path = "../../llml/ai" }
# ... autres modules
EOF
```

---

## ✅ Validation Finale

Quand tout marche, tu pourras faire:

```bash
# 1. Écrire du MATHIS
cat > app.mhs << 'EOF'
@block("greet")
@intent("Say hello with AI")
func greet(name) {
    let response = ai.complete("Say hello to " + name)
    return response
}
EOF

# 2. Compiler vers MathisASM
mathis compile app.mhs -o app.masm

# 3. Assembler en bytecode
masm assemble app.masm -o app.mbc

# 4. Exécuter
mathis-kernel run app.mbc
# Output: "Hello, [name]! It's wonderful to meet you!"
```

---

## 📚 Documents de Référence

1. **[00-OVERVIEW.md](./00-OVERVIEW.md)** - Vue d'ensemble
2. **[01-MATHIS-ASM-SPEC.md](./01-MATHIS-ASM-SPEC.md)** - Syntaxe MathisASM
3. **[02-BYTECODE-FORMAT.md](./02-BYTECODE-FORMAT.md)** - Format .mbc
4. **[03-OPCODES.md](./03-OPCODES.md)** - Tous les opcodes
5. **[04-KERNEL-SPEC.md](./04-KERNEL-SPEC.md)** - Architecture kernel
6. **[05-AI-RUNTIME.md](./05-AI-RUNTIME.md)** - Runtime IA
7. **[06-SYSCALLS.md](./06-SYSCALLS.md)** - Tous les syscalls
8. **[08-IMPLEMENTATION-GUIDE.md](./08-IMPLEMENTATION-GUIDE.md)** - Guide détaillé

---

## 💬 Prochaine Étape

**Commence par `masm/src/lexer.rs`** - c'est le plus simple et ça débloque tout le reste.

Tu veux que je t'aide à coder le lexer? Ou une autre partie?

---

*Let's build JARVIS! 🚀*
