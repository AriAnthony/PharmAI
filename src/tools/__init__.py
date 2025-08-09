import dspy
from .extract_tasks_tool import extract_tasks
from dspy_utils import load_dspy_config

# Initialize DSPy
load_dspy_config()

# Simple list of all available tools
TOOLS = [
    extract_tasks
]

