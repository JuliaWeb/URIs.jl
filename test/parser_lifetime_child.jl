# Run in its own Julia process: this test temporarily extends a Base method.
using URIs, Test

const tracked_match_data = Ref{Ptr{Cvoid}}(C_NULL)
const match_data_frees = Ref(0)

# Count one selected buffer while delegating to PCRE's real native free.
@eval Base.PCRE function free_match_data(p::Ptr{Cvoid})
    p == $(tracked_match_data)[] && ($(match_data_frees)[] += 1)
    return invoke(free_match_data, Tuple{Any}, p)
end

const sample_uri = "https://user:pass@example.com:443/path?query=value#fragment"

function track(owner)
    tracked_match_data[] = owner.match_data
    match_data_frees[] = 0
    nothing
end

@noinline function weak_owner_and_captures()
    owner = URIs.uri_reference_regex_f()
    track(owner)
    GC.@preserve owner begin
        @test URIs.exec(owner, sample_uri)
        captures = (URIs.group(1, owner, sample_uri),
                    URIs.group(3, owner, sample_uri),
                    URIs.group(5, owner, sample_uri))
        return WeakRef(owner), captures
    end
end

function explicit_finalization()
    first = URIs.uri_reference_regex_f()
    second = URIs.uri_reference_regex_f()
    @test first.re === second.re
    @test first.match_data != second.match_data
    track(first)
    finalize(first)
    @test match_data_frees[] == 1
    finalize(first)
    GC.gc(true)
    @test match_data_frees[] == 1
    GC.@preserve second begin
        @test URIs.exec(second, sample_uri)
        @test URIs.group(3, second, sample_uri) == "example.com"
    end
    finalize(second)
    nothing
end

function collected_owner()
    weak, captures = weak_owner_and_captures()
    GC.gc(true)
    GC.gc(true)
    @test weak.value === nothing
    @test match_data_frees[] == 1
    @test captures == ("https", "example.com", "/path")
    GC.gc(true)
    @test match_data_frees[] == 1
    nothing
end

const converting_owner = Ref(WeakRef(nothing))
struct GCSubject <: AbstractString
    value::String
end
function Base.String(s::GCSubject)
    GC.gc(true)
    GC.gc(true)
    # Fail before PCRE could access the freed buffer.
    converting_owner[].value === nothing && error("match owner collected during conversion")
    s.value
end

@noinline function match_converting_subject()
    owner = URIs.uri_reference_regex_f()
    track(owner)
    converting_owner[] = WeakRef(owner)
    URIs.exec(owner, GCSubject(sample_uri))
end

function conversion_lifetime()
    @test match_converting_subject()
    GC.gc(true)
    GC.gc(true)
    @test converting_owner[].value === nothing
    @test match_data_frees[] == 1
    nothing
end

@testset "URI match buffer lifetime" begin
    explicit_finalization()
    collected_owner()
    conversion_lifetime()
    @test URI(sample_uri).query == "query=value"
    @test URI("https://example.com/alpha").path == "/alpha"
    @test URI("relative?x=1").host == ""
    @test_throws URIs.ParseError URI("https://exa mple.com/")
end
