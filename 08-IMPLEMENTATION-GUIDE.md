# Guide d'Implémentation - MATHIS OS

## 1. Plan de Migration

Tu as déjà **65 modules** dans LLML. Voici comment les migrer vers l'architecture MATHIS OS:

```
╔══════════════════════════════════════════════════════════════════════════════╗
║                         MIGRATION STRATEGY                                   ║
║                                                                              ║
║   LLML actuel (65 modules)                                                   ║
║         │                                                                    ║
║         ▼                                                                    ║
║   ┌─────────────────────────────────────────────────────────────────────┐   ║
║   │                                                                     │   ║
║   │  1. EXTRAIRE le runtime actuel → Kernel VM                         │   ║
║   │  2. DÉFINIR MathisASM → Nouveau fichier masm/                      │   ║
║   │  3. REFACTORER le compiler → Émettre du MathisASM                  │   ║
║   │  4. WRAPPER les modules → Syscalls                                 │   ║
║   │  5. AJOUTER le AI Runtime                                          │   ║
║   │                                                                     │   ║
║   └─────────────────────────────────────────────────────────────────────┘   ║
║                                                                              ║
╚══════════════════════════════════════════════════════════════════════════════╝
```

---

## 2. Phase 1: MathisASM Parser & Assembler (1-2 semaines)

### 2.1 Structure

```
mathis-os/
└── masm/
    ├── Cargo.toml
    ├── src/
    │   ├── lib.rs
    │   ├── lexer.rs        # Tokenizer pour .masm
    │   ├── parser.rs       # Parse vers AST
    │   ├── ast.rs          # Structures AST
    │   ├── assembler.rs    # AST → Bytecode
    │   ├── disasm.rs       # Bytecode → .masm
    │   ├── bytecode.rs     # Format .mbc
    │   └── opcodes.rs      # Définition des opcodes
    └── tests/
```

### 2.2 Lexer (masm/src/lexer.rs)

```rust
use std::str::CharIndices;

#[derive(Debug, Clone, PartialEq)]
pub enum Token {
    // Keywords
    Module,
    Version,
    Import,
    Export,
    Func,
    End,
    Constants,
    Types,
    Globals,
    Struct,
    Enum,
    Alias,
    
    // Directives
    Directive(String),     // .arity, .locals, .ai_block, etc.
    
    // Literals
    Ident(String),
    String(String),
    Int(i64),
    Float(f64),
    Bool(bool),
    
    // Opcodes
    Opcode(String),        // ADD, SUB, CALL, etc.
    
    // Punctuation
    Colon,
    Comma,
    LBracket,
    RBracket,
    LBrace,
    RBrace,
    LParen,
    RParen,
    Arrow,
    
    // Labels
    Label(String),         // .loop_start:
    LabelRef(String),      // .loop_start (in JUMP)
    
    // Other
    Comment(String),
    Newline,
    Eof,
}

pub struct Lexer<'a> {
    input: &'a str,
    chars: CharIndices<'a>,
    current: Option<(usize, char)>,
    line: usize,
    col: usize,
}

impl<'a> Lexer<'a> {
    pub fn new(input: &'a str) -> Self {
        let mut chars = input.char_indices();
        let current = chars.next();
        Self {
            input,
            chars,
            current,
            line: 1,
            col: 1,
        }
    }
    
    pub fn tokenize(&mut self) -> Result<Vec<Token>, LexError> {
        let mut tokens = Vec::new();
        
        loop {
            match self.next_token()? {
                Token::Eof => {
                    tokens.push(Token::Eof);
                    break;
                }
                token => tokens.push(token),
            }
        }
        
        Ok(tokens)
    }
    
    fn next_token(&mut self) -> Result<Token, LexError> {
        self.skip_whitespace();
        
        let Some((pos, ch)) = self.current else {
            return Ok(Token::Eof);
        };
        
        match ch {
            '\n' => {
                self.advance();
                self.line += 1;
                self.col = 1;
                Ok(Token::Newline)
            }
            
            ';' => {
                // Comment
                let comment = self.read_until('\n');
                Ok(Token::Comment(comment))
            }
            
            '.' => {
                self.advance();
                let ident = self.read_ident();
                
                // Check if it's a label definition (ends with :)
                if self.current.map(|(_, c)| c) == Some(':') {
                    self.advance();
                    Ok(Token::Label(ident))
                } else if is_directive(&ident) {
                    Ok(Token::Directive(ident))
                } else {
                    Ok(Token::LabelRef(ident))
                }
            }
            
            '"' => {
                let s = self.read_string()?;
                Ok(Token::String(s))
            }
            
            '0'..='9' | '-' => {
                let num = self.read_number()?;
                Ok(num)
            }
            
            'a'..='z' | 'A'..='Z' | '_' => {
                let ident = self.read_ident();
                
                // Check if it's a keyword or opcode
                match ident.as_str() {
                    "true" => Ok(Token::Bool(true)),
                    "false" => Ok(Token::Bool(false)),
                    "none" => Ok(Token::Ident("none".into())),
                    _ if is_opcode(&ident) => Ok(Token::Opcode(ident)),
                    _ => Ok(Token::Ident(ident)),
                }
            }
            
            ':' => { self.advance(); Ok(Token::Colon) }
            ',' => { self.advance(); Ok(Token::Comma) }
            '[' => { self.advance(); Ok(Token::LBracket) }
            ']' => { self.advance(); Ok(Token::RBracket) }
            '{' => { self.advance(); Ok(Token::LBrace) }
            '}' => { self.advance(); Ok(Token::RBrace) }
            '(' => { self.advance(); Ok(Token::LParen) }
            ')' => { self.advance(); Ok(Token::RParen) }
            
            _ => Err(LexError::UnexpectedChar(ch, self.line, self.col)),
        }
    }
    
    // ... helper methods
}

fn is_opcode(s: &str) -> bool {
    matches!(s, 
        "NOP" | "HALT" | "CONST" | "CONST_I64" | "CONST_F64" | "CONST_STR" |
        "CONST_NONE" | "CONST_TRUE" | "CONST_FALSE" |
        "GET_LOCAL" | "SET_LOCAL" | "GET_GLOBAL" | "SET_GLOBAL" |
        "ADD" | "SUB" | "MUL" | "DIV" | "MOD" | "NEG" |
        "EQ" | "NE" | "LT" | "LE" | "GT" | "GE" |
        "AND" | "OR" | "NOT" |
        "JUMP" | "JUMP_IF_TRUE" | "JUMP_IF_FALSE" |
        "CALL" | "RET" | "SYSCALL" |
        "DUP" | "POP" | "SWAP" |
        "MAKE_STRUCT" | "GET_FIELD" | "SET_FIELD" |
        "MAKE_LIST" | "MAKE_MAP" | "INDEX" |
        "AI_CALL" | "AI_DECIDE" | "AI_EXPLAIN_START" | "AI_EXPLAIN_END" |
        // ... autres opcodes
        _ => false
    )
}
```

