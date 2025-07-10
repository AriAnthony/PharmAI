# PharmAI: AI-Powered Pharmacometric Analysis

PharmAI is a modular AI workflow system for pharmacometric analysis, featuring a custom MCP server and orchestrator agent for automating complex analytical tasks.

## Project Overview

- **Modular Architecture**: Central orchestrator agent (Claude Code) with custom MCP server for pharmacometric tasks
- **MCP Server**: Built with FastMCP, handles analysis plan parsing, pharmpy/nlmixr2/nonmem documentation, report generation
- **Workflow Templates**: Encapsulated as MCP prompts for common tasks (exploratory analysis, PopPK analysis, end-to-end workflows)
- **Evaluation Framework**: Comprehensive testing using regulatory templates and published reports

![Architecture Overview](./architecture_overview.png)

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

### Testing Tools
```bash
# Test the extract_tasks tool
uv run python src/tools/extract_tasks_tool.py
```

## Blog Series

This repository accompanies a blog series documenting the development process:

1. ✅ **The Vision** (Published 5/31/2025): [Why PopPK Analysis is Perfect for AI Automation](https://www.aripritchardbell.com/blog/2025-05-31-welcome-to-pmx-ai)
2. ✅ **The Foundation** (Published 6/09/2025): [LLM Powered Pharmacometric Workflows](https://www.aripritchardbell.com/blog/2025-06-09-llm-workflows-in-langchain)
3. 🔄 **The Orchestration**: Multi-Agent Workflows with Model Context Protocol (planned)

## License & Disclaimer

This project is licensed under the MIT License. It is intended for educational and research purposes. All AI-generated analyses must be reviewed and validated by a qualified professional before being used for regulatory or clinical decision-making.