# Clinical Trial Simulation for Glucamax Phase 2 Dose-Finding Study
# Population PK/PD Analysis using mrgsolve

library(mrgsolve)
library(dplyr)
library(ggplot2)
library(tidyr)
library(lubridate)

# Set seed for reproducibility
set.seed(12345)

# Define mrgsolve model for Glucamax PK/PD
code <- '
$PARAM @annotated
TVCL   : 10    : Typical clearance (L/h)
TVV2   : 50    : Typical central volume (L)
TVQ    : 5     : Typical intercompartmental clearance (L/h)
TVV3   : 100   : Typical peripheral volume (L)
TVKA   : 1.5   : Typical absorption rate constant (1/h)
ALAG1  : 0.5   : Absorption lag time (h)

// Covariate effects
CLCR_CL : -0.5  : Creatinine clearance effect on CL
WT_CL   : 0.75  : Weight effect on CL
AGE_CL  : -0.3  : Age effect on CL
WT_V2   : 1.0   : Weight effect on V2

// PD parameters
TVKIN  : 0.1   : HbA1c production rate (1/week)
TVKOUT : 0.1   : HbA1c elimination rate (1/week)
TVIC50 : 50    : Concentration for 50% max effect (ng/mL)
TVIMAX : 0.8   : Maximum inhibition of HbA1c production
TVHBA1C0: 8.5  : Baseline HbA1c (%)
PROG   : 0.002 : Disease progression rate (1/week)

$PARAM @annotated
// Individual covariates (will be set for each subject)
CLCR : 90   : Creatinine clearance (mL/min)
WT   : 80   : Weight (kg)
AGE  : 55   : Age (years)
HBA1C0: 8.5 : Baseline HbA1c (%)

$CMT @annotated
DEPOT  : Dosing compartment
CENT   : Central compartment (ng/mL)
PERIPH : Peripheral compartment
HBA1C  : HbA1c response compartment

$OMEGA @annotated @block
ETA_CL : 0.09 : IIV on CL
ETA_V2 : 0.01 0.04 : IIV on V2
ETA_KA : 0.0 0.0 0.16 : IIV on KA
ETA_IC50: 0.0 0.0 0.0 0.25 : IIV on IC50

$SIGMA @annotated
PROP_PK : 0.04 : Proportional error PK
ADD_PK  : 1.0  : Additive error PK (ng/mL)
PROP_PD : 0.01 : Proportional error PD

$MAIN
// Individual PK parameters with covariate effects
double CL = TVCL * pow(WT/80, WT_CL) * pow(CLCR/90, CLCR_CL) * 
            pow(AGE/55, AGE_CL) * exp(ETA(1));
double V2 = TVV2 * pow(WT/80, WT_V2) * exp(ETA(2));
double Q  = TVQ;
double V3 = TVV3;
double KA = TVKA * exp(ETA(3));

// Individual PD parameters
double KIN = TVKIN;
double KOUT = TVKOUT;
double IC50 = TVIC50 * exp(ETA(4));
double IMAX = TVIMAX;

// Initial conditions
HBA1C_0 = HBA1C0;

$ODE
// PK equations (2-compartment with first-order absorption)
dxdt_DEPOT = -KA * DEPOT;
dxdt_CENT = KA * DEPOT - (CL/V2) * CENT - (Q/V2) * CENT + (Q/V3) * PERIPH;
dxdt_PERIPH = (Q/V2) * CENT - (Q/V3) * PERIPH;

// PD equation (indirect response with disease progression)
double CONC = CENT;
double INHIB = (IMAX * CONC) / (IC50 + CONC);
dxdt_HBA1C = KIN * (1 + PROG * SOLVERTIME/168) * (1 - INHIB) - KOUT * HBA1C;

$TABLE
double CP = CENT;
double HBA1C_PRED = HBA1C;

// Add residual error
double IPRED_PK = CP;
double DV_PK = IPRED_PK * (1 + PROP_PK * EPS(1)) + ADD_PK * EPS(2);
if(DV_PK < 0) DV_PK = 0;

double IPRED_PD = HBA1C_PRED;
double DV_PD = IPRED_PD * (1 + PROP_PD * EPS(3));

