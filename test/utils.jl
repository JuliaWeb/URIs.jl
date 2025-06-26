good_patterns = ["foo", "foo.bar", "oldcommit..newcommit"]

for pattern in good_patterns
    @test !URIs.contains_path_traversal(pattern)
end

bad_patterns = [
    "..foo"   ,
    "foo.."   ,
    "../"     ,
    "..\\"    ,
    "/.."     ,
    "\\.."    ,
    "./"      ,
    ".\\"     ,
    "/./"     ,
    "\\.\\"   ,
]

for pattern in bad_patterns
    @test URIs.contains_path_traversal(pattern)
end

good_urls = [
    URI("https://foo.bar:1234/p1/p2/p3?q1=1#fragment"),
    URI("https://foo.bar:1234/p1/b1..b2/p3?q1=1#fragment"),
    URI("https://foo.bar:1234/p1/p2/p3?q1=1#frag..ment"),
    URI("https://foo.bar:1234/p1/p2/p3?q1=va..ue#frag..ment"),
    URI("https://foo.bar:1234/p1/p2/p3?q1=value/with/path#frag/ment"),
]

for url in good_urls
    @test !URIs.contains_path_traversal(url)
end

bad_urls = [
    URI("https://foo.bar:1234/../p1/p2/p3?q1=1#fragment"),
    URI("https://foo.bar:1234/p1/p2/..?q1=1#fragment"),
    URI("https://foo.bar:1234/..?q1=1#fragment"),
    URI("https://foo.bar:1234/p1/../p3?q1=1#fragment"),
    URI("https://foo.bar:1234/p1/../../p3?q1=1#fragment"),
    URI("https://foo.bar:1234/p1/./p3?q1=1#fragment"),
    URI("https://foo.bar:1234/p1\\.\\p3?q1=1#fragment"),
    URI("https://foo.bar:1234/p1\\.."),
    URI("https://foo.bar:1234/p1\\p2\\.."),
    URI("https://foo.bar:1234/p1/p2\\..p3"),
]

for url in bad_urls
    @test URIs.contains_path_traversal(url)
end
