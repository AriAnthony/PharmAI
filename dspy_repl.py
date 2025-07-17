import dspy
import json
import subprocess
import sys
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

class CodeGenerator(dspy.Signature):
    """Generate code to achieve a specific task, learning from previous attempts and feedback."""
    task: str = dspy.InputField(desc="What we want to achieve")
    language: str = dspy.InputField(desc="Programming language to use (e.g., Python, R)")
    context: str = dspy.InputField(desc="Previous attempts, results, and specific feedback for improvement")
    
    reasoning: str = dspy.OutputField(desc="Step-by-step thinking about the approach")
    code: str = dspy.OutputField(desc="Complete script to execute")

class GoalEvaluator(dspy.Signature):
    """Evaluate if the executed code achieved the stated goal and provide actionable feedback."""
    task: str = dspy.InputField(desc="What we want to achieve")
    language: str = dspy.InputField(desc="Programming language to use (e.g., Python, R)")
    code: str = dspy.InputField(desc="The code that was executed")
    execution_result: str = dspy.InputField(desc="The result of code execution (stdout, stderr)")
    
    evaluation_reasoning: str = dspy.OutputField(desc="Detailed reasoning for why the task was or wasn't accomplished. Includes specific feedback for improvement towards the goal.")
    goal_achieved: bool = dspy.OutputField(desc="True if task was accomplished, False otherwise")

def execute_code(code, language="python", timeout=600):
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

def repl_loop(task, language="python", max_iterations=5):
    """Main REPL loop that iteratively generates and executes code."""
    generator = dspy.ChainOfThought(CodeGenerator)
    context = "This is the first attempt."
    
    for iteration in range(1, max_iterations + 1):
        print(f"Attempt {iteration}...")
        response = generator(task=task, language=language, context=context)
        result = execute_code(response.code, language)
        evaluation = evaluate_goal(task, response.code, result, language)
        
        if evaluation.goal_achieved:
            print("Success!")
            return {
                "success": True,
                "iterations": iteration,
                "response": response,
                "result": result,
                "evaluation": evaluation
            }

        print(f"Failed - \nresult: {json.dumps(result, indent=2)}\nReason: {evaluation.evaluation_reasoning}")
        context = f"Previous attempt failed. Code: {response.code}\nResult: {json.dumps(result, indent=2)}\nFeedback: {evaluation.evaluation_reasoning}"
    
    return {
        "success": False,
        "iterations": max_iterations,
        "response": response,
        "result": result,
        "evaluation": evaluation
    }

def main():
    """Interactive REPL interface."""
    print("DSPy Code Generation REPL")
    print("Type 'quit' to exit")
    
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
            result = repl_loop(task, language)
            
            if result["success"]:
                print(f"✅ Success in {result['iterations']} iterations")
            else:
                print(f"❌ Failed after {result['iterations']} iterations")

            print(f"Output: {result}")

        except KeyboardInterrupt:
            print("\nExiting...")
            break
        except Exception as e:
            print(f"Error: {e}")

if __name__ == "__main__":
    main()