$CAPTURE @annotated
CP     : Plasma concentration (ng/mL)
DV_PK  : Observed PK concentration (ng/mL)
HBA1C_PRED : Predicted HbA1c (%)
DV_PD  : Observed HbA1c (%)
CL     : Individual clearance (L/h)
V2     : Individual central volume (L)
'

# Compile the model
mod <- mcode("glucamax", code)

# Generate patient population
n_subjects <- 240
dose_groups <- c(25, 50, 100, 200)  # mg doses
n_per_group <- n_subjects / length(dose_groups)

# Create covariate distributions for Type 2 diabetes patients
set.seed(123)
covariates <- data.frame(
  ID = 1:n_subjects,
  DOSE = rep(dose_groups, each = n_per_group),
  AGE = pmax(18, pmin(80, rnorm(n_subjects, 58, 12))),
  WT = pmax(50, pmin(150, rnorm(n_subjects, 85, 18))),
  SEX = sample(c(0, 1), n_subjects, replace = TRUE, prob = c(0.45, 0.55)),
  RACE = sample(c(1, 2, 3), n_subjects, replace = TRUE, prob = c(0.7, 0.15, 0.15)),
  HBA1C0 = pmax(6.5, pmin(12, rnorm(n_subjects, 8.2, 1.2))),
  DIAB_DUR = pmax(0.5, pmin(25, rlnorm(n_subjects, 1.8, 0.8))),
  stringsAsFactors = FALSE
)

# Calculate derived covariates
covariates$BMI <- covariates$WT / (1.75^2)  # Assuming average height 1.75m
covariates$CLCR <- pmax(30, 140 - covariates$AGE) * covariates$WT / 72  # Cockcroft-Gault
# Fix the vectorized condition for female adjustment
covariates$CLCR <- ifelse(covariates$SEX == 0, covariates$CLCR * 0.85, covariates$CLCR)

# Create dosing events (once daily for 12 weeks)
dosing_events <- expand.grid(
  ID = 1:n_subjects,
  time = seq(0, 12*7*24, by = 24),  # Daily dosing for 12 weeks (hours)
  stringsAsFactors = FALSE
) %>%
  left_join(covariates[c("ID", "DOSE")], by = "ID") %>%
  mutate(
    evid = 1,
    cmt = 1,
    amt = DOSE * 1000,  # Convert mg to μg
    addl = 0,
    ii = 0,
    ss = 0
  )

# Create PK sampling times (sparse sampling design)
pk_times <- c(1, 2, 4, 8, 24)  # Hours post-dose
pk_visits <- c(1, 2, 4, 8, 12)  # Weeks

pk_sampling <- expand.grid(
  ID = 1:n_subjects,
  WEEK = pk_visits,
  PK_TIME = pk_times,
  stringsAsFactors = FALSE
) %>%
  mutate(
    time = WEEK * 7 * 24 + PK_TIME,  # Convert to hours
    evid = 0,
    cmt = 2,
    amt = 0,
    SAMPLE_TYPE = "PK"
  ) %>%
  filter(time <= 12*7*24)  # Only within study period

# Create PD sampling times (weekly HbA1c measurements)
pd_sampling <- expand.grid(
  ID = 1:n_subjects,
  WEEK = c(0, 2, 4, 6, 8, 10, 12),
  stringsAsFactors = FALSE
) %>%
  mutate(
    time = WEEK * 7 * 24,
    evid = 0,
    cmt = 4,
    amt = 0,
    SAMPLE_TYPE = "PD"
  )

# Combine all events
all_events <- bind_rows(
  dosing_events %>% select(ID, time, evid, cmt, amt, addl, ii, ss),
  pk_sampling %>% select(ID, time, evid, cmt, amt),
  pd_sampling %>% select(ID, time, evid, cmt, amt)
) %>%
  arrange(ID, time, evid) %>%
  left_join(covariates, by = "ID")

# Run simulation
sim_data <- mod %>%
  data_set(all_events) %>%
  carry_out(ID, DOSE, AGE, WT, SEX, RACE, HBA1C0, DIAB_DUR, BMI, CLCR, evid, cmt) %>%
  mrgsim(end = 12*7*24, delta = 1, digits = 3)

