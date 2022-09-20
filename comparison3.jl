using Random, Combinatorics, LinearAlgebra, Convex, Mosek, BenchmarkTools, DelimitedFiles, StatsBase, JLD2, FileIO
include("functions.jl")

Random.seed!(1992)

μ = 0.1
γ = 1
k = collect(5:5:50)

acc_train = zeros(10,7,100)
auc_train = zeros(10,7,100)

acc_test = zeros(10,7,100)
auc_test = zeros(10,7,100)

for rep = 1:100
    sonar = readdlm("dataset/sonar.all-data",',',Any,'\n')
    y_sonar = sonar[:,end]
    sonar = convert(Array{Float64,2}, sonar[:,1:end-1])
    y_sonar[findall(x->x=="M",y_sonar)] .= 1
    y_sonar[findall(x->x=="R",y_sonar)] .= 0
    y_sonar = convert(Array{Float64, 1}, y_sonar)
    n, p = size(sonar)

    train = sample(1:n, Int(n/2), replace=false)
    X = sonar[train,:]
    y = y_sonar[train]
    n, p = size(X)

    test = setdiff(1:n,train)
    X_test = sonar[test,:]
    y_test = y_sonar[test]

    for i = 1:length(k)
        
        pre = sample(1:n, k[i], replace =false)
        rest = setdiff(1:n, pre)
        β = irls(X[pre,:], y[pre],μ=μ)
        mu = logistic(X[rest,:]*β)
        w = sqrt.(mu .* (1 .- mu))
        
        # OED, SOCP - sampling w/ probability
        socp = sagnol_A(Diagonal(w)*X[rest,:], μ*Diagonal(ones(p)), k[i]; verbose=0, IC=0)
        cand = rest[rand(n-k[i]) .< socp]
        append!(cand, pre)
        β = irls(X[cand,:],y[cand],μ=μ)
        auc_train[i,1,rep], acc_train[i,1,rep] = auc(y, logistic.(X*β))
        auc_test[i,1,rep], acc_test[i,1,rep] = auc(y_test, logistic.(X_test*β))
    
        # OED, SOCP - top k candidate
        cand = rest[partialsortperm(socp, 1:k[i], rev=true)]
        append!(cand, pre)
        β = irls(X[cand,:],y[cand],μ=μ)
        auc_train[i,2,rep], acc_train[i,2,rep] = auc(y, logistic.(X*β))
        auc_test[i,2,rep], acc_test[i,2,rep] = auc(y_test, logistic.(X_test*β))
        
        # TED, SOCP - sampling w/ probability
        socp = sagnol_A(Diagonal(w)*X[rest,:], μ*Diagonal(ones(p)), k[i]; K=X', verbose=0, IC=0)
        cand = rest[rand(n-k[i]) .< socp]
        append!(cand, pre)
        β = irls(X[cand,:],y[cand],μ=μ)
        auc_train[i,3,rep], acc_train[i,3,rep] = auc(y, logistic.(X*β))
        auc_test[i,3,rep], acc_test[i,3,rep] = auc(y_test, logistic.(X_test*β))
    
        # TED, SOCP - top k candidate
        cand = rest[partialsortperm(socp, 1:k[i], rev=true)]
        append!(cand, pre)
        β = irls(X[cand,:],y[cand],μ=μ)
        auc_train[i,4,rep], acc_train[i,4,rep] = auc(y, logistic.(X*β))
        auc_test[i,4,rep], acc_test[i,4,rep] = auc(y_test, logistic.(X_test*β))

        # sequential
        cand = rest[alg1(Diagonal(w)*X[rest,:],k[i])]
        append!(cand, pre)
        β = irls(X[cand,:],y[cand],μ=μ)
        auc_train[i,5,rep], acc_train[i,5,rep] = auc(y, logistic.(X*β))
        auc_test[i,5,rep], acc_test[i,5,rep] = auc(y_test, logistic.(X_test*β))

        # relaxation
        cand = rest[alg4(Diagonal(w)*X[rest,:],k[i])]
        append!(cand, pre)
        β = irls(X[cand,:],y[cand],μ=μ)
        auc_train[i,6,rep], acc_train[i,6,rep] = auc(y, logistic.(X*β))
        auc_test[i,6,rep], acc_test[i,6,rep] = auc(y_test, logistic.(X_test*β))
    
        # random sampling
        cand = sample(rest, k[i] ,replace=false)
        append!(cand, pre)
        β = irls(X[cand,:],y[cand],μ=μ)
        auc_train[i,7,rep], acc_train[i,7,rep] = auc(y, logistic.(X*β))
        auc_test[i,7,rep], acc_test[i,7,rep] = auc(y_test, logistic.(X_test*β))

        @save "comparison3.jld2" acc_train auc_train acc_test auc_test
        println("$i / 10 iteration in $rep / 100 repitition complete")
    end
end