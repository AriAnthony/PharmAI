# Function to install and load required packages
install_and_load <- function(packages) {
  for (pkg in packages) {
    if (!require(pkg, character.only = TRUE)) {
      install.packages(pkg, dependencies = TRUE)
      library(pkg, character.only = TRUE)
    }
  }
}

# Install and load required libraries
required_packages <- c("mrgsolve", "dplyr")
install_and_load(required_packages)

cat("Libraries loaded successfully!\n")

# Define PKPD model with error handling
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
WT     : Weight (kg)
'

# Compile the model with error handling
cat("Compiling PKPD model...\n")
tryCatch({
  mod <- mcode("pkpd_model", pkpd_model)
  cat("Model compiled successfully!\n")
}, error = function(e) {
  cat("Error compiling model:", e$message, "\n")
  stop("Model compilation failed")
})

# Create population of 50 subjects with varying weights
set.seed(123)
n_subjects <- 50
cat("Creating population of", n_subjects, "subjects...\n")

subjects <- tibble(
  ID = 1:n_subjects,
  WT = rnorm(n_subjects, mean = 70, sd = 15)
) %>%
  mutate(WT = pmax(WT, 45)) %>%  # Minimum weight of 45 kg
  mutate(WT = pmin(WT, 120))     # Maximum weight of 120 kg

cat("Weight range:", round(min(subjects$WT), 1), "-", round(max(subjects$WT), 1), "kg\n")

# Create dosing regimen - 100mg twice daily for 7 days
dose_events <- ev(amt = 100, ii = 12, addl = 13, cmt = 1)
cat("Dosing regimen: 100mg every 12 hours for 7 days\n")

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

cat("Number of sampling times:", length(sampling_times), "\n")

# Run simulation using idata for covariates
cat("Running simulation...\n")
tryCatch({
  sim_data <- mod %>%
    ev(dose_events) %>%
    idata_set(subjects) %>%
    mrgsim(end = 240, delta = 0.1, add = sampling_times) %>%
    as_tibble() %>%
    filter(time %in% sampling_times)
  
  cat("Simulation completed successfully!\n")
  cat("Raw simulation data rows:", nrow(sim_data), "\n")
  
  # Check what columns are available
  cat("Available columns:", paste(names(sim_data), collapse = ", "), "\n")
  
}, error = function(e) {
  cat("Error during simulation:", e$message, "\n")
  stop("Simulation failed")
})

# Add study information
sim_data <- sim_data %>%
  mutate(
    STUDY = "PKPD_SIM_001",
    DOSE = 100,
    ROUTE = "PO"
  )

# Create long format for PK and PD observations
cat("Processing PK data...\n")
pk_data <- sim_data %>%
  select(STUDY, ID, time, DOSE, ROUTE, DV = DV_PK, CP, CL, V2, WT) %>%
  mutate(DVID = 1, TYPE = "PK", UNIT = "mg/L") %>%
  filter(DV > 0.01)  # Remove very low concentrations

cat("Processing PD data...\n")
pd_data <- sim_data %>%
  select(STUDY, ID, time, DOSE, ROUTE, DV = DV_PD, EFFECT, CL, V2, WT) %>%
  mutate(DVID = 2, TYPE = "PD", UNIT = "units") %>%
  filter(time >= 0)  # Keep all PD observations

# Combine datasets
cat("Combining datasets...\n")
final_data <- bind_rows(pk_data, pd_data) %>%
  arrange(ID, time, DVID) %>%
  mutate(
    LLOQ_PK = 0.1,
    LLOQ_PD = NA,
    BLQ = ifelse(TYPE == "PK" & DV < LLOQ_PK, 1, 0)
  ) %>%
  select(STUDY, ID, time, DVID, TYPE, DV, UNIT, DOSE, ROUTE, 
         CL, V2, WT, LLOQ_PK, BLQ)

# Validate the final dataset
cat("Validating dataset...\n")
if (nrow(final_data) == 0) {
  stop("Final dataset is empty!")
}

# Check for missing values in critical columns
missing_check <- final_data %>%
  summarise(
    missing_ID = sum(is.na(ID)),
    missing_time = sum(is.na(time)),
    missing_DV = sum(is.na(DV)),
    missing_TYPE = sum(is.na(TYPE))
  )

if (any(missing_check > 0)) {
  cat("Warning: Missing values detected in critical columns\n")
  print(missing_check)
}

# Save to CSV with error handling
output_file <- "simulated_pkpd_data.csv"
cat("Saving data to", output_file, "...\n")

tryCatch({
  write.csv(final_data, output_file, row.names = FALSE)
  cat("Dataset saved successfully!\n")
}, error = function(e) {
  cat("Error saving file:", e$message, "\n")
  stop("File save failed")
})

# Display comprehensive summary
cat("\n=== SIMULATION SUMMARY ===\n")
cat("Dataset saved as:", output_file, "\n")
cat("Number of subjects:", n_subjects, "\n")
cat("Total observations:", nrow(final_data), "\n")
cat("PK observations:", sum(final_data$TYPE == "PK"), "\n")
cat("PD observations:", sum(final_data$TYPE == "PD"), "\n")
cat("BLQ observations:", sum(final_data$BLQ, na.rm = TRUE), "\n")

# Summary statistics
pk_summary <- final_data %>% filter(TYPE == "PK") %>% pull(DV)
pd_summary <- final_data %>% filter(TYPE == "PD") %>% pull(DV)

cat("\nPK concentration range:", round(min(pk_summary), 3), "-", round(max(pk_summary), 3), "mg/L\n")
cat("PD effect range:", round(min(pd_summary), 1), "-", round(max(pd_summary), 1), "units\n")

# Show first few rows of each type
cat("\n=== SAMPLE DATA ===\n")
cat("First 5 PK observations:\n")
print(final_data %>% filter(TYPE == "PK") %>% head(5) %>% select(ID, time, DV, TYPE, UNIT))

cat("\nFirst 5 PD observations:\n")
print(final_data %>% filter(TYPE == "PD") %>% head(5) %>% select(ID, time, DV, TYPE, UNIT))

cat("\nSimulation completed successfully! ✓\n")