module URIs

export URI,
       queryparams, absuri,
       escapeuri, unescapeuri, escapepath

import Base.==

const DEBUG_LEVEL = Ref(0)
include("debug.jl")
include("parseutils.jl")

struct ParseError <: Exception
    msg::String
end

"""
    URI(; scheme="", host="", port="", etc...)
    URI(str) = parse(URI, str::String)

A type representing a URI (e.g. a URL). Can be constructed from distinct parts using the various
supported keyword arguments, or from a string. The `URI` constructors will automatically escape any provided
`query` arguments, typically provided as `"key"=>"value"::Pair` or `Dict("key"=>"value")`.
Note that multiple values for a single query key can provided like `Dict("key"=>["value1", "value2"])`.

When constructing a `URI` from a `String`, you need to first unescape that string: `URI( URIs.unescapeuri(str) )`.

The `URI` struct stores the complete URI in the `uri::String` field and the
component parts in the following `SubString` fields:
  * `scheme`, e.g. `"http"` or `"https"`
  * `userinfo`, e.g. `"username:password"`
  * `host` e.g. `"julialang.org"`
  * `port` e.g. `"80"` or `""`
  * `path` e.g `"/"`
  * `query` e.g. `"Foo=1&Bar=2"`
  * `fragment`

The `queryparams(::URI)` function returns a `Dict` containing the `query`.
"""
struct URI
    uri::String
    scheme::SubString{String}
    userinfo::SubString{String}
    host::SubString{String}
    port::SubString{String}
    path::SubString{String}
    query::SubString{String}
    fragment::SubString{String}
end

const absent = SubString("absent", 1, 0)

const emptyuri = (()->begin
    uri = ""
    return URI(uri, absent, absent, absent, absent, absent, absent, absent)
end)()

const nostring = ""

function URI(uri::URI; scheme::AbstractString=uri.scheme,
                              userinfo::AbstractString=uri.userinfo,
                              host::AbstractString=uri.host,
                              port::Union{Integer,AbstractString}=uri.port,
                              path::AbstractString=uri.path,
                              query=uri.query,
                              fragment::AbstractString=uri.fragment)

    @require isempty(host) || host[end] != '/'
    @require scheme in uses_authority || isempty(host)
    @require !isempty(host) || isempty(port)
    @require !(scheme in ["http", "https"]) || isempty(path) || path[1] == '/'
    @require !isempty(path) || !isempty(query) || isempty(fragment)

    if port !== absent
        port = string(port)
    end
    querys = query isa AbstractString ? query : escapeuri(query)

    return URI(nostring, scheme, userinfo, host, port, path, querys, fragment)
end

URI(;kw...) = URI(emptyuri; kw...)

# Based on regex from RFC 3986:
# https://tools.ietf.org/html/rfc3986#appendix-B
const uri_reference_regex =
    [RegexAndMatchData(r"""^
    (?: ([^:/?#]+) :) ?                     # 1. scheme
    (?: // (?: ([^/?#@]*) @) ?              # 2. userinfo
           (?| (?: \[ ([^:\]]*:[^\]]*) \] ) # 3. host (ipv6)
             | ([^:/?#\[]*) )               # 3. host
           (?: : ([^/?#]*) ) ? ) ?          # 4. port
    ([^?#]*)                                # 5. path
    (?: \?([^#]*) ) ?                       # 6. query
    (?: [#](.*) ) ?                         # 7. fragment
    $"""x)]

"""
https://tools.ietf.org/html/rfc3986#section-3
"""
function parse_uri(str::AbstractString; kw...)
    uri = parse_uri_reference(str; kw...)
    if isempty(uri.scheme)
        throw(URIs.ParseError("URI without scheme: $str"))
    end
    return uri
end

"""
https://tools.ietf.org/html/rfc3986#section-4.1
"""
function parse_uri_reference(str::Union{String, SubString{String}};
                             strict = false)
    uri_reference_re = uri_reference_regex[Threads.threadid()]
    if !exec(uri_reference_re, str)
        throw(ParseError("URI contains invalid character"))
    end
    uri = URI(str, group(1, uri_reference_re, str, absent),
                   group(2, uri_reference_re, str, absent),
                   group(3, uri_reference_re, str, absent),
                   group(4, uri_reference_re, str, absent),
                   group(5, uri_reference_re, str, absent),
                   group(6, uri_reference_re, str, absent),
                   group(7, uri_reference_re, str, absent))
    if strict
        ensurevalid(uri)
        @ensure uristring(uri) == str
    end
    return uri
end

parse_uri_reference(str; strict = false) =
    parse_uri_reference(SubString(str); strict = false)

URI(str::AbstractString) = parse_uri_reference(str)

