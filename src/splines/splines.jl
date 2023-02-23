module splines

export filter_coeffs, interpolant_cspline, filter_coeffs
export eval_UC_spline, eval_UC_spline!
export prefilter!

include("csplines.jl")
include("splines_filter.jl")
include("cubic_prefilter.jl")
include("interp.jl")


function interpolant_cspline(a, b, orders, V)

    coefs = filter_coeffs(a, b, orders, V)

    function fun(s::Array{Float64,2})
        return eval_UC_spline(a, b, orders, coefs, s)
    end

    function fun(p::Float64...)
        return fun([p...]')
    end

    return fun

end

abstract type Linear end
abstract type Cubic end

struct MLinear<:Linear end
struct MCubic<:Cubic end

struct CubicInterpolator{G,C} <: Cubic
    grid::G
    θ::C
end

struct SplineInterpolator{G,C,k}
    grid::G
    θ::C
end




    function prefilter(ranges::NTuple{d,Tuple{Float64,Float64,i}}, V::AbstractArray{T, d}, ::Val{3}) where d where i<:Int where T
        θ = zeros(eltype(V), ((e[3]+2) for e in ranges)...)
        ind = tuple( (2:(e[3]+1) for e in ranges )...)
        θ[ind...] = V
        splines.prefilter!(θ)
        return θ
    end


    function prefilter!(θ::AbstractArray{T, d}, grid::NTuple{d,Tuple{Float64,Float64,i}}, V::AbstractArray{T, d}, ::Val{3}) where d where i<:Int where T
        splines.prefilter!(θ)
    end

    function prefilter(ranges::NTuple{d,Tuple{Float64,Float64,i}}, V::AbstractArray{T, d}, ::Val{1}) where d where i<:Int where T
        θ = copy(V)
        return θ
    end


    function prefilter!(θ::AbstractArray{T, d}, grid::NTuple{d,Tuple{Float64,Float64,i}}, V::AbstractArray{T, d}, ::Val{1}) where d where i<:Int where T
        θ[:] = V
    end

    function CubicInterpolator(grid; values=nothing)

        n = [e[3] for e in grid.ranges]
        θ = zeros(eltype(values), (i+2 for i in n)...)
        ci = CubicInterpolator{typeof(grid), typeof(θ)}(grid, θ)
        if !isnothing(values)
            ind = tuple( (2:(e[3]+1) for e in grid.ranges )...)
            ci.θ[ind...] .= values
            splines.prefilter!(ci.θ)
        end
        return ci
    
    end

    function SplineInterpolator(ranges; values=nothing, k=3)

        # TODO: logic here is ridiculous
        @assert !isnothing(values)
        n = [e[3] for e in ranges]
        if k==3
            θ = zeros(eltype(values), (i+2 for i in n)...)
            ind = tuple( (2:(e[3]+1) for e in ranges )...)
            θ[ind...] .= values
            splines.prefilter!(θ)
        elseif k==1
            θ = copy(values)
        end
        ci = SplineInterpolator{typeof(ranges), typeof(θ), k}(ranges, θ)
        return ci
    
    end

    function (spl::SplineInterpolator{G,C,3})(x) where G where C
        a = tuple( (e[1] for e in spl.grid)...)
        b = tuple( (e[2] for e in spl.grid)...)
        n = tuple( (e[3] for e in spl.grid)...)
        splines.eval_UC_spline(a,b,n, spl.θ, x)
    end


    function (spl::SplineInterpolator{G,C,1})(x) where G where C
        # ranges = spl.grid.ranges
        # data = spl.θ
        # dims = tuple( (e[3] for e in ranges)... )
        # v = reshape(view(data, :), dims) 
        interp(spl.grid, spl.θ, x...)
    end

end
