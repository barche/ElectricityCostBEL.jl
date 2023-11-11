## Electricity cost for Belgium

Simple package to compute electricity cost over a period, using either dynamic tariff or a user-supplied tariff function.

### Installation

In Pkg mode (hit `]`) type:

```
add https://github.com/barche/ElectricityCostBEL.jl.git
```

Running a calculation requires a download in CSV of the meter quarter-hour values from the Fluvius site, called `kwartierwaarden-2022-2023.csv` here. You may also need to update the dynamic tariff files as needed in the source directory, obtainable from https://www.energy-charts.info/charts/price_spot_market/chart.htm?l=en&c=BE

Then use the package and call `computecosts` to calculate dynamic tariff costs for a chosen start and end:

```julia
using ElectricityCostBEL, Dates

starttime = DateTime("2022-10-01T00")
endtime = DateTime("2023-09-30T23")

consumptionfile = "kwartierwaarden-2022-2023.csv"

dynamic_consumption_cost, dynamic_injection_return = computecosts(consumptionfile, starttime, endtime;
  yearcosts = 335.12 + 13.39, # Yearly cost in € / year
  netcost = (156.8/4301) + (3.6/206) + (0.65/206), # network in € per kwh
  tax = 225.24/4301, # extra tax in € per kWh
  vat = 1.06 # VAT
)
```

It is also possible to override the electricity price functions, e.g:

```julia
using ElectricityCostBEL, Dates

starttime = DateTime("2022-10-01T00")
endtime = DateTime("2023-09-30T23")

consumptionfile = "kwartierwaarden-2022-2023.csv"

function consumption_engie_variable(datetime)
  if isnight(datetime)
    return 15.641/106
  end
  return 19.425/106
end

function injection_engie_variable(datetime)
  if isnight(datetime)
    return 3.433/100
  end
  return 8.809/100
end

fixed_consumption_cost, fixed_injection_return = computecosts(consumptionfile, starttime, endtime, consumption_engie_variable, injection_engie_variable;
  yearcosts = 335.12 + 13.39, # Yearly cost in € / year
  netcost = (156.8/4301) + (3.6/206) + (0.65/206), # network in € per kwh
  tax = 225.24/4301, # extra tax in € per kWh
  vat = 1.06 # VAT
)
```
