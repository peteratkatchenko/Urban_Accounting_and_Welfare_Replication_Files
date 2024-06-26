using StatFiles
using DataFrames 
using GLM
using JLD2
using CSV 
using StatFiles

#PARAMETER VALUES 

psi=1.5247
theta=0.5221
totalhours=5110
inter=0.2008

#DATASET USED
filepath1 = joinpath(@__DIR__, "DataChina.jld2")

data = DataFrame(load(filepath1)) 

rename!(data, 
"censpop152005" => "censpop15",
"censemp2005" => "censemp",
"censhours2005" => "censhours",
"emp2005" => "emp",
"pop2005" => "pop",
"gdp2005" => "gdp",
"cons2005" => "cons")

#CALCULATE SOME OF THE VARIABLES NEEDED

#Labor wedge expressed as (1-tau)

function hours_fun(censemp::Vector, censhours::Vector, censpop15::Vector)
(censemp .*censhours .*52) ./censpop15 ./totalhours
end 
 
data = transform(data, [:censemp, :censhours, :censpop15] => hours_fun => :hours) 

function laborwedge_fun(cons::Vector, gdp::Vector, hours::Vector)
psi/(1-theta) .* cons ./gdp .* hours./(1 .- hours)
end

data = transform(data, [:cons, :gdp, :hours] => laborwedge_fun => :laborwedge)
    

#Efficiency wedge

function effwedge_fun(gdp::Vector, pop::Vector, hours::Vector)
(gdp ./pop) .^(1-theta) ./(theta/inter)^theta ./ (hours .^(1-theta))
end 

data = transform(data,  [:gdp, :pop, :hours] => effwedge_fun => :efficiencywedge)
  
 
#CREATE LOG VARIABLES

data.logpop = log.(data[!, :pop]) 

insert = (1 .- data[!, :laborwedge])
    
for i in 1:length(insert)
    if !ismissing(insert[i]) && insert[i] < 0
        insert[i] = missing
    end 
end 

data.loglaborwedge = log.(insert)   

data.logeff = log.(data[!, :efficiencywedge]) 

data.logpop2 = log.(exp.(data[!, :logpop]).*10000) 


#USE EQUATION (20) TO COMPUTE LOG OF EXCESSIVE FRICTIONS AND ALPHA_5 AND THEN DETERMINE KAPPA

data.loglaborpop = data[!, :loglaborwedge] .- 0.5 .* log.(exp.(data[!, :logpop]) .*10000)

data.constant = zeros(length(data[!, :loglaborpop]))
    
model = lm(@formula(loglaborpop ~ constant), data)

alpha5 = coef(model)[1] 

alpha5 = -7.779912

kappa = exp(alpha5 - log(2/3)+0.5*log(3.1415))

println(kappa)

data.logexcfrict = log.(exp.(data[!, :loglaborwedge]) ./ kappa .* 3/2 .* (3.1415 ./ (data[!, :pop] .* 10000)).^0.5)

#KEEP VARIABLES NEEDED TO RUN COUNTERFACTUAL EXERCISE
#population in 1,000 to make comparable to U.S. 

data.pop = data[!, :pop] .* 10

filter!(row -> !ismissing(row.loglaborwedge) ,data)

filter!(row -> !ismissing(row.logpop), data)

filter!(row -> !ismissing(row.cityid), data)

data.year = fill(2005, nrow(data))

data.zero = zeros(length(data.year))

data = select(data, :province, :city, :year, :zero, :logeff, :logexcfrict, :pop)

#DATA SET FOR MAIN MODULE

data = select(data, [:year, :logeff, :zero, :logexcfrict, :pop])

filepath9 = joinpath(@__DIR__, "ChinaBenchmark.txt")

CSV.write(filepath9, data)