Base.parse(::Type{URI}, str::AbstractString) = parse_uri_reference(str)

function ensurevalid(uri::URI)
    # https://tools.ietf.org/html/rfc3986#section-3.1
    # ALPHA *( ALPHA / DIGIT / "+" / "-" / "." )
    if !(uri.scheme === absent ||
         occursin(r"^[[:alpha:]][[:alnum:]+-.]*$", uri.scheme))
        throw(ParseError("Invalid URI scheme: $(uri.scheme)"))
    end
    # https://tools.ietf.org/html/rfc3986#section-3.2.2
    # unreserved / pct-encoded / sub-delims
    if !(uri.host === absent ||
         occursin(r"^[:[:alnum:]\-._~%!$&'()*+,;=]+$", uri.host))
        throw(ParseError("Invalid URI host: $(uri.host) $uri"))
    end
    # https://tools.ietf.org/html/rfc3986#section-3.2.3
    # "port number in decimal"
    if !(uri.port === absent || occursin(r"^\d+$", uri.port))
        throw(ParseError("Invalid URI port: $(uri.port)"))
    end

    # https://tools.ietf.org/html/rfc3986#section-3.3
    # unreserved / pct-encoded / sub-delims / ":" / "@"
    if !(uri.path === absent ||
         occursin(r"^[/[:alnum:]\-._~%!$&'()*+,;=:@]*$", uri.path))
        throw(ParseError("Invalid URI path: $(uri.path)"))
    end

    # FIXME
    # For compatibility with existing test/uri.jl
    if !(uri.host === absent) &&
        (occursin("=", uri.host) ||
         occursin(";", uri.host) ||
         occursin("%", uri.host))
        throw(ParseError("Invalid URI host: $(uri.host)"))
    end
end

"""
https://tools.ietf.org/html/rfc3986#section-4.3
"""
isabsolute(uri::URI) =
    !isempty(uri.scheme) &&
     isempty(uri.fragment) &&
    (isempty(uri.host) || isempty(uri.path) || isabspath(uri))

"""
https://tools.ietf.org/html/rfc7230#section-5.3.1
https://tools.ietf.org/html/rfc3986#section-3.3
"""
isabspath(uri::URI) = startswith(uri.path, "/") && !startswith(uri.path, "//")

==(a::URI,b::URI) = a.scheme      == b.scheme      &&
                    a.host        == b.host        &&
                    normalport(a) == normalport(b) &&
                    a.path        == b.path        &&
                    a.query       == b.query       &&
                    a.fragment    == b.fragment    &&
                    a.userinfo    == b.userinfo

normalport(uri::URI) = uri.scheme == "http"  && uri.port == "80" ||
                       uri.scheme == "https" && uri.port == "443" ?
                       "" : uri.port

hoststring(h) = ':' in h ? "[$h]" : h

Base.show(io::IO, uri::URI) = print(io, "URI(\"", uri, "\")")

showparts(io::IO, uri::URI) =
    print(io, "URI(\"", uri.uri, "\"\n",
              "    scheme = \"", uri.scheme, "\"",
                       uri.scheme === absent ? " (absent)" : "", ",\n",
              "    userinfo = \"", uri.userinfo, "\"",
                       uri.userinfo === absent ? " (absent)" : "", ",\n",
              "    host = \"", uri.host, "\"",
                       uri.host === absent ? " (absent)" : "", ",\n",
              "    port = \"", uri.port, "\"",
                       uri.port === absent ? " (absent)" : "", ",\n",
              "    path = \"", uri.path, "\"",
                       uri.path === absent ? " (absent)" : "", ",\n",
              "    query = \"", uri.query, "\"",
                       uri.query === absent ? " (absent)" : "", ",\n",
              "    fragment = \"", uri.fragment, "\"",
                       uri.fragment === absent ? " (absent)" : "", ")\n")

showparts(uri::URI) = showparts(stdout, uri)

Base.print(io::IO, u::URI) = print(io, string(u))

Base.string(u::URI) = u.uri === nostring ? uristring(u) : u.uri

#isabsent(ui) = isempty(ui) && !(ui === blank)
isabsent(ui) = ui === absent

function formaturi(io::IO,
                   scheme::AbstractString,
                   userinfo::AbstractString,
                   host::AbstractString,
                   port::AbstractString,
                   path::AbstractString,
                   query::AbstractString,
                   fragment::AbstractString)

    isempty(scheme)      || print(io, scheme, isabsent(host) ?
                                           ":" : "://")
    isabsent(userinfo)   || print(io, userinfo, "@")
    isempty(host)        || print(io, hoststring(host))
    isabsent(port)       || print(io, ":", port)
    isempty(path)        || print(io, path)
    isabsent(query)      || print(io, "?", query)
    isabsent(fragment)   || print(io, "#", fragment)

    return io
