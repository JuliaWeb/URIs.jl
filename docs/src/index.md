# URIs.jl

`URIs` is a Julia package for parsing and working with Uniform Resource
Identifiers, as defined in [RFC 3986](https://www.ietf.org/rfc/rfc3986.txt).
It also supports data URI as defined in [RFC 2397](https://datatracker.ietf.org/doc/html/rfc2397).

## Tutorial

### URI
```@meta
DocTestSetup = quote
    using URIs
end
```

Parsing URIs from a string can be done with the [`URI`](@ref) constructor:

```jldoctest
julia> u = URI("http://example.com/some/path")
URI("http://example.com/some/path")
```

The components of the URI can then be accessed via the fields `scheme`,
`userinfo`, `host`, `port`, `path`, `query` or `fragment`:

```jldoctest
julia> u = URI("http://example.com/some/path")
URI("http://example.com/some/path")

julia> u.scheme
"http"

julia> u.host
"example.com"

julia> u.path
"/some/path"
```

To access the query part of a URI as a dictionary, the `queryparams` function
is provided:

```jldoctest
julia> u = URI("http://example.com/path?x=1&y=hi")
URI("http://example.com/path?x=1&y=hi")

julia> queryparams(u)
Dict{String,String} with 2 entries:
  "x" => "1"
  "y" => "hi"
```

### Data URI

```@meta
DocTestSetup = quote
    using URIs
end
```

Parsing Data URIs from a string can be done with the [`DataURI`](@ref) constructor:

```jldoctest
julia> u = DataURI("data:,A%20brief%20note")
DataURI("data:,A%20brief%20note")
```

See reference and unit tests for more usage.

## Reference

```@docs
URI
queryparams
queryparampairs
absuri
escapeuri
unescapeuri
escapepath
resolvereference
URIs.splitpath
Base.isvalid(::URI)
DataURI
getdata
```

