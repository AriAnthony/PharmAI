# Population PK/PD Analysis Plan Template

## Title Page

* **Study Title:** *\[Insert Study Title]*
* **Compound:** *\[Insert Compound Name/Identifier]*
* **Plan Version:** *\[e.g., Version 1.0]*
* **Date:** *\[Insert Date]*
* **Author:** *\[Name(s) and Affiliation]*

*(Include basic identifying information for the analysis plan.)*

## Introduction and Background

Provide a concise summary of the drug and development context, including mechanism of action, therapeutic area, and clinical trial phase. Describe the purpose of the PopPK/PKPD analysis, linking it to the overall drug development plan (e.g. dose justification, labeling support). Summarize prior knowledge (literature and preclinical/early clinical data) relevant to pharmacokinetics and pharmacodynamics. For example, the FDA notes that *“population PK analysis is a well-established, quantitative method that can explain variability in drug concentrations among individuals”*, and recommends clearly stating why the analysis is being performed.  Early alignment of analysis objectives with stakeholders is crucial.

## Analysis Objectives

### Primary Objectives

* Clearly state the main goals of the analysis, e.g. **characterize the population PK profile** (typical clearance and volume), **identify statistically and clinically significant covariates** on PK parameters, and **estimate inter-individual variability**.
* Example: *“To develop a PopPK model of \[Drug] that describes the central tendency and variability of PK parameters across the target population.”*

*(Regulatory guidance stresses that the analysis objectives should be prespecified in the plan.)*

### Secondary Objectives

* List additional aims, such as **exposure–response analyses for safety or efficacy endpoints**, **simulations for dose selection or patient subpopulations**, or **prediction of exposures under untested regimens**.
* Example: *“To assess the relationship between drug exposure and key PD biomarkers or safety outcomes.”*

*(Secondary objectives may include performing simulations (e.g. for pediatric or renal impairment dosing) or generating individual exposure metrics for further analyses.)*

## Data Sources

### Clinical Study Data

* **Included Studies:** List all relevant studies (study IDs, phase, population, design). For each study, briefly describe the design (single/multiple dose, intensive vs. sparse sampling, patient demographics, and any covariate-enriched arms). For example, *“Data from Study 101 (Phase 1, SAD/MAD in healthy volunteers) and Study 201 (Phase 2 in patients with \[disease]) will be pooled.”*
* **Data Characteristics:** Summarize sample sizes (number of subjects and observations) and sampling density. Indicate if data are pooled across studies or stratified.

*(Guidelines recommend documenting the study context for the data sources, including the number of subjects and sampling scheme.)*

### Analysis Dataset Specifications

* **Dataset Structure:** Describe the analysis dataset(s) to be used (e.g. NONMEM or CDISC format), including key variables (ID, time, concentration, dosing records, covariates). Specify any data transformations or units.
* **Handling of BLOQ (below LLOQ) and Missing Data:** Define how values below the limit of quantification will be handled (e.g. M3 method, substitution) and how missing data (in PK or covariates) are addressed.
* **Outlier and Exclusion Rules:** Specify criteria for identifying outlier records or subjects (e.g. normalized weighted residual > 5) and handling rules. Any exclusion or imputation strategy for outliers or missing covariates should be prespecified. For example, *“Suspected outlier observations (e.g. IWRES > 5) will be flagged; influence of such points will be assessed with and without their inclusion”*.

*(As recommended, include data cleaning procedures. EMA guidance notes the plan should cover handling of missing/outlier data. FDA similarly advises prespecifying outlier rules in the analysis plan.)*

## Software and Computing Environment

### Primary Modeling Software

* List the nonlinear mixed-effects software to be used (e.g. **NONMEM**, **nlmixr2**, **Monolix**, **Phoenix NLME**) and relevant versions. Indicate solver/estimation method (e.g. FOCEI, SAEM).
* If using PBPK or QSP tools (e.g. Simcyp, GastroPlus), include them here.

### Post-processing and Visualization Software

* List the software and packages for data manipulation, diagnostics, and plots (e.g. **R** with `tidyverse`, `ggplot2`, `xgxr`; **Perl-speaks-NONMEM (PsN)**, **VPA**, **Mlxplore**, etc.). Include versions.
* Include any scripts or tools used for covariate analysis, VPC generation, and reporting.