### 2.3 AST (masm/src/ast.rs)

```rust
#[derive(Debug, Clone)]
pub struct Module {
    pub name: String,
    pub version: Option<String>,
    pub imports: Vec<Import>,
    pub exports: Vec<String>,
    pub constants: Vec<Constant>,
    pub types: Vec<TypeDef>,
    pub globals: Vec<Global>,
    pub functions: Vec<Function>,
}

#[derive(Debug, Clone)]
pub struct Import {
    pub module: String,
    pub alias: String,
}

#[derive(Debug, Clone)]
pub struct Constant {
    pub index: u32,
    pub value: ConstValue,
}

#[derive(Debug, Clone)]
pub enum ConstValue {
    None,
    Bool(bool),
    Int(i64),
    Float(f64),
    String(String),
    List(Vec<ConstValue>),
    Map(Vec<(ConstValue, ConstValue)>),
}

#[derive(Debug, Clone)]
pub struct TypeDef {
    pub name: String,
    pub kind: TypeKind,
}

#[derive(Debug, Clone)]
pub enum TypeKind {
    Struct(Vec<Field>),
    Enum(Vec<Variant>),
    Alias(TypeSig),
}

#[derive(Debug, Clone)]
pub struct Field {
    pub name: String,
    pub type_sig: TypeSig,
    pub default: Option<ConstValue>,
}

#[derive(Debug, Clone)]
pub struct Function {
    pub name: String,
    pub arity: u8,
    pub locals: u8,
    pub returns: Option<TypeSig>,
    pub params: Vec<TypeSig>,
    pub ai_metadata: Option<AiMetadata>,
    pub code: Vec<Instruction>,
    pub labels: HashMap<String, usize>,
}

#[derive(Debug, Clone)]
pub struct AiMetadata {
    pub block_name: Option<String>,
    pub intent: Option<String>,
    pub is_pure: bool,
    pub complexity: Option<String>,
    pub depends: Vec<String>,
    pub effects: Vec<String>,
}

#[derive(Debug, Clone)]
pub enum Instruction {
    // Control
    Nop,
    Halt,
    
    // Constants
    Const(u16),
    ConstNone,
    ConstTrue,
    ConstFalse,
    ConstI64(i64),
    ConstF64(f64),
    ConstStr(String),
    
    // Variables
    GetLocal(u8),
    SetLocal(u8),
    GetGlobal(u16),
    SetGlobal(u16),
    
    // Arithmetic
    Add,
    Sub,
    Mul,
    Div,
    Mod,
    Neg,
    
    // Comparison
    Eq,
    Ne,
    Lt,
    Le,
    Gt,
    Ge,
    
    // Logic
    And,
    Or,
    Not,
    
    // Control flow
    Jump(i32),           // Offset relatif
    JumpIfTrue(i32),
    JumpIfFalse(i32),
    JumpLabel(String),   // Résolu en offset lors de l'assemblage
    JumpIfTrueLabel(String),
    JumpIfFalseLabel(String),
    Call(u16, u8),       // func_idx, argc
    TailCall(u16, u8),
    Ret,
    
    // Stack
    Pop,
    Dup,
    Swap,
    
    // Objects
    MakeStruct(u16, u8), // type_id, field_count
    GetField(u16),
    SetField(u16),
    
    // Collections
    MakeList(u16),
    MakeMap(u16),
    Index,
    IndexSet,
    
    // AI
    AiBreakpoint,
    AiCall(u8),          // model_hint
    AiDecide(u8),        // options_count
    AiExplainStart(u16), // label_idx
    AiExplainEnd,
    
    // System
    Syscall(u16),
    
    // Label (pseudo-instruction, removed during assembly)
    Label(String),
}
```

