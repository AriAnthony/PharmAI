"""
DSPy Code Generation REPL with Simple Example Injection

Provides a DSPy-powered code generation REPL that can learn from examples.
Examples are loaded from examples.json and injected into prompts based on simple matching.
"""

import dspy
import json
import os
import subprocess
import sys
import tempfile
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
    """Save a successful result as a new example with clean reasoning."""
    # Determine if we need to generate clean reasoning
    if result.iterations == 1:
        # First iteration success - use original reasoning
        clean_reasoning = result.reasoning
        print("Using original reasoning (first iteration success)")
    else:
        # Multi-iteration success - generate clean reasoning
        print(f"Generating clean reasoning (took {result.iterations} iterations)...")
        reasoning_generator = dspy.ChainOfThought(ExampleReasoning)
        clean_result = reasoning_generator(
            task=result.task,
            language=result.language,
            code=result.code,
            iteration_context=getattr(result, 'iteration_context', 'No iteration context available')
        )
        clean_reasoning = clean_result.reasoning
    
    # Preview the reasoning before saving
    print(f"\n--- Example Preview ---")
    print(f"Task: {result.task}")
    print(f"Language: {result.language}")
    print(f"Reasoning: {clean_reasoning}")
    print(f"Code length: {len(result.code)} characters")
    print("--- End Preview ---\n")
    
    # Confirm before saving
    confirm = input("Save this example? (y/n): ").strip().lower()
    if confirm != 'y':
        print("Example not saved.")
        return
    
    # Save the example
    examples = load_examples()
    new_example = {
        "task": result.task,
        "language": result.language,
        "reasoning": clean_reasoning,
        "code": result.code
    }
    examples.append(new_example)
    
    with open("examples.json", 'w') as f:
        json.dump(examples, f, indent=2)
    
    print(f"✅ Saved example: {result.task}")

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

class ExampleReasoning(dspy.Signature):
    """Generate clean, reusable reasoning for a successful code solution."""
    task: str = dspy.InputField(desc="What we want to achieve")
    language: str = dspy.InputField(desc="Programming language used") 
    code: str = dspy.InputField(desc="The successful code solution")
    iteration_context: str = dspy.InputField(desc="Context from previous iterations showing what was learned and refined")
    
    reasoning: str = dspy.OutputField(desc="Clear, general reasoning explaining the approach and methodology. Synthesize insights from the iteration process but avoid referencing specific attempts or failures.")

def clean_code(code: str, language: str) -> str:
    """Clean code by removing markdown artifacts and other LLM response artifacts."""
    # Remove markdown code fences
    lines = code.strip().split('\n')
    
    # Remove opening code fence (```python, ```r, etc.)
    if lines and lines[0].strip().startswith('```'):
        lines = lines[1:]
    
    # Remove closing code fence
    if lines and lines[-1].strip() == '```':
        lines = lines[:-1]
    
    # Remove any remaining standalone backticks
    cleaned_lines = []
    for line in lines:
        # Skip lines that are just backticks
        if line.strip() in ['```', '```python', '```r', f'```{language.lower()}']:
            continue
        cleaned_lines.append(line)
    
    return '\n'.join(cleaned_lines)

def write_script(code: str, language: str, save_script: bool = False) -> str:
    """Write code to a script file and return the file path."""
    # Clean the code first
    cleaned_code = clean_code(code, language)
    
    # Determine file extension
    if language.lower() == "python":
        suffix = ".py"
    elif language.lower() == "r":
        suffix = ".R"
    else:
        raise ValueError(f"Unsupported language: {language}")
    
    # Create temporary file with explicit UTF-8 encoding
    with tempfile.NamedTemporaryFile(mode='w', suffix=suffix, delete=False, encoding='utf-8') as f:
        f.write(cleaned_code)
        temp_path = f.name
    
    # Optionally save to permanent location
    if save_script:
        save_path = f"saved_script_{os.path.basename(temp_path)}"
        os.rename(temp_path, save_path)
        print(f"Script saved to: {save_path}")
        return save_path
    
    return temp_path

