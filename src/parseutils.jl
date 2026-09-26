# Each task or thread owns its match buffer and releases it when collected.
mutable struct RegexAndMatchData
    re::Regex
    match_data::Ptr{Cvoid}
    function RegexAndMatchData(re::Regex)
        Base.compile(re)
        owner = new(re, Base.PCRE.create_match_data(re.regex))
        finalizer(owner) do x
            Base.PCRE.free_match_data(x.match_data)
        end
        return owner
    end
end

"""
Execute a regular expression without the overhead of `Base.Regex`
"""
exec(re::RegexAndMatchData, bytes, offset::Int=1) =
    GC.@preserve re Base.PCRE.exec(re.re.regex, bytes, offset-1, re.re.match_options, re.match_data)

"""
`SubString` containing the bytes following the matched regular expression.
"""
nextbytes(re::RegexAndMatchData, bytes) =
    GC.@preserve re SubString(bytes, unsafe_load(Base.PCRE.ovec_ptr(re.match_data), 2) + 1)

"""
`SubString` containing a regular expression match group.
"""
function group(i, re::RegexAndMatchData, bytes)
    GC.@preserve re begin
        p = Base.PCRE.ovec_ptr(re.match_data)
        SubString(bytes, unsafe_load(p, 2i+1) + 1, prevind(bytes, unsafe_load(p, 2i+2) + 1))
    end
end

function group(i, re::RegexAndMatchData, bytes, default)
    GC.@preserve re begin
        p = Base.PCRE.ovec_ptr(re.match_data)
        return unsafe_load(p, 2i+1) == Base.PCRE.UNSET ? default :
            SubString(bytes, unsafe_load(p, 2i+1) + 1, prevind(bytes, unsafe_load(p, 2i+2) + 1))
    end
end
