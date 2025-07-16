# Clinical Trial Simulation for Type 2 Diabetes Phase 2 Dose-Finding Study
# Using mrgsolve for PK/PD modeling

library(mrgsolve)
library(dplyr)
library(ggplot2)
library(tidyr)
library(purrr)

# Set seed for reproducibility
set.seed(12345)

# Define the PK/PD model
model_code <- '
$PARAM @annotated
TVCL   : 10    : Typical clearance (L/h)
TVV2   : 50    : Typical central volume (L)
TVV3   : 100   : Typical peripheral volume (L)
TVQ    : 5     : Typical intercompartmental clearance (L/h)
TVKA   : 1.5   : Typical absorption rate constant (1/h)
TVALAG : 0.5   : Typical absorption lag time (h)
TVKOUT : 0.01  : Typical HbA1c elimination rate (1/h)
TVIC50 : 100   : Typical IC50 for HbA1c effect (ng/mL)
TVHBA1C0 : 8.5 : Typical baseline HbA1c (%)
HILL   : 1     : Hill coefficient
WT     : 70    : Weight (kg)
AGE    : 55    : Age (years)
EGFR   : 90    : Estimated GFR (mL/min/1.73m2)
SEX    : 0     : Sex (0=male, 1=female)
HBA1C_BL : 8.5 : Baseline HbA1c (%)

$PARAM @annotated @covariates
ETA1 : 0 : IIV on CL
ETA2 : 0 : IIV on V2
ETA3 : 0 : IIV on KA
ETA4 : 0 : IIV on KOUT
ETA5 : 0 : IIV on IC50
ETA6 : 0 : IIV on HBA1C0

$CMT @annotated
DEPOT  : Absorption compartment
CENT   : Central compartment
PERIPH : Peripheral compartment
HBA1C  : HbA1c response compartment

$MAIN
// Covariate effects
double CL_WT = pow(WT/70, 0.75);
double CL_AGE = AGE < 65 ? 1 : 0.8;
double CL_EGFR = EGFR < 60 ? 0.6 : (EGFR < 90 ? 0.8 : 1.0);
double V2_WT = WT/70;

// Individual parameters with IIV
double CL = TVCL * CL_WT * CL_AGE * CL_EGFR * exp(ETA1);
double V2 = TVV2 * V2_WT * exp(ETA2);
double V3 = TVV3;
double Q = TVQ;
double KA = TVKA * exp(ETA3);
double ALAG1 = TVALAG;
double KOUT = TVKOUT * exp(ETA4);
double IC50 = TVIC50 * exp(ETA5);
double HBA1C0 = TVHBA1C0 * (HBA1C_BL/8.5) * exp(ETA6);

// Initialize HbA1c compartment
if(NEWIND <= 1) HBA1C_0 = HBA1C0/KOUT;

$ODE
// PK equations (2-compartment model)
dxdt_DEPOT = -KA * DEPOT;
dxdt_CENT = KA * DEPOT - (CL/V2) * CENT - (Q/V2) * CENT + (Q/V3) * PERIPH;
dxdt_PERIPH = (Q/V2) * CENT - (Q/V3) * PERIPH;

// PD equation (indirect response model)
double CP = CENT/V2;  // Plasma concentration
double IMAX = 0.8;    // Maximum inhibition
double INHIB = (IMAX * CP) / (IC50 + CP);
dxdt_HBA1C = HBA1C0 * KOUT * (1 - INHIB) - KOUT * HBA1C;

$TABLE
double CP = CENT/V2;
double HBA1C_PRED = HBA1C;
double FPG = 180 - 50 * (1 - HBA1C/HBA1C0); // Simplified FPG model

$CAPTURE @annotated
CP     : Plasma concentration (ng/mL)
HBA1C_PRED : Predicted HbA1c (%)
FPG    : Fasting plasma glucose (mg/dL)
CL     : Individual clearance (L/h)
V2     : Individual central volume (L)
'