def execute_script(script_path: str, language: str) -> ExecutionResult:
    """Execute a script file and return results."""
    # Determine interpreter command
    if language.lower() == "python":
        cmd = [sys.executable, script_path]
    elif language.lower() == "r":
        cmd = ["Rscript", script_path]
    else:
        return {
            "success": False,
            "stdout": "",
            "stderr": f"Unsupported language: {language}",
            "returncode": -1
        }
    
    # Execute with simple subprocess call
    result = subprocess.run(cmd, capture_output=True)
    
    return {
        "success": result.returncode == 0,
        "stdout": result.stdout.decode('utf-8') if result.stdout else "",
        "stderr": result.stderr.decode('utf-8') if result.stderr else "",
        "returncode": result.returncode
    }

def execute_code(code: str, language: str = "python", save_script: bool = False) -> ExecutionResult:
    """Execute code by writing to script file and running it."""
    script_path = None
    
    try:
        # Write code to script file
        script_path = write_script(code, language, save_script)
        
        # Execute the script
        result = execute_script(script_path, language)
        
        return result
        
    except Exception as e:
        return {
            "success": False,
            "stdout": "",
            "stderr": f"Execution error: {str(e)}",
            "returncode": -1
        }
    finally:
        # Clean up temporary file (if not saved)
        if script_path and not save_script and os.path.exists(script_path):
            try:
                os.unlink(script_path)
            except:
                pass  # Ignore cleanup errors

def evaluate_goal(task, code, result, language):
    """Evaluate if the goal was achieved using LLM-based evaluation."""
    evaluator = dspy.ChainOfThought(GoalEvaluator)
    
    return evaluator(
        task=task,
        language=language,  
        code=code,
        execution_result=json.dumps(result, indent=2)
    )

def repl_loop(task: str, language: str = "python", max_iterations: int = 5, examples: Optional[List[Example]] = None, start_iteration: int = 1, initial_context: str = None) -> dspy.Prediction:
    """Main REPL loop that iteratively generates and executes code."""
    generator = dspy.ChainOfThought(CodeGenerator)
    
    # Build initial context with examples
    if initial_context:
        context = initial_context
    else:
        context = "This is the first attempt."
        if examples:
            relevant = get_relevant_examples(examples, task, language)
            context += format_examples_for_context(relevant)
    
    for iteration in range(start_iteration, max_iterations + 1):
        print(f"Attempt {iteration}...")
        response = generator(task=task, language=language, context=context)
        result = execute_code(response.code, language, save_script=False)
        evaluation = evaluate_goal(task, response.code, result, language)
        
        if evaluation.goal_achieved:
            print("Success!")
            # Save the final successful script
            execute_code(response.code, language, save_script=True)
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
                code=response.code,
                iteration_context=context
            )

        print(f"Failed - \nresult: {json.dumps(result, indent=2)}\nReason: {evaluation.evaluation_reasoning}")
        context = f"Previous attempt failed. Code: {response.code}\nResult: {json.dumps(result, indent=2)}\nFeedback: {evaluation.evaluation_reasoning}"
    
    # Save the final failed script
    execute_code(response.code, language, save_script=True)
    
    # Save session state when max attempts reached (only if we started from iteration 1)
    if start_iteration == 1:
        generator = dspy.ChainOfThought(CodeGenerator)
        evaluator = dspy.ChainOfThought(GoalEvaluator)
        save_session_state(
            task=task,
            language=language,
            iteration=max_iterations + 1,  # Next iteration to try
            max_iterations=max_iterations + 5,  # Allow 5 more attempts
            context=context,
            generator_state=generator.dump_state(),
            evaluator_state=evaluator.dump_state(),
            examples=examples or []
        )
    
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

