good_patterns = ["foo", "foo.bar"]

for pattern in good_patterns
    @test !URIs.contains_path_traversal(pattern)
end

bad_patterns = ["../", "..\\", "/..", "\\..", "./", ".\\", "/./", "\\.\\"]

for pattern in bad_patterns
    @test URIs.contains_path_traversal(pattern)
end
