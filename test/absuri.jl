@testset "absuri.jl" begin
    cases = [
        ("https://en.wikipedia.org/api/rest_v1/page/summary/Potatoes", "Potato", "https://en.wikipedia.org/api/rest_v1/page/summary/Potato"),
        ("https://en.wikipedia.org/api/rest_v1/page/summary/Potatoes", "./Potato", "https://en.wikipedia.org/api/rest_v1/page/summary/Potato"),
        ("https://en.wikipedia.org/api/rest_v1/page/summary/Potatoes", "/foo/bar/baz", "https://en.wikipedia.org/foo/bar/baz"),
        ("https://en.wikipedia.org/api/rest_v1/page/summary/Potatoes", "https://julialang.org/foo/bar/baz", "https://julialang.org/foo/bar/baz"),
    ]
    for case in cases
        url = case[1]
        location = case[2]
        actual_output = URIs.absuri(location, url)
        expected_output = URIs.URI(case[3])
        @test actual_output == expected_output
    end
end
