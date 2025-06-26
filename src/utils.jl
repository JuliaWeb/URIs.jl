contains_path_traversal(url::URI) = contains_path_traversal(url.path)
function contains_path_traversal(url::AbstractString)
    # Patterns:
    # ../, ..\, /.., \.., ./, .\, /./, \.\
    PATH_TRAVERSAL = r"(?:^\.{2,}|\.{2,}$|\.{2,}[\/\\]|\.{1,}[\/\\]|[\/\\]\.{2,}|[\/\\]\.{1,}[\/\\])"
    if occursin(PATH_TRAVERSAL, url)
        return true
    end

    return false
end
