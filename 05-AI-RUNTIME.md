# AI Runtime - Spécification

## 1. Vue d'Ensemble

Le **AI Runtime** est le sous-système qui permet l'intégration profonde de l'IA dans MATHIS OS. Il fournit:

- **Introspection**: L'IA peut voir l'état du système
- **Interaction**: L'IA peut prendre des décisions à runtime
- **Évolution**: L'IA peut modifier le bytecode
- **Apprentissage**: L'IA apprend des patterns d'utilisation
- **Explication**: L'IA peut expliquer ce que fait le code

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                             AI RUNTIME                                      │
│                                                                             │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐            │
│  │  INTROSPECTION  │  │   INTERACTION   │  │   EVOLUTION     │            │
│  │                 │  │                 │  │                 │            │
│  │ - VM State      │  │ - AI_DECIDE     │  │ - Optimize      │            │
│  │ - Stack View    │  │ - AI_CALL       │  │ - Refactor      │            │
│  │ - Metadata      │  │ - AI_ASSERT     │  │ - Extend        │            │
│  │ - Call Stack    │  │ - AI_CONTRACT   │  │ - Verify        │            │
│  └─────────────────┘  └─────────────────┘  └─────────────────┘            │
│                                                                             │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐            │
│  │   LEARNING      │  │   EXPLANATION   │  │    PROOF        │            │
│  │                 │  │                 │  │                 │            │
│  │ - Patterns      │  │ - AI_EXPLAIN    │  │ - Invariants    │            │
│  │ - Usage Stats   │  │ - Code Summary  │  │ - Contracts     │            │
│  │ - Optimization  │  │ - Documentation │  │ - Verification  │            │
│  │ - Suggestions   │  │ - Q&A           │  │ - Formal        │            │
│  └─────────────────┘  └─────────────────┘  └─────────────────┘            │
│                                                                             │
│  ┌───────────────────────────────────────────────────────────────────────┐ │
│  │                        LLM INTERFACE                                   │ │
│  │  OpenAI │ Claude │ Mistral │ Ollama │ LM Studio │ Custom             │ │
│  └───────────────────────────────────────────────────────────────────────┘ │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 2. Architecture

### 2.1 Composants

```rust
pub struct AiRuntime {
    /// Interface vers les LLMs
    llm_client: LlmClient,
    
    /// Cache des embeddings
    embedding_cache: EmbeddingCache,
    
    /// Historique pour l'apprentissage
    learning_history: LearningHistory,
    
    /// Système de preuves
    proof_system: ProofSystem,
    
    /// Générateur d'explications
    explainer: Explainer,
    
    /// Optimiseur de bytecode
    optimizer: AiOptimizer,
    
    /// Configuration
    config: AiConfig,
    
    /// Métriques
    metrics: AiMetrics,
}

pub struct AiConfig {
    /// Modèle par défaut
    pub default_model: ModelId,
    
    /// Modèle pour les décisions rapides
    pub fast_model: ModelId,
    
    /// Modèle pour les raisonnements complexes
    pub smart_model: ModelId,
    
    /// Modèle local (Ollama)
    pub local_model: Option<ModelId>,
    
    /// Activer le cache d'embeddings
    pub enable_embedding_cache: bool,
    
    /// Activer l'apprentissage
    pub enable_learning: bool,
    
    /// Timeout pour les appels LLM (ms)
    pub llm_timeout: u64,
    
    /// Max tokens par requête
    pub max_tokens: u32,
}
```

### 2.2 LLM Client

