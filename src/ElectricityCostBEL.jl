module ElectricityCostBEL

export computecosts, dynamic_consumption, dynamic_injection, isnight

using CSV, Dates

const spotprices = Dict{DateTime,Float64}()

function readspot!(spotprices, fname)
  csv = CSV.File(fname; header=[:date,:cost], skipto=3, types=[String,Float64])
  
  for (dtstring,cost) in csv
    dt = DateTime(dtstring[1:16])
    if !ismissing(cost)
      spotprices[dt] = cost
    end
  end
end

const spotfiles = [
  joinpath(@__DIR__, "spot-2022.csv"),
  joinpath(@__DIR__, "spot-2023.csv"),
]

function __init__()
  for f in spotfiles
    println("reading $f")
    readspot!(spotprices, f)
  end
end

const daystarthour = 6
const nightstarthour = 21

function isnight(datetime)
  if !(daystarthour <= hour(datetime) < nightstarthour)
    return true
  end
  if dayofweek(datetime) >= 6
    return true
  end
  return false
end

function storekwh!(storedvalues, date, newvalue)
  if minute(date) == 0
    storedvalues[date] = 0.0
  end
  storedvalues[floor(date,Hour)] += newvalue
end

function readkwh(filename)
  consumption = Dict{DateTime,Float64}()
  injection = Dict{DateTime,Float64}()
  open(filename) do file
    for (linenum,line) in enumerate(eachline(file))
      if linenum == 1
        continue
      end
      (startd,starttime,_,_,_,_,_,reg,valstr,_,_) = split(line,';')
      startdt = DateTime(startd*starttime[1:5], dateformat"dd-mm-yyyyHH:MM")
      val = parse(Float64, replace(valstr, ',' => '.'))
      if occursin("Dag", reg) && isnight(startdt)
        @error "Invalid day/night check at date $startdt"
      end
      if occursin("Injectie",reg)
        storekwh!(injection, startdt, val)
      else
        storekwh!(consumption, startdt, val)
      end
    end
  end
  return (consumption,injection)
end

function injection_engie_variable(datetime)
  if isnight(datetime)
    return 3.433/100
  end
  return 8.809/100
end

function consumption_engie_variable(datetime)
  if isnight(datetime)
    return 15.641/100
  end
  return 19.425/100
end

function spotprice(dt)
  if !haskey(spotprices, dt)
    return 0.0
  end
  return spotprices[dt]
end

dynamic_consumption(datetime) = (0.1*spotprice(datetime - Day(1)) + 0.204)/100 # € / kWh
dynamic_injection(datetime) = spotprice(datetime - Day(1)) / 1000 # € /kWh

function computecosts(consumptionfile, starttime, endtime, consumptionprice=dynamic_consumption, injectionprice=dynamic_injection;
    yearcosts = 335.12 + 13.39, # captar and data mgt,
    netcost = (156.8/4301) + (3.6/206) + (0.65/206),
    tax = 225.24/4301,
    vat = 1.06)

(consumption, injection) = readkwh(consumptionfile)

conscost = 0.0
injcost = 0.0
totcons = 0.0
for dt in starttime:Hour(1):endtime
  if !haskey(consumption, dt) # Skips e.g. DST hour
    continue
  end
  totcons += consumption[dt]
  conscost += consumptionprice(dt)*consumption[dt]
  injcost += injectionprice(dt)*injection[dt]
end
conscost += yearcosts*(endtime-starttime)/Millisecond(Day(365)) + netcost*totcons + tax*totcons
return conscost*vat, injcost
end

end # module ElectricityCostBEL
