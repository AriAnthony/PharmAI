## Design Principles

**YAGNI (You Aren't Gonna Need It)**
- Build only what is needed now, not what might be needed later
- Avoid premature optimization and complex architectures
- Add features when proven necessary, not "just in case"

**KISS (Keep It Simple, Stupid)**  
- Prefer simple solutions over complex ones
- Minimize dependencies and abstractions
- Choose clarity over cleverness

**Start Simple, Evolve When Needed**
- Begin with the minimal viable implementation
- Identify actual problems before solving theoretical ones
- Refactor and add complexity only when current solution proves insufficient

**Focus on Core Value**
- Identify the essential functionality that delivers real value
- Eliminate features that don't directly serve the primary use case
- Question every layer of abstraction and complexity

## PharmAI Project Outline
Blog posts will cover some background and eventually go through each of the elements and explain how they are implemented.

## Architecture Philosophy

**Hybrid Agent-Module Architecture**
- **Modules provide**: Structure, validation, reproducibility, compliance
- **Agent provides**: Adaptability, reasoning, problem-solving, integration
- **Sweet spot**: Modules create optimal execution context for intelligent agents

**Eval-Driven Development**
- Component-level evals for rapid iteration and optimization
- End-to-end agent evaluation for workflow effectiveness
- Synthetic data generation for scalable testing
- Continuous improvement through DSPy optimization and fine-tuning

## Current Status
- MCP server operational with `extract_tasks_tool` and analysis plan parsing
- Template-driven task structure in `/templates/template_tasks.md`
- **Synthetic data generation**: DSPy-powered synthetic data generator creating complete datasets
  - **Glucamax dataset**: Type 2 diabetes Phase 2 dose-finding study with CDISC-formatted data (PC, EX, DM, LB, VS domains)
  - **Analysis plan generation**: Automated creation of population PK/PD analysis plans from templates
  - **mrgsolve simulation**: R scripts generating realistic PK/PD trial data with known parameters
- **REPL evolution**: Moving from standalone tool to agent-controlled execution engine
- **Hybrid approach validated**: Modular components + agent orchestration

## Overview
- Modular workflow with a central orchestrator agent as Claude Code (may later make subagent the orchestrator)
- Custom MCP server for pharmacometric specific tasks (analysis plan parsing, pharmpy/nlmixr2/nonmem documentation loading, report generation)
- Workflow templates encapsulated as MCP prompts (or ai_specs.md) in the Claude Code "command" style to facilitate easy prompting
- Comprehensive evals and optimization framework using ChatGPT deep research report and analysis plan templates, published reports from FDA/Health Canada, and published FDA reviews

![](./architecture_overview.png)

## Components
**Orchestrator Agent (Hybrid Control)**

Claude Code acts as the primary orchestrator, providing:
- End-to-end workflow execution with contextual reasoning
- Adaptive problem-solving when standard patterns fail
- Integration across analysis phases
- Domain expertise in pharmacometric methods

The agent operates within a structured framework provided by modular components, receiving rich context injection including analysis plans, quality criteria, and execution constraints.

**PharmAI MCP Server (Execution Engine)**

Enhanced REPL-based execution engine supporting:
- **Agent-controlled execution**: Structured context injection from orchestrator
- **Multi-environment support**: Local, SSH, Docker, cloud execution
- **Rich context handling**: Analysis plans, quality criteria, domain constraints
- **Pharmacometric specialization**: R/Python/nlmixr2/NONMEM integration
- Core capabilities:
  - Analysis plan parsing and task extraction
  - Code generation and iterative execution
  - Data processing and validation
  - Report generation and compliance checking

**Existing MCP Servers**
Existing MCP servers will be evaluated and curated as they fit within a given workflow. This may include:
- [Context7](https://github.com/upstash/context7) for documentation loading
- [MCP SSH](https://github.com/tufantunc/ssh-mcp) for easy SSH access to remote servers
- [Playwright](https://github.com/microsoft/playwright-mcp) for web scraping and data digitization

**Workflow Templates**

Workflow templates will be created to encapsulate common tasks and processes for the orchestrator. These may be incorporated into the MCP prompts or stored in a separate file (ai_specs.md) or as Claude Code /commands. Include details on what to do, where to do it (server, local, docker), and how to do it (what tools).
- Exploratory analysis
- PopPK analysis (e.g., "Read x data, run nlmixr2 model, generate report")
- End to end (e.g., "Parse analysis plan and explore data, run PopPK analysis, generate report" with details on what, where, and how)

**Evaluation Framework**

**Three-Tier Evaluation Strategy**:

*Component Level (Fast, Frequent)*:
- Code generation validity and efficiency
- Data parsing accuracy  
- Statistical method correctness
- Plot quality and compliance

*Integration Level (Medium)*:
- Task sequence optimization
- Error recovery effectiveness
- Cross-module communication
- Context utilization quality

*End-to-End Level (Comprehensive)*:
- Full PopPK workflow success
- Parameter recovery accuracy
- Regulatory compliance scoring
- Novel compound adaptability

**Synthetic Data Strategy**:
- mrgsolve/NONMEM-generated datasets with known parameters
- Graded complexity levels (simple to complex PK profiles)
- Diverse covariate scenarios (renal impairment, pediatric, etc.)
- Regulatory scenario coverage (FDA/EMA guidelines)

## Implementation Roadmap

### Phase 1: Enhanced REPL & Eval Infrastructure (Current)
**Objectives**: Transform REPL into agent-controlled execution engine with comprehensive evaluation

**Deliverables**:
- [ ] Agent-controlled REPL with context injection interface
- [ ] Multi-environment execution (local, SSH, Docker)
- [x] **Synthetic data generator with known PK parameters** (Glucamax dataset complete)
- [x] **DSPy-powered analysis plan generation** from templates
- [x] **CDISC-formatted datasets** with realistic PK/PD profiles
- [ ] Component-level evaluation framework
- [x] **Template-driven task structure validation** (template_tasks.md)

**Success Metrics**:
- REPL accepts structured context from agent
- Code generation quality scores >90% on synthetic data
- Multi-environment execution works reliably

### Phase 2: Modular Optimization (Next 2-3 months)
**Objectives**: Optimize individual components through targeted evaluation

**Deliverables**:
- [ ] DSPy-optimized prompting for each REPL component
- [ ] Automated quality scoring for code generation
- [ ] Error recovery pattern optimization
- [ ] Performance benchmarking suite
- [ ] A/B testing framework for different strategies

**Success Metrics**:
- 50% improvement in component-level performance
- Reduced iteration counts in REPL loops
- Higher success rates on complex analysis tasks

### Phase 3: End-to-End Agent Integration (Months 3-6)
**Objectives**: Full workflow optimization with agent fine-tuning

**Deliverables**:
- [ ] End-to-end evaluation on complete PopPK analyses
- [ ] Agent fine-tuning on successful execution patterns
- [ ] Regulatory compliance validation framework
- [ ] Multi-compound analysis capability
- [ ] Continuous learning pipeline

**Success Metrics**:
- 95%+ success rate on standard PopPK analyses
- Regulatory submission-ready outputs
- Handles novel compounds without human intervention

### Phase 4: Production Deployment (Months 6-12)
**Objectives**: Real-world validation and scaling

**Deliverables**:
- [ ] Production-grade reliability and error handling
- [ ] Integration with existing pharma workflows
- [ ] Multi-therapeutic area expansion
- [ ] Regulatory agency validation
- [ ] Commercial deployment readiness

**Success Metrics**:
- Real-world analysis success >90%
- Regulatory acceptance for submissions
- 10x improvement in analysis efficiency

**Optimization**

Optimization will be performed at the atomic level via DSPy prompt optimization and finetuning. End-to-end will be performed with the complete MCP server and orchestrator agent potentially using finetuning and/or reinforcement learning.