```rust
pub struct LlmClient {
    providers: HashMap<ProviderId, Box<dyn LlmProvider>>,
    default_provider: ProviderId,
}

#[async_trait]
pub trait LlmProvider: Send + Sync {
    /// Complétion de chat
    async fn chat(&self, request: ChatRequest) -> Result<ChatResponse, LlmError>;
    
    /// Complétion simple
    async fn complete(&self, prompt: &str) -> Result<String, LlmError>;
    
    /// Génération d'embeddings
    async fn embed(&self, texts: &[String]) -> Result<Vec<Vec<f64>>, LlmError>;
    
    /// Streaming
    async fn chat_stream(
        &self, 
        request: ChatRequest
    ) -> Result<impl Stream<Item = String>, LlmError>;
    
    /// Function calling
    async fn function_call(
        &self,
        request: ChatRequest,
        functions: &[FunctionDef],
    ) -> Result<FunctionCallResponse, LlmError>;
}

pub struct ChatRequest {
    pub messages: Vec<Message>,
    pub model: Option<ModelId>,
    pub max_tokens: Option<u32>,
    pub temperature: Option<f32>,
    pub tools: Option<Vec<ToolDef>>,
}

pub struct Message {
    pub role: Role,
    pub content: String,
}

pub enum Role {
    System,
    User,
    Assistant,
    Tool,
}
```

---

## 3. Introspection

### 3.1 VM State Snapshot

```rust
impl AiRuntime {
    /// Capture l'état actuel de la VM
    pub fn capture_state(&self, vm: &VmEngine) -> VmStateSnapshot {
        VmStateSnapshot {
            // Position d'exécution
            program_counter: vm.current_frame().pc,
            function_name: vm.current_function_name(),
            module_name: vm.current_module_name(),
            
            // Stack
            stack: vm.stack.iter()
                .map(|v| self.value_to_ai_repr(v))
                .collect(),
            
            // Locals
            locals: vm.current_frame().locals.iter()
                .enumerate()
                .map(|(i, v)| (format!("local_{}", i), self.value_to_ai_repr(v)))
                .collect(),
            
            // Metadata
            ai_metadata: vm.current_ai_metadata(),
            
            // Call stack
            call_stack: vm.frames.iter()
                .map(|f| FrameSnapshot {
                    function: f.function.name.clone(),
                    pc: f.pc,
                    locals_count: f.locals.len(),
                })
                .collect(),
            
            // Statistiques
            instruction_count: vm.instruction_count,
            memory_used: vm.memory.bytes_allocated(),
            
            // Code context
            surrounding_code: self.get_surrounding_code(vm, 5),
        }
    }
    
    /// Convertit une valeur en représentation pour l'IA
    fn value_to_ai_repr(&self, value: &Value) -> AiValue {
        match value {
            Value::None => AiValue::None,
            Value::Bool(b) => AiValue::Bool(*b),
            Value::Int(i) => AiValue::Int(*i),
            Value::Float(f) => AiValue::Float(*f),
            Value::String(s) => AiValue::String(s.to_string()),
            Value::List(l) => AiValue::List {
                len: l.len(),
                preview: l.iter().take(5)
                    .map(|v| self.value_to_ai_repr(v))
                    .collect(),
            },
            Value::Map(m) => AiValue::Map {
                len: m.len(),
                keys_preview: m.keys().take(5)
                    .map(|k| k.to_string())
                    .collect(),
            },
            Value::Struct(s) => AiValue::Struct {
                type_name: s.type_name().to_string(),
                fields: s.fields().iter()
                    .map(|(k, v)| (k.clone(), self.value_to_ai_repr(v)))
                    .collect(),
            },
            _ => AiValue::Other(value.type_name().to_string()),
        }
    }
}
```

### 3.2 Metadata Access

