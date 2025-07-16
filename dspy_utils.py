import json
import dspy

def load_dspy_config(config_path="dspy_config.json"):
    """Load and configure DSPy from config file."""
    with open(config_path, 'r') as f:
        config = json.load(f)
    
    active = config["active_model"]
    model_config = config["models"][active]
    
    lm = dspy.LM(model_config["model"], **{k: v for k, v in model_config.items() if k != "model"})
    dspy.configure(lm=lm)
    return lm