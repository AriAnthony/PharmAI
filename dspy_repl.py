import dspy
import subprocess
import sys
from dspy_utils import load_dspy_config

class CodeGenerator(dspy.Signature):
    """Generate code to achieve a specific task, learning from previous attempts and feedback."""
    task: str = dspy.InputField(desc="What we want to achieve")
    language: str = dspy.InputField(desc="Programming language to use (e.g., Python, R)")
    context: str = dspy.InputField(desc="Previous attempts, results, and specific feedback for improvement")
    
    reasoning: str = dspy.OutputField(desc="Step-by-step thinking about the approach, addressing previous failures")
    code: str = dspy.OutputField(desc="Complete script to execute, incorporating lessons learned")

class GoalEvaluator(dspy.Signature):
    """Evaluate if the executed code achieved the stated goal and provide actionable feedback."""
    task: str = dspy.InputField(desc="The original task to achieve")
    language: str = dspy.InputField(desc="Programming language to use (e.g., Python, R)")
    code: str = dspy.InputField(desc="The code that was executed")
    execution_result: str = dspy.InputField(desc="The result of code execution (success, stdout, stderr)")
    
    evaluation_reasoning: str = dspy.OutputField(desc="Detailed reasoning for why the task was or wasn't accomplished")
    goal_achieved: bool = dspy.OutputField(desc="True if task was accomplished, False otherwise")
    feedback: str = dspy.OutputField(desc="Specific, actionable feedback for the next attempt. Include what to fix, what to try differently, or what approach to take.")

def execute_code(code, language="python", timeout=10):
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
    
    execution_result = f"Success: {result['success']}, Return Code: {result['returncode']}, Output: {result['stdout']}, Error: {result['stderr']}"
    
    return evaluator(
        task=task,
        language=language,  
        code=code,
        execution_result=execution_result
    )

def repl_loop(task, language="python", max_iterations=5):
    """Main REPL loop that iteratively generates and executes code."""
    generator = dspy.ChainOfThought(CodeGenerator)
    context = "This is the first attempt. Focus on understanding the task and creating a working solution."
    
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
                "final_code": response.code,
                "result": result,
                "evaluation": evaluation
            }
        
        print(f"Failed - {evaluation.feedback}")
        context = f"Previous attempt failed. Code: {response.code}\nResult: {result}\nFeedback: {evaluation.feedback}"
    
    return {
        "success": False,
        "iterations": max_iterations,
        "final_code": response.code,
        "result": result,
        "evaluation": evaluation
    }

def main():
    """Interactive REPL interface."""
    load_dspy_config()
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
            
            print(f"Final code:\n{result['final_code']}")
            if result['result']['stdout']:
                print(f"Output: {result['result']['stdout']}")
            if result['result']['stderr']:
                print(f"Error: {result['result']['stderr']}")
            print(f"Evaluation: {result['evaluation'].evaluation_reasoning}")
                
        except KeyboardInterrupt:
            print("\nExiting...")
            break
        except Exception as e:
            print(f"Error: {e}")

if __name__ == "__main__":
    main()