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

allocated_normalization(p) = @allocated URIs.normpath(p)

@testset "Path normalization boundaries and allocation growth" begin
    cases = Pair{String,String}[
        ""=>"", "."=>"", ".."=>"", "..."=>"...", "...."=>"....",
        "./..."=>"...", "../..."=>"...", "../../...."=>"....",
        "/"=>"/", "//"=>"//", "/."=>"/", "/.."=>"/", "/..."=>"/...",
        "/./"=>"/", "/../"=>"/", ".//a"=>"/a", "..//a"=>"/a",
        "a/."=>"a/", "a/.."=>"/", "a/..."=>"a/...",
        "a/../../b"=>"/b", "a/..//b"=>"//b", "a/../.."=>"/",
        "/a///../b"=>"/a//b", "//a/../b"=>"//b",
        "a.b/c.d"=>"a.b/c.d", "a/..b"=>"a/..b", "a/.b"=>"a/.b",
        "é/../🌟"=>"/🌟", "./é/../🌟"=>"/🌟",
        "/é/./🌟/"=>"/é/🌟/", "/é/..//%2e"=>"//%2e",
        "%2E"=>"%2E", "%2e%2e/a"=>"%2e%2e/a",
        "/%2E/%2e%2E/.."=>"/%2E/", "/a%2fb/../c"=>"/c",
        "a\\b/../c"=>"/c", "dir/..\\file"=>"dir/..\\file",
        String(UInt8[0xff, 0x2f, 0x2e, 0x2f, 0xfe])=>String(UInt8[0xff, 0x2f, 0xfe]),
    ]
    for (path, expected) in cases
        wrapped = "prefix" * path * "suffix"
        view = SubString(wrapped, 7, prevind(wrapped, 7 + ncodeunits(path)))
        for input in (path, view, Test.GenericString(path))
            actual = URIs.normpath(input)
            @test actual isa String
            @test actual == expected
            @test URIs.normpath(actual) == actual
        end
    end

    @test string(URIs.normpath(URI("file:...?q=/../#section"))) ==
          "file:...?q=/../#section"
    @test string(resolvereference(URI("custom:base"), URI("..."))) == "custom:..."
    @test string(joinpath(URI("file:dir"), "../...")) == "file:/..."
    @test string(resolvereference(URI("http://host/a/b"), URI("../é/./c?q=/../#f"))) ==
          "http://host/é/c?q=/../#f"

    for path in ("", "/bucket/object-key", "data.csv", ".config", "...", "name.ext/"^1024)
        allocated_normalization(path)
        @test allocated_normalization(path) == 0
    end
    # Actual dot segments exercise the output buffer. Four times the input
    # must not restore quadratic copying.
    small, large = "name.ext/./"^128, "name.ext/./"^512
    @test URIs.normpath(small) == "name.ext/"^128
    @test URIs.normpath(large) == "name.ext/"^512
    allocated_normalization(small)
    allocated_normalization(large)
    small_bytes = allocated_normalization(small)
    large_bytes = allocated_normalization(large)
    @test large_bytes <= 6small_bytes
    @test large_bytes <= 32ncodeunits(large) + 4096
end
