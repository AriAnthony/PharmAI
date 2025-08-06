# Clinical Trial Simulation for Dermakinib Population PK/PD Analysis
# JAK1 inhibitor for Atopic Dermatitis - Phase 2 Dose-Finding Study

library(mrgsolve)
library(dplyr)
library(tidyr)
library(ggplot2)
library(purrr)

# Create output directory
dir.create("data", showWarnings = FALSE)

# Set seed for reproducibility
set.seed(12345)

# Define the PK/PD model
model_code <- '
$PARAM
// PK Parameters
CL = 10      // Clearance (L/h)
V2 = 50      // Central volume (L) 
Q = 5        // Intercompartmental clearance (L/h)
V3 = 100     // Peripheral volume (L)
KA = 1.5     // Absorption rate constant (1/h)
ALAG1 = 0.5  // Absorption lag time (h)

// PD Parameters - TARC (biomarker)
TARC0 = 1000    // Baseline TARC (pg/mL)
IMAXTAR = 0.8   // Maximum inhibition of TARC production
IC50TAR = 50    // IC50 for TARC inhibition (ng/mL)
KOUTTAR = 0.1   // TARC elimination rate (1/h)

// PD Parameters - EASI Score
EASI0 = 25      // Baseline EASI score
IMAXEAS = 0.75  // Maximum EASI improvement
IC50EAS = 100   // IC50 for EASI improvement (ng/mL)
KOUTEAS = 0.02  // EASI improvement rate (1/h)

// Covariates
WT = 70         // Weight (kg)
AGE = 35        // Age (years)
SEX = 0         // Sex (0=male, 1=female)
BSLEASI = 25    // Baseline EASI score
CREATCL = 100   // Creatinine clearance (mL/min)

$PARAM
// IIV parameters (variances)
ETA_CL = 0
ETA_V2 = 0
ETA_KA = 0
ETA_TARC0 = 0
ETA_EASI0 = 0

$CMT
GUT CENT PERIPH TARC EASI

$MAIN
// Allometric scaling
double CLi = CL * pow(WT/70, 0.75) * exp(ETA_CL);
double V2i = V2 * (WT/70) * exp(ETA_V2);
double KAi = KA * exp(ETA_KA);

// Covariate effects
if(AGE > 65) CLi = CLi * 0.8;  // Reduced clearance in elderly
if(SEX == 1) CLi = CLi * 0.9;  // Reduced clearance in females
if(CREATCL < 60) CLi = CLi * 0.7;  // Reduced clearance in renal impairment

// PD baseline with IIV
double TARC0i = TARC0 * (1 + 0.3 * (BSLEASI - 25)/25) * exp(ETA_TARC0);
double EASI0i = EASI0 * exp(ETA_EASI0);

// Initialize compartments
TARC_0 = TARC0i;
EASI_0 = EASI0i;

$ODE
// PK equations
dxdt_GUT = -KAi * GUT;
dxdt_CENT = KAi * GUT - (CLi/V2i) * CENT - (Q/V2i) * CENT + (Q/V3) * PERIPH;
dxdt_PERIPH = (Q/V2i) * CENT - (Q/V3) * PERIPH;

// Plasma concentration
double CP = CENT / V2i;

// PD equations - TARC (indirect response, inhibition of input)
double INHTAR = IMAXTAR * CP / (IC50TAR + CP);
dxdt_TARC = TARC0i * (1 - INHTAR) - KOUTTAR * TARC;

// PD equations - EASI (indirect response, stimulation of loss)
double STIMEAS = IMAXEAS * CP / (IC50EAS + CP);
dxdt_EASI = -KOUTEAS * EASI * (1 + STIMEAS);

$TABLE
double CP = CENT / V2i;
double AUC = CP;  // Will be calculated post-hoc

$CAPTURE
CP TARC EASI WT AGE SEX BSLEASI CREATCL
'

# Compile the model
mod <- mcode("dermakinib_pkpd", model_code)

# Define study population characteristics
n_subjects <- 240

