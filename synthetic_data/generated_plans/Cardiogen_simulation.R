library(mrgsolve)
library(dplyr)
library(tidyr)
library(ggplot2)

# Hypertension Drug PopPK/PD Simulation Model
hypertension_model <- mrgsolve::house(
  # PK compartment structure
  cpp = "
  $PARAM 
    CL = 5,     // Clearance (L/hr)
    V = 50,     // Central volume (L)
    KA = 1.0,   // Absorption rate
    SLOPE = 0.5 // BP reduction slope

  $PKMODEL 
    ncmt = 2    // Two-compartment model
    
  $OMEGA 
    0.1   // IIV on CL
    0.2   // IIV on V
    
  $SIGMA 
    0.1   // Residual error
  
  $MAIN 
    // Covariate effects
    double CLi = CL * pow(WEIGHT/70, 0.75) * 
                 (AGE < 65 ? 1.0 : 0.8) * 
                 (SEX == 1 ? 1.1 : 1.0);
    
    double Vi = V * (WEIGHT/70);
    
  $PRED
    // Blood Pressure Response Model
    double BP_REDUCTION = SLOPE * (CENT/Vi);
    
  $ERROR
    // Residual error model
    double BPERR = BP_REDUCTION + EPS(1);
  "
)

# Simulation Parameters
set.seed(123)
n_subjects <- 500
age_range <- c(18, 75)
weight_range <- c(50, 120)

# Generate Virtual Population
virtual_population <- data.frame(
  ID = 1:n_subjects,
  AGE = runif(n_subjects, age_range[1], age_range[2]),
  WEIGHT = runif(n_subjects, weight_range[1], weight_range[2]),
  SEX = sample(c(0, 1), n_subjects, replace = TRUE),
  eGFR = rnorm(n_subjects, 85, 15)
)

# Dosing Scenario
dosing_scenario <- data.frame(
  ID = virtual_population$ID,
  TIME = 0,
  AMT = 10,   # Standard dose
  EVID = 1    # Dosing event
)

# Run Simulation
sim_results <- mrgsolve::mrgsim(
  hypertension_model, 
  data = virtual_population,
  events = dosing_scenario,
  end = 24  # 24-hour simulation
)

# Convert to SDTM-like Dataset
sdtm_pk <- sim_results %>%
  as.data.frame() %>%
  mutate(
    USUBJID = ID,
    VISIT = "Treatment",
    VISITNUM = 1,
    AVAL = CENT,  # Concentration
    PARAMCD = "CONC"
  ) %>%
  select(USUBJID, VISIT, VISITNUM, TIME, AVAL, PARAMCD)

sdtm_pd <- sim_results %>%
  as.data.frame() %>%
  mutate(
    USUBJID = ID,
    VISIT = "Treatment",
    VISITNUM = 1,
    AVAL = BP_REDUCTION,
    PARAMCD = "BPRED"
  ) %>%
  select(USUBJID, VISIT, VISITNUM, TIME, AVAL, PARAMCD)

# Save Datasets
write.csv(sdtm_pk, "SDTM_PK.csv", row.names = FALSE)
write.csv(sdtm_pd, "SDTM_PD.csv", row.names = FALSE)

# Visualization
ggplot(sdtm_pk, aes(x = TIME, y = AVAL, group = USUBJID)) +
  geom_line(alpha = 0.3) +
  theme_minimal() +
  labs(title = "Population PK Simulation")

ggplot(sdtm_pd, aes(x = TIME, y = AVAL, group = USUBJID)) +
  geom_line(alpha = 0.3) +
  theme_minimal() +
  labs(title = "Blood Pressure Reduction")