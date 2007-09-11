require "datafilter-test"
local Filter = require "data.filter"
local testcase = TestCase("Different output methods in OO API")

function testcase:test_from_file ()
    local obj = Filter:new("md5")
    obj:addfile("t/data/random1.dat")
    is("a3f8e5cf50de466c81117093acace63a", bytes_to_hex(obj:result()),
       "addfile() on random1.dat")

    obj = Filter:new("md5")
    obj:addfile("t/data/random1.dat")
    obj:addfile("t/data/random1.dat")
    is("b9054bf8fd1941b722ec172efdb7015e", bytes_to_hex(obj:result()),
       "addfile() on random1.dat * 2")

    obj = Filter:new("md5")
    obj:addfile("t/data/random1.dat")
    obj:addfile("t/data/random1.dat")
    obj:addfile("t/data/random1.dat")
    is("b4950de76365266129ccad54c814fddc", bytes_to_hex(obj:result()),
       "addfile() on random1.dat * 3")
end

function testcase:test_mix_add_and_addfile ()
    local obj = Filter:new("md5")
    obj:add("string before the file")
    obj:addfile("t/data/random1.dat")
    obj:add("another string between two copies of the random chunk of data")
    obj:addfile("t/data/random1.dat")
    obj:add("some stuff at the end, and this nul should be included: \0")
    is("ef988d269b28ab947437648d63d68a56", bytes_to_hex(obj:result()),
       "addfile() on random1.dat * 2 with strings mixed in")
end

function testcase:test_bad_usage ()
    local obj = Filter:new("md5")
    obj:addfile("COPYRIGHT")
    assert_error("invalid input file name",
                 function () obj:addfile("COPYRIGHT\0foo") end)
    assert_error("error opening/reading input file",
                 function () obj:addfile("t") end)

    obj = Filter:new("md5")
    obj:add("foo")
    is("acbd18db4cc2f85cedef654fccc4a4d8", bytes_to_hex(obj:result()))
    assert_error("adding more after finished", function () obj:add("foo") end)
    assert_error("adding more from file after finished",
                 function () obj:addfile("COPYRIGHT") end)
    is("acbd18db4cc2f85cedef654fccc4a4d8", bytes_to_hex(obj:result()))
end

lunit.run()
-- vi:ts=4 sw=4 expandtab