### Version Control and Environment Details

* Document the version control system (e.g. **Git**) and repository if applicable.
* Note the computing environment (operating system, cluster or local).

*(Health Canada expects submissions to include software and version details. The FDA/ICH emphasize documenting technical methods; for example ICH M15 encourages including software information in the Model Analysis Plan.)*

## Analysis Methods

### 6.1 Exploratory Data Analysis (EDA)

* **Descriptive Summaries:** Generate summary statistics and visualizations of the PK data (e.g. mean/median concentration–time profiles, boxplots by dose level or covariate strata).
* **Trend and Covariate Plots:** Plot concentrations or derived PK metrics against potential covariates (age, weight, organ function) to identify trends.
* **Outlier Detection:** Examine residuals or predicted vs. observed plots from an initial simple model to flag aberrant points. Document any data cleaning steps.
* **Baseline Check:** Confirm accurate dosing history and flag protocol deviations (e.g. missing doses, erroneous time stamps).

*(Exploratory plots inform model building. The FDA notes that structural model selection should be guided by data exploration.)*

### 6.2 Structural Model Development

* **Base Model Selection:** Specify candidate structural models (e.g. 1- or 2-compartment with first-order elimination, with/without absorption lag) and rationale. The choice of model should be informed by EDA and scientific plausibility.
* **Model Building Strategy:** Outline the approach (e.g. start from simplest model and add complexity). Describe how model performance and fit will be evaluated at each step (e.g. objective function, plausibility of estimates).
* **Cross-validation of Model:** If multiple models fit similarly, justify selection based on criteria such as precision of estimates and physiological plausibility.

*(FDA guidance emphasizes that structural model choice should be justified by data exploration and prior knowledge. Include any alternative models to test.)*

### 6.3 Inter-Individual Variability Model

* **Random Effects Specification:** State which parameters will include IIV (commonly clearance, volume, etc.) and assumed distributions (typically log-normal).
* **Covariance Structure:** Note whether covariances between random effects will be estimated or fixed to zero.
* **Shrinkage Consideration:** Indicate plans to assess shrinkage of Empirical Bayes Estimates (EBEs), especially if using outputs in E-R analysis. If ETA-shrinkage on a key parameter exceeds [e.g., 30%], the corresponding EBEs will not be used for exploratory exposure-response analyses, and EBE-based diagnostic plots for that parameter will be interpreted with caution.

### 6.4 Covariate Model Development

* **Covariate Selection Strategy:** List covariates to be tested (e.g. age, weight, renal function, sex, concomitant meds) with biological or literature justification for each. Indicate any pre-specified hierarchy or grouping of covariates.
* **Screening and Modeling Approach:** Describe the covariate model building method (e.g. full-model, stepwise forward addition/backward elimination, or machine-learning approaches). For example, *“A stepwise approach (α=0.01 for inclusion, α=0.001 for elimination) will be used”* or justify use of a full fixed-effects model. Sponsors should justify the chosen method.
* **Handling of Correlated Covariates:** If covariates are correlated (e.g. weight and BMI), describe how multicollinearity will be addressed (e.g. one covariate tested at a time, or principal component analysis).
* **Significance and Relevance Criteria:** Define criteria for including covariates (change in objective function, % change in parameter and precision, and clinical relevance). A covariate effect will be considered potentially clinically relevant if it leads to a >[e.g., 20-30%] change in a key exposure metric (AUC or C_max) for the plausible range of the covariate. This threshold will be discussed with the clinical team and justified.

*(Regulators expect a clear rationale for covariates and justification of the selection algorithm. For instance, FDA highlights justifying the covariate approach used and forming relationships based on biology. EMA guidance similarly lists planned covariates and rationale in the analysis plan.)*

### 6.5 Residual Unexplained Variability Model

* **Error Model:** Specify the residual error structure to be tested (e.g. proportional, additive, combined).
* **Modeling Approach:** Indicate how the best error model will be selected (comparison of likelihood, fit, and parameter plausibility).
* **Assumption Checks:** Note how error model adequacy will be assessed (e.g. no trends in residual plots vs. predictions or time).

