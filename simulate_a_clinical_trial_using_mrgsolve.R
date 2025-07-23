# Load required libraries
library(mrgsolve)
library(dplyr)
library(ggplot2)

# Define the pharmacokinetic model with correct mrgsolve syntax
pk_model <- mcode("clinical_trial_sim", 
"$PARAM 
  CL = 5      // Clearance 
  V = 50      // Volume of distribution
  KA = 1      // Absorption rate
  TLAG = 0.5  // Lag time

$INIT
  DEPOT = 0
  CENTRAL = 0

$ODE
  dxdt_DEPOT = -KA * DEPOT;
  dxdt_CENTRAL = KA * DEPOT - (CL/V) * CENTRAL;

$OMEGA
  0.1 0.2     // Inter-individual variability in CL and V

$SIGMA
  0.1         // Residual error model

$ERROR
  double IPRED = CENTRAL/V;
  double DV = IPRED * (1 + EPS(1));
")

# Create dosing scenario
dose_scenario <- ev(
  amt = 100,   # Dose amount
  ii = 24,     # Interdose interval (once daily)
  addl = 13,   # Additional doses
  cmt = 1      # Compartment for dosing
)

# Set random seed for reproducibility
set.seed(1234)

# Run simulation for 100 patients with enhanced parameters
sim_results <- pk_model %>%
  ev(dose_scenario) %>%
  mrgsim(
    nid = 100,       # Number of individuals
    end = 336,       # Total simulation time (14 days)
    delta = 1,       # Output time step
    seed = 1234      # Reproducible random seed
  )

# Convert results to dataframe
sim_data <- as.data.frame(sim_results)

# Create concentration-time plot for central compartment
concentration_plot <- ggplot(sim_data, aes(x = time, y = CENTRAL, group = ID)) +
  geom_line(aes(color = as.factor(ID)), alpha = 0.3) +
  geom_smooth(aes(group = NULL), color = "red", size = 1.5) +
  theme_minimal() +
  labs(
    title = "Simulated Drug Concentration Over Time",
    x = "Time (hours)",
    y = "Concentration (mg/L)",
    color = "Patient ID"
  )

# Print the plot
print(concentration_plot)

# Comprehensive summary statistics
summary_stats <- sim_data %>%
  group_by(time) %>%
  summarise(
    mean_conc = mean(CENTRAL),
    median_conc = median(CENTRAL),
    sd_conc = sd(CENTRAL),
    min_conc = min(CENTRAL),
    max_conc = max(CENTRAL),
    .groups = 'drop'
  )

# Print summary
print(summary_stats)

# Save results with error handling
tryCatch({
  saveRDS(sim_data, "clinical_trial_simulation.rds")
  ggsave("concentration_plot.png", concentration_plot)
  message("Simulation results and plot saved successfully.")
}, error = function(e) {
  message("Error saving results: ", e$message)
})