def save_session_state(task: str, language: str, iteration: int, max_iterations: int, context: str, generator_state: dict, evaluator_state: dict, examples: List[Example]) -> None:
    """Save current session state for resumption."""
    session_data = {
        "task": task,
        "language": language,
        "current_iteration": iteration,
        "max_iterations": max_iterations,
        "context": context,
        "generator_state": generator_state,
        "evaluator_state": evaluator_state,
        "examples": examples
    }
    
    with open("session_state.json", 'w') as f:
        json.dump(session_data, f, indent=2)
    
    print(f"Session saved. Resume with 'resume' option in main menu.")

def load_session_state() -> Optional[dict]:
    """Load session state from file."""
    try:
        with open("session_state.json", 'r') as f:
            return json.load(f)
    except FileNotFoundError:
        return None
    except json.JSONDecodeError:
        print("Warning: Corrupted session state file.")
        return None

def resume_repl_loop(session_data: dict) -> dspy.Prediction:
    """Resume REPL loop from saved session state."""
    task = session_data["task"]
    language = session_data["language"]
    start_iteration = session_data["current_iteration"]
    max_iterations = session_data["max_iterations"]
    context = session_data["context"]
    examples = session_data["examples"]
    
    # Recreate generator and evaluator with saved state
    generator = dspy.ChainOfThought(CodeGenerator)
    evaluator = dspy.ChainOfThought(GoalEvaluator)
    
    if "generator_state" in session_data:
        generator.load_state(session_data["generator_state"])
    if "evaluator_state" in session_data:
        evaluator.load_state(session_data["evaluator_state"])
    
    print(f"Resuming task: {task}")
    print(f"Starting from iteration {start_iteration}/{max_iterations}")
    
    return repl_loop(
        task=task,
        language=language, 
        max_iterations=max_iterations,
        examples=examples,
        start_iteration=start_iteration,
        initial_context=context
    )

def main(max_attempts: int = 5):
    """Interactive REPL interface."""
    print("DSPy Code Generation REPL")
    print("Commands: 'quit' to exit, 'resume' to continue saved session")
    
    # Load examples
    examples = load_examples()
    print(f"Loaded {len(examples)} examples")
    
    # Check for existing session
    session_data = load_session_state()
    if session_data:
        print(f"Found saved session: {session_data['task']}")
    
    while True:
        try:
            task = input("\nTask (or 'resume' to continue saved session): ").strip()
            if task.lower() in ['quit', 'exit', 'q']:
                break
            if not task:
                continue
            
            # Handle resume command
            if task.lower() == 'resume':
                # Reload session data in case it was created during current execution
                current_session = load_session_state()
                if current_session:
                    result = resume_repl_loop(current_session)
                    task = current_session["task"]  # For display purposes
                else:
                    print("No saved session found.")
                    continue
            else:
                language = input("Language (python/r): ").strip().lower() or "python"
                if language not in ['python', 'r']:
                    language = "python"
                
                # Get max attempts (optional)
                attempts_input = input(f"Max attempts (default {max_attempts}): ").strip()
                if attempts_input:
                    try:
                        max_attempts = max(1, int(attempts_input))
                    except ValueError:
                        print(f"Invalid number, using default: {max_attempts}")
                
                print(f"Running {language} code generation...")
                result = repl_loop(task, language, max_iterations=max_attempts, examples=examples)
            
            if result["success"]:
                print(f"✅ Success in {result['iterations']} iterations")
                
                # Clean up session state on success
                if os.path.exists("session_state.json"):
                    os.remove("session_state.json")
                
                # Offer to save as example
                save = input("Save this as an example? (y/n): ").strip().lower()
                if save == 'y':
                    save_as_example(result)
            else:
                print(f"❌ Failed after {result['iterations']} iterations")
                print("Session state saved for resumption.")

        except KeyboardInterrupt:
            print("\nExiting...")
            break
        except Exception as e:
            print(f"Error: {e}")


if __name__ == "__main__":
    main()