### 2.4 Parser (masm/src/parser.rs)

```rust
pub struct Parser {
    tokens: Vec<Token>,
    pos: usize,
}

impl Parser {
    pub fn new(tokens: Vec<Token>) -> Self {
        Self { tokens, pos: 0 }
    }
    
    pub fn parse(&mut self) -> Result<Module, ParseError> {
        let mut module = Module {
            name: String::new(),
            version: None,
            imports: Vec::new(),
            exports: Vec::new(),
            constants: Vec::new(),
            types: Vec::new(),
            globals: Vec::new(),
            functions: Vec::new(),
        };
        
        while !self.is_at_end() {
            self.skip_newlines();
            
            match self.current() {
                Token::Directive(d) if d == "module" => {
                    self.advance();
                    module.name = self.expect_string()?;
                }
                Token::Directive(d) if d == "version" => {
                    self.advance();
                    module.version = Some(self.expect_string()?);
                }
                Token::Directive(d) if d == "import" => {
                    module.imports.push(self.parse_import()?);
                }
                Token::Directive(d) if d == "export" => {
                    self.advance();
                    module.exports.push(self.expect_string()?);
                }
                Token::Directive(d) if d == "constants" => {
                    self.advance();
                    self.expect(Token::Colon)?;
                    module.constants = self.parse_constants()?;
                }
                Token::Directive(d) if d == "types" => {
                    self.advance();
                    self.expect(Token::Colon)?;
                    module.types = self.parse_types()?;
                }
                Token::Directive(d) if d == "func" => {
                    module.functions.push(self.parse_function()?);
                }
                Token::Eof => break,
                Token::Newline | Token::Comment(_) => {
                    self.advance();
                }
                _ => return Err(ParseError::UnexpectedToken(self.current().clone())),
            }
        }
        
        Ok(module)
    }
    
    fn parse_function(&mut self) -> Result<Function, ParseError> {
        self.expect_directive("func")?;
        let name = self.expect_ident()?;
        self.skip_newlines();
        
        let mut func = Function {
            name,
            arity: 0,
            locals: 0,
            returns: None,
            params: Vec::new(),
            ai_metadata: None,
            code: Vec::new(),
            labels: HashMap::new(),
        };
        
        // Parse directives
        while let Token::Directive(d) = self.current() {
            match d.as_str() {
                "arity" => {
                    self.advance();
                    func.arity = self.expect_int()? as u8;
                }
                "locals" => {
                    self.advance();
                    func.locals = self.expect_int()? as u8;
                }
                "returns" => {
                    self.advance();
                    func.returns = Some(self.parse_type_sig()?);
                }
                "ai_block" => {
                    self.advance();
                    let ai = func.ai_metadata.get_or_insert(AiMetadata::default());
                    ai.block_name = Some(self.expect_string()?);
                }
                "ai_intent" => {
                    self.advance();
                    let ai = func.ai_metadata.get_or_insert(AiMetadata::default());
                    ai.intent = Some(self.expect_string()?);
                }
                "ai_pure" => {
                    self.advance();
                    let ai = func.ai_metadata.get_or_insert(AiMetadata::default());
                    ai.is_pure = self.expect_bool()?;
                }
                "end" => break,
                _ => {
                    // Skip unknown directives
                    self.advance();
                    self.skip_until_newline();
                }
            }
            self.skip_newlines();
        }
        
        // Parse instructions
        while !matches!(self.current(), Token::Directive(d) if d == "end") {
            self.skip_newlines();
            
            match self.current() {
                Token::Label(name) => {
                    let label_name = name.clone();
                    self.advance();
                    func.labels.insert(label_name.clone(), func.code.len());
                    func.code.push(Instruction::Label(label_name));
                }
                Token::Opcode(op) => {
                    let inst = self.parse_instruction(op.clone())?;
                    func.code.push(inst);
                }
                Token::Comment(_) | Token::Newline => {
                    self.advance();
                }
                Token::Directive(d) if d == "end" => break,
                _ => return Err(ParseError::ExpectedInstruction),
            }
        }
        
        self.expect_directive("end")?;
        
        Ok(func)
    }
    
    fn parse_instruction(&mut self, opcode: String) -> Result<Instruction, ParseError> {
        self.advance(); // consume opcode
        
        let inst = match opcode.as_str() {
            "NOP" => Instruction::Nop,
            "HALT" => Instruction::Halt,
            
            "CONST" => Instruction::Const(self.expect_int()? as u16),
            "CONST_NONE" => Instruction::ConstNone,
            "CONST_TRUE" => Instruction::ConstTrue,
            "CONST_FALSE" => Instruction::ConstFalse,
            "CONST_I64" => Instruction::ConstI64(self.expect_int()?),
            "CONST_F64" => Instruction::ConstF64(self.expect_float()?),
            "CONST_STR" => Instruction::ConstStr(self.expect_string()?),
            
            "GET_LOCAL" => Instruction::GetLocal(self.expect_int()? as u8),
            "SET_LOCAL" => Instruction::SetLocal(self.expect_int()? as u8),
            "GET_GLOBAL" => Instruction::GetGlobal(self.expect_int()? as u16),
            "SET_GLOBAL" => Instruction::SetGlobal(self.expect_int()? as u16),
            
            "ADD" => Instruction::Add,
            "SUB" => Instruction::Sub,
            "MUL" => Instruction::Mul,
            "DIV" => Instruction::Div,
            "MOD" => Instruction::Mod,
            "NEG" => Instruction::Neg,
            
            "EQ" => Instruction::Eq,
            "NE" => Instruction::Ne,
            "LT" => Instruction::Lt,
            "LE" => Instruction::Le,
            "GT" => Instruction::Gt,
            "GE" => Instruction::Ge,
            
            "AND" => Instruction::And,
            "OR" => Instruction::Or,
            "NOT" => Instruction::Not,
            
            "JUMP" => {
                if let Token::LabelRef(label) = self.current() {
                    let label = label.clone();
                    self.advance();
                    Instruction::JumpLabel(label)
                } else {
                    Instruction::Jump(self.expect_int()? as i32)
                }
            }
            "JUMP_IF_TRUE" => {
                if let Token::LabelRef(label) = self.current() {
                    let label = label.clone();
                    self.advance();
                    Instruction::JumpIfTrueLabel(label)
                } else {
                    Instruction::JumpIfTrue(self.expect_int()? as i32)
                }
            }
            "JUMP_IF_FALSE" => {
                if let Token::LabelRef(label) = self.current() {
                    let label = label.clone();
                    self.advance();
                    Instruction::JumpIfFalseLabel(label)
                } else {
                    Instruction::JumpIfFalse(self.expect_int()? as i32)
                }
            }
            
            "CALL" => {
                let func_idx = self.expect_int()? as u16;
                let argc = self.expect_int()? as u8;
                Instruction::Call(func_idx, argc)
            }
            
            "RET" => Instruction::Ret,
            
            "POP" => Instruction::Pop,
            "DUP" => Instruction::Dup,
            "SWAP" => Instruction::Swap,
            
            "MAKE_STRUCT" => {
                let type_name = self.expect_string()?;
                let field_count = self.expect_int()? as u8;
                // TODO: resolve type_name to type_id
                Instruction::MakeStruct(0, field_count)
            }
            "GET_FIELD" => Instruction::GetField(self.expect_int()? as u16),
            "SET_FIELD" => Instruction::SetField(self.expect_int()? as u16),
            
            "MAKE_LIST" => Instruction::MakeList(self.expect_int()? as u16),
            "MAKE_MAP" => Instruction::MakeMap(self.expect_int()? as u16),
            "INDEX" => Instruction::Index,
            "INDEX_SET" => Instruction::IndexSet,
            
            "AI_BREAKPOINT" => Instruction::AiBreakpoint,
            "AI_CALL" => Instruction::AiCall(self.expect_int()? as u8),
            "AI_DECIDE" => Instruction::AiDecide(self.expect_int()? as u8),
            "AI_EXPLAIN_START" => Instruction::AiExplainStart(self.expect_int()? as u16),
            "AI_EXPLAIN_END" => Instruction::AiExplainEnd,
            
            "SYSCALL" => Instruction::Syscall(self.expect_int()? as u16),
            
            _ => return Err(ParseError::UnknownOpcode(opcode)),
        };
        
        Ok(inst)
    }
}
```

