library(nlmixr2)

## Load population pharmacokinetic data from the data directory
data <- read.csv('./data/simulated_pk_data.csv')

## Define the one-compartment model with inter-individual variability
one.compartment <- function() {
  ini({
    tka <- log(1.57); label("Ka")
    tcl <- log(2.72); label("Cl")
    tv <- log(31.5); label("V")
    eta.ka ~ 0.6
    eta.cl ~ 0.3
    eta.v ~ 0.1
    add.sd <- 0.7
  })
  model({
    ka <- exp(tka + eta.ka)
    cl <- exp(tcl + eta.cl)
    v <- exp(tv + eta.v)
    d/dt(depot) <- -ka * depot
    d/dt(center) <- ka * depot - cl / v * center
    cp <- center / v
    cp ~ add(add.sd)
  })
}

## Fit the model using SAEM algorithm
fit <- nlmixr(one.compartment, data, "saem",
              control=list(print=0), 
              table=list(cwres=TRUE, npde=TRUE))

# Print summary of parameter estimates and confidence intervals
print(fit)

# Basic Goodness of Fit Plots
plot(fit)