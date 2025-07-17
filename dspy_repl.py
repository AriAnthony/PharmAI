"""
DSPy Code Generation REPL with Simple Example Injection

Provides a DSPy-powered code generation REPL that can learn from examples.
Examples are loaded from examples.json and injected into prompts based on simple matching.
"""

import dspy
import json
import subprocess
import sys
from typing import TypedDict, List, Optional
from dspy_utils import load_dspy_config
import mlflow

# Initialize DSPy and MLflow
load_dspy_config()

# Configure MLflow experiment and enable simple autologging
# Enable autologging with all features
mlflow.dspy.autolog(
    log_compiles=True,    # Track optimization process
    log_evals=True,       # Track evaluation results
    log_traces_from_compile=True  # Track program traces during optimization
)

# Configure MLflow tracking
# To view results in UI, run: mlflow ui
mlflow.set_tracking_uri("file:./mlruns")  # Use local file-based tracking
mlflow.set_experiment("DSPy-REPL")

# Type definitions
class Example(TypedDict):
    """Schema for code examples with DSPy integration."""
    task: str
    language: str
    reasoning: str
    code: str

# Future DSPy Optimization Integration:
# When implementing DSPy optimizers (BootstrapFewShot, MIPROv2, etc.), 
# convert Examples to dspy.Example objects like this:
#
# def examples_to_dspy_trainset(examples: List[Example]) -> List[dspy.Example]:
#     return [
#         dspy.Example(
#             task=ex['task'], language=ex['language'], 
#             reasoning=ex['reasoning'], code=ex['code']
#         ).with_inputs('task', 'language') 
#         for ex in examples
#     ]
#
# Usage: trainset = examples_to_dspy_trainset(load_examples())
#        optimizer = dspy.BootstrapFewShot(metric=your_metric)
#        optimized = optimizer.compile(generator, trainset=trainset)

class ExecutionResult(TypedDict):
    """Schema for code execution results."""
    success: bool
    stdout: str
    stderr: str
    returncode: int


def load_examples(examples_file: str = "examples.json") -> List[Example]:
    """Load examples from JSON file."""
    try:
        with open(examples_file, 'r') as f:
            return json.load(f)
    except (FileNotFoundError, json.JSONDecodeError):
        return []

def get_relevant_examples(examples: List[Example], task: str, language: str, max_examples: int = 2) -> List[Example]:
    """Get relevant examples using simple keyword matching."""
    task_words = task.lower().split()
    relevant = []
    
    for ex in examples:
        if ex['language'].lower() == language.lower():
            # Simple keyword matching in task
            if any(word in ex['task'].lower() for word in task_words):
                relevant.append(ex)
    
    return relevant[:max_examples]

def format_examples_for_context(examples: List[Example]) -> str:
    """Format examples as context string."""
    if not examples:
        return ""
    
    context_parts = ["\n\nRelevant examples:"]
    for i, ex in enumerate(examples, 1):
        context_parts.append(f"\nExample {i}:")
        context_parts.append(f"Task: {ex['task']}")
        context_parts.append(f"Reasoning: {ex['reasoning']}")
        context_parts.append(f"Code:\n```{ex['language']}\n{ex['code']}\n```")
    
    return "\n".join(context_parts)

def save_as_example(result: dspy.Prediction) -> None:
    """Save a successful result as a new example."""
    examples = load_examples()
    new_example = {
        "task": result.task,
        "language": result.language,
        "reasoning": result.reasoning,
        "code": result.code
    }
    examples.append(new_example)
    
    with open("examples.json", 'w') as f:
        json.dump(examples, f, indent=2)
    
    print(f"Saved example: {result.task}")

class CodeGenerator(dspy.Signature):
    """Generate code to achieve a specific task, learning from previous attempts and feedback."""
    task: str = dspy.InputField(desc="What we want to achieve")
    language: str = dspy.InputField(desc="Programming language to use (e.g., Python, R)")
    context: str = dspy.InputField(desc="Previous attempts, results, feedback, and examples")
    
    reasoning: str = dspy.OutputField(desc="Step-by-step thinking about the approach")
    code: str = dspy.OutputField(desc="Complete script to execute")
    
    # Note: Output matches our Example TypedDict schema (task, language, reasoning, code)

