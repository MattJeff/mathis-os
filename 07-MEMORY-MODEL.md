# Memory Model - Spécification

## 1. Vue d'Ensemble

Le **Memory Model** de MATHIS OS définit comment la mémoire est gérée:

- **Stack**: Valeurs temporaires, frames d'appel
- **Heap**: Objets alloués dynamiquement (GC)
- **Raw Memory**: Accès direct (kernel mode uniquement)
- **Constant Pool**: Constantes du module (read-only)

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           MÉMOIRE MATHIS                                    │
│                                                                             │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────────────────┐ │
│  │     STACK       │  │      HEAP       │  │      CONSTANT POOL          │ │
│  │                 │  │                 │  │                             │ │
│  │  ┌───────────┐  │  │  ┌───────────┐  │  │  0: "hello"                │ │
│  │  │ Frame 2   │  │  │  │  Object   │  │  │  1: 3.14159                │ │
│  │  │ locals    │  │  │  │  (String) │◄─┼──┤  2: [1, 2, 3]              │ │
│  │  │ stack     │  │  │  └───────────┘  │  │  ...                       │ │
│  │  ├───────────┤  │  │                 │  │                             │ │
│  │  │ Frame 1   │  │  │  ┌───────────┐  │  └─────────────────────────────┘ │
│  │  │ locals    │  │  │  │  Object   │  │                                  │
│  │  │ stack     │  │  │  │  (List)   │  │  ┌─────────────────────────────┐ │
│  │  ├───────────┤  │  │  └───────────┘  │  │      RAW MEMORY             │ │
│  │  │ Frame 0   │  │  │                 │  │    (Kernel Mode Only)       │ │
│  │  │ (main)    │  │  │  ┌───────────┐  │  │                             │ │
│  │  └───────────┘  │  │  │  Object   │  │  │  FFI buffers               │ │
│  │                 │  │  │  (Map)    │  │  │  Native allocations        │ │
│  └─────────────────┘  │  └───────────┘  │  │  Memory-mapped I/O         │ │
│          │            │        │        │  └─────────────────────────────┘ │
│          │            │        │        │                                  │
│          ▼            │        ▼        │                                  │
│  Automatic cleanup    │  Garbage        │                                  │
│  (pop frame)          │  Collection     │                                  │
│                       │                 │                                  │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 2. Types de Valeurs

### 2.1 Valeurs Immédiates (Stack)

Ces valeurs sont stockées directement sur la stack:

```rust
pub enum Value {
    // Immédiates (64 bits max, copiées)
    None,                    // 0 bits de données
    Bool(bool),              // 1 bit effectif
    Int(i64),                // 64 bits
    Float(f64),              // 64 bits
    Char(char),              // 32 bits (Unicode)
    
    // Références vers le heap (pointeur 64 bits)
    String(GcRef<MathisString>),
    List(GcRef<MathisList>),
    Map(GcRef<MathisMap>),
    Set(GcRef<MathisSet>),
    Tuple(GcRef<MathisTuple>),
    Struct(GcRef<MathisStruct>),
    Closure(GcRef<MathisClosure>),
    Bytes(GcRef<MathisBytes>),
    // ...
    
    // Kernel mode uniquement
    RawPtr(usize),
}
```

### 2.2 Layout en Mémoire

```
Value sur la stack (16 bytes, aligned):
┌────────────────┬────────────────┐
│  Tag (8 bytes) │  Data (8 bytes)│
└────────────────┴────────────────┘

Exemples:
  None:   [0x00, ........]  [0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]
  Bool:   [0x01, ........]  [0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]
  Int:    [0x02, ........]  [i64 little-endian]
  Float:  [0x03, ........]  [f64 IEEE 754]
  String: [0x10, ........]  [GcRef pointer]
```

---

## 3. Stack

### 3.1 Structure