# Generate population with realistic demographics for atopic dermatitis
pop_data <- tibble(
  ID = 1:n_subjects,
  WT = rnorm(n_subjects, 75, 15),
  AGE = pmax(18, pmin(75, rnorm(n_subjects, 40, 15))),
  SEX = rbinom(n_subjects, 1, 0.6),  # 60% female
  BSLEASI = pmax(12, pmin(50, rnorm(n_subjects, 25, 8))),  # Moderate-severe AD
  CREATCL = pmax(30, rnorm(n_subjects, 100, 20)),
  
  # Random effects (IIV)
  ETA_CL = rnorm(n_subjects, 0, sqrt(0.09)),    # 30% CV
  ETA_V2 = rnorm(n_subjects, 0, sqrt(0.04)),    # 20% CV  
  ETA_KA = rnorm(n_subjects, 0, sqrt(0.16)),    # 40% CV
  ETA_TARC0 = rnorm(n_subjects, 0, sqrt(0.04)), # 20% CV
  ETA_EASI0 = rnorm(n_subjects, 0, sqrt(0.01))  # 10% CV
) %>%
  mutate(
    WT = pmax(45, pmin(120, WT)),  # Reasonable weight bounds
    EASI0 = BSLEASI  # Set baseline EASI parameter
  )

# Define dose groups (4 dose levels, equal allocation)
dose_groups <- c(50, 100, 200, 400)  # mg QD
subjects_per_group <- n_subjects / length(dose_groups)

pop_data <- pop_data %>%
  mutate(
    DOSE_GROUP = rep(1:4, each = subjects_per_group),
    DOSE = dose_groups[DOSE_GROUP],
    TRT = paste0("Dermakinib ", DOSE, " mg QD")
  )

# Define dosing regimen (QD for 12 weeks)
dosing <- expand_grid(
  ID = 1:n_subjects,
  time = seq(0, 12*7*24, by = 24)  # Daily dosing for 12 weeks
) %>%
  left_join(pop_data %>% select(ID, DOSE), by = "ID") %>%
  mutate(
    amt = DOSE * 1000,  # Convert to μg
    cmt = 1,  # Dosing into GUT compartment
    evid = 1
  )

# Define PK sampling times (sparse sampling as per protocol)
pk_times <- c(0, 2, 4, 24, 168, 336, 504, 672, 840, 1344, 1680, 2016)  # Hours

pk_sampling <- expand_grid(
  ID = 1:n_subjects,
  time = pk_times
) %>%
  mutate(
    evid = 0,
    cmt = 2  # Sampling from central compartment
  )

# Define PD sampling times (weekly assessments)
pd_times <- seq(0, 12*7*24, by = 7*24)  # Weekly for 12 weeks

pd_sampling <- expand_grid(
  ID = 1:n_subjects,
  time = pd_times
) %>%
  mutate(evid = 0)

# Combine dosing and sampling events
events <- bind_rows(
  dosing %>% select(ID, time, amt, cmt, evid),
  pk_sampling %>% select(ID, time, cmt, evid) %>% mutate(amt = 0),
  pd_sampling %>% select(ID, time, evid) %>% mutate(amt = 0, cmt = 0)
) %>%
  arrange(ID, time, desc(evid))

# Run simulation
sim_data <- mod %>%
  data_set(events) %>%
  idata_set(pop_data) %>%
  carry_out(amt, cmt, evid, DOSE, TRT, DOSE_GROUP) %>%
  mrgsim(end = 12*7*24, delta = 1) %>%
  as_tibble()

# Add residual error to PK concentrations
sim_data <- sim_data %>%
  mutate(
    # Proportional error model (30% CV)
    CP_obs = ifelse(evid == 0 & cmt == 2, 
                   pmax(0, CP * exp(rnorm(n(), 0, 0.3))), 
                   CP),
    # Add measurement error to PD endpoints
    TARC_obs = ifelse(evid == 0 & time %in% pd_times,
                     pmax(10, TARC * exp(rnorm(n(), 0, 0.2))),
                     TARC),
    EASI_obs = ifelse(evid == 0 & time %in% pd_times,
                     pmax(0, EASI + rnorm(n(), 0, 1)),
                     EASI)
  )