### 2.5 Assembler (masm/src/assembler.rs)

```rust
use crate::ast::*;
use crate::bytecode::*;

pub struct Assembler {
    /// Bytecode output
    output: Vec<u8>,
    
    /// Constant pool
    constants: Vec<ConstantEntry>,
    
    /// Function table
    functions: Vec<FunctionEntry>,
    
    /// Current position in output
    pos: usize,
}

impl Assembler {
    pub fn new() -> Self {
        Self {
            output: Vec::new(),
            constants: Vec::new(),
            functions: Vec::new(),
            pos: 0,
        }
    }
    
    pub fn assemble(&mut self, module: &Module) -> Result<Vec<u8>, AssembleError> {
        // 1. Build constant pool
        self.build_constants(&module.constants)?;
        
        // 2. Assemble functions
        for func in &module.functions {
            self.assemble_function(func)?;
        }
        
        // 3. Build final bytecode
        self.build_bytecode(module)
    }
    
    fn assemble_function(&mut self, func: &Function) -> Result<(), AssembleError> {
        let code_start = self.output.len();
        
        // First pass: collect label positions
        let mut label_positions: HashMap<String, usize> = HashMap::new();
        let mut current_pos = 0;
        
        for inst in &func.code {
            if let Instruction::Label(name) = inst {
                label_positions.insert(name.clone(), current_pos);
            } else {
                current_pos += instruction_size(inst);
            }
        }
        
        // Second pass: emit bytecode
        let mut inst_pos = 0;
        for inst in &func.code {
            match inst {
                Instruction::Label(_) => continue, // Skip labels
                
                // Resolve label references
                Instruction::JumpLabel(label) => {
                    let target = *label_positions.get(label)
                        .ok_or(AssembleError::UndefinedLabel(label.clone()))?;
                    let offset = (target as i32) - (inst_pos as i32 + 5); // 5 = opcode + i32
                    self.emit_u8(0x60); // JUMP opcode
                    self.emit_i32(offset);
                }
                Instruction::JumpIfTrueLabel(label) => {
                    let target = *label_positions.get(label)
                        .ok_or(AssembleError::UndefinedLabel(label.clone()))?;
                    let offset = (target as i32) - (inst_pos as i32 + 5);
                    self.emit_u8(0x61); // JUMP_IF_TRUE opcode
                    self.emit_i32(offset);
                }
                Instruction::JumpIfFalseLabel(label) => {
                    let target = *label_positions.get(label)
                        .ok_or(AssembleError::UndefinedLabel(label.clone()))?;
                    let offset = (target as i32) - (inst_pos as i32 + 5);
                    self.emit_u8(0x62); // JUMP_IF_FALSE opcode
                    self.emit_i32(offset);
                }
                
                // Regular instructions
                _ => self.emit_instruction(inst)?,
            }
            
            inst_pos += instruction_size(inst);
        }
        
        let code_size = self.output.len() - code_start;
        
        // Add to function table
        self.functions.push(FunctionEntry {
            name_idx: self.add_string_constant(&func.name),
            arity: func.arity,
            locals: func.locals,
            code_offset: code_start as u32,
            code_size: code_size as u32,
            ai_meta_idx: None, // TODO
        });
        
        Ok(())
    }
    
    fn emit_instruction(&mut self, inst: &Instruction) -> Result<(), AssembleError> {
        match inst {
            Instruction::Nop => self.emit_u8(0x00),
            Instruction::Halt => self.emit_u8(0x01),
            
            Instruction::Const(idx) => {
                self.emit_u8(0x10);
                self.emit_u16(*idx);
            }
            Instruction::ConstNone => self.emit_u8(0x11),
            Instruction::ConstTrue => self.emit_u8(0x12),
            Instruction::ConstFalse => self.emit_u8(0x13),
            Instruction::ConstI64(v) => {
                self.emit_u8(0x14);
                self.emit_i64(*v);
            }
            Instruction::ConstF64(v) => {
                self.emit_u8(0x15);
                self.emit_f64(*v);
            }
            
            Instruction::GetLocal(idx) => {
                self.emit_u8(0x20);
                self.emit_u8(*idx);
            }
            Instruction::SetLocal(idx) => {
                self.emit_u8(0x21);
                self.emit_u8(*idx);
            }
            
            Instruction::Add => self.emit_u8(0x30),
            Instruction::Sub => self.emit_u8(0x31),
            Instruction::Mul => self.emit_u8(0x32),
            Instruction::Div => self.emit_u8(0x33),
            
            Instruction::Eq => self.emit_u8(0x40),
            Instruction::Ne => self.emit_u8(0x41),
            Instruction::Lt => self.emit_u8(0x42),
            
            Instruction::Jump(offset) => {
                self.emit_u8(0x60);
                self.emit_i32(*offset);
            }
            Instruction::JumpIfTrue(offset) => {
                self.emit_u8(0x61);
                self.emit_i32(*offset);
            }
            Instruction::JumpIfFalse(offset) => {
                self.emit_u8(0x62);
                self.emit_i32(*offset);
            }
            
            Instruction::Call(func_idx, argc) => {
                self.emit_u8(0x65);
                self.emit_u16(*func_idx);
                self.emit_u8(*argc);
            }
            Instruction::Ret => self.emit_u8(0x68),
            
            Instruction::Pop => self.emit_u8(0x70),
            Instruction::Dup => self.emit_u8(0x71),
            Instruction::Swap => self.emit_u8(0x73),
            
            Instruction::Syscall(id) => {
                self.emit_u8(0xC0);
                self.emit_u16(*id);
            }
            
            Instruction::AiBreakpoint => self.emit_u8(0xA0),
            Instruction::AiCall(hint) => {
                self.emit_u8(0xA6);
                self.emit_u8(*hint);
            }
            
            _ => return Err(AssembleError::UnsupportedInstruction),
        }
        
        Ok(())
    }
    
    fn emit_u8(&mut self, v: u8) {
        self.output.push(v);
    }
    
    fn emit_u16(&mut self, v: u16) {
        self.output.extend_from_slice(&v.to_le_bytes());
    }
    
    fn emit_u32(&mut self, v: u32) {
        self.output.extend_from_slice(&v.to_le_bytes());
    }
    
    fn emit_i32(&mut self, v: i32) {
        self.output.extend_from_slice(&v.to_le_bytes());
    }
    
    fn emit_i64(&mut self, v: i64) {
        self.output.extend_from_slice(&v.to_le_bytes());
    }
    
    fn emit_f64(&mut self, v: f64) {
        self.output.extend_from_slice(&v.to_le_bytes());
    }
}
```

