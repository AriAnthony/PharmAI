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



class CodeGenerator(dspy.Signature):
    """Generate code to achieve a specific task."""
    task: str = dspy.InputField(desc="What we want to achieve")
    language: str = dspy.InputField(desc="Programming language to use (e.g., Python, R)")
    context: str = dspy.InputField(desc="Previous attempts and feedback")
    
    reasoning: str = dspy.OutputField(desc="Step-by-step thinking about the approach")
    code: str = dspy.OutputField(desc="Complete script to execute")

class TaskEvaluator(dspy.Signature):
    """Evaluate if executed code completed the task and provide summary."""
    task: str = dspy.InputField(desc="What we wanted to achieve")
    code: str = dspy.InputField(desc="The code that was executed")
    execution_result: str = dspy.InputField(desc="The result of code execution")
    
    result_summary: str = dspy.OutputField(desc="Analyze the execution result. If task completed, explain what was accomplished and key results. If not completed, explain what still needs to be done and why.")
    task_completed: bool = dspy.OutputField(desc="Based on the above analysis, True if task was successfully completed")


def clean_code(code: str) -> str:
    """Remove markdown code fences from code."""
    lines = code.strip().split('\n')
    
    # Remove opening code fence
    if lines and lines[0].strip().startswith('```'):
        lines = lines[1:]
    
    # Remove closing code fence
    if lines and lines[-1].strip() == '```':
        lines = lines[:-1]
    
    return '\n'.join(lines)

def generate_script_name(task: str, max_length: int = 50) -> str:
    """Generate a clean script name from task description."""
    # Replace spaces and special characters with underscores
    import re
    clean_name = re.sub(r'[^\w\s-]', '', task)  # Remove special chars except spaces and hyphens
    clean_name = re.sub(r'[-\s]+', '_', clean_name)  # Replace spaces/hyphens with underscores
    clean_name = clean_name.strip('_')  # Remove leading/trailing underscores
    
    # Truncate to max length
    if len(clean_name) > max_length:
        clean_name = clean_name[:max_length].rstrip('_')
    
    return clean_name or "script"  # Fallback if empty

def execute_code(code: str, language: str = "python", save_script: bool = False, save_only: bool = False, script_name: str = None) -> dict:
    """Execute code and return results."""
    script_path = None
    
    try:
        # Clean and prepare code
        cleaned_code = clean_code(code)
        
        # Determine file extension
        if language.lower() == "python":
            suffix = ".py"
        elif language.lower() == "r":
            suffix = ".R"
        else:
            raise ValueError(f"Unsupported language: {language}")
        
        # If save_only, just save and return success
        if save_only:
            base_name = script_name if script_name else "saved_script"
            save_path = f"{base_name}{suffix}"
            with open(save_path, 'w', encoding='utf-8') as f:
                f.write(cleaned_code)
            print(f"Script saved to: {save_path}")
            return {
                "success": True,
                "stdout": "",
                "stderr": "",
                "returncode": 0
            }
        
        # Normal execution path
        with tempfile.NamedTemporaryFile(mode='w', suffix=suffix, delete=False, encoding='utf-8') as f:
            f.write(cleaned_code)
            script_path = f.name
        
        # Execute
        if language.lower() == "python":
            cmd = [sys.executable, script_path]
        else:  # R
            cmd = ["Rscript", script_path]
            
        result = subprocess.run(cmd, capture_output=True)
        
        execution_result = {
            "success": result.returncode == 0,
            "stdout": result.stdout.decode('utf-8') if result.stdout else "",
            "stderr": result.stderr.decode('utf-8') if result.stderr else "",
            "returncode": result.returncode
        }
        
        # Save script if requested
        if save_script:
            base_name = script_name if script_name else f"saved_script_{os.path.basename(script_path)}"
            save_path = f"{base_name}{suffix}"
            with open(save_path, 'w', encoding='utf-8') as f:
                f.write(cleaned_code)
            print(f"Script saved to: {save_path}")
        
        return execution_result
        
    except Exception as e:
        return {
            "success": False,
            "stdout": "",
            "stderr": f"Execution error: {str(e)}",
            "returncode": -1
        }
    finally:
        # Clean up temp file
        if script_path and os.path.exists(script_path):
            try:
                os.unlink(script_path)
            except:
                pass