```rust
pub struct Stack {
    /// Buffer de valeurs
    data: Vec<Value>,
    
    /// Pointeur de stack (index du prochain slot libre)
    sp: usize,
    
    /// Taille maximale
    max_size: usize,
}

impl Stack {
    pub fn new(max_size: usize) -> Self {
        Self {
            data: Vec::with_capacity(1024),
            sp: 0,
            max_size,
        }
    }
    
    pub fn push(&mut self, value: Value) -> Result<(), StackOverflow> {
        if self.sp >= self.max_size {
            return Err(StackOverflow);
        }
        if self.sp >= self.data.len() {
            self.data.push(value);
        } else {
            self.data[self.sp] = value;
        }
        self.sp += 1;
        Ok(())
    }
    
    pub fn pop(&mut self) -> Result<Value, StackUnderflow> {
        if self.sp == 0 {
            return Err(StackUnderflow);
        }
        self.sp -= 1;
        Ok(std::mem::take(&mut self.data[self.sp]))
    }
    
    pub fn peek(&self) -> Result<&Value, StackUnderflow> {
        if self.sp == 0 {
            return Err(StackUnderflow);
        }
        Ok(&self.data[self.sp - 1])
    }
    
    pub fn peek_n(&self, n: usize) -> Result<&Value, StackUnderflow> {
        if self.sp <= n {
            return Err(StackUnderflow);
        }
        Ok(&self.data[self.sp - 1 - n])
    }
}
```

### 3.2 Call Frames

```rust
pub struct CallFrame {
    /// Fonction en cours d'exécution
    pub function: FunctionRef,
    
    /// Program counter (offset dans le bytecode)
    pub pc: usize,
    
    /// Base de la stack pour ce frame
    pub stack_base: usize,
    
    /// Variables locales
    pub locals: Vec<Value>,
    
    /// Upvalues (pour closures)
    pub upvalues: Vec<UpvalueRef>,
    
    /// Handler d'exception actif
    pub exception_handler: Option<ExceptionHandler>,
}

impl CallFrame {
    pub fn get_local(&self, idx: u8) -> &Value {
        &self.locals[idx as usize]
    }
    
    pub fn set_local(&mut self, idx: u8, value: Value) {
        self.locals[idx as usize] = value;
    }
}
```

### 3.3 Gestion des Frames

```
Avant CALL:
┌─────────────────────────────────────┐
│ Stack                               │
│                                     │
│  [...] [arg1] [arg2] [arg3]        │
│                        ▲            │
│                        SP           │
└─────────────────────────────────────┘

Après CALL (nouveau frame créé):
┌─────────────────────────────────────┐
│ Stack                               │
│                                     │
│  [...] [arg1] [arg2] [arg3]        │  ← stack_base du nouveau frame
│                                     │
│  [local0] [local1] [local2]        │  ← locals (params + vars)
│                        ▲            │
│                        SP           │
└─────────────────────────────────────┘

Frame:
┌─────────────────────────────────────┐
│ function: &add                      │
│ pc: 0                               │
│ stack_base: 10                      │
│ locals: [arg1, arg2, arg3, ...]    │
└─────────────────────────────────────┘
```

---

## 4. Heap et Garbage Collector

### 4.1 Architecture du Heap

```rust
pub struct GcHeap {
    /// Tous les objets alloués
    objects: Vec<GcObject>,
    
    /// Bytes alloués actuellement
    bytes_allocated: usize,
    
    /// Seuil pour déclencher un GC
    gc_threshold: usize,
    
    /// Facteur de croissance du seuil
    growth_factor: f64,
    
    /// Statistiques
    stats: GcStats,
}

pub struct GcObject {
    /// Header de l'objet
    header: GcHeader,
    
    /// Données de l'objet
    data: Box<dyn GcTraceable>,
}

pub struct GcHeader {
    /// Marqué pendant le GC?
    marked: bool,
    
    /// Type de l'objet
    type_id: TypeId,
    
    /// Taille en bytes
    size: usize,
    
    /// Génération (pour GC générationnel)
    generation: u8,
}
```

### 4.2 GcRef (Smart Pointer)

