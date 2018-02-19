struct LabelStats{T, S} <: ExactStat{(1,0)}
    label::T 
    stats::S
    nobs::Int
end
function fit!(o::LabelStats, xy, γ) 
    o.nobs += 1
    x, y = xy 
    y == o.label || error("observation label doesn't match")
    for (oi, yi) in zip(o.stats, y)
        fit!(oi, yi, γ)
    end
end

struct MultiLabelStats{T, S} <: ExactStat{(1, 0)}
    value::Vector{LabelStats{T,S}}
    empty_stats::S
end
function fit!(o::MultiLabelStats, xy, γ)
    x, y = xy 
    addlabel = true 
    for v in o.value 
        if v.label == y 
            fit!(v, xy, γ)
            addlabel = false 
            break
        end
    end
    if addlabel 
        ls = LabelStats(y, copy.(o.empty_stats))
        fit!(ls, xy)
        push!(o.value, LabelStats)
    end
end


"""
    NBClassifier(p, T, b = 20)

Create a Naive Bayes classifier for `p` predictors for classes of type `T`.  Conditional
probabilities are estimated using the [`Hist`](@ref) (with `AdaptiveBins`) type with `b` bins.

# Example

    x = randn(100, 5)
    y = rand(Bool, 100)
    o = NBClassifier(5, Bool)
    Series((x,y), o)
    predict(o, x)
    classify(o,x)
"""
#-----------------------------------------------------------------------# NBClassifier
struct NBClassifier{T} <: ExactStat{(1,0)}
    value::Vector{Pair{T, MV{Hist{0, AdaptiveBins{Float64}}}}}
    p::Int 
    b::Int
end
function NBClassifier(p::Integer, T::Type, b::Integer = 10)
    NBClassifier(Pair{T, MV{Hist{0, AdaptiveBins{Float64}}}}[], p, b)
end
function Base.show(io::IO, o::NBClassifier)
    print(io, "NBClassifier with labels: $(first.(o.value))")
end
Base.keys(o::NBClassifier) = first.(o.value)
Base.length(o::NBClassifier) = o.p

nobs(o::NBClassifier) = sum(nobs.(first.(last.(o.value))))

function probs(o::NBClassifier)
    nvec = nobs.(first.(last.(o.value)))
    nvec ./ sum(nvec)
end

function fit!(o::NBClassifier, xy::Tuple, γ::Float64)
    x, y = xy 
    addlabel = true
    for v in o.value
        if first(v) == y 
            fit!(last(v), x, 1.0)
            addlabel = false
            break
        end
    end
    if addlabel
        stat = MV(o.p, Hist(o.b))
        fit!(stat, x, 1.0)
        push!(o.value, Pair(y, stat))
    end
end

function predict(o::NBClassifier, x::VectorOb)
    pvec = log.(probs(o))
    buffer = zeros(length(x))
    for i in eachindex(pvec)
        mvhist = last(o.value[i])
        buffer .= log.(_pdf.(mvhist.stats, x))
        pvec[i] += sum(buffer)
    end
    out = exp.(pvec)
    out ./ sum(out)
end
function classify(o::NBClassifier, x::VectorOb) 
    val, i = findmax(predict(o, x))
    first(o.value[i])
end
for f in [:predict, :classify]
    @eval begin 
        function $f(o::NBClassifier, x::AbstractMatrix, dim::Rows = Rows())
            mapslices(x -> $f(o, x), x, 2)
        end
        function $f(o::NBClassifier, x::AbstractMatrix, dim::Cols)
            mapslices(x -> $f(o, x), x, 1)
        end
    end
end