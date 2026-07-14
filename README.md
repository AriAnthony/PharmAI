# PharmAI (archived early prototype)

> **This project has moved.** Active work on AI agents for pharmacometrics now
> happens at
> [**AIML-SIG/Agentic-workflows**](https://github.com/AIML-SIG/Agentic-workflows),
> a working group of the ISoP AI/ML SIG. Start there for anything current.

This repo was the original single-author prototype behind the blog series
below. The MCP server / orchestrator experiments described in earlier
versions of this README have been superseded and were removed; the
[`getting_started`](./getting_started/) demo is kept as-is since it still
runs standalone and is a reasonable first taste of the approach.

## Getting Started Demo

[`getting_started/pharmacometric_ai_demo.ipynb`](./getting_started/pharmacometric_ai_demo.ipynb) —
a self-contained notebook going from a prompt to a validated PopPK-style
analysis using a local LLM via Ollama. See
[`getting_started/README.md`](./getting_started/README.md) for setup.

## Blog Series

This repo accompanies a blog series on
[aripritchardbell.com/blog](https://www.aripritchardbell.com/blog):

1. **The Vision** (2025-05-31) — why AI in pharmacometrics, focused on secure, auditable, human-in-the-loop systems
2. **The Foundation** (2025-06-09) — core single-agent framework generating basic R scripts from prompts
3. **The Orchestration** (2025-07-11) — multi-agent architecture using DSPy and MCP
4. **The REPL** (2025-08-09) — a self-correcting read-eval-print loop for iterative debugging

## License & Disclaimer

MIT License. Intended for educational and research purposes. All AI-generated
analyses must be reviewed and validated by a qualified professional before
use in regulatory or clinical decision-making.