```rust
pub struct AiMetadata {
    /// Nom du bloc
    pub block_name: Option<String>,
    
    /// Intent (description de l'objectif)
    pub intent: Option<String>,
    
    /// Est-ce une fonction pure?
    pub is_pure: bool,
    
    /// Complexité algorithmique
    pub complexity: Option<String>,
    
    /// Dépendances
    pub dependencies: Vec<String>,
    
    /// Effets de bord
    pub effects: Vec<String>,
    
    /// Exemples d'utilisation
    pub examples: Vec<AiExample>,
    
    /// Tags pour recherche
    pub tags: Vec<String>,
}

impl AiRuntime {
    /// Récupère les metadata du bloc courant
    pub fn get_current_metadata(&self, vm: &VmEngine) -> Option<AiMetadata> {
        let func = vm.current_function();
        let ai_meta_idx = func.ai_meta_idx?;
        
        let module = vm.current_module();
        module.ai_metadata.get(ai_meta_idx as usize).cloned()
    }
    
    /// Recherche des blocs par intent
    pub fn search_by_intent(&self, query: &str) -> Vec<BlockMatch> {
        // Générer l'embedding de la requête
        let query_embedding = self.embed(query);
        
        // Chercher dans tous les blocs
        let mut matches: Vec<_> = self.all_blocks().iter()
            .filter_map(|block| {
                let intent = block.metadata.intent.as_ref()?;
                let intent_embedding = self.get_or_compute_embedding(intent);
                let score = cosine_similarity(&query_embedding, &intent_embedding);
                
                if score > 0.7 {
                    Some(BlockMatch { block: block.clone(), score })
                } else {
                    None
                }
            })
            .collect();
        
        matches.sort_by(|a, b| b.score.partial_cmp(&a.score).unwrap());
        matches
    }
}
```

---

## 4. Interaction

### 4.1 AI_DECIDE - Décisions à Runtime

```rust
impl AiRuntime {
    /// Implémente l'instruction AI_DECIDE
    pub async fn decide(
        &self,
        options: Vec<Value>,
        context: &VmStateSnapshot,
    ) -> Result<usize, AiError> {
        // Construire le prompt
        let prompt = self.build_decide_prompt(&options, context);
        
        // Appeler le LLM
        let response = self.llm_client.chat(ChatRequest {
            messages: vec![
                Message {
                    role: Role::System,
                    content: DECIDE_SYSTEM_PROMPT.to_string(),
                },
                Message {
                    role: Role::User,
                    content: prompt,
                },
            ],
            model: Some(self.config.fast_model.clone()),
            max_tokens: Some(100),
            temperature: Some(0.1), // Déterministe
            ..Default::default()
        }).await?;
        
        // Parser la réponse
        self.parse_decide_response(&response.content, options.len())
    }
    
    fn build_decide_prompt(
        &self,
        options: &[Value],
        context: &VmStateSnapshot,
    ) -> String {
        format!(
            r#"
You are making a runtime decision for a MATHIS program.

Current context:
- Function: {}
- Intent: {}
- Stack: {:?}

Options:
{}

Which option should be chosen? Respond with just the number (0-indexed).
"#,
            context.function_name,
            context.ai_metadata.as_ref()
                .and_then(|m| m.intent.as_ref())
                .unwrap_or(&"Unknown".to_string()),
            context.stack,
            options.iter()
                .enumerate()
                .map(|(i, opt)| format!("{}: {:?}", i, opt))
                .collect::<Vec<_>>()
                .join("\n")
        )
    }
}

const DECIDE_SYSTEM_PROMPT: &str = r#"
You are an AI decision maker for the MATHIS programming language.
Your role is to make optimal decisions based on the code context and intent.
Always respond with just the number of your choice.
Consider the program's intent and the current state when making decisions.
"#;
```

### 4.2 AI_CALL - Appel Direct au LLM