# Convert to data frame and process
sim_df <- as.data.frame(sim_data)

# Create SDTM-formatted datasets

# Demographics (DM)
dm <- covariates %>%
  mutate(
    STUDYID = "GCX-201",
    DOMAIN = "DM",
    USUBJID = paste0("GCX-201-", sprintf("%03d", ID)),
    SUBJID = as.character(ID),
    RFSTDTC = "2024-01-15",  # Reference start date
    RFENDTC = "2024-04-15",  # Reference end date
    SITEID = sprintf("%02d", ((ID-1) %/% 20) + 1),
    AGE = round(AGE),
    AGEU = "YEARS",
    SEX = ifelse(SEX == 1, "M", "F"),
    RACE = case_when(
      RACE == 1 ~ "WHITE",
      RACE == 2 ~ "BLACK OR AFRICAN AMERICAN",
      RACE == 3 ~ "ASIAN"
    ),
    ARMCD = paste0("ARM", match(DOSE, dose_groups)),
    ARM = paste0("Glucamax ", DOSE, " mg"),
    ACTARMCD = ARMCD,
    ACTARM = ARM
  ) %>%
  select(STUDYID, DOMAIN, USUBJID, SUBJID, RFSTDTC, RFENDTC, SITEID, 
         AGE, AGEU, SEX, RACE, ARMCD, ARM, ACTARMCD, ACTARM)

# Exposure (EX)
ex <- dosing_events %>%
  filter(time <= 12*7*24) %>%
  mutate(
    STUDYID = "GCX-201",
    DOMAIN = "EX",
    USUBJID = paste0("GCX-201-", sprintf("%03d", ID)),
    EXSEQ = row_number(),
    EXTRT = paste0("Glucamax ", DOSE, " mg"),
    EXDOSE = DOSE,
    EXDOSU = "mg",
    EXDOSFRM = "TABLET",
    EXROUTE = "ORAL",
    VISITNUM = ceiling(time / (7*24)) + 1,
    EXSTDTC = as.character(as.Date("2024-01-15") + round(time/24)),
    EXENDTC = EXSTDTC
  ) %>%
  select(STUDYID, DOMAIN, USUBJID, EXSEQ, EXTRT, EXDOSE, EXDOSU, 
         EXDOSFRM, EXROUTE, VISITNUM, EXSTDTC, EXENDTC)

# Pharmacokinetics (PC) - Fixed date calculation
pc <- sim_df %>%
  filter(evid == 0, cmt == 2, time > 0) %>%
  mutate(
    STUDYID = "GCX-201",
    DOMAIN = "PC",
    USUBJID = paste0("GCX-201-", sprintf("%03d", ID)),
    PCSEQ = row_number(),
    PCTESTCD = "GLUCAMAX",
    PCTEST = "Glucamax",
    PCORRES = round(DV_PK, 2),
    PCORRESU = "ng/mL",
    PCSTRESC = as.character(PCORRES),
    PCSTRESN = PCORRES,
    PCSTRESU = "ng/mL",
    VISITNUM = ceiling(time / (7*24)) + 1,
    PCDTC = as.character(as.Date("2024-01-15") + round(time/24)),
    PCTPT = paste0(round(time %% 24), "H POST-DOSE"),
    PCELTM = time %% 24
  ) %>%
  select(STUDYID, DOMAIN, USUBJID, PCSEQ, PCTESTCD, PCTEST, PCORRES, 
         PCORRESU, PCSTRESC, PCSTRESN, PCSTRESU, VISITNUM, PCDTC, PCTPT, PCELTM)