end

uristring(a...) = String(take!(formaturi(IOBuffer(), a...)))

uristring(u::URI) = uristring(u.scheme, u.userinfo, u.host, u.port,
                              u.path, u.query, u.fragment)

"""
    queryparams(::URI)
    queryparams(query_str::AbstractString)

Returns a `Dict` containing the `query` parameter string parsed according to
the key=value pair formatting convention.

Note that this is not part of the formal URI grammar, merely a common parsing
convention — see [RFC 3986](https://tools.ietf.org/html/rfc3986#section-3.4).
"""
queryparams(uri::URI) = queryparams(uri.query)

function queryparams(q::AbstractString)
    Dict{String,String}(unescapeuri(decodeplus(k)) => unescapeuri(decodeplus(v))
                        for (k,v) in ([split(e, "=")..., ""][1:2]
                                      for e in split(q, "&", keepempty=false)))
end

# Validate known URI formats
const uses_authority = ["https", "http", "ws", "wss", "hdfs", "ftp", "gopher", "nntp", "telnet", "imap", "wais", "file", "mms", "shttp", "snews", "prospero", "rtsp", "rtspu", "rsync", "svn", "svn+ssh", "sftp" ,"nfs", "git", "git+ssh", "ldap", "s3"]
const non_hierarchical = ["gopher", "hdl", "mailto", "news", "telnet", "wais", "imap", "snews", "sip", "sips"]
const uses_query = ["http", "wais", "imap", "https", "shttp", "mms", "gopher", "rtsp", "rtspu", "sip", "sips", "ldap"]
const uses_fragment = ["hdfs", "ftp", "hdl", "http", "gopher", "news", "nntp", "wais", "https", "shttp", "snews", "file", "prospero"]

"checks if a `URI` is valid"
function Base.isvalid(uri::URI)
    sch = uri.scheme
    isempty(sch) && throw(ArgumentError("can not validate relative URI"))
    if ((sch in non_hierarchical) && (i = findfirst(isequal('/'), uri.path); i !== nothing && i > 1)) ||       # path hierarchy not allowed
       (!(sch in uses_query) && !isempty(uri.query)) ||                    # query component not allowed
       (!(sch in uses_fragment) && !isempty(uri.fragment)) ||              # fragment identifier component not allowed
       (!(sch in uses_authority) && (!isempty(uri.host) || ("" != uri.port) || !isempty(uri.userinfo))) # authority component not allowed
        return false
    end
    return true
end

# RFC3986 Unreserved Characters (and '~' Unsafe per RFC1738).
@inline issafe(c::Char) = c == '-' ||
                          c == '.' ||
                          c == '_' ||
                          (isascii(c) && (isletter(c) || isnumeric(c)))

"""
    _bytes(s::String)

Get a `Vector{UInt8}`, a vector of bytes of a string.
"""
function _bytes end
_bytes(s::SubArray{UInt8}) = unsafe_wrap(Array, pointer(s), length(s))

_bytes(s::Union{Vector{UInt8}, Base.CodeUnits}) = _bytes(String(s))
_bytes(s::String) = codeunits(s)
_bytes(s::SubString{String}) = codeunits(s)

_bytes(s::Vector{UInt8}) = s


utf8_chars(str::AbstractString) = (Char(c) for c in _bytes(str))

"""
    escapeuri(x)

Apply URI percent-encoding to escape special characters in `x`.
"""
function escapeuri end

escapeuri(c::Char) = string('%', uppercase(string(Int(c), base=16, pad=2)))
escapeuri(str::AbstractString, safe::Function=issafe) =
    join(safe(c) ? c : escapeuri(c) for c in utf8_chars(str))

escapeuri(bytes::Vector{UInt8}) = bytes
escapeuri(v::Number) = escapeuri(string(v))
escapeuri(v::Symbol) = escapeuri(string(v))

"""
    escapeuri(key, value)
    escapeuri(query_vals)

Percent-encode and concatenate a value pair(s) as they would conventionally be
encoded within the query part of a URI.
"""
escapeuri(key, value) = string(escapeuri(key), "=", escapeuri(value))
escapeuri(key, values::Vector) = escapeuri(key => v for v in values)
escapeuri(query) = isempty(query) ? absent : join((escapeuri(k, v) for (k,v) in query), "&")
escapeuri(nt::NamedTuple) = escapeuri(pairs(nt))

decodeplus(q) = replace(q, '+' => ' ')