# Create SDTM PC (Pharmacokinetic Concentrations) dataset
pc_data <- sim_data %>%
  filter(evid == 0, cmt == 2, time %in% pk_times) %>%
  mutate(
    STUDYID = "DK-201",
    DOMAIN = "PC",
    USUBJID = paste0("DK201-", sprintf("%03d", ID)),
    PCSEQ = row_number(),
    PCTESTCD = "DERMA",
    PCTEST = "Dermakinib",
    PCORRES = as.character(round(CP_obs, 2)),
    PCORRESU = "ng/mL",
    PCSTRESC = PCORRES,
    PCSTRESN = CP_obs,
    PCSTRESU = "ng/mL",
    VISITNUM = case_when(
      time == 0 ~ 1,
      time <= 24 ~ 2,
      time <= 168 ~ 3,
      time <= 336 ~ 4,
      time <= 504 ~ 5,
      time <= 672 ~ 6,
      time <= 840 ~ 7,
      time <= 1344 ~ 8,
      time <= 1680 ~ 9,
      TRUE ~ 10
    ),
    VISIT = paste("Week", ceiling(time/(7*24))),
    PCDTC = as.character(as.Date("2024-01-01") + time/24),
    PCDY = ceiling(time/24),
    PCTPT = case_when(
      time %% 24 == 0 ~ "Pre-dose",
      time %% 24 == 2 ~ "2h post-dose", 
      time %% 24 == 4 ~ "4h post-dose",
      TRUE ~ "Other"
    ),
    PCTPTNUM = time %% 24,
    PCBLFL = ifelse(time == 0, "Y", "N")
  ) %>%
  select(STUDYID, DOMAIN, USUBJID, PCSEQ, PCTESTCD, PCTEST, PCORRES, PCORRESU,
         PCSTRESC, PCSTRESN, PCSTRESU, VISITNUM, VISIT, PCDTC, PCDY, 
         PCTPT, PCTPTNUM, PCBLFL)

# Create SDTM PP (Pharmacodynamic Parameters) dataset for biomarkers
pp_data <- sim_data %>%
  filter(evid == 0, time %in% pd_times) %>%
  select(ID, time, TARC_obs, EASI_obs, DOSE, TRT) %>%
  pivot_longer(cols = c(TARC_obs, EASI_obs), names_to = "PARAM", values_to = "VALUE") %>%
  mutate(
    STUDYID = "DK-201",
    DOMAIN = "PP",
    USUBJID = paste0("DK201-", sprintf("%03d", ID)),
    PPSEQ = row_number(),
    PPTESTCD = case_when(
      PARAM == "TARC_obs" ~ "TARC",
      PARAM == "EASI_obs" ~ "EASI"
    ),
    PPTEST = case_when(
      PARAM == "TARC_obs" ~ "TARC/CCL17",
      PARAM == "EASI_obs" ~ "EASI Score"
    ),
    PPCAT = case_when(
      PARAM == "TARC_obs" ~ "BIOMARKER",
      PARAM == "EASI_obs" ~ "EFFICACY"
    ),
    PPORRES = as.character(round(VALUE, 2)),
    PPORRESU = case_when(
      PARAM == "TARC_obs" ~ "pg/mL",
      PARAM == "EASI_obs" ~ "Score"
    ),
    PPSTRESC = PPORRES,
    PPSTRESN = VALUE,
    PPSTRESU = PPORRESU,
    VISITNUM = ceiling(time/(7*24)) + 1,
    VISIT = ifelse(time == 0, "Baseline", paste("Week", ceiling(time/(7*24)))),
    PPDTC = as.character(as.Date("2024-01-01") + time/24),
    PPDY = ceiling(time/24),
    PPBLFL = ifelse(time == 0, "Y", "N")
  ) %>%
  select(STUDYID, DOMAIN, USUBJID, PPSEQ, PPTESTCD, PPTEST, PPCAT, 
         PPORRES, PPORRESU, PPSTRESC, PPSTRESN, PPSTRESU, 
         VISITNUM, VISIT, PPDTC, PPDY, PPBLFL)

# Create SDTM DM (Demographics) dataset
dm_data <- pop_data %>%
  mutate(
    STUDYID = "DK-201",
    DOMAIN = "DM",
    USUBJID = paste0("DK201-", sprintf("%03d", ID)),
    SUBJID = sprintf("%03d", ID),
    RFSTDTC = "2024-01-01",
    RFENDTC = as.character(as.Date("2024-01-01") + 84),  # 12 weeks
    RFXSTDTC = "2024-01-01",
    RFXENDTC = as.character(as.Date("2024-01-01") + 84),
    RFICDTC = "2024-01-01",
    RFPENDTC = as.character(as.Date("2024-01-01") + 84),
    DTHDTC = "",
    DTHFL = "N",
    SITEID = "001",
    INVID = "INV001",
    INVNAM = "Principal Investigator",
    BRTHDTC = as.character(as.Date("2024-01-01") - AGE*365.25),
    AGEU = "YEARS",
    SEX = ifelse(SEX == 1, "F", "M"),
    RACE = "WHITE",
    ETHNIC = "NOT HISPANIC OR LATINO",
    ARMCD = paste0("ARM", DOSE_GROUP),
    ARM = TRT,
    ACTARMCD = paste0("ARM", DOSE_GROUP),
    ACTARM = TRT,
    COUNTRY = "USA",
    DMDTC = "2024-01-01",
    DMDY = 1
  ) %>%
  select(STUDYID, DOMAIN, USUBJID, SUBJID, RFSTDTC, RFENDTC, RFXSTDTC, RFXENDTC,
         RFICDTC, RFPENDTC, DTHDTC, DTHFL, SITEID, INVID, INVNAM, BRTHDTC,
         AGE, AGEU, SEX, RACE, ETHNIC, ARMCD, ARM, ACTARMCD, ACTARM, 
         COUNTRY, DMDTC, DMDY)

