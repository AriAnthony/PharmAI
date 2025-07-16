import dspy 
from langchain_community.document_loaders import Docx2txtLoader
from pydantic import BaseModel, Field

# Define the structure of the task and task list using Pydantic models
class Task(BaseModel):
    """Structure for pharmacometric analysis tasks"""
    task: str = Field(description="Short name for the analysis")
    description: str = Field(description="Step by step breakdown of how the task will be performed")

class ExtractTasksSignature(dspy.Signature):
    """Extract analysis tasks from an analysis plan."""
    text: str = dspy.InputField(
        description="Text content of the analysis plan document, typically extracted from a .docx file"
    )
    task_list: list[dict[str, str]] = dspy.OutputField(
        description="List of dictionaries of tasks extracted from the analysis plan. Each list item contains a dictionary with keys 'task' and 'description' with the corresponding string values.",
    )

module = dspy.Predict(ExtractTasksSignature)

def extract_tasks(filename: str) -> str:
    """Extract analysis tasks from an analysis plan."""
    # Load the document using Docx2txtLoader
    loader = Docx2txtLoader(filename)
    text = loader.load()
    
    # Extract the text content from the loaded document
    response = module(text=text)

    # Unpack the task list to a markdown string, using the first and second keys dynamically
    task_list = response.task_list
    task_list_md = "\n".join(
        [
            f"### {list(task.values())[0]}\n{list(task.values())[1]}" if len(task) >= 2 else str(task)
            for task in task_list
        ]
    )

    return task_list_md

if __name__ == "__main__":
    # Initialize DSPy
    from dspy_utils import load_dspy_config
    load_dspy_config()

    # Example usage
    filename = "./data/analysis_plan_arimab.docx"
    tasks = extract_tasks(filename)
    print("Extracted Tasks:")
    print(tasks)
