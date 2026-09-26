using URIs

function @main(args::Vector{String})::Cint
    length(args) == 2 || return 2
    path, expected = args
    URIs.normpath(path) == expected || return 1
    URIs.normpath(URI(; scheme="file", path)).path == expected || return 1
    if startswith(path, "/")
        base = URI("http://example.test/base/file")
        joinpath(base, path).path == expected || return 1
        resolvereference(base, URI(; path)).path == expected || return 1
    end
    return 0
end
