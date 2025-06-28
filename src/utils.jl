# Patterns:
# ../, ..\, /.., \.., ./, .\, /./, \.\
const PATH_TRAVERSAL = r"(?:^\.{2,}|\.{2,}$|\.{2,}[\/\\]|\.{1,}[\/\\]|[\/\\]\.{2,}|[\/\\]\.{1,}[\/\\])"

contains_path_traversal(url::URI) = contains_path_traversal(url.path)
contains_path_traversal(url::AbstractString) = occursin(PATH_TRAVERSAL, url)