---

## 3. Phase 2: Kernel VM (2-3 semaines)

### 3.1 Refactorer ton Runtime Actuel

Tu as déjà un `runtime/` dans LLML. L'idée est de:

1. **Extraire** la boucle d'exécution
2. **Adapter** pour lire le format .mbc
3. **Ajouter** les instructions AI

### 3.2 Structure Cible

```
mathis-os/
└── kernel/
    ├── Cargo.toml
    ├── src/
    │   ├── lib.rs
    │   ├── vm/
    │   │   ├── mod.rs
    │   │   ├── engine.rs      # Boucle d'exécution
    │   │   ├── stack.rs       # Stack operations
    │   │   ├── frame.rs       # Call frames
    │   │   └── value.rs       # Types de valeurs
    │   │
    │   ├── memory/
    │   │   ├── mod.rs
    │   │   ├── allocator.rs   # Allocateur
    │   │   ├── gc.rs          # Garbage collector
    │   │   └── heap.rs        # Heap management
    │   │
    │   ├── scheduler/
    │   │   ├── mod.rs
    │   │   ├── task.rs        # Tâches
    │   │   ├── executor.rs    # Async executor
    │   │   └── channel.rs     # Channels
    │   │
    │   └── syscalls/
    │       ├── mod.rs
    │       ├── io.rs          # Wrapper mathis-io
    │       ├── net.rs         # Wrapper mathis-http, etc.
    │       ├── crypto.rs      # Wrapper mathis-crypto
    │       ├── ai.rs          # Wrapper mathis-ai
    │       └── db.rs          # Wrapper mathis-database
    └── tests/
```