# Compile the model
mod <- mcode("t2dm_model", model_code)

# Generate patient demographics for Phase 2 study (N=240)
n_subjects <- 240
dose_groups <- c(1, 2.5, 5, 10, 15, 20)  # mg doses
n_per_group <- n_subjects / length(dose_groups)

# Create patient demographics
demographics <- tibble(
  ID = 1:n_subjects,
  DOSE_GROUP = rep(dose_groups, each = n_per_group),
  WT = rnorm(n_subjects, 85, 15),  # Weight (kg)
  AGE = pmax(18, pmin(75, rnorm(n_subjects, 58, 12))),  # Age (years)
  SEX = rbinom(n_subjects, 1, 0.45),  # Sex (45% female)
  EGFR = pmax(30, rnorm(n_subjects, 85, 20)),  # eGFR
  HBA1C_BL = pmax(7.0, pmin(12.0, rnorm(n_subjects, 8.5, 1.2))),  # Baseline HbA1c
  RACE = sample(c("White", "Black", "Hispanic", "Asian", "Other"), 
                n_subjects, replace = TRUE, 
                prob = c(0.6, 0.15, 0.15, 0.08, 0.02))
) %>%
  mutate(
    WT = pmax(45, pmin(150, WT)),  # Constrain weight
    BMI = rnorm(n_subjects, 32, 5),  # BMI for T2DM population
    DIABETES_DURATION = pmax(0.5, rexp(n_subjects, 1/8))  # Years since diagnosis
  )

# Generate individual random effects
eta_matrix <- matrix(
  c(0.04, 0.01, 0.00, 0.00, 0.00, 0.00,  # ETA1 (CL)
    0.01, 0.09, 0.00, 0.00, 0.00, 0.00,  # ETA2 (V2)
    0.00, 0.00, 0.16, 0.00, 0.00, 0.00,  # ETA3 (KA)
    0.00, 0.00, 0.00, 0.25, 0.00, 0.00,  # ETA4 (KOUT)
    0.00, 0.00, 0.00, 0.00, 0.36, 0.00,  # ETA5 (IC50)
    0.00, 0.00, 0.00, 0.00, 0.00, 0.16), # ETA6 (HBA1C0)
  nrow = 6, ncol = 6
)

library(MASS)
etas <- mvrnorm(n_subjects, mu = rep(0, 6), Sigma = eta_matrix)
colnames(etas) <- paste0("ETA", 1:6)

# Combine demographics with ETAs
idata <- bind_cols(demographics, as_tibble(etas))

# Create dosing events (once daily for 12 weeks)
dosing_events <- idata %>%
  select(ID, DOSE_GROUP, WT, AGE, EGFR, SEX, HBA1C_BL, ETA1:ETA6) %>%
  mutate(
    amt = DOSE_GROUP * 1000,  # Convert mg to μg for model
    evid = 1,
    cmt = 1,
    time = 0
  ) %>%
  # Add daily doses for 12 weeks (84 days)
  slice(rep(1:n(), each = 84)) %>%
  group_by(ID) %>%
  mutate(
    time = (row_number() - 1) * 24,  # Daily dosing
    ii = 24,  # Dosing interval
    addl = ifelse(row_number() == 1, 83, 0),  # Additional doses
    ss = 0
  ) %>%
  slice(1) %>%  # Keep only first dose record with addl
  ungroup()

# Create PK sampling times (sparse sampling design)
pk_times <- c(0, 2, 4, 8, 24, 168, 336, 504, 672, 840, 1344, 1680, 2016)  # Hours

pk_sampling <- idata %>%
  select(ID, WT, AGE, EGFR, SEX, HBA1C_BL, ETA1:ETA6) %>%
  slice(rep(1:n(), each = length(pk_times))) %>%
  group_by(ID) %>%
  mutate(
    time = pk_times,
    evid = 0,
    cmt = 2,
    amt = 0
  ) %>%
  ungroup()