```rust
impl AiRuntime {
    /// Implémente l'instruction AI_CALL
    pub async fn call(
        &self,
        prompt: &str,
        model_hint: u8,
        context: &VmStateSnapshot,
    ) -> Result<String, AiError> {
        let model = match model_hint {
            0 => &self.config.default_model,
            1 => &self.config.fast_model,
            2 => &self.config.smart_model,
            3 => self.config.local_model.as_ref()
                .ok_or(AiError::NoLocalModel)?,
            _ => &self.config.default_model,
        };
        
        // Enrichir le prompt avec le contexte
        let enriched_prompt = self.enrich_prompt(prompt, context);
        
        // Appeler le LLM
        let response = self.llm_client.complete_with_model(
            &enriched_prompt,
            model,
        ).await?;
        
        // Logger pour apprentissage
        if self.config.enable_learning {
            self.learning_history.log_ai_call(
                prompt,
                &response,
                context,
            );
        }
        
        Ok(response)
    }
    
    fn enrich_prompt(&self, prompt: &str, context: &VmStateSnapshot) -> String {
        format!(
            r#"
Context:
- Running function: {} 
- Intent: {}
- Current state: {:?}

User prompt:
{}
"#,
            context.function_name,
            context.ai_metadata.as_ref()
                .and_then(|m| m.intent.as_ref())
                .unwrap_or(&"Unknown".to_string()),
            context.locals,
            prompt
        )
    }
}
```

### 4.3 AI_CONTRACT - Vérification de Contrats

```rust
impl AiRuntime {
    /// Vérifie un contrat AI
    pub async fn verify_contract(
        &self,
        precondition: &str,
        postcondition: &str,
        context: &VmStateSnapshot,
    ) -> Result<ContractResult, AiError> {
        let prompt = format!(
            r#"
Verify this contract for the current program state:

Precondition: {}
Postcondition: {}

Current state:
- Function: {}
- Locals: {:?}
- Stack: {:?}

Does the current state satisfy the precondition?
Will the postcondition hold after execution?
Respond with:
- PRE_OK or PRE_FAIL
- POST_LIKELY or POST_UNLIKELY
- Brief explanation
"#,
            precondition,
            postcondition,
            context.function_name,
            context.locals,
            context.stack
        );
        
        let response = self.llm_client.chat(ChatRequest {
            messages: vec![
                Message {
                    role: Role::System,
                    content: CONTRACT_SYSTEM_PROMPT.to_string(),
                },
                Message {
                    role: Role::User,
                    content: prompt,
                },
            ],
            model: Some(self.config.smart_model.clone()),
            ..Default::default()
        }).await?;
        
        self.parse_contract_response(&response.content)
    }
}

pub struct ContractResult {
    pub precondition_met: bool,
    pub postcondition_likely: bool,
    pub explanation: String,
    pub confidence: f64,
}
```

---

## 5. Explication

### 5.1 Générateur d'Explications

```rust
pub struct Explainer {
    /// Cache des explications
    cache: HashMap<ExplainKey, String>,
    
    /// Templates
    templates: ExplainTemplates,
}

impl Explainer {
    /// Explique un bloc de code
    pub async fn explain_block(
        &self,
        code: &[Instruction],
        metadata: &AiMetadata,
        llm: &LlmClient,
    ) -> Result<String, AiError> {
        // Vérifier le cache
        let key = ExplainKey::from_code(code);
        if let Some(cached) = self.cache.get(&key) {
            return Ok(cached.clone());
        }
        
        // Construire le prompt
        let prompt = format!(
            r#"
Explain this MATHIS bytecode block in simple terms:

Block name: {}
Intent: {}

Code:
{}

Provide a clear, concise explanation of what this code does.
Focus on the high-level purpose, not individual instructions.
"#,
            metadata.block_name.as_deref().unwrap_or("Unknown"),
            metadata.intent.as_deref().unwrap_or("Unknown"),
            self.format_code(code)
        );
        
        let explanation = llm.complete(&prompt).await?;
        
        // Mettre en cache
        self.cache.insert(key, explanation.clone());
        
        Ok(explanation)
    }
    
    /// Explique l'état actuel
    pub async fn explain_current_state(
        &self,
        context: &VmStateSnapshot,
        llm: &LlmClient,
    ) -> Result<String, AiError> {
        let prompt = format!(
            r#"
Explain the current state of this MATHIS program:

Function: {}
Intent: {}
Program counter: {}
Stack: {:?}
Local variables: {:?}

What is the program currently doing? What will likely happen next?
"#,
            context.function_name,
            context.ai_metadata.as_ref()
                .and_then(|m| m.intent.as_ref())
                .unwrap_or(&"Unknown".to_string()),
            context.program_counter,
            context.stack,
            context.locals
        );
        
        llm.complete(&prompt).await
    }
    
    /// Génère de la documentation
    pub async fn generate_docs(
        &self,
        module: &Module,
        llm: &LlmClient,
    ) -> Result<Documentation, AiError> {
        let mut docs = Documentation::new();
        
        for func in &module.functions {
            let func_doc = self.document_function(func, llm).await?;
            docs.functions.insert(func.name.clone(), func_doc);
        }
        
        for type_def in &module.types {
            let type_doc = self.document_type(type_def, llm).await?;
            docs.types.insert(type_def.name.clone(), type_doc);
        }
        
        // Générer le README
        docs.readme = self.generate_readme(module, &docs, llm).await?;
        
        Ok(docs)
    }
}
```