class GoalEvaluator(dspy.Signature):
    """Evaluate if the executed code achieved the stated goal and provide actionable feedback."""
    task: str = dspy.InputField(desc="What we want to achieve")
    language: str = dspy.InputField(desc="Programming language to use (e.g., Python, R)")
    code: str = dspy.InputField(desc="The code that was executed")
    execution_result: str = dspy.InputField(desc="The result of code execution (stdout, stderr)")
    
    evaluation_reasoning: str = dspy.OutputField(desc="Detailed reasoning for why the task was or wasn't accomplished. Includes specific feedback for improvement towards the goal.")
    goal_achieved: bool = dspy.OutputField(desc="True if task was accomplished, False otherwise")

def execute_code(code: str, language: str = "python", timeout: int = 600) -> ExecutionResult:
    """Execute code via subprocess with timeout."""
    try:
        if language.lower() == "python":
            cmd = [sys.executable, "-c", code]
        elif language.lower() == "r":
            cmd = ["Rscript", "-e", code]
        else:
            return {
                "success": False,
                "stdout": "",
                "stderr": f"Unsupported language: {language}",
                "returncode": -1
            }
        
        result = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            timeout=timeout
        )
        return {
            "success": result.returncode == 0,
            "stdout": result.stdout,
            "stderr": result.stderr,
            "returncode": result.returncode
        }
    except subprocess.TimeoutExpired:
        return {
            "success": False,
            "stdout": "",
            "stderr": f"Code execution timed out after {timeout} seconds",
            "returncode": -1
        }
    except Exception as e:
        return {
            "success": False,
            "stdout": "",
            "stderr": f"Execution error: {str(e)}",
            "returncode": -1
        }

def evaluate_goal(task, code, result, language):
    """Evaluate if the goal was achieved using LLM-based evaluation."""
    evaluator = dspy.ChainOfThought(GoalEvaluator)
    
    return evaluator(
        task=task,
        language=language,  
        code=code,
        execution_result=json.dumps(result, indent=2)
    )

def repl_loop(task: str, language: str = "python", max_iterations: int = 5, examples: Optional[List[Example]] = None) -> dspy.Prediction:
    """Main REPL loop that iteratively generates and executes code."""
    generator = dspy.ChainOfThought(CodeGenerator)
    
    # Build initial context with examples
    context = "This is the first attempt."
    if examples:
        relevant = get_relevant_examples(examples, task, language)
        context += format_examples_for_context(relevant)
    
    for iteration in range(1, max_iterations + 1):
        print(f"Attempt {iteration}...")
        response = generator(task=task, language=language, context=context)
        result = execute_code(response.code, language)
        evaluation = evaluate_goal(task, response.code, result, language)
        
        if evaluation.goal_achieved:
            print("Success!")
            # Return the successful response with additional metadata
            return dspy.Prediction(
                success=True,
                iterations=iteration,
                response=response,
                result=result,
                evaluation=evaluation,
                task=task,
                language=language,
                reasoning=response.reasoning,
                code=response.code
            )

        print(f"Failed - \nresult: {json.dumps(result, indent=2)}\nReason: {evaluation.evaluation_reasoning}")
        context = f"Previous attempt failed. Code: {response.code}\nResult: {json.dumps(result, indent=2)}\nFeedback: {evaluation.evaluation_reasoning}"
    
    return dspy.Prediction(
        success=False,
        iterations=max_iterations,
        response=response,
        result=result,
        evaluation=evaluation,
        task=task,
        language=language,
        reasoning=getattr(response, 'reasoning', ''),
        code=getattr(response, 'code', '')
    )

def main():
    """Interactive REPL interface."""
    print("DSPy Code Generation REPL")
    print("Type 'quit' to exit")
    
    # Load examples
    examples = load_examples()
    print(f"Loaded {len(examples)} examples")
    
    while True:
        try:
            task = input("\nTask: ").strip()
            if task.lower() in ['quit', 'exit', 'q']:
                break
            if not task:
                continue
            
            language = input("Language (python/r): ").strip().lower() or "python"
            if language not in ['python', 'r']:
                language = "python"
            
            print(f"Running {language} code generation...")
            result = repl_loop(task, language, examples=examples)
            
            if result["success"]:
                print(f"✅ Success in {result['iterations']} iterations")
                
                # Offer to save as example
                save = input("Save this as an example? (y/n): ").strip().lower()
                if save == 'y':
                    save_as_example(result)
            else:
                print(f"❌ Failed after {result['iterations']} iterations")

        except KeyboardInterrupt:
            print("\nExiting...")
            break
        except Exception as e:
            print(f"Error: {e}")


if __name__ == "__main__":
    main()