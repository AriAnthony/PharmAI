# PharmAI: AI-Powered Pharmacometric Analysis

PharmAI is a modular AI workflow system for pharmacometric analysis, featuring a custom MCP server and orchestrator agent for automating complex analytical tasks.

Follow along as I write about this project [here](https://www.aripritchardbell.com/blog)

## Project Overview

- **Modular Architecture**: Central orchestrator agent (Claude Code) with custom MCP server for pharmacometric tasks
- **MCP Server**: Built with FastMCP, handles analysis plan parsing, pharmpy/nlmixr2/nonmem documentation, report generation
- **Workflow Templates**: Encapsulated as MCP prompts for common tasks (exploratory analysis, PopPK analysis, end-to-end workflows)
- **Evaluation Framework**: Comprehensive testing using regulatory templates and published reports

## Quick Setup

### Prerequisites
- [uv](https://docs.astral.sh/uv/) for Python package management
- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) CLI tool

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/arianthony/pharmai.git
   cd pharmai
   ```

2. **Install dependencies with uv**
   ```bash
   uv sync
   ```

3. **Configure MCP server**
   
   Copy the example MCP configuration:
   ```bash
   cp .mcp.json.example .mcp.json
   ```
   
   Update `.mcp.json` with your paths:
   ```json
   {
     "mcpServers": {
       "PharmAI": {
         "command": "/path/to/uv",
         "args": [
           "--directory",
           "/path/to/pharmai",
           "run",
           "python",
           "mcp_server.py"
         ],
         "env": {
           "LOG_LEVEL": "INFO"
         }
       }
     }
   }
   ```
   
   Find your uv path:
   ```bash
   which uv
   ```

4. **Verify MCP server connection**
   ```bash
   claude /mcp
   ```
   
   You should see the PharmAI server listed and connected.

## Current Status

- ✅ MCP server is up and running with the `extract_tasks_tool`
- ✅ Test analysis plan in `/data` for demonstration
- 🔄 Additional MCP tools in development
- 🔄 Workflow templates being designed

## Getting Started

For a hands-on introduction to the general concepts, see the [getting_started](./getting_started/) folder.

## Components

### Orchestrator Agent (MCP Client)
Claude Code serves as the orchestrator agent, acting as a client to the MCP server. Future versions may include custom ReAct/coding agents using frameworks like litellm/Autogen.

### PharmAI MCP Server
Custom MCP server handling pharmacometric-specific tasks:
- Analysis plan parsing
- Custom REPL for R, Python, nlmixr2, and pharmpy commands
- Data digitization
- Specialized documentation loading
- Report generation

### Existing MCP Servers
Integration with curated MCP servers:
- [Context7](https://github.com/upstash/context7) for documentation loading
- [MCP SSH](https://github.com/tufantunc/ssh-mcp) for remote server access
- [Playwright](https://github.com/microsoft/playwright-mcp) for web scraping

### Workflow Templates
Structured templates for common pharmacometric tasks:
- Exploratory analysis
- PopPK analysis workflows
- End-to-end analysis pipelines

## Development

### Running the MCP Server Directly
```bash
uv run python mcp_server.py
```

### Tools

#### DSPy REPL (Interactive Code Generation)
The DSPy REPL provides an AI-powered code generation interface with self-correction and MLflow tracking:

```bash
# Start the interactive REPL
uv run python src/tools/dspy_repl.py

# Example session:
# Task: create a simple plot of random data with seaborn
# Language (python/r): python
# Max attempts (default 5): 3
# Debug mode? (y/n): n
```

Key features:
- **Iterative refinement**: Automatically debugs and improves code based on execution results
- **Multi-language support**: Python and R code generation
- **Context loading**: Load existing scripts with `load:filename.py` to enhance/modify them
- **MLflow tracking**: All generations and evaluations are logged for analysis
- **Smart saving**: Successful scripts are automatically saved to `temp_workdir/`

#### Testing Tools
```bash
# Test the extract_tasks tool
uv run python src/tools/extract_tasks_tool.py
```

## Blog Series

This repository accompanies a blog series documenting the development process. Read all posts at [aripritchardbell.com/blog](https://www.aripritchardbell.com/blog).

**Published Posts:**
1. ✅ **The Vision (2025-05-31)**: Established the "why" for AI in pharmacometrics, focusing on secure, auditable, and human-in-the-loop systems
2. ✅ **The Foundation (2025-06-09)**: Built the core single-agent framework capable of generating basic R scripts from prompts  
3. ✅ **The Orchestration (2025-07-11)**: Introduced multi-agent architecture using DSPy and Model Context Protocol (MCP) for managing specialized AI tools
4. ✅ **The REPL (2025-08-09)**: Built a self-correcting Read-Eval-Print-Loop that enables iterative debugging and refinement

**Upcoming Topics:**
- End-to-end walkthrough using synthetic pharmacometric data - from data generation through PopPK modeling with the full agent system
- Building realistic synthetic data from LLM-generated templates and simulation
- Generating realistic hybrid synthetic data from public regulatory sources (e.g., FDA SBoA)

## License & Disclaimer

This project is licensed under the MIT License. It is intended for educational and research purposes. All AI-generated analyses must be reviewed and validated by a qualified professional before being used for regulatory or clinical decision-making.
