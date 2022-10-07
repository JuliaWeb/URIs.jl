using URIs
using Test

include("uri.jl")
include("url.jl")

# https://github.com/JuliaWeb/URIs.jl/issues/42
struct CustomString <: AbstractString
    str::String
end

Base.codeunits(x::CustomString) = codeunits(x.str)

@test URIs.escapeuri(CustomString("http://example.com")) == URIs.escapeuri("http://example.com")
