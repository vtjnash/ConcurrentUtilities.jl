using ConcurrentUtilities
using Test

@testset "ConcurrentStack: simple" begin
    stack = ConcurrentStack{Int}()
    xs = 1:10
    foldl(push!, xs; init = stack)
    @test [pop!(stack) for _ in xs] == reverse(xs)
    @test pop!(stack) === nothing
end

function pushpop(xs, ntasks = Threads.nthreads())
    stack = ConcurrentStack{eltype(xs)}()
    local tasks
    done = Threads.Atomic{Bool}(false)
    try
        tasks = map(1:ntasks) do _
            Threads.@spawn begin
                local ys = eltype(xs)[]
                while true
                    r = pop!(stack)
                    if r === nothing
                        done[] && break
                        continue
                    end
                    push!(ys, r)
                end
                ys
            end
        end
        for x in xs
            push!(stack, x)
        end
    finally
        done[] = true
    end
    return fetch.(tasks), stack
end

function test_random_push_pop(T::Type, xs = 1:2^10)
    if T !== eltype(xs)
        xs = collect(T, xs)
    end
    yss, _ = pushpop(xs)
    @test all(allunique, yss)
    @debug "pushpop(xs)" length.(yss)
    ys = sort!(foldl(append!, yss; init = T[]))
    @debug "pushpop(xs)" setdiff(ys, xs) setdiff(xs, ys) length(xs) length(ys)
    @test ys == xs
end

@testset "ConcurrentStack: random push/pop" begin
    @testset for T in [Int, Any, Int, Any]
        test_random_push_pop(T)
    end
end
