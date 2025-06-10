# PharmAI: AI-Powered Pharmacometric Analysis

PharmAI demonstrates how to build a secure, reliable AI agent for pharmacometric analysis. It transforms natural language tasks into auditable, executable R scripts, bridging the gap between cutting-edge AI and the rigorous demands of pharmaceutical science.

**🚀 Try the interactive demo: [getting_started/pharmacometric_ai_demo.ipynb](./getting_started/pharmacometric_ai_demo.ipynb)**

From a simple prompt to a complete, validated analysis

## Why This Matters for Pharma

This isn't just another AI demo. It's a blueprint for building production-grade AI tools that meet the industry's core needs:

*   🔒 **Secure & Compliant**: Uses local LLMs via Ollama, ensuring **no proprietary data ever leaves your network**. The structured workflow creates the auditable trails required for regulatory oversight.
*   🔬 **Domain-Specific**: Built by a pharmacometrician for pharmacometricians. The agent understands the context of PopPK, NCA, and tools like `nlmixr2`.
*   ⚙️ **Production-Ready**: Moves beyond fragile scripts. It uses a foundational **Plan, Act, Observe, Reflect** loop—the building block for robust, self-correcting agents that can handle real-world complexity.
*   🔄 **Reliable & Auditable**: Leverages Pydantic for structured, validated outputs. Every action the AI takes is predictable and traceable.

## Quick Start

Get the agent running in 5 minutes.

1.  **Clone the Repository**
    ```bash
    git clone https://github.com/arianthony/pharmai.git
    cd pharmai
    ```

2.  **Install Dependencies**
    ```bash
    pip install -r requirements.txt
    ```

3.  **Install & Run a Local LLM with Ollama**
    ```bash
    # Install Ollama (on macOS/Linux)
    curl -fsSL https://ollama.com/install.sh | sh

    # Download and run the recommended model
    ollama run qwen2.5-coder:7b
    ```
    *(For Windows, see [Ollama Windows Guide](https://github.com/ollama/ollama/blob/main/docs/windows.md))*

4.  **Run the Demo Notebook**
    ```bash
    jupyter notebook getting_started/pharmacometric_ai_demo.ipynb
    ```

## Blog Series: Building Production AI for Pharmacometrics

This repository contains the code for the blog series, which documents the journey from a simple concept to a production-ready system.

1.  ✅ **The Vision**: [Why PopPK Analysis is Perfect for AI Automation](https://arianthony.github.io/intro/2025/05/31/welcome-to-pmx-ai.html)
2.  ✅ **The Foundation**: [LLM Powered Pharmacometric Workflows](https://blog.pharm.ai/llm-powered-pharmacometric-workflows) 
3.  🔄 **The Optimization**: Advanced RAG for Scientific Domain Knowledge (coming soon)
4.  🔄 **The Orchestration**: Multi-Agent Workflows for End-to-End Analysis (coming soon)
5.  🔄 **The Validation**: Human-in-the-Loop and Regulatory Compliance (coming soon)

## License & Disclaimer

This project is licensed under the MIT License. It is intended for educational and research purposes. All AI-generated analyses must be reviewed and validated by a qualified professional before being used for regulatory or clinical decision-making.