```rust
/// Référence vers un objet sur le heap
pub struct GcRef<T: GcTraceable> {
    /// Index dans le heap
    index: u32,
    
    /// Phantom pour le type
    _marker: PhantomData<T>,
}

impl<T: GcTraceable> GcRef<T> {
    pub fn new(heap: &mut GcHeap, value: T) -> Self {
        let index = heap.allocate(value);
        Self {
            index,
            _marker: PhantomData,
        }
    }
    
    pub fn get<'a>(&self, heap: &'a GcHeap) -> &'a T {
        heap.get(self.index)
    }
    
    pub fn get_mut<'a>(&self, heap: &'a mut GcHeap) -> &'a mut T {
        heap.get_mut(self.index)
    }
}

impl<T: GcTraceable> Clone for GcRef<T> {
    fn clone(&self) -> Self {
        // Juste copie l'index, pas l'objet
        Self {
            index: self.index,
            _marker: PhantomData,
        }
    }
}
```

### 4.3 Trait GcTraceable

```rust
/// Trait pour les objets traçables par le GC
pub trait GcTraceable: 'static {
    /// Retourne les références vers d'autres objets GC
    fn trace(&self, tracer: &mut Tracer);
    
    /// Taille en bytes de l'objet
    fn size(&self) -> usize;
    
    /// Nom du type (pour debug)
    fn type_name(&self) -> &'static str;
    
    /// Appelé avant destruction (optionnel)
    fn finalize(&mut self) {}
}

pub struct Tracer {
    to_trace: Vec<u32>,
}

impl Tracer {
    pub fn trace<T: GcTraceable>(&mut self, gc_ref: &GcRef<T>) {
        self.to_trace.push(gc_ref.index);
    }
}
```

### 4.4 Implémentation pour les Types MATHIS

```rust
// String
pub struct MathisString {
    data: String,
}

impl GcTraceable for MathisString {
    fn trace(&self, _tracer: &mut Tracer) {
        // Pas de références GC
    }
    
    fn size(&self) -> usize {
        std::mem::size_of::<Self>() + self.data.len()
    }
    
    fn type_name(&self) -> &'static str {
        "String"
    }
}

// List
pub struct MathisList {
    items: Vec<Value>,
}

impl GcTraceable for MathisList {
    fn trace(&self, tracer: &mut Tracer) {
        for item in &self.items {
            item.trace(tracer);
        }
    }
    
    fn size(&self) -> usize {
        std::mem::size_of::<Self>() + 
        self.items.len() * std::mem::size_of::<Value>()
    }
    
    fn type_name(&self) -> &'static str {
        "List"
    }
}

// Map
pub struct MathisMap {
    entries: HashMap<Value, Value>,
}

impl GcTraceable for MathisMap {
    fn trace(&self, tracer: &mut Tracer) {
        for (key, value) in &self.entries {
            key.trace(tracer);
            value.trace(tracer);
        }
    }
    
    fn size(&self) -> usize {
        std::mem::size_of::<Self>() + 
        self.entries.len() * 2 * std::mem::size_of::<Value>()
    }
    
    fn type_name(&self) -> &'static str {
        "Map"
    }
}

// Closure
pub struct MathisClosure {
    function: FunctionRef,
    upvalues: Vec<UpvalueRef>,
}

impl GcTraceable for MathisClosure {
    fn trace(&self, tracer: &mut Tracer) {
        for upvalue in &self.upvalues {
            upvalue.trace(tracer);
        }
    }
    
    fn size(&self) -> usize {
        std::mem::size_of::<Self>() + 
        self.upvalues.len() * std::mem::size_of::<UpvalueRef>()
    }
    
    fn type_name(&self) -> &'static str {
        "Closure"
    }
}
```

---

## 5. Garbage Collection

### 5.1 Algorithme Mark-and-Sweep

