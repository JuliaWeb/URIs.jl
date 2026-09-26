This fixture compiles and executes path normalization with runtime inputs on
Julia 1.13. It covers `URIs.normpath` for strings and URIs, and absolute-path
joining and reference resolution. It does not assert that every URIs API trims.

From the repository root:

```sh
julia --project=test/trim -e 'using Pkg; Pkg.develop(path=pwd()); Pkg.instantiate()'
julia --project=test/trim -e 'using JuliaC; JuliaC.main(ARGS)' -- --output-exe uri-normalize --project=test/trim --experimental --trim=safe test/trim/path_normalization.jl
JULIA_LOAD_CODEGEN_LIB=0 ./uri-normalize '/a/b/../c' '/a/c'
JULIA_LOAD_CODEGEN_LIB=0 ./uri-normalize './...' '...'
```