# Create PD sampling times (weekly HbA1c, more frequent glucose)
hba1c_times <- seq(0, 2016, by = 168)  # Weekly for 12 weeks
fpg_times <- c(0, 24, 168, 336, 504, 672, 840, 1008, 1176, 1344, 1512, 1680, 1848, 2016)

pd_sampling <- bind_rows(
  # HbA1c sampling
  idata %>%
    select(ID, WT, AGE, EGFR, SEX, HBA1C_BL, ETA1:ETA6) %>%
    slice(rep(1:n(), each = length(hba1c_times))) %>%
    group_by(ID) %>%
    mutate(
      time = hba1c_times,
      evid = 0,
      cmt = 4,
      amt = 0,
      ENDPOINT = "HBA1C"
    ) %>%
    ungroup(),
  
  # FPG sampling
  idata %>%
    select(ID, WT, AGE, EGFR, SEX, HBA1C_BL, ETA1:ETA6) %>%
    slice(rep(1:n(), each = length(fpg_times))) %>%
    group_by(ID) %>%
    mutate(
      time = fpg_times,
      evid = 0,
      cmt = 4,
      amt = 0,
      ENDPOINT = "FPG"
    ) %>%
    ungroup()
)

# Combine all events
all_events <- bind_rows(
  dosing_events %>% mutate(ENDPOINT = "DOSE"),
  pk_sampling %>% mutate(ENDPOINT = "PK"),
  pd_sampling
) %>%
  arrange(ID, time, evid) %>%
  select(ID, time, evid, cmt, amt, ii, addl, ss, WT, AGE, EGFR, SEX, HBA1C_BL, ETA1:ETA6, ENDPOINT)

# Run simulation
sim_out <- mod %>%
  data_set(all_events) %>%
  carry_out(evid, amt, ii, addl, ss, ENDPOINT, DOSE_GROUP = DOSE_GROUP[ID]) %>%
  mrgsim(end = 2016, delta = 1) %>%
  as_tibble()

# Add residual error and create observed values
sim_data <- sim_out %>%
  mutate(
    # PK observations with proportional + additive error
    CP_OBS = ifelse(ENDPOINT == "PK" & evid == 0,
                   pmax(0.05, CP * exp(rnorm(n(), 0, 0.2)) + rnorm(n(), 0, 0.5)),
                   NA),
    
    # HbA1c observations with proportional error
    HBA1C_OBS = ifelse(ENDPOINT == "HBA1C" & evid == 0,
                      HBA1C_PRED * exp(rnorm(n(), 0, 0.05)),
                      NA),
    
    # FPG observations with combined error
    FPG_OBS = ifelse(ENDPOINT == "FPG" & evid == 0,
                    pmax(70, FPG * exp(rnorm(n(), 0, 0.1)) + rnorm(n(), 0, 5)),
                    NA)
  )

# Create SDTM datasets

# Demographics (DM)
dm <- idata %>%
  select(ID, AGE, SEX, RACE, WT, BMI, DIABETES_DURATION, DOSE_GROUP) %>%
  mutate(
    USUBJID = sprintf("SUBJ-%04d", ID),
    STUDYID = "T2DM-P2-001",
    DOMAIN = "DM",
    ARMCD = paste0("ARM", DOSE_GROUP),
    ARM = paste0(DOSE_GROUP, " mg"),
    AGEU = "YEARS",
    SEX = ifelse(SEX == 1, "F", "M"),
    RFSTDTC = "2024-01-15",  # Reference start date
    RFENDTC = "2024-04-15"   # Reference end date
  ) %>%
  select(STUDYID, DOMAIN, USUBJID, ARMCD, ARM, AGE, AGEU, SEX, RACE, RFSTDTC, RFENDTC)

# Exposure (EX) - Dosing records
ex <- sim_data %>%
  filter(evid == 1) %>%
  left_join(idata %>% select(ID,