"""
    unescapeuri(str)

Percent-decode a string according to the URI escaping rules.
"""
function unescapeuri(str)
    occursin("%", str) || return str
    out = IOBuffer()
    i = 1
    io = IOBuffer(str)
    while !eof(io)
        c = read(io, Char)
        if c == '%'
            c1 = read(io, Char)
            c = read(io, Char)
            write(out, parse(UInt8, string(c1, c); base=16))
        else
            write(out, c)
        end
    end
    return String(take!(out))
end

ispathsafe(c::Char) = c == '/' || issafe(c)
"""
    escapepath(path)

Escape the path portion of a URI, given the string `path` containing embedded
`/` characters which separate the path segments.
"""
escapepath(path) = escapeuri(path, ispathsafe)

"""
Splits the path into components
See: http://tools.ietf.org/html/rfc3986#section-3.3
"""
function splitpath(p::AbstractString)
    elems = String[]
    len = length(p)
    len > 1 || return elems
    start_ind = i = ifelse(p[1] == '/', 2, 1)
    while true
        c = p[i]
        if c == '/'
            push!(elems, p[start_ind:i-1])
            start_ind = i + 1
        elseif i == len
            push!(elems, p[start_ind:i])
        end
        i += 1
        (i > len || c in ('?', '#')) && break
    end
    return elems
end

"""
    URIs.normpath(url)

Normalize the path portion of a URI by removing dot segments.

Refer to:
* https://tools.ietf.org/html/rfc3986#section-5.2.4
"""
normpath(url::URI) =
    URI(scheme=url.scheme, userinfo=url.userinfo, host=url.host, port=url.port,
        path=normpath(url.path), query=url.query, fragment=url.fragment)

function normpath(p::AbstractString)
    if isempty(p) || p == "/"
        return p
    elseif p == "." || p == ".."
        return "/"
    end
    buf = String[]
    for part in splitpath(p)
        if part == "."
            continue
        elseif part == ".."
            isempty(buf) || pop!(buf)
        else
            push!(buf, part)
        end
    end
    out = join(buf, '/')
    # Preserve leading and trailing slashes if present, but don't duplicate them
    if startswith(p, '/') && !startswith(out, '/')
        out = "/" * out
    end
    if (endswith(p, '/') || endswith(p, '.')) && !endswith(out, '/')
        out *= "/"
    end
    out
end

absuri(u, context) = absuri(URI(u), URI(context))

"""
    absuri(uri, context)

Construct an absolute URI, using `uri.path` and `uri.query` and filling in
other components from `context`.
"""
function absuri(uri::URI, context::URI)

    if !isempty(uri.host)
        return uri
    end

    @assert !isempty(context.scheme)
    @assert !isempty(context.host)
    @assert isempty(uri.port)

    if !(context.scheme in ["http", "https"]) || isempty(uri.path) || uri.path[1] == '/'
        path = String(uri.path)
    else
        # > The "Location" header field is used to identify a newly created resource, or to redirect the recipient to a different location for completion of the request.
        # > The field value consists of a single URI-reference. When it has the form of a relative reference ([RFC3986], Section 4.2), the final value is computed by resolving it against the effective request URI ([RFC3986], Section 5).
        # Sources:
        # 1. https://greenbytes.de/tech/webdav/draft-ietf-httpbis-p2-semantics-17.html#header.location
        # 2. https://web.archive.org/web/20200926022629/https://greenbytes.de/tech/webdav/draft-ietf-httpbis-p2-semantics-17.html
        # 3. https://www.rfc-editor.org/rfc/rfc3986.html#section-4.2
        # 4. https://web.archive.org/web/20201106144353/https://www.rfc-editor.org/rfc/rfc3986.html#section-4.2
        # 5. https://www.rfc-editor.org/rfc/rfc3986.html#section-5
        # 6. https://web.archive.org/web/20201106144353/https://www.rfc-editor.org/rfc/rfc3986.html#section-5
        path = String(uristring(normpath(joinpath(URI(; path = context.path), "..", String(uri.path)))))
    end

    return URI(context; path=path, query=uri.query)
end

"""
    joinpath(uri, path) -> URI

Join the path component of URI and other parts.
"""
function Base.joinpath(uri::URI, parts::String...)
    path = uri.path
    for p in parts
        if startswith(p, '/')
            path = p
        elseif isempty(path) || endswith(path, '/')
            path *= p
        else
            path *= "/" * p
        end
    end

    if isempty(uri.path)
        path = "/" * path
    end
    return URI(uri; path=normpath(path))
end

function __init__()
    Threads.resize_nthreads!(uri_reference_regex)
    foreach(x -> Base.compile(x.re), uri_reference_regex)
    foreach(initialize!, uri_reference_regex)
    return
end

include("deprecate.jl")

end # module