### 5.2 Q&A sur le Code

```rust
impl AiRuntime {
    /// Répond à une question sur le code
    pub async fn ask_about_code(
        &self,
        question: &str,
        context: &VmStateSnapshot,
    ) -> Result<String, AiError> {
        let prompt = format!(
            r#"
Answer this question about the MATHIS program:

Question: {}

Context:
- Current function: {}
- Intent: {}
- Code around current position:
{}
- Stack: {:?}
- Variables: {:?}

Provide a helpful, accurate answer based on the code context.
"#,
            question,
            context.function_name,
            context.ai_metadata.as_ref()
                .and_then(|m| m.intent.as_ref())
                .unwrap_or(&"Unknown".to_string()),
            self.format_surrounding_code(&context.surrounding_code),
            context.stack,
            context.locals
        );
        
        self.llm_client.chat(ChatRequest {
            messages: vec![
                Message {
                    role: Role::System,
                    content: QA_SYSTEM_PROMPT.to_string(),
                },
                Message {
                    role: Role::User,
                    content: prompt,
                },
            ],
            ..Default::default()
        }).await.map(|r| r.content)
    }
}

const QA_SYSTEM_PROMPT: &str = r#"
You are an expert on the MATHIS programming language and its bytecode.
Answer questions accurately based on the provided code context.
If you're unsure, say so rather than guessing.
"#;
```

---

## 6. Apprentissage

### 6.1 Learning History

