good_patterns = ["foo", "foo.bar", "oldcommit..newcommit"]

for pattern in good_patterns
    @test !URIs.contains_path_traversal(pattern)
end

bad_patterns = [
    "..foo",
    "foo.."
    "../",
    "..\\",
    "/..",
    "\\..",
    "./",
    ".\\",
    "/./",
    "\\.\\",
]

for pattern in bad_patterns
    @test URIs.contains_path_traversal(pattern)
end
