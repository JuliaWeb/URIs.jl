function contains_path_traversal(url)
    # Patterns:
    # ../, ..\, /.., \.., ./, .\, /./, \.\
    PATH_TRAVERSAL = r"(?:^\.{2,}|\.{2,}$|\.{2,}[\/\\]|\.{1,}[\/\\]|[\/\\]\.{2,}|[\/\\]\.{1,}[\/\\])"
    if occursin(PATH_TRAVERSAL, url)
        return true
    end

    return false
end
