library(mrgsolve)
library(ggplot2)

# Create a one-compartment PK model
pk_model <- mcode("one_comp_model", 
"$PARAM 
  CL = 5    // Clearance (L/hr)
  V = 50    // Volume of distribution (L)
  KA = 0    // Absorption rate (0 for IV bolus)
  KE = CL/V // Elimination rate constant

$INIT 
  CENT = 0  // Central compartment concentration

$MAIN
  D_CENT = -KE*CENT;

$CAPTURE 
  CENT
")

# Simulation parameters
sim_data <- ev(amt = 1000, time = 0)  // 1000 mg IV bolus at time 0

# Run simulation
sim_result <- pk_model %>% 
  mrgsim(data = sim_data, 
         end = 24,     // Simulate for 24 hours
         delta = 0.5)  // Output every 0.5 hours

# Plot results
plot(sim_result)