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

## Current Status
- MCP server is up and running with the `extract_tasks_tool` and test analysis plan in `/data`

## Overview
- Modular workflow with a central orchestrator agent as Claude Code (may later make subagent the orchestrator)
- Custom MCP server for pharmacometric specific tasks (analysis plan parsing, pharmpy/nlmixr2/nonmem documentation loading, report generation)
- Workflow templates encapsulated as MCP prompts (or ai_specs.md) in the Claude Code "command" style to facilitate easy prompting
- Comprehensive evals and optimization framework using ChatGPT deep research report and analysis plan templates, published reports from FDA/Health Canada, and published FDA reviews

![](./architecture_overview.png)

## Components
**Orchestrator Agent (MCP Client)**

For now Claude Code will be the orchestrator agent, but a custom ReAct/coding agent may be constructed using litellm/Autogen/MCP-agent (frameworks are being investigated). It needs to act as a client to the MCP server. [List of clients](https://modelcontextprotocol.io/clients)

**PharmAI MCP Server**

The MCP server (built with the FastMCP package wrapping simply defined tools) will handle all pharmacometric specific tasks. 
- analysis plan parsing
- custom REPL to run R, Python, nlmixr2, and pharmpy commands (Locally, Docker, and or SSH to remote server; SSH MCP server)
- data digitization
- specialized documentation loading using pharmpy/nlmixr2/nonmem (custom or Context7 MCP server)
- report generation

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

**Evaluation**

Pharmacometric test data is intrinsically well suited for generation. Evaluation should be divided into modular tests as well as end-to-end tests.  Evals may be incorporated as an MCP server component.
- Report and analysis plan templates (prompt ChatGPT deep research with regulatory sources), then use to make dummy reports with dummy population simulations with mrgsolve
- Reconstructed from published reports (FDA/Health Canada), simulated data from published model
- Create rubric from published FDA reviews.

**Optimization**

Optimization will be performed at the atomic level via DSPy prompt optimization and finetuning. End-to-end will be performed with the complete MCP server and orchestrator agent potentially using finetuning and/or reinforcement learning. 