### 3.3 Wrapper les Modules Existants

Tes 65 modules deviennent des **syscalls**. Exemple pour `mathis-http`:

```rust
// kernel/src/syscalls/net.rs

use mathis_http::{Client, Request, Response};
use crate::vm::{Value, VmError};

pub fn handle_http_syscall(
    syscall_id: u16,
    args: Vec<Value>,
) -> Result<Value, VmError> {
    match syscall_id {
        // http_get
        0x0120 => {
            let url = args[0].as_str()?;
            
            // Utilise ton module http existant!
            let client = Client::new();
            let response = client.get(&url).send()?;
            
            Ok(Value::Struct(response_to_value(response)))
        }
        
        // http_post
        0x0121 => {
            let url = args[0].as_str()?;
            let body = args[1].as_bytes()?;
            let headers = args[2].as_map()?;
            
            let client = Client::new();
            let mut req = client.post(&url).body(body);
            
            for (k, v) in headers {
                req = req.header(k.as_str()?, v.as_str()?);
            }
            
            let response = req.send()?;
            Ok(Value::Struct(response_to_value(response)))
        }
        
        _ => Err(VmError::UnknownSyscall(syscall_id)),
    }
}
```

---

## 4. Phase 3: AI Runtime (1-2 semaines)

### 4.1 Wrapper mathis-ai

