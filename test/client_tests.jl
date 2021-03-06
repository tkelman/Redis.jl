using Base.Test

function flatten_test()
    @test flatten("simple") == "simple"
    @test flatten(1) == "1"
    @test flatten(2.5) == "2.5"
    @test flatten([1, "2", 3.5]) == ["1", "2", "3.5"]

    s = Set({1, 5, "10.9"})
    @test Set(flatten(s)) == Set({"1", "5", "10.9"})

    d = Dict({1 => 2, 3 => 4})
    @test Set(flatten(d)) == Set({"1", "2", "3", "4"})
end

function flatten_command_test()
    result = flatten_command(1, 2, ["4", "5", 6.7], 8)
    @test result == ["1", "2", "4", "5", "6.7", "8"]
end

function convert_response_test()
    @test convert_response(Dict, ["1","2","3","4"]) == Dict({"1" => "2", "3" => "4"})
    @test convert_response(Dict, []) == Dict()
    @test_approx_eq convert_response(Float64, "12.3") 12.3
    @test_approx_eq convert_response(Float64, 10) 10.0
    @test convert_response(Bool, "OK")
    @test !convert_response(Bool, "f")
    @test convert_response(Bool, 1)
    @test convert_response(Bool, 4)
    @test !convert_response(Bool, 0)
    @test convert_response(Set, 1) == Set({1})
    @test convert_response(Set, [1,2,3]) == Set({1,2,3})
end

flatten_test()
flatten_command_test()
convert_response_test()