```rust
impl GcHeap {
    pub fn collect(&mut self, roots: &[Value]) {
        // Phase 1: Mark
        self.mark_roots(roots);
        
        // Phase 2: Sweep
        self.sweep();
        
        // Phase 3: Ajuster le seuil
        self.adjust_threshold();
        
        // Stats
        self.stats.collections += 1;
    }
    
    fn mark_roots(&mut self, roots: &[Value]) {
        let mut tracer = Tracer::new();
        
        // Tracer toutes les racines
        for root in roots {
            root.trace(&mut tracer);
        }
        
        // Tracer récursivement
        while let Some(index) = tracer.to_trace.pop() {
            let obj = &mut self.objects[index as usize];
            
            if obj.header.marked {
                continue; // Déjà visité
            }
            
            obj.header.marked = true;
            obj.data.trace(&mut tracer);
        }
    }
    
    fn sweep(&mut self) {
        let mut freed = 0;
        
        self.objects.retain(|obj| {
            if obj.header.marked {
                // Garder et reset le mark
                // Note: on ne peut pas muter ici, donc on le fait après
                true
            } else {
                // Libérer
                freed += obj.header.size;
                false
            }
        });
        
        // Reset les marks
        for obj in &mut self.objects {
            obj.header.marked = false;
        }
        
        self.bytes_allocated -= freed;
        self.stats.bytes_freed += freed;
    }
    
    fn adjust_threshold(&mut self) {
        // Nouveau seuil = bytes actuels * growth_factor
        self.gc_threshold = (self.bytes_allocated as f64 * self.growth_factor) as usize;
        self.gc_threshold = self.gc_threshold.max(MIN_GC_THRESHOLD);
    }
}
```

### 5.2 Quand Déclencher le GC

```rust
impl GcHeap {
    /// Appelé à chaque allocation
    pub fn maybe_collect(&mut self, roots: &[Value]) {
        if self.bytes_allocated >= self.gc_threshold {
            self.collect(roots);
        }
    }
    
    /// Force un GC
    pub fn force_collect(&mut self, roots: &[Value]) {
        self.collect(roots);
    }
}

// Dans la VM
impl VmEngine {
    fn run(&mut self) -> Result<Value, VmError> {
        loop {
            // ... execute instruction ...
            
            // Vérifier GC périodiquement
            if self.instruction_count % GC_CHECK_INTERVAL == 0 {
                let roots = self.collect_roots();
                self.heap.maybe_collect(&roots);
            }
        }
    }
    
    fn collect_roots(&self) -> Vec<Value> {
        let mut roots = Vec::new();
        
        // Stack
        for value in &self.stack.data[..self.stack.sp] {
            roots.push(value.clone());
        }
        
        // Locals de tous les frames
        for frame in &self.frames {
            for local in &frame.locals {
                roots.push(local.clone());
            }
        }
        
        // Globals
        for value in self.globals.values() {
            roots.push(value.clone());
        }
        
        roots
    }
}
```

### 5.3 GC Générationnel (Optionnel)

```rust
pub struct GenerationalGcHeap {
    /// Young generation (objets récents)
    young: Vec<GcObject>,
    
    /// Old generation (objets survivants)
    old: Vec<GcObject>,
    
    /// Seuil pour promotion
    promotion_threshold: u8, // Nombre de collections survivées
    
    /// Configuration
    config: GenerationalGcConfig,
}

impl GenerationalGcHeap {
    /// Minor GC - collecte seulement young
    pub fn minor_collect(&mut self, roots: &[Value]) {
        self.mark_roots_young(roots);
        self.sweep_young();
        self.promote_survivors();
    }
    
    /// Major GC - collecte young + old
    pub fn major_collect(&mut self, roots: &[Value]) {
        self.mark_all(roots);
        self.sweep_all();
    }
    
    fn promote_survivors(&mut self) {
        // Déplacer les objets qui ont survécu N collections vers old
        let to_promote: Vec<_> = self.young
            .drain_filter(|obj| obj.header.generation >= self.promotion_threshold)
            .collect();
        
        self.old.extend(to_promote);
    }
}
```

---

## 6. Allocateur Raw (Kernel Mode)

Pour le code kernel qui a besoin d'accès mémoire direct.

### 6.1 Interface

