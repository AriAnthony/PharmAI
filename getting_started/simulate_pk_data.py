import numpy as np
import pandas as pd
import matplotlib.pyplot as plt

np.random.seed(42)  # Set seed for reproducibility

# Simulation parameters
n_subjects = 20
time_points = np.array([0, 0.5, 1, 2, 4, 6, 8, 12, 16, 24])
DOSE = 100  # mg

# Typical PK parameters (one-compartment SC)
TV_CL = 5.0  # L/h
TV_V = 50.0  # L
TV_KA = 1.2  # 1/h (typical absorption rate constant)
F = 1.0      # Bioavailability (fraction absorbed)

# Inter-individual variability (log-normal)
omega_cl = 0.3  # 30% CV
omega_v = 0.2   # 20% CV
omega_ka = 0.25 # 25% CV (added for ka)

# Residual error (proportional)
sigma = 0.15  # 15% CV

records = []

for subj in range(1, n_subjects + 1):
    # Simulate individual PK parameters
    CL = TV_CL * np.exp(np.random.normal(0, omega_cl))
    V = TV_V * np.exp(np.random.normal(0, omega_v))
    KA = TV_KA * np.exp(np.random.normal(0, omega_ka))
    k = CL / V
    for t in time_points:
        # One-compartment SC: C = (F*DOSE*KA)/(V*(KA-k)) * (exp(-k*t) - exp(-KA*t))
        if abs(KA - k) < 1e-6:
            # Avoid division by zero if KA ~ k
            true_conc = (F * DOSE / V) * t * KA * np.exp(-k * t)
        else:
            true_conc = (F * DOSE * KA) / (V * (KA - k)) * (np.exp(-k * t) - np.exp(-KA * t))
        # Add proportional residual error
        obs_conc = true_conc * (1 + np.random.normal(0, sigma))
        records.append({
            'ID': subj,
            'TIME': t,
            'DV': max(obs_conc, 0.01),  # avoid negative concentrations
            'AMT': DOSE if t == 0 else 0,
            'EVID': 1 if t == 0 else 0
        })

# Create DataFrame
sim_df = pd.DataFrame(records)

# Plot
plt.figure(figsize=(10, 6))
for subj in range(1, n_subjects + 1):
    subj_data = sim_df[sim_df['ID'] == subj]
    plt.plot(subj_data['TIME'], subj_data['DV'], marker='o', label=f'Subj {subj}')
plt.xlabel('Time (h)')
plt.ylabel('Concentration (mg/L)')
plt.title('Simulated PK Profiles (n=20)')
plt.yscale('log')
plt.legend(bbox_to_anchor=(1.05, 1), loc='upper left', fontsize='small', ncol=2)
plt.tight_layout()
plt.show()

# Optionally, save to CSV
sim_df.to_csv('data/simulated_pk_data.csv', index=False)
