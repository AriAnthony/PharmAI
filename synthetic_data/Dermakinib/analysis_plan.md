# Population PK/PD Analysis Plan for Dermakinib in Atopic Dermatitis

## Title Page

* **Study Title:** Population Pharmacokinetic/Pharmacodynamic Analysis of Dermakinib in Patients with Atopic Dermatitis: Phase 2 Dose-Finding Study
* **Compound:** Dermakinib (selective JAK1 inhibitor)
* **Plan Version:** Version 1.0
* **Date:** [Insert Date]
* **Author:** [Name(s) and Affiliation]

## Introduction and Background

Dermakinib is a selective JAK1 inhibitor being developed for the treatment of moderate-to-severe atopic dermatitis. JAK1 inhibition blocks key inflammatory pathways including IL-4, IL-13, and IL-31 signaling that drive the pathophysiology of atopic dermatitis. This population PK/PD analysis supports the Phase 2 dose-finding program by characterizing the exposure-response relationships for efficacy and safety endpoints.

The purpose of this PopPK/PKPD analysis is to: (1) support dose selection for Phase 3 studies, (2) identify patient subpopulations that may require dose adjustments, and (3) characterize the therapeutic window relative to the competitive landscape, particularly Dupixent (dupilumab). Prior preclinical data suggest dose-proportional PK with moderate inter-individual variability, and early clinical data indicate potential for once-daily dosing.

Population PK analysis is a well-established quantitative method that can explain variability in drug concentrations among individuals and support regulatory decision-making for dose optimization in atopic dermatitis patients.

## Analysis Objectives

### Primary Objectives

* **Characterize the population PK profile** of Dermakinib in atopic dermatitis patients, including typical clearance, volume of distribution, and absorption parameters
* **Identify statistically and clinically significant covariates** affecting PK parameters, with emphasis on disease-related factors (disease severity, concomitant treatments) and patient demographics
* **Estimate inter-individual and inter-occasion variability** in PK parameters to support individualized dosing strategies

### Secondary Objectives

* **Assess exposure-response relationships** for key efficacy endpoints (EASI score reduction, IGA response, pruritus NRS) and safety endpoints (laboratory abnormalities, infections)
* **Develop PK/PD models** linking Dermakinib exposure to pharmacodynamic biomarkers (TARC/CCL17, IL-31) and clinical outcomes
* **Perform simulations** to optimize dosing regimens for Phase 3, including evaluation of alternative dosing frequencies and dose levels
* **Evaluate exposure-response relationships** in clinically relevant subpopulations (disease severity, age groups, concomitant topical therapy use)

## Data Sources

### Clinical Study Data

* **Included Studies:** 
  - Study DK-101 (Phase 1, SAD/MAD in healthy volunteers, n=72, intensive PK sampling)
  - Study DK-201 (Phase 2 dose-finding in moderate-to-severe atopic dermatitis patients, n=240, sparse PK sampling with rich PD assessments)
* **Data Characteristics:** Pooled dataset with approximately 312 subjects and ~2,500 PK observations. Phase 1 data provide intensive sampling (0-72h post-dose), while Phase 2 provides sparse sampling (pre-dose, 2-4h post-dose) over 12 weeks of treatment.

### Analysis Dataset Specifications

* **Dataset Structure:** NONMEM-compatible dataset including subject ID, time, concentration, dosing records, and covariates. Concentration units in ng/mL, time in hours post-first dose.
* **Handling of BLOQ and Missing Data:** BLOQ values (LLOQ = 1 ng/mL) handled using M3 method. Missing covariate data imputed using median (continuous) or mode (categorical) with sensitivity analysis.
* **Outlier and Exclusion Rules:** Suspected outlier observations (IWRES > 4 or studentized residuals > 4) will be flagged and assessed for impact. Protocol deviations affecting PK (missed doses >24h, incorrect timing) will be documented but included with appropriate flags.

## Software and Computing Environment

### Primary Modeling Software

* **NONMEM** version 7.5.1 with FOCEI estimation method for population PK modeling
* **Monolix** version 2023R1 for alternative PK/PD modeling approaches and diagnostics

### Post-processing and Visualization Software

* **R** version 4.3.0 with packages: `tidyverse`, `ggplot2`, `xgxr`, `vpc`, `pmxTools`
* **Perl-speaks-NONMEM (PsN)** version 5.3.0 for bootstrap, VPC, and covariate analysis
* **Pirana** version 23.0 for model management and execution

### Version Control and Environment Details

* **Git** repository for version control of analysis code and documentation
* **Linux** computing cluster environment with R and NONMEM installations

## Analysis Methods

### 6.1 Exploratory Data Analysis (EDA)

* **Descriptive Summaries:** Generate concentration-time profiles by dose level, study population, and key covariates. Summarize demographic and disease characteristics.
* **Trend and Covariate Plots:** Plot concentrations and derived PK metrics (AUC, Cmax) against potential covariates including age, weight, BMI, disease severity (baseline EASI), concomitant topical corticosteroid use, and renal function.
* **PD Endpoint Exploration:** Examine time course of efficacy endpoints (EASI, IGA, pruritus NRS) and biomarkers (TARC, IL-31) by dose group and explore relationships with PK metrics.
* **Outlier Detection:** Identify aberrant concentration values and assess impact on population estimates.

### 6.2 Structural Model Development