```rust
pub struct RawAllocator {
    /// Mémoire disponible
    arena: Vec<u8>,
    
    /// Free list par classe de taille
    free_lists: [FreeList; NUM_SIZE_CLASSES],
    
    /// Position courante dans l'arena
    bump_ptr: usize,
}

impl RawAllocator {
    pub fn alloc(&mut self, size: usize, align: usize) -> Result<*mut u8, AllocError> {
        let size = align_up(size, align);
        
        // Essayer la free list d'abord
        if let Some(ptr) = self.alloc_from_free_list(size) {
            return Ok(ptr);
        }
        
        // Sinon, bump allocation
        self.bump_alloc(size, align)
    }
    
    pub fn free(&mut self, ptr: *mut u8, size: usize) {
        // Ajouter à la free list
        self.add_to_free_list(ptr, size);
    }
    
    pub fn realloc(
        &mut self, 
        ptr: *mut u8, 
        old_size: usize, 
        new_size: usize
    ) -> Result<*mut u8, AllocError> {
        if new_size <= old_size {
            return Ok(ptr);
        }
        
        let new_ptr = self.alloc(new_size, 8)?;
        unsafe {
            std::ptr::copy_nonoverlapping(ptr, new_ptr, old_size);
        }
        self.free(ptr, old_size);
        Ok(new_ptr)
    }
}
```

### 6.2 Syscalls Mémoire (Kernel Mode)

```rust
// Uniquement disponibles en kernel mode!

// 0x0400 - Alloc
pub fn syscall_alloc(args: Vec<Value>) -> Result<Value, VmError> {
    let size = args[0].as_int()? as usize;
    let ptr = ALLOCATOR.lock().alloc(size, 8)?;
    Ok(Value::RawPtr(ptr as usize))
}

// 0x0401 - Free
pub fn syscall_free(args: Vec<Value>) -> Result<Value, VmError> {
    let ptr = args[0].as_raw_ptr()?;
    let size = args[1].as_int()? as usize;
    ALLOCATOR.lock().free(ptr as *mut u8, size);
    Ok(Value::None)
}

// 0x0402 - Mem read
pub fn syscall_mem_read(args: Vec<Value>) -> Result<Value, VmError> {
    let ptr = args[0].as_raw_ptr()?;
    let len = args[1].as_int()? as usize;
    
    let slice = unsafe {
        std::slice::from_raw_parts(ptr as *const u8, len)
    };
    
    Ok(Value::Bytes(GcRef::new(MathisBytes::from(slice))))
}

// 0x0403 - Mem write
pub fn syscall_mem_write(args: Vec<Value>) -> Result<Value, VmError> {
    let ptr = args[0].as_raw_ptr()?;
    let data = args[1].as_bytes()?;
    
    unsafe {
        std::ptr::copy_nonoverlapping(
            data.as_ptr(),
            ptr as *mut u8,
            data.len()
        );
    }
    
    Ok(Value::None)
}
```

---

## 7. Pool de Constantes

### 7.1 Structure

```rust
pub struct ConstantPool {
    /// Constantes du module
    constants: Vec<Constant>,
    
    /// Index des strings internées
    string_intern: HashMap<String, u32>,
}

pub enum Constant {
    None,
    Bool(bool),
    Int(i64),
    Float(f64),
    String(String),
    Bytes(Vec<u8>),
    List(Vec<Constant>),
    Map(Vec<(Constant, Constant)>),
}

impl ConstantPool {
    /// Charge une constante sur la stack
    pub fn load(&self, index: u16, heap: &mut GcHeap) -> Value {
        match &self.constants[index as usize] {
            Constant::None => Value::None,
            Constant::Bool(b) => Value::Bool(*b),
            Constant::Int(i) => Value::Int(*i),
            Constant::Float(f) => Value::Float(*f),
            Constant::String(s) => {
                // Allouer sur le heap
                let gc_ref = GcRef::new(heap, MathisString::new(s.clone()));
                Value::String(gc_ref)
            }
            Constant::List(items) => {
                let values: Vec<Value> = items.iter()
                    .map(|c| self.constant_to_value(c, heap))
                    .collect();
                let gc_ref = GcRef::new(heap, MathisList::new(values));
                Value::List(gc_ref)
            }
            // ...
        }
    }
}
```

---

## 8. Upvalues (Closures)

### 8.1 Structure