*(Include details on the form of residual error to ensure reproducibility. This forms part of the “variability models to be tested” as recommended by EMA.)*

## Model Evaluation and Validation

### 7.1 Goodness-of-Fit (GOF) Criteria

* **Graphical Diagnostics:** Describe planned GOF plots: observed vs. predicted concentrations (population and individual), residuals vs. time and vs. predictions, and distribution of random effects (e.g. Q–Q plots). Indicate any subgroup (stratified) plots for important covariates or dosing groups.
* **Numerical Metrics:** State model fit statistics to report: final objective function value (OFV), parameter standard errors, condition number (assess identifiability), shrinkage, and decrease in OFV for added covariates.
* **Fit-for-Purpose Assessment:** Note that model performance will be assessed in the context of its intended use (e.g. precision of key PK parameters, adequacy of predictions in key subgroups).

*(FDA guidance notes GOF plots “illustrate how well the model describes the observed data” and should include various residual diagnostics. Multiple diagnostics and metrics should be used in a fit-for-purpose manner.)*

### 7.2 Model Qualification Techniques

* **Visual Predictive Checks (VPC):** Plan to perform simulation-based diagnostics, such as VPC or prediction-corrected VPC, to compare observed and simulated percentiles over time. Specify the number of simulations and binning approach.
* **Normalized Prediction Distribution Errors (NPDE):** Include NPDE or similar metrics to quantify predictive performance across the dataset.
* **Bootstrap or Sampling-based Uncertainty:** Describe use of bootstrap or importance sampling to quantify parameter uncertainty and confidence intervals.
* **Other Diagnostics:** Mention any additional checks (e.g. posterior predictive checks, nonparametric bootstrap, numeric predictive check) that will be used to confirm model robustness.
* **Validation Strategy:** If applicable, note plans for external validation or data-splitting (e.g. training vs. test set) and justification.

*(FDA recommends simulation-based diagnostics (VPC, pcVPC, NPC, NPDE) and bootstrap or profiling to evaluate model performance. Multiple complementary methods should be used to validate that the model is adequate for its purpose.)*

## Simulation Plan

* **Simulation Objectives:** Describe any intended simulation exercises using the final model (e.g. predicting exposures in renal impairment, pediatric dosing, alternative regimens).
* **Simulation Design:** Outline simulation scenarios (populations, covariate distributions, dosing regimens, number of replicates). Specify outcome metrics to report (AUC, Cmax, target attainment rates, etc.). Simulation outputs will be summarized using tables of descriptive statistics (mean, median, 5th and 95th percentiles) for AUC and C_max, and visualized using box plots stratified by dose/subgroup and/or simulated concentration-time profile plots with 90% prediction intervals.
* **Protocol and Assumptions:** State that simulations will follow a predefined protocol detailing assumptions. The level of detail will match the complexity of the question being addressed.

*(Per FDA guidance, simulations should be pre-planned in a protocol with appropriate detail for the question at hand.)*

## Reporting and Deliverables

* **Final Report:** Comprehensive population PK/PD report including all sections above, results, tables/figures, and discussion of findings. The final report will explicitly reference the final version and date of this analysis plan and will document and justify any deviations from it.
* **Analysis Plan Document:** The prospectively written plan itself (this document) should be included as an appendix to the report. Any deviations during analysis must be documented.
* **Model Code and Datasets:** Provide the complete modeling code (e.g. NONMEM control streams or Monolix project files) and final analysis datasets. Electronic files of models and data definitions should be submitted.
* **Software and Environment Logs:** Include documentation of software versions and run environments.
* **Presentation Materials:** Optionally, slides summarizing key findings for stakeholders.
* **Other Deliverables:** Any intermediate data summaries, diagnostic tables, or custom scripts used. This includes a model development log or table summarizing key steps in model building (e.g., changes in OFV, parameter estimates, and diagnostics between base, intermediate, and final models).

*(Health Canada guidance expects submission of full model documentation including software and data details. ICH M15 recommends including model code and electronic files with submissions.)*

## References

*(List relevant guidelines, SOPs, and publications cited above.)*
