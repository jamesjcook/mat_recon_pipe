function factors=integer_factors(input)

factors = input ./(1:ceil(sqrt(input))); 
factors = factors(factors==fix(factors)).' ; 
factors = unique([factors;input./factors]);