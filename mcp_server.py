import dspy
from fastmcp import FastMCP
from src.tools import TOOLS
from dspy_utils import load_dspy_config

# Initialize the server
mcp = FastMCP(name="PharmAI", tools=TOOLS)

# Initialize DSPy
load_dspy_config()

if __name__ == "__main__":
    # Start the server
    mcp.run()