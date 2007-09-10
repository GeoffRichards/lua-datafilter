require "datafilter-test"
local Filter = require "data.filter"
local testcase = TestCase("Different output methods in OO API")

local big_expected = ("YWJjZGVmZ2hpamts"):rep(8192)

function testcase:test_output_string_repeatedly ()
    local obj = Filter:new("base64_encode")
    obj:add("foobar")
    obj:add("and some more")
    for _ = 1, 10 do
        is("Zm9vYmFyYW5kIHNvbWUgbW9yZQ==", obj:result())
    end
end

function testcase:test_output_simple_big ()
    local input = ("abcdefghijkl"):rep(8192)
    local got = Filter.base64_encode(input)
    is(131072, got:len())
    is(big_expected, got)
end

function testcase:test_output_string_big ()
    local obj = Filter:new("base64_encode")
    -- This should force it to reallocate the buffer.  The default buffer is
    -- likely to be in the region of 8Kb, the result of this will be 128Kb.
    for _ = 1, 8192 do obj:add("abcdefghijkl") end
    is(131072, obj:result():len())
    is(big_expected, obj:result())
end

function testcase:test_output_filename ()
    local tmpname = os.tmpname()
    local obj = Filter:new("base64_encode", tmpname)
    obj:add("foobar")
    obj:add("and some more")
    obj:finish()
    is("Zm9vYmFyYW5kIHNvbWUgbW9yZQ==", read_file(tmpname))
    assert(os.remove(tmpname))
end

function testcase:test_output_filename_big ()
    local tmpname = os.tmpname()
    local obj = Filter:new("base64_encode", tmpname)
    for _ = 1, 8192 do obj:add("abcdefghijkl") end
    obj:finish()
    local got = read_file(tmpname)
    is(131072, got:len())
    is(big_expected, got)
    assert(os.remove(tmpname))
end

lunit.run()
-- vi:ts=4 sw=4 expandtab