```rust
pub struct LearningHistory {
    /// Historique des exécutions
    executions: Vec<ExecutionRecord>,
    
    /// Patterns détectés
    patterns: Vec<Pattern>,
    
    /// Statistiques d'usage
    usage_stats: UsageStats,
    
    /// Suggestions d'optimisation
    optimization_suggestions: Vec<OptimizationSuggestion>,
}

pub struct ExecutionRecord {
    pub timestamp: Instant,
    pub function: String,
    pub inputs: Vec<AiValue>,
    pub output: AiValue,
    pub duration: Duration,
    pub instructions_executed: u64,
    pub memory_peak: usize,
}

impl LearningHistory {
    /// Enregistre une exécution
    pub fn record_execution(&mut self, record: ExecutionRecord) {
        self.executions.push(record.clone());
        self.update_stats(&record);
        self.detect_patterns();
    }
    
    /// Détecte des patterns dans les exécutions
    fn detect_patterns(&mut self) {
        // Pattern: Fonction appelée fréquemment avec les mêmes inputs
        let frequent_calls = self.find_frequent_identical_calls();
        for (func, inputs, count) in frequent_calls {
            if count > 10 {
                self.patterns.push(Pattern::MemoizationCandidate {
                    function: func,
                    common_inputs: inputs,
                    call_count: count,
                });
            }
        }
        
        // Pattern: Boucles avec beaucoup d'itérations
        let slow_loops = self.find_slow_loops();
        for (func, avg_iterations) in slow_loops {
            if avg_iterations > 1000.0 {
                self.patterns.push(Pattern::LoopOptimizationCandidate {
                    function: func,
                    avg_iterations,
                });
            }
        }
        
        // Pattern: Allocations fréquentes
        let heavy_allocators = self.find_heavy_allocators();
        for (func, alloc_rate) in heavy_allocators {
            if alloc_rate > 0.1 { // Plus de 10% du temps en allocs
                self.patterns.push(Pattern::AllocationHotspot {
                    function: func,
                    allocation_ratio: alloc_rate,
                });
            }
        }
    }
    
    /// Génère des suggestions basées sur les patterns
    pub fn generate_suggestions(&self) -> Vec<OptimizationSuggestion> {
        let mut suggestions = Vec::new();
        
        for pattern in &self.patterns {
            match pattern {
                Pattern::MemoizationCandidate { function, common_inputs, call_count } => {
                    suggestions.push(OptimizationSuggestion {
                        function: function.clone(),
                        suggestion_type: SuggestionType::AddMemoization,
                        description: format!(
                            "Function '{}' is called {} times with identical inputs. \
                             Consider memoization.",
                            function, call_count
                        ),
                        estimated_improvement: 0.3, // 30% improvement
                        confidence: 0.8,
                    });
                }
                Pattern::LoopOptimizationCandidate { function, avg_iterations } => {
                    suggestions.push(OptimizationSuggestion {
                        function: function.clone(),
                        suggestion_type: SuggestionType::OptimizeLoop,
                        description: format!(
                            "Function '{}' has loops averaging {} iterations. \
                             Consider vectorization or early exit.",
                            function, avg_iterations
                        ),
                        estimated_improvement: 0.5,
                        confidence: 0.6,
                    });
                }
                // ... autres patterns
            }
        }
        
        suggestions
    }
}
```

### 6.2 Usage Statistics

```rust
pub struct UsageStats {
    /// Fonctions par nombre d'appels
    function_calls: HashMap<String, u64>,
    
    /// Temps moyen par fonction
    function_avg_time: HashMap<String, Duration>,
    
    /// Instructions les plus utilisées
    opcode_frequency: HashMap<OpCode, u64>,
    
    /// Erreurs par type
    error_frequency: HashMap<String, u64>,
    
    /// Patterns d'entrée courants
    common_input_patterns: HashMap<String, Vec<InputPattern>>,
}

impl UsageStats {
    /// Retourne les fonctions les plus appelées
    pub fn hot_functions(&self, top_n: usize) -> Vec<(&str, u64)> {
        let mut sorted: Vec<_> = self.function_calls.iter()
            .map(|(k, v)| (k.as_str(), *v))
            .collect();
        sorted.sort_by(|a, b| b.1.cmp(&a.1));
        sorted.truncate(top_n);
        sorted
    }
    
    /// Retourne les fonctions les plus lentes
    pub fn slow_functions(&self, top_n: usize) -> Vec<(&str, Duration)> {
        let mut sorted: Vec<_> = self.function_avg_time.iter()
            .map(|(k, v)| (k.as_str(), *v))
            .collect();
        sorted.sort_by(|a, b| b.1.cmp(&a.1));
        sorted.truncate(top_n);
        sorted
    }
}
```

---

## 7. Évolution

### 7.1 Optimiseur IA

