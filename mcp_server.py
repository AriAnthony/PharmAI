import dspy
from fastmcp import FastMCP
from src.tools import TOOLS

# Initialize the server
mcp = FastMCP(name="PharmAI", tools=TOOLS)

# Initialize DSPy
lm = dspy.LM('ollama_chat/qwen2.5-coder:7b', api_base='http://localhost:11434', api_key='', temperature=0.9)
dspy.configure(lm=lm)

if __name__ == "__main__":
    # Start the server
    mcp.run()