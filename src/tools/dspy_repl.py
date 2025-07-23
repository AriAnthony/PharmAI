"""
DSPy Code Generation REPL

Provides a DSPy-powered code generation REPL with MLflow tracking.
"""

import dspy
import json
import os
import subprocess
import sys
import tempfile
from typing import TypedDict
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

class ExecutionResult(TypedDict):
    """Schema for code execution results."""
    success: bool
    stdout: str
    stderr: str
    returncode: int



class CodeGeneratorAndEvaluator(dspy.Signature):
    """Generate code to achieve a specific task and evaluate if finished after execution."""
    task: str = dspy.InputField(desc="What we want to achieve")
    language: str = dspy.InputField(desc="Programming language to use (e.g., Python, R)")
    context: str = dspy.InputField(desc="Previous attempt and result")
    execution_result: str = dspy.InputField(desc="The result of code execution from previous attempt (empty for first attempt)")
    
    reasoning: str = dspy.OutputField(desc="Step-by-step thinking about the approach")
    code: str = dspy.OutputField(desc="Complete script to execute")
    finished: bool = dspy.OutputField(desc="True ONLY if there are execution results showing the task is complete. Always False on first attempt when execution_result is empty. Only True when previous code execution demonstrates task completion.")


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


def repl_loop(task: str, language: str = "python", max_iterations: int = 5, debug: bool = False) -> dspy.Prediction:
    """Main REPL loop that iteratively generates and executes code."""
    # Ensure at least 2 iterations so LLM can see execution results before evaluating completion
    max_iterations = max(2, max_iterations)
    generator = dspy.ChainOfThought(CodeGeneratorAndEvaluator)
    
    context = "This is the first attempt."
    execution_result = ""
    
    for iteration in range(1, max_iterations + 1):
        print(f"Attempt {iteration}...")
        
        if debug:
            print(f"DEBUG - Context: {context}")
            print(f"DEBUG - Execution result from previous: {execution_result}")
        
        response = generator(
            task=task, 
            language=language, 
            context=context,
            execution_result=execution_result
        )
        
        if debug:
            print(f"DEBUG - Generated reasoning: {response.reasoning}")
            print(f"DEBUG - Generated code:\n{response.code}")
            print(f"DEBUG - Finished flag: {response.finished}")
        
        result = execute_code(response.code, language, save_script=False)
        execution_result = json.dumps(result, indent=2)
        
        if debug:
            print(f"DEBUG - Execution result: {execution_result}")
        
        # Only check finished flag after first iteration (when LLM has seen execution results)
        if iteration > 1 and response.finished:
            print("Success!")
            # Save the final successful script
            execute_code(response.code, language, save_script=True)
            return dspy.Prediction(
                success=True,
                iterations=iteration,
                task=task,
                language=language,
                reasoning=response.reasoning,
                code=response.code,
                result=result
            )

        if iteration == 1:
            print(f"First attempt executed - \nresult: {execution_result}")
        else:
            print(f"Not finished - \nresult: {execution_result}")
        
        context = f"Previous attempt. Code: {response.code}\nResult: {execution_result}\nContinue working on the task."
    
    # Save the final script even if not finished
    execute_code(response.code, language, save_script=True)
    
    return dspy.Prediction(
        success=False,
        iterations=max_iterations,
        task=task,
        language=language,
        reasoning=getattr(response, 'reasoning', ''),
        code=getattr(response, 'code', ''),
        result=result
    )


def main(max_attempts: int = 5):
    """Interactive REPL interface."""
    print("DSPy Code Generation REPL")
    print("Commands: 'quit' to exit")
    
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
            
            # Get max attempts (optional, minimum 2)
            attempts_input = input(f"Max attempts (default {max_attempts}, minimum 2): ").strip()
            if attempts_input:
                try:
                    max_attempts = max(2, int(attempts_input))
                except ValueError:
                    print(f"Invalid number, using default: {max_attempts}")
            
            # Get debug flag (optional)
            debug_input = input("Debug mode? (y/n): ").strip().lower()
            debug = debug_input == 'y'
            
            print(f"Running {language} code generation...")
            result = repl_loop(task, language, max_iterations=max_attempts, debug=debug)
            
            if result.success:
                print(f"✅ Success in {result.iterations} iterations")
            else:
                print(f"❌ Failed after {result.iterations} iterations")

        except KeyboardInterrupt:
            print("\nExiting...")
            break
        except Exception as e:
            print(f"Error: {e}")


if __name__ == "__main__":
    main()