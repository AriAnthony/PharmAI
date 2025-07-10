import dspy
from .extract_tasks_tool import extract_tasks

# Initialize DSPy
lm = dspy.LM('ollama_chat/qwen2.5-coder:7b', api_base='http://localhost:11434', api_key='')
dspy.configure(lm=lm)

# Simple list of all available tools
TOOLS = [
    extract_tasks
]