def repl_loop(task: str, language: str = "python", max_iterations: int = 5, debug: bool = False) -> dspy.Prediction:
    """Main REPL loop that iteratively generates and executes code."""
    generator = dspy.ChainOfThought(CodeGenerator)
    evaluator = dspy.ChainOfThought(TaskEvaluator)
    
    # Generate script name from task
    script_name = generate_script_name(task)
    
    context = "This is the first attempt."
    
    for iteration in range(1, max_iterations + 1):
        print(f"Attempt {iteration}...")
        
        if debug:
            print(f"DEBUG - Context: {context}")
        
        # Generate code (LLM call #1)
        code_response = generator(
            task=task, 
            language=language, 
            context=context
        )
        
        if debug:
            print(f"DEBUG - Generated reasoning: {code_response.reasoning}")
            print(f"DEBUG - Generated code:\n{code_response.code}")
        
        # Execute code
        result = execute_code(code_response.code, language, save_script=False)
        execution_result = json.dumps(result, indent=2)
        
        if debug:
            print(f"DEBUG - Execution result: {execution_result}")
        
        # Evaluate completion (LLM call #2)
        eval_response = evaluator(
            task=task,
            code=code_response.code,
            execution_result=execution_result
        )
        
        if debug:
            print(f"DEBUG - Task completed: {eval_response.task_completed}")
            print(f"DEBUG - Result summary: {eval_response.result_summary}")
        
        if eval_response.task_completed:
            print("Success!")
            print(f"Summary: {eval_response.result_summary}")
            # Save the successful script without re-executing
            execute_code(code_response.code, language, save_only=True, script_name=script_name)
            return dspy.Prediction(
                success=True,
                iterations=iteration,
                task=task,
                language=language,
                reasoning=code_response.reasoning,
                code=code_response.code,
                result=result,
                result_summary=eval_response.result_summary
            )

        print(f"Not completed - {eval_response.result_summary}")
        context = f"Previous attempt failed. Code: {code_response.code}\nResult: {execution_result}\nWhat needs to be done: {eval_response.result_summary}"
    
    # Save the final script even if not finished
    execute_code(code_response.code, language, save_only=True, script_name=script_name)
    
    return dspy.Prediction(
        success=False,
        iterations=max_iterations,
        task=task,
        language=language,
        reasoning=code_response.reasoning,
        code=code_response.code,
        result=result,
        result_summary=eval_response.result_summary
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
            
            # Get max attempts (optional)
            attempts_input = input(f"Max attempts (default {max_attempts}): ").strip()
            if attempts_input:
                try:
                    max_attempts = max(1, int(attempts_input))
                except ValueError:
                    print(f"Invalid number, using default: {max_attempts}")
            
            # Get debug flag (optional)
            debug_input = input("Debug mode? (y/n): ").strip().lower()
            debug = debug_input == 'y'
            
            print(f"Running {language} code generation...")
            result = repl_loop(task, language, max_iterations=max_attempts, debug=debug)
            
            if result.success:
                print(f"✅ Success in {result.iterations} iterations")
                if hasattr(result, 'result_summary'):
                    print(f"📋 {result.result_summary}")
            else:
                print(f"❌ Failed after {result.iterations} iterations")
                if hasattr(result, 'result_summary'):
                    print(f"❌ {result.result_summary}")

        except KeyboardInterrupt:
            print("\nExiting...")
            break
        except Exception as e:
            print(f"Error: {e}")


if __name__ == "__main__":
    main()