```rust
// kernel/src/ai/mod.rs

use mathis_ai::{AiClient, ChatMessage, EmbeddingRequest};
use crate::vm::{Value, VmEngine};

pub struct AiRuntime {
    client: AiClient,
    config: AiConfig,
}

impl AiRuntime {
    pub fn new(config: AiConfig) -> Self {
        Self {
            client: AiClient::new()
                .with_provider(&config.provider)
                .with_api_key(&config.api_key),
            config,
        }
    }
    
    /// Implémente AI_CALL
    pub async fn call(
        &self,
        prompt: &str,
        model_hint: u8,
    ) -> Result<String, AiError> {
        let model = match model_hint {
            0 => &self.config.default_model,
            1 => "gpt-3.5-turbo",  // fast
            2 => "gpt-4",          // smart
            3 => "ollama/llama3",  // local
            _ => &self.config.default_model,
        };
        
        self.client.complete(prompt, model).await
    }
    
    /// Implémente AI_DECIDE
    pub async fn decide(
        &self,
        options: Vec<Value>,
        context: &VmSnapshot,
    ) -> Result<usize, AiError> {
        let prompt = format!(
            "Choose the best option (0-{}): {:?}\nContext: {:?}",
            options.len() - 1,
            options,
            context
        );
        
        let response = self.client.complete(&prompt, "gpt-3.5-turbo").await?;
        response.trim().parse().map_err(|_| AiError::InvalidResponse)
    }
}
```

---

## 5. Phase 4: Compiler Upgrade (2-3 semaines)

### 5.1 Modifier le Compiler LLML

Ton compiler actuel génère probablement du JS/TS ou du bytecode propriétaire. Il faut le modifier pour émettre du **MathisASM**.

```rust
// llml/compiler/src/codegen/masm.rs

use crate::ast::*;
use std::fmt::Write;

pub struct MasmCodegen {
    output: String,
    indent: usize,
    const_pool: Vec<String>,
    func_counter: usize,
}

impl MasmCodegen {
    pub fn generate(&mut self, module: &AstModule) -> String {
        // Header
        writeln!(self.output, ".module \"{}\"", module.name).unwrap();
        
        // Imports
        for import in &module.imports {
            writeln!(self.output, ".import \"{}\" as {}", 
                import.path, import.alias).unwrap();
        }
        
        // Exports
        for export in &module.exports {
            writeln!(self.output, ".export \"{}\"", export).unwrap();
        }
        
        // Constants
        writeln!(self.output, "\n.constants:").unwrap();
        for (idx, constant) in self.const_pool.iter().enumerate() {
            writeln!(self.output, "    {}: {}", idx, constant).unwrap();
        }
        
        // Functions
        for func in &module.functions {
            self.generate_function(func);
        }
        
        self.output.clone()
    }
    
    fn generate_function(&mut self, func: &AstFunction) {
        writeln!(self.output, "\n.func {}", func.name).unwrap();
        writeln!(self.output, "    .arity {}", func.params.len()).unwrap();
        writeln!(self.output, "    .locals {}", func.locals.len()).unwrap();
        
        // AI metadata from decorators
        if let Some(block) = &func.block_annotation {
            writeln!(self.output, "    .ai_block \"{}\"", block).unwrap();
        }
        if let Some(intent) = &func.intent_annotation {
            writeln!(self.output, "    .ai_intent \"{}\"", intent).unwrap();
        }
        
        writeln!(self.output).unwrap();
        
        // Body
        self.generate_block(&func.body);
        
        writeln!(self.output, ".end").unwrap();
    }
    
    fn generate_expr(&mut self, expr: &AstExpr) {
        match expr {
            AstExpr::Int(n) => {
                writeln!(self.output, "    CONST_I64 {}", n).unwrap();
            }
            AstExpr::Float(n) => {
                writeln!(self.output, "    CONST_F64 {}", n).unwrap();
            }
            AstExpr::String(s) => {
                let idx = self.add_string_const(s);
                writeln!(self.output, "    CONST {}", idx).unwrap();
            }
            AstExpr::Ident(name) => {
                if let Some(idx) = self.find_local(name) {
                    writeln!(self.output, "    GET_LOCAL {}", idx).unwrap();
                } else {
                    writeln!(self.output, "    GET_GLOBAL {}", 
                        self.find_global(name)).unwrap();
                }
            }
            AstExpr::BinOp(left, op, right) => {
                self.generate_expr(left);
                self.generate_expr(right);
                let opcode = match op {
                    BinOp::Add => "ADD",
                    BinOp::Sub => "SUB",
                    BinOp::Mul => "MUL",
                    BinOp::Div => "DIV",
                    BinOp::Eq => "EQ",
                    BinOp::Lt => "LT",
                    // ...
                };
                writeln!(self.output, "    {}", opcode).unwrap();
            }
            AstExpr::Call(name, args) => {
                // Push args
                for arg in args {
                    self.generate_expr(arg);
                }
                
                // Check if it's a syscall
                if let Some(syscall_id) = self.resolve_syscall(name) {
                    writeln!(self.output, "    SYSCALL 0x{:04X}", syscall_id).unwrap();
                } else {
                    let func_idx = self.find_function(name);
                    writeln!(self.output, "    CALL {} {}", func_idx, args.len()).unwrap();
                }
            }
            // ...
        }
    }
}
```

