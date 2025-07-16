# Pembrolizumab Population PK Simulation
library(mrgsolve)
library(dplyr)
library(tidyr)

# Define PK Model
pembro_mod <- mcode("pembrolizumab_pk", 
"$PARAM 
CL = 0.2      // Clearance (L/day)
V1 = 3        // Central compartment volume
V2 = 5        // Peripheral compartment volume
Q = 0.1       // Inter-compartmental clearance

// Covariate effects
WTEFF = 1     // Weight effect on clearance
AGEEFF = 1    // Age effect on clearance

$MAIN
double CLi = CL * pow(WTEFF, WT/70) * pow(AGEEFF, AGE/50);

$CMT 
CENT     // Central compartment
PERIPH   // Peripheral compartment

$ODE
dxdt_CENT = -(CLi/V1 + Q/V1)*CENT + Q/V2*PERIPH;
dxdt_PERIPH = Q/V1*CENT - Q/V2*PERIPH;

$OMEGA
0.1   // Inter-individual variability in CL
0.2   // Inter-individual variability in V1

$SIGMA
0.1   // Residual error model

$CAPTURE 
CL V1 WT AGE
")

# Simulation Parameters
set.seed(123)
n_subjects <- 200
dose_levels <- c(2, 5, 10, 20, 50)  # mg/kg

# Generate Subject Characteristics
subjects <- data.frame(
  ID = 1:n_subjects,
  WT = rnorm(n_subjects, mean=70, sd=10),
  AGE = rnorm(n_subjects, mean=50, sd=10),
  SEX = sample(c(0,1), n_subjects, replace=TRUE)
)

# Dosing Simulation
dosing_scenario <- expand.grid(
  ID = subjects$ID,
  DOSE = dose_levels,
  TIME = c(0, 14, 28),  # Typical dosing intervals
  AMT = dose_levels
)

# Merge with Subject Characteristics
dosing_scenario <- dosing_scenario %>%
  left_join(subjects, by="ID")

# Run Simulation
sim_result <- mrgsim(
  pembro_mod, 
  data = dosing_scenario,
  end = 84,  # 12 weeks simulation
  delta = 1  # Daily observations
)

# Convert to SDTM-like Dataset
sdtm_pk <- sim_result %>%
  as_tibble() %>%
  mutate(
    USUBJID = ID,
    VISIT = case_when(
      TIME == 0 ~ "Baseline",
      TIME == 14 ~ "Week 2",
      TIME == 28 ~ "Week 4"
    ),
    PKPARAM = "CONC",
    PKUNIT = "ug/mL"
  ) %>%
  select(USUBJID, TIME, DOSE, CENT, VISIT, PKPARAM, PKUNIT)

# Save Results
write.csv(sdtm_pk, "pembrolizumab_pk_simulation.csv", row.names=FALSE)