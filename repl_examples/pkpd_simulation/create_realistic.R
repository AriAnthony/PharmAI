# Load required libraries
library(mrgsolve)
library(dplyr)

# Define PKPD model
pkpd_model <- '
$PARAM @annotated
TVCL   : 10    : Typical clearance (L/h)
TVV2   : 70    : Typical central volume (L)  
TVV3   : 50    : Typical peripheral volume (L)
TVQ    : 5     : Typical inter-compartmental clearance (L/h)
TVKA   : 1.5   : Typical absorption rate constant (1/h)
TVE0   : 100   : Typical baseline effect
TVEMAX : 80    : Typical maximum effect
TVEC50 : 5     : Typical EC50 (mg/L)

$PARAM @annotated @covariates
WT : 70 : Weight (kg)

$OMEGA @annotated @block
ETA_CL  : 0.09  : IIV on CL
ETA_V2  : 0.01 0.04 : IIV on V2  
ETA_V3  : 0.01 0.01 0.04 : IIV on V3
ETA_Q   : 0.01 0.01 0.01 0.04 : IIV on Q
ETA_KA  : 0.01 0.01 0.01 0.01 0.09 : IIV on KA
ETA_E0  : 0.01 0.01 0.01 0.01 0.01 0.16 : IIV on E0
ETA_EMAX: 0.01 0.01 0.01 0.01 0.01 0.01 0.09 : IIV on EMAX
ETA_EC50: 0.01 0.01 0.01 0.01 0.01 0.01 0.01 0.04 : IIV on EC50

$SIGMA @annotated
PROP_PK : 0.04 : Proportional error PK
ADD_PK  : 0.1  : Additive error PK  
PROP_PD : 0.09 : Proportional error PD

$CMT @annotated
GUT    : Gut compartment
CENT   : Central compartment
PERIPH : Peripheral compartment

$MAIN
double CL = TVCL * pow(WT/70, 0.75) * exp(ETA_CL);
double V2 = TVV2 * (WT/70) * exp(ETA_V2);
double V3 = TVV3 * (WT/70) * exp(ETA_V3);
double Q  = TVQ * pow(WT/70, 0.75) * exp(ETA_Q);
double KA = TVKA * exp(ETA_KA);
double E0 = TVE0 * exp(ETA_E0);
double EMAX = TVEMAX * exp(ETA_EMAX);
double EC50 = TVEC50 * exp(ETA_EC50);

$ODE
dxdt_GUT = -KA * GUT;
dxdt_CENT = KA * GUT - (CL/V2) * CENT - (Q/V2) * CENT + (Q/V3) * PERIPH;
dxdt_PERIPH = (Q/V2) * CENT - (Q/V3) * PERIPH;

$TABLE
double CP = CENT/V2;
double EFFECT = E0 + (EMAX * CP)/(EC50 + CP);

double DV_PK = CP * (1 + PROP_PK * EPS(1)) + ADD_PK * EPS(2);
double DV_PD = EFFECT * (1 + PROP_PD * EPS(3));

$CAPTURE @annotated
CP     : Plasma concentration (mg/L)
DV_PK  : Observed PK concentration (mg/L)
EFFECT : Pharmacodynamic effect
DV_PD  : Observed PD effect
CL     : Individual clearance (L/h)
V2     : Individual central volume (L)
'

# Compile the model
mod <- mcode("pkpd_model", pkpd_model)

# Create population of 50 subjects with varying weights
set.seed(123)
n_subjects <- 50
subjects <- tibble(
  ID = 1:n_subjects,
  WT = rnorm(n_subjects, mean = 70, sd = 15)
) %>%
  mutate(WT = pmax(WT, 45)) %>%  # Minimum weight of 45 kg
  mutate(WT = pmin(WT, 120))     # Maximum weight of 120 kg

# Create dosing regimen - 100mg twice daily for 7 days
dose_events <- ev(amt = 100, ii = 12, addl = 13, cmt = 1)

# Create sampling times - intensive sampling on day 1 and 7, sparse otherwise
sampling_times <- c(
  # Day 1: intensive
  0, 0.5, 1, 2, 4, 6, 8, 12,
  # Days 2-6: sparse  
  24, 48, 72, 96, 120,
  # Day 7: intensive
  144, 144.5, 145, 146, 148, 150, 152, 156,
  # Follow-up
  168, 192, 216, 240
)

# Run simulation using idata for covariates
sim_data <- mod %>%
  ev(dose_events) %>%
  idata_set(subjects) %>%
  mrgsim(end = 240, delta = 0.1, add = sampling_times) %>%
  as_tibble() %>%
  filter(time %in% sampling_times) %>%
  mutate(
    STUDY = "PKPD_SIM_001",
    DOSE = 100,
    ROUTE = "PO"
  )

# Create long format for PK and PD observations
pk_data <- sim_data %>%
  select(STUDY, ID, time, DOSE, ROUTE, DV = DV_PK, CP, CL, V2, WT) %>%
  mutate(DVID = 1, TYPE = "PK", UNIT = "mg/L") %>%
  filter(DV > 0.01)  # Remove very low concentrations

pd_data <- sim_data %>%
  select(STUDY, ID, time, DOSE, ROUTE, DV = DV_PD, EFFECT, CL, V2, WT) %>%
  mutate(DVID = 2, TYPE = "PD", UNIT = "units") %>%
  filter(time >= 0)  # Keep all PD observations

# Combine datasets
final_data <- bind_rows(pk_data, pd_data) %>%
  arrange(ID, time, DVID) %>%
  mutate(
    LLOQ_PK = 0.1,
    LLOQ_PD = NA,
    BLQ = ifelse(TYPE == "PK" & DV < LLOQ_PK, 1, 0)
  ) %>%
  select(STUDY, ID, time, DVID, TYPE, DV, UNIT, DOSE, ROUTE, 
         CL, V2, WT, LLOQ_PK, BLQ)

# Save to CSV
write.csv(final_data, "simulated_pkpd_data.csv", row.names = FALSE)

# Display summary
cat("Simulation completed successfully!\n")
cat("Dataset saved as: simulated_pkpd_data.csv\n")
cat("Number of subjects:", n_subjects, "\n")
cat("Number of observations:", nrow(final_data), "\n")
cat("PK observations:", sum(final_data$TYPE == "PK"), "\n")
cat("PD observations:", sum(final_data$TYPE == "PD"), "\n")

# Show first few rows
print(head(final_data, 10))