---

## 6. Checklist de Démarrage

```
╔══════════════════════════════════════════════════════════════════════════════╗
║                         CHECKLIST DÉMARRAGE                                 ║
╠══════════════════════════════════════════════════════════════════════════════╣
║                                                                              ║
║  SEMAINE 1-2: MathisASM                                                     ║
║  ─────────────────────────                                                   ║
║  □ Créer mathis-os/masm/                                                    ║
║  □ Implémenter le lexer                                                     ║
║  □ Implémenter le parser                                                    ║
║  □ Implémenter l'assembler (AST → bytecode)                                ║
║  □ Implémenter le disassembler (bytecode → AST)                            ║
║  □ Tests: parser round-trip                                                 ║
║                                                                              ║
║  SEMAINE 3-4: Kernel VM                                                     ║
║  ─────────────────────────                                                   ║
║  □ Créer mathis-os/kernel/                                                  ║
║  □ Migrer/refactorer le runtime LLML existant                              ║
║  □ Adapter pour lire .mbc                                                   ║
║  □ Implémenter les opcodes de base                                         ║
║  □ Implémenter SYSCALL dispatch                                            ║
║  □ Tests: exécution simple                                                  ║
║                                                                              ║
║  SEMAINE 5: Syscalls                                                        ║
║  ─────────────────────────                                                   ║
║  □ Wrapper mathis-crypto → syscalls 0x0900                                 ║
║  □ Wrapper mathis-http → syscalls 0x0100                                   ║
║  □ Wrapper mathis-database → syscalls 0x0700                               ║
║  □ Wrapper mathis-ai → syscalls 0x0A00                                     ║
║  □ Tests: syscalls fonctionnent                                             ║
║                                                                              ║
║  SEMAINE 6: AI Runtime                                                      ║
║  ─────────────────────────                                                   ║
║  □ Implémenter AI_CALL, AI_DECIDE                                          ║
║  □ Implémenter AI_EXPLAIN_START/END                                        ║
║  □ Implémenter introspection basique                                        ║
║  □ Tests: AI fonctionne                                                     ║
║                                                                              ║
║  SEMAINE 7-8: Compiler Upgrade                                              ║
║  ─────────────────────────                                                   ║
║  □ Modifier le compiler LLML                                                ║
║  □ Émettre du MathisASM au lieu de JS                                      ║
║  □ Préserver les annotations @block/@intent                                ║
║  □ Tests: compilation end-to-end                                            ║
║                                                                              ║
╚══════════════════════════════════════════════════════════════════════════════╝
```

---

## 7. Ordre de Priorité

```
1. masm/lexer.rs        ← COMMENCE ICI
2. masm/parser.rs
3. masm/assembler.rs
4. kernel/vm/engine.rs  ← Puis ici
5. kernel/syscalls/     ← Wrapper tes modules
6. ai-runtime/          ← Le fun!
7. compiler upgrade     ← Boucle la boucle
```

---

*Implementation Guide v1.0.0*