# Laboratory Data - HbA1c (LB) - Fixed date calculation
lb <- sim_df %>%
  filter(evid == 0, cmt == 4) %>%
  mutate(
    STUDYID = "GCX-201",
    DOMAIN = "LB",
    USUBJID = paste0("GCX-201-", sprintf("%03d", ID)),
    LBSEQ = row_number(),
    LBTESTCD = "HBA1C",
    LBTEST = "Hemoglobin A1c",
    LBORRES = round(DV_PD, 1),
    LBORRESU = "%",
    LBSTRESC = as.character(LBORRES),
    LBSTRESN = LBORRES,
    LBSTRESU = "%",
    VISITNUM = ceiling(time / (7*24)) + 1,
    LBDTC = as.character(as.Date("2024-01-15") + round(time/24)),
    LBBLFL = ifelse(time == 0, "Y", "N")
  ) %>%
  select(STUDYID, DOMAIN, USUBJID, LBSEQ, LBTESTCD, LBTEST, LBORRES, 
         LBORRESU, LBSTRESC, LBSTRESN, LBSTRESU, VISITNUM, LBDTC, LBBLFL)

# Vital Signs - Weight (VS)
vs <- covariates %>%
  mutate(
    STUDYID = "GCX-201",
    DOMAIN = "VS",
    USUBJID = paste0("GCX-201-", sprintf("%03d", ID)),
    VSSEQ = 1,
    VSTESTCD = "WEIGHT",
    VSTEST = "Weight",
    VSORRES = round(WT, 1),
    VSORRESU = "kg",
    VSSTRESC = as.character(VSORRES),
    VSSTRESN = VSORRES,
    VSSTRESU = "kg",
    VISITNUM = 1,
    VSDTC = "2024-01-15",
    VSBLFL = "Y"
  ) %>%
  select(STUDYID, DOMAIN, USUBJID, VSSEQ, VSTESTCD, VSTEST, VSORRES, 
         VSORRESU, VSSTRESC, VSSTRESN, VSSTRESU, VISITNUM, VSDTC, VSBLFL)

# Save datasets
write.csv(dm, "dm.csv", row.names = FALSE)
write.csv(ex, "ex.csv", row.names = FALSE)
write.csv(pc, "pc.csv", row.names = FALSE)
write.csv(lb, "lb.csv", row.names = FALSE)
write.csv(vs, "vs.csv", row.names = FALSE)

# Generate summary plots
# PK concentration-time profiles by dose
pk_plot <- sim_df %>%
  filter(evid == 0, cmt == 2, time > 0, time <= 7*24) %>%
  ggplot(aes(x = time, y = CP, color = factor(DOSE))) +
  geom_line(aes(group = interaction(ID, DOSE)), alpha = 0.3) +
  stat_summary(fun = median, geom = "line", size = 1.2) +
  scale_y_log10() +
  labs(title = "Glucamax PK Profiles by Dose Group",
       x = "Time (hours)", y = "Concentration (ng/mL)",
       color = "Dose (mg)") +
  theme_minimal()

# HbA1c time course by dose
pd_plot <- sim_df %>%
  filter(evid == 0, cmt == 4) %>%
  ggplot(aes(x = time/(7*24), y = HBA1C_PRED, color = factor(DOSE))) +
  geom_line(aes(group = interaction(ID, DOSE)), alpha = 0.3) +
  stat_summary(fun = median, geom = "line", size = 1.2) +
  labs(title = "HbA1c Time Course by Dose Group",
       x = "Time (weeks)", y = "HbA1c (%)",
       color = "Dose (mg)") +
  theme_minimal()

# Print plots
print(pk_plot)
print(pd_plot)

# Print summary statistics
cat("Simulation Summary:\n")
cat("Number of subjects:", n_subjects, "\n")
cat("Dose groups:", paste(dose_groups, "mg", collapse = ", "), "\n")
cat("Study duration: 12 weeks\n")
cat("PK samples per subject:", nrow(pk_sampling)/n_subjects, "\n")
cat("PD samples per subject:", nrow(pd_sampling)/n_subjects, "\n")

# Summary of generated datasets
cat("\nGenerated SDTM datasets:\n")
cat("DM (Demographics):", nrow(dm), "records\n")
cat("EX (Exposure):", nrow(ex), "records\n")
cat("PC (Pharmacokinetics):", nrow(pc), "records\n")
cat("LB (Laboratory - HbA1c):", nrow(lb), "records\n")
cat("VS (Vital Signs - Weight):", nrow(vs), "records\n")

cat("\nFiles saved: dm.csv, ex.csv, pc.csv, lb.csv, vs.csv\n")