# Create SDTM EX (Exposure) dataset
ex_data <- dosing %>%
  filter(evid == 1) %>%
  left_join(pop_data %>% select(ID, TRT, DOSE_GROUP), by = "ID") %>%
  mutate(
    STUDYID = "DK-201",
    DOMAIN = "EX",
    USUBJID = paste0("DK201-", sprintf("%03d", ID)),
    EXSEQ = row_number(),
    EXTRT = TRT,
    EXDOSE = DOSE,
    EXDOSU = "mg",
    EXDOSFRM = "TABLET",
    EXDOSFRQ = "QD",
    EXROUTE = "ORAL",
    VISITNUM = ceiling(time/(7*24)) + 1,
    VISIT = ifelse(time == 0, "Day 1", paste("Week", ceiling(time/(7*24)))),
    EXSTDTC = as.character(as.Date("2024-01-01") + time/24),
    EXSTTM = "08:00",
    EXENDTC = as.character(as.Date("2024-01-01") + time/24),
    EXENDTM = "08:00",
    EXSTDY = ceiling(time/24) + 1,
    EXENDY = ceiling(time/24) + 1
  ) %>%
  select(STUDYID, DOMAIN, USUBJID, EXSEQ, EXTRT, EXDOSE, EXDOSU, EXDOSFRM,
         EXDOSFRQ, EXROUTE, VISITNUM, VISIT, EXSTDTC, EXSTTM, EXENDTC, 
         EXENDTM, EXSTDY, EXENDY)

# Save datasets
write.csv(pc_data, "data/pc.csv", row.names = FALSE, na = "")
write.csv(pp_data, "data/pp.csv", row.names = FALSE, na = "")
write.csv(dm_data, "data/dm.csv", row.names = FALSE, na = "")
write.csv(ex_data, "data/ex.csv", row.names = FALSE, na = "")

# Create summary statistics
cat("=== DERMAKINIB PHASE 2 SIMULATION SUMMARY ===\n")
cat("Study: DK-201 - Population PK/PD Analysis\n")
cat("Subjects:", n_subjects, "\n")
cat("Dose Groups:", paste(dose_groups, "mg QD", collapse = ", "), "\n")
cat("Study Duration: 12 weeks\n")
cat("PK Samples:", nrow(pc_data), "\n")
cat("PD Observations:", nrow(pp_data), "\n\n")

# Summary by dose group
dose_summary <- sim_data %>%
  filter(time == 2016, evid == 0) %>%  # Week 12 data
  group_by(DOSE) %>%
  summarise(
    N = n(),
    CP_mean = mean(CP_obs, na.rm = TRUE),
    CP_sd = sd(CP_obs, na.rm = TRUE),
    TARC_mean = mean(TARC_obs, na.rm = TRUE),
    TARC_reduction = mean((1000 - TARC_obs)/1000 * 100, na.rm = TRUE),
    EASI_mean = mean(EASI_obs, na.rm = TRUE),
    EASI_reduction = mean((25 - EASI_obs)/25 * 100, na.rm = TRUE),
    .groups = 'drop'
  )

print(dose_summary)

cat("\nDatasets saved to /data folder:\n")
cat("- pc.csv: Pharmacokinetic concentrations (SDTM PC domain)\n")
cat("- pp.csv: Pharmacodynamic parameters (SDTM PP domain)\n") 
cat("- dm.csv: Demographics (SDTM DM domain)\n")
cat("- ex.csv: Exposure/dosing (SDTM EX domain)\n")

cat("\nSimulation completed successfully!\n")