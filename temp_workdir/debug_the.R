library(mrgsolve)
library(dplyr)
library(tidyr)

# Simplified mrgsolve model definition
nexorab_mod <- mrgsolve::mcode("nexorab_pk", "
$PARAM
CL = 5      // Base clearance
V = 50      // Volume
WT = 70     // Default weight
ETA1 = 0    // Clearance variability

$INIT
CENT = 0

$MAIN
double TVCL = CL * pow(WT/70, 0.75) * exp(ETA1);

$ODE
dxdt_CENT = -TVCL/V * CENT;

$ERROR
double IPRED = CENT/V;
")

# Enhanced simulation function with robust error handling
simulate_nexorab <- function(
  n_subjects = 200, 
  doses = c(10, 30, 60, 100),
  sim_days = 28,
  seed = 123
) {
  # Input validation
  stopifnot(
    n_subjects > 0, 
    length(doses) > 0,
    sim_days > 0
  )
  
  # Set consistent random seed
  set.seed(seed)
  
  # Generate population data with robust constraints
  pop_data <- tryCatch({
    data.frame(
      ID = seq_len(n_subjects),
      WT = pmax(40, pmin(rnorm(n_subjects, 70, 15), 120)),
      DOSE = sample(doses, n_subjects, replace = TRUE)
    )
  }, error = function(e) {
    stop("Population data generation failed: ", e$message)
  })
  
  # Create dosing events using mrgsolve's ev() method
  ev_data <- do.call(rbind, lapply(1:n_subjects, function(i) {
    ev(
      ID = i, 
      time = 0, 
      amt = pop_data$DOSE[i], 
      cmt = 1
    )
  }))
  
  # Simulation with comprehensive error management
  out <- tryCatch({
    nexorab_mod %>%
      update(data = ev_data) %>%
      mrgsim(end = sim_days, delta = 1)
  }, error = function(e) {
    stop("Simulation failed: ", e$message)
  })
  
  # Results processing
  sim_results <- as.data.frame(out) %>%
    left_join(pop_data, by = "ID")
  
  return(sim_results)
}

# Main execution with error handling
tryCatch({
  results <- simulate_nexorab()
  print(summary(results))
  
  # Optional: Visualization
  library(ggplot2)
  ggplot(results, aes(x = time, y = CENT, group = ID)) +
    geom_line(alpha = 0.3) +
    theme_minimal() +
    labs(title = "Nexorab PK Simulation", 
         x = "Time", 
         y = "Concentration")
}, error = function(e) {
  message("Simulation failed: ", e$message)
})