* **Base Model Selection:** Test 1- and 2-compartment models with first-order absorption and elimination. Consider absorption lag time and mixed zero/first-order absorption based on formulation characteristics.
* **Model Building Strategy:** Start with simplest adequate model, add complexity based on data support and biological plausibility. Evaluate transit compartment absorption if delayed/prolonged absorption observed.
* **Allometric Scaling:** Implement allometric scaling for clearance and volume parameters using body weight with fixed exponents (0.75 for CL, 1.0 for V).

### 6.3 Inter-Individual Variability Model

* **Random Effects Specification:** Include IIV on clearance, central volume, and absorption rate constant assuming log-normal distributions.
* **Covariance Structure:** Estimate covariance between CL and V parameters; assess need for additional covariances based on data support.
* **Shrinkage Consideration:** Monitor ETA-shrinkage; if >30% for key parameters, limit use of EBEs in exposure-response analyses.

### 6.4 Covariate Model Development

* **Covariate Selection Strategy:** Test clinically relevant covariates:
  - Demographics: age, weight, sex, race
  - Disease-related: baseline EASI score, disease duration, atopic comorbidities
  - Concomitant medications: topical corticosteroids, topical calcineurin inhibitors, antihistamines
  - Organ function: creatinine clearance, hepatic function markers
* **Screening and Modeling Approach:** Stepwise forward addition (α=0.01) and backward elimination (α=0.001) with clinical relevance assessment.
* **Clinical Relevance Criteria:** Covariate effects causing >25% change in AUC or Cmax over the covariate range will be considered clinically relevant for this therapeutic area.

### 6.5 Residual Unexplained Variability Model

* **Error Model:** Test proportional, additive, and combined error models. Expect proportional error to dominate given concentration range.
* **Modeling Approach:** Select based on objective function improvement, parameter precision, and residual diagnostic plots.

## PK/PD Model Development

### 7.1 Exposure Metrics

* **Primary Exposure Metrics:** Steady-state AUC24 and average concentration (Cavg) as primary drivers of JAK1 inhibition
* **Secondary Metrics:** Cmax and Cmin for assessment of peak-related safety and trough efficacy relationships

### 7.2 PD Endpoints and Biomarkers

* **Efficacy Endpoints:** 
  - EASI score (continuous and categorical response ≥75% improvement)
  - IGA response (clear/almost clear)
  - Pruritus NRS reduction
* **Biomarkers:** TARC/CCL17, IL-31, and other Th2-related inflammatory markers
* **Safety Endpoints:** Laboratory abnormalities (lymphocyte count, liver enzymes), infection rates

### 7.3 PK/PD Model Structure

* **Efficacy Models:** Emax or sigmoid Emax models relating exposure to efficacy endpoints, accounting for disease progression and placebo response
* **Safety Models:** Logistic regression for categorical safety endpoints, linear or Emax models for continuous laboratory parameters
* **Time Course:** Incorporate appropriate delay/turnover models for biomarkers with known kinetics

## Model Evaluation and Validation

### 8.1 Goodness-of-Fit Criteria

* **Graphical Diagnostics:** Standard GOF plots including DV vs PRED/IPRED, residuals vs time/predictions, ETA distributions, and stratified plots by dose and key covariates
* **Numerical Metrics:** Report OFV, parameter RSE, condition number, and shrinkage values
* **PK/PD Specific Diagnostics:** Exposure-response plots with confidence intervals, observed vs predicted response rates

### 8.2 Model Qualification Techniques

* **Visual Predictive Checks:** Perform VPC for PK data stratified by dose and study. Conduct prediction-corrected VPC for PD endpoints
* **Bootstrap Analysis:** 1000 bootstrap runs to assess parameter uncertainty and generate confidence intervals
* **Cross-validation:** Assess model performance using data-splitting approach (70% training, 30% validation)

## Simulation Plan

* **Simulation Objectives:** 
  - Predict exposures and responses for alternative dosing regimens (QD vs BID, different dose levels)
  - Assess dose requirements in special populations (elderly, renal impairment)
  - Evaluate probability of achieving target efficacy (EASI75 response) while maintaining acceptable safety profile
* **Simulation Design:** 
  - Virtual populations (n=1000 per scenario) representing Phase 3 target population
  - Dose levels: 50, 100, 200, 400 mg QD and 100, 200 mg BID
  - 12-week treatment duration with steady-state assessments
* **Outcome Metrics:** AUC24ss, Cmax,ss, Cmin,ss, probability of EASI75 response, probability of Grade 3+ laboratory abnormalities

## Reporting and Deliverables

* **Final Report:** Comprehensive population PK/PD report with executive summary, detailed methodology, results, and dose recommendations for Phase 3
* **Analysis Plan Document:** This prospectively written plan with documentation of any deviations
* **Model Code and Datasets:** Complete NONMEM control streams, R analysis scripts, and final analysis datasets
* **Model Development Log:** Summary table of model building steps, OFV changes, and key decisions
* **Regulatory Submission Package:** Model files and documentation formatted for regulatory submission requirements

## References

* FDA Guidance for Industry: Population Pharmacokinetics (2022)
* EMA Guideline on Reporting the Results of Population Pharmacokinetic Analyses (2007)
* ICH M15 Guideline on Pharmacokinetics in Special Populations (2023)
* Relevant JAK inhibitor and atopic dermatitis literature