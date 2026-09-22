using URIs
using Test

include("uri.jl")
include("url.jl")
include("utils.jl")

# https://github.com/JuliaWeb/URIs.jl/issues/42
struct CustomString <: AbstractString
    str::String
end

Base.codeunits(x::CustomString) = codeunits(x.str)

@test URIs.escapeuri(CustomString("http://example.com")) == URIs.escapeuri("http://example.com")

# `tryparse` must rethrow errors other than parse failures.
@test_throws MethodError tryparse(URI, CustomString("http://example.com"))

allocated_escape(f, str) = @allocated f(str)
@testset "escaping safe prefixes" begin
    for f in (escapeuri, escapepath), str in ("", "bucket", "object-key.data", "abc"^1024)
        @test f(str) == str
        allocated_escape(f, str)
        @test allocated_escape(f, str) == 0
    end
    path = "/bucket/object-key.data"
    allocated_escape(escapepath, path)
    @test allocated_escape(escapepath, path) == 0
    @test escapepath(path) == path
    @test escapeuri(SubString("prefixbucket", 7)) === "bucket"

    for prefix in ("", "a", "abc"^1024), (suffix, escaped) in
            (("?", "%3F"), ("α", "%CE%B1"), (String(UInt8[0xff]), "%FF"))
        @test escapeuri(prefix * suffix) == prefix * escaped
    end

    seen = Char[]
    safe(c) = (push!(seen, c); iseven(length(seen)))
    @test escapeuri("a?b&", safe) == "%61?%62&"
    @test seen == ['a', '?', 'b', '&']
end
