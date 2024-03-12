using Base64

const DATA_URI_PATTERNS = [
    r"data:(?<mediatype>[^;]+)(?:;(?<parameters>.+))?,(?<data>.+)",
    r"data:,(?<data>.+)"
]

"""
    DataURI(; mediatype="", encode=false, data="")
    DataURI(str) = parse(DataURI, str::String)

A type representing a Data URI (e.g. a data URL scheme as defined in RFC 2397). Can be constructed from distinct parts using the various
supported keyword arguments, or from a string.
"""
struct DataURI
    uri::String
    mediatype::DataType
    isbase64::Bool
    data::SubString{String}
    parameters::Vector{Pair{String, String}}
    
end

function DataURI(; mediatype=MIME"text/plain", encoded=false, data="", parameters=Pair{String, String}[])
    base64 = encoded ? ";base64" : ""
    s_parameters = ""
    for (key, value) in parameters
        s_parameters *= ";$(key)=$(value)"
    end
    s_mediatype = string(mediatype.parameters[1])
    uri = "data:$(s_mediatype)$(s_parameters)$(base64),$(data)"
    DataURI(uri, mediatype, encoded, data, parameters)
end

function DataURI(str)
    m = match(DATA_URI_PATTERNS[1], str)
    if !isnothing(m)
        groups = m.captures
        mediatype, parameters, data = groups
        mime = MIME{Symbol(mediatype)}
        isbase64 = endswith(parameters, "base64")
        _parameters = filter(p -> p != "base64", split(parameters, ";"))
        parameters = Pair{String, String}[]
        for p in _parameters
            key, value = split(p, "=")
            push!(parameters, key => value)
        end
    else
        m = match(DATA_URI_PATTERNS[2], str)
        data, = m.captures
        mime = MIME""
        isbase64 = false
        parameters = Pair{String, String}[]
    end
    DataURI(str, mime, isbase64, data, parameters)
end

function getdata(data_uri::DataURI)
    data_uri.isbase64 ? base64decode(data_uri.data) : data_uri.data
end