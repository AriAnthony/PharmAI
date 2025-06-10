from pathlib import Path
from langchain.schema import AIMessage, HumanMessage
import subprocess


# Define a function to iterate through LLM call and message appends
def llm_feedback_loop(task, llm, messages, max_iterations=5):
    """
    Iteratively call the LLM with the provided messages and append the response to the messages.
    
    Parameters:
    - llm: The language model instance to call.
    - messages: A list of messages to send to the LLM.
    - max_iterations: Maximum number of iterations to perform.
    
    Returns:
    - The final response from the LLM after all iterations.
    """
    for i in range(max_iterations):
        response = llm.invoke(messages)

        print("✅ Analysis generated!")
        print(f"Completed Status: {response.status_complete}")
        print(f"\nLLM thoughts: {response.thoughts}")
        print(f"\n📝 Generated R script ({len(response.script)} characters):")

        # Check for llm completion flag BEFORE running the R script
        if response.status_complete:
            print("LLM response: completed successfully.")
            break

        # Run the R script and capture output
        output = run_r_script(task, response)
        print(output)

        # Append the model output and the script results to the messages
        messages.append(
            AIMessage(content=response.model_dump_json())
        )
        messages.append(
            HumanMessage(content=output)
        )

        print(f"Iteration {i + 1}: {response}")
    
    return response

# Define function to write and run R script
def run_r_script(task, response):
    # Write R script to the current directory
    script_path = Path(task.task_name.replace(" ", "_") + "_analysis.R")
    script_path.write_text(response.script)
    
    # Execute R script in the current directory
    result = subprocess.run(
        ["Rscript", str(script_path)],
        cwd=".",
        capture_output=True,
        text=True,
        timeout=180
    )
    # Check if the script ran successfully
    if result.returncode == 0:
       output = f"STDOUT:\n{result.stdout}"
    else:
        output = f"STDERR:\n{result.stderr}"
   
    return output