```rust
pub struct AiOptimizer {
    /// Stratégies d'optimisation disponibles
    strategies: Vec<Box<dyn OptimizationStrategy>>,
    
    /// Historique des optimisations
    history: Vec<OptimizationRecord>,
    
    /// Vérificateur de bytecode
    verifier: BytecodeVerifier,
}

impl AiOptimizer {
    /// Optimise une fonction
    pub async fn optimize_function(
        &mut self,
        func: &mut Function,
        llm: &LlmClient,
    ) -> Result<OptimizationResult, AiError> {
        let original_code = func.code.clone();
        let mut total_improvement = 0.0;
        let mut changes = Vec::new();
        
        for strategy in &self.strategies {
            if strategy.is_applicable(func) {
                let result = strategy.apply(func, llm).await?;
                
                if result.improvement > 0.0 {
                    // Vérifier que le bytecode est toujours valide
                    self.verifier.verify(&func.code)?;
                    
                    total_improvement += result.improvement;
                    changes.push(result.description);
                }
            }
        }
        
        // Enregistrer l'optimisation
        self.history.push(OptimizationRecord {
            function: func.name.clone(),
            original_size: original_code.len(),
            optimized_size: func.code.len(),
            improvement: total_improvement,
            changes: changes.clone(),
            timestamp: Instant::now(),
        });
        
        Ok(OptimizationResult {
            success: true,
            improvement: total_improvement,
            changes,
        })
    }
    
    /// Suggère des optimisations sans les appliquer
    pub async fn suggest_optimizations(
        &self,
        func: &Function,
        llm: &LlmClient,
    ) -> Result<Vec<OptimizationSuggestion>, AiError> {
        let prompt = format!(
            r#"
Analyze this MATHIS bytecode and suggest optimizations:

Function: {}
Intent: {}
Code:
{}

Consider:
1. Dead code elimination
2. Constant folding
3. Common subexpression elimination
4. Loop optimizations
5. Strength reduction

For each suggestion, explain:
- What to change
- Expected improvement
- Confidence level
"#,
            func.name,
            func.ai_metadata.as_ref()
                .and_then(|m| m.intent.as_ref())
                .unwrap_or(&"Unknown".to_string()),
            self.format_code(&func.code)
        );
        
        let response = llm.complete(&prompt).await?;
        self.parse_optimization_suggestions(&response)
    }
}
```

### 7.2 Stratégies d'Optimisation

```rust
#[async_trait]
pub trait OptimizationStrategy: Send + Sync {
    fn name(&self) -> &str;
    fn is_applicable(&self, func: &Function) -> bool;
    async fn apply(
        &self, 
        func: &mut Function,
        llm: &LlmClient,
    ) -> Result<StrategyResult, AiError>;
}

/// Élimination du code mort
pub struct DeadCodeElimination;

#[async_trait]
impl OptimizationStrategy for DeadCodeElimination {
    fn name(&self) -> &str { "Dead Code Elimination" }
    
    fn is_applicable(&self, func: &Function) -> bool {
        // Applicable si la fonction a plus de 10 instructions
        func.code.len() > 10
    }
    
    async fn apply(
        &self,
        func: &mut Function,
        _llm: &LlmClient,
    ) -> Result<StrategyResult, AiError> {
        let original_len = func.code.len();
        
        // Analyse de vivacité
        let live_ranges = self.compute_live_ranges(&func.code);
        
        // Supprimer les instructions dont le résultat n'est jamais utilisé
        let mut new_code = Vec::new();
        for (i, inst) in func.code.iter().enumerate() {
            if live_ranges.is_live(i) || inst.has_side_effects() {
                new_code.push(inst.clone());
            }
        }
        
        let removed = original_len - new_code.len();
        func.code = new_code;
        
        Ok(StrategyResult {
            description: format!("Removed {} dead instructions", removed),
            improvement: removed as f64 / original_len as f64,
        })
    }
}

/// Constant folding
pub struct ConstantFolding;

#[async_trait]
impl OptimizationStrategy for ConstantFolding {
    fn name(&self) -> &str { "Constant Folding" }
    
    fn is_applicable(&self, _func: &Function) -> bool { true }
    
    async fn apply(
        &self,
        func: &mut Function,
        _llm: &LlmClient,
    ) -> Result<StrategyResult, AiError> {
        let mut changes = 0;
        let mut i = 0;
        
        while i + 2 < func.code.len() {
            // Pattern: CONST_I64 a, CONST_I64 b, ADD -> CONST_I64 (a+b)
            if let (
                Instruction::ConstI64(a),
                Instruction::ConstI64(b),
                Instruction::Add,
            ) = (&func.code[i], &func.code[i+1], &func.code[i+2]) {
                func.code[i] = Instruction::ConstI64(a + b);
                func.code.remove(i + 2);
                func.code.remove(i + 1);
                changes += 1;
            } else {
                i += 1;
            }
        }
        
        Ok(StrategyResult {
            description: format!("Folded {} constant expressions", changes),
            improvement: changes as f64 * 0.01,
        })
    }
}
```

---

## 8. Système de Preuves

### 8.1 Architecture

```rust
pub struct ProofSystem {
    /// Invariants enregistrés
    invariants: HashMap<String, Invariant>,
    
    /// Contrats par fonction
    contracts: HashMap<String, Contract>,
    
    /// Résultats de vérification
    verification_cache: HashMap<ProofKey, ProofResult>,
}

pub struct Invariant {
    pub name: String,
    pub description: String,
    pub condition: String,  // Expression logique
    pub scope: InvariantScope,
}

pub struct Contract {
    pub function: String,
    pub preconditions: Vec<String>,
    pub postconditions: Vec<String>,
}

impl ProofSystem {
    /// Vérifie un invariant
    pub async fn check_invariant(
        &self,
        invariant: &Invariant,
        state: &VmStateSnapshot,
        llm: &LlmClient,
    ) -> Result<ProofResult, AiError> {
        let prompt = format!(
            r#"
Verify this invariant:
Name: {}
Condition: {}
Description: {}

Current state:
- Function: {}
- Variables: {:?}
- Stack: {:?}

Is the invariant satisfied? Respond with:
- SATISFIED or VIOLATED
- Explanation
- Confidence (0-1)
"#,
            invariant.name,
            invariant.condition,
            invariant.description,
            state.function_name,
            state.locals,
            state.stack
        );
        
        let response = llm.complete(&prompt).await?;
        self.parse_proof_response(&response)
    }
    
    /// Vérifie tous les invariants
    pub async fn check_all_invariants(
        &self,
        state: &VmStateSnapshot,
        llm: &LlmClient,
    ) -> Result<Vec<ProofResult>, AiError> {
        let mut results = Vec::new();
        
        for invariant in self.invariants.values() {
            if invariant.scope.applies_to(&state.function_name) {
                let result = self.check_invariant(invariant, state, llm).await?;
                results.push(result);
            }
        }
        
        Ok(results)
    }
}
```

---

## 9. Configuration et Démarrage

### 9.1 Initialisation

```rust
impl AiRuntime {
    pub fn new(config: AiConfig) -> Self {
        // Créer le client LLM
        let llm_client = LlmClient::new()
            .with_provider("openai", OpenAiProvider::new())
            .with_provider("anthropic", AnthropicProvider::new())
            .with_provider("ollama", OllamaProvider::new())
            .with_default(&config.default_model);
        
        Self {
            llm_client,
            embedding_cache: EmbeddingCache::new(10000), // 10k embeddings max
            learning_history: LearningHistory::new(),
            proof_system: ProofSystem::new(),
            explainer: Explainer::new(),
            optimizer: AiOptimizer::new(),
            config,
            metrics: AiMetrics::new(),
        }
    }
    
    pub fn with_local_model(mut self, endpoint: &str) -> Self {
        self.llm_client.add_provider(
            "local",
            OllamaProvider::with_endpoint(endpoint)
        );
        self.config.local_model = Some("local:default".into());
        self
    }
}
```

---

*AI Runtime Specification v1.0.0*