```rust
pub enum Upvalue {
    /// Variable encore sur la stack
    Open { frame_idx: usize, local_idx: u8 },
    
    /// Variable fermée (copiée sur le heap)
    Closed(Value),
}

pub struct UpvalueRef {
    index: u32,
}

impl UpvalueRef {
    pub fn get(&self, upvalues: &[Upvalue], frames: &[CallFrame]) -> Value {
        match &upvalues[self.index as usize] {
            Upvalue::Open { frame_idx, local_idx } => {
                frames[*frame_idx].locals[*local_idx as usize].clone()
            }
            Upvalue::Closed(value) => value.clone(),
        }
    }
    
    pub fn set(&self, upvalues: &mut [Upvalue], frames: &mut [CallFrame], value: Value) {
        match &mut upvalues[self.index as usize] {
            Upvalue::Open { frame_idx, local_idx } => {
                frames[*frame_idx].locals[*local_idx as usize] = value;
            }
            Upvalue::Closed(v) => {
                *v = value;
            }
        }
    }
    
    /// Fermer l'upvalue (quand le frame est détruit)
    pub fn close(&self, upvalues: &mut [Upvalue], frames: &[CallFrame]) {
        let upvalue = &mut upvalues[self.index as usize];
        if let Upvalue::Open { frame_idx, local_idx } = upvalue {
            let value = frames[*frame_idx].locals[*local_idx as usize].clone();
            *upvalue = Upvalue::Closed(value);
        }
    }
}
```

### 8.2 Fermeture des Upvalues

```rust
impl VmEngine {
    fn close_upvalues_for_frame(&mut self, frame_idx: usize) {
        // Trouver tous les upvalues qui pointent vers ce frame
        for upvalue in &mut self.upvalues {
            if let Upvalue::Open { frame_idx: f, local_idx } = upvalue {
                if *f == frame_idx {
                    let value = self.frames[*f].locals[*local_idx as usize].clone();
                    *upvalue = Upvalue::Closed(value);
                }
            }
        }
    }
    
    fn op_return(&mut self) -> Result<(), VmError> {
        let return_value = self.stack.pop()?;
        
        // Fermer les upvalues de ce frame
        let frame_idx = self.frames.len() - 1;
        self.close_upvalues_for_frame(frame_idx);
        
        // Pop le frame
        let frame = self.frames.pop().unwrap();
        
        // Restaurer la stack
        self.stack.sp = frame.stack_base;
        
        // Push la valeur de retour
        self.stack.push(return_value)?;
        
        Ok(())
    }
}
```

---

## 9. Configuration Mémoire

```rust
pub struct MemoryConfig {
    /// Taille max de la stack (en Values)
    pub max_stack_size: usize,
    
    /// Taille max du heap (en bytes)
    pub max_heap_size: usize,
    
    /// Seuil initial pour le GC
    pub initial_gc_threshold: usize,
    
    /// Facteur de croissance du seuil GC
    pub gc_growth_factor: f64,
    
    /// Intervalle de vérification GC (en instructions)
    pub gc_check_interval: u64,
    
    /// Type de GC
    pub gc_type: GcType,
}

impl Default for MemoryConfig {
    fn default() -> Self {
        Self {
            max_stack_size: 65536,              // 64K values
            max_heap_size: 256 * 1024 * 1024,   // 256 MB
            initial_gc_threshold: 1024 * 1024,  // 1 MB
            gc_growth_factor: 2.0,
            gc_check_interval: 1000,
            gc_type: GcType::MarkSweep,
        }
    }
}

pub enum GcType {
    /// Simple mark-and-sweep
    MarkSweep,
    
    /// Générationnel (young/old)
    Generational,
    
    /// Incrémental (pour faible latence)
    Incremental,
}
```

---

## 10. Résumé

| Zone | Gestion | Lifetime | Accès |
|------|---------|----------|-------|
| **Stack** | Automatique (LIFO) | Frame | Direct |
| **Heap** | GC | Jusqu'au GC | Via GcRef |
| **Constants** | Statique | Module | Read-only |
| **Raw Memory** | Manuel | Explicite | Kernel only |

---

*Memory Model Specification v1.0.0*
