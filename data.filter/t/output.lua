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
    assert_error("output sent elsewhere", function () obj:result() end)
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

function testcase:test_output_function ()
    local got = ""
    local func = function (data) got = got .. data end
    local obj = Filter:new("base64_encode", func)
    obj:add("foobar")
    obj:add("and some more")
    obj:finish()
    is("Zm9vYmFyYW5kIHNvbWUgbW9yZQ==", got)
    assert_error("output sent elsewhere", function () obj:result() end)
end

function testcase:test_output_function_big ()
    local got = ""
    local func = function (data) got = got .. data end
    local obj = Filter:new("base64_encode", func)
    for _ = 1, 8192 do obj:add("abcdefghijkl") end
    obj:finish()
    is(131072, got:len())
    is(big_expected, got)
end

function testcase:test_output_function_error ()
    local func = function (data) error"grumpy callback function" end
    local obj = Filter:new("base64_encode", func)
    obj:add("foo")
    assert_error("callback throws exception", function () obj:finish() end)
end

function testcase:test_bad_usage ()
    assert_error("too many args",
                 function () Filter:new("md5", nil, "foo") end)
    assert_error("invalid algo name", function () Filter:new("md5\0foo") end)
    assert_error("unknown algo name", function () Filter:new("erinaceous") end)
    assert_error("invalid output file name",
                 function () Filter:new("md5", "tmpname\0foo") end)
    assert_error("error opening output file",
                 function () Filter:new("md5", "t") end)

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

    obj = Filter:new("md5", function () end)
    obj:add("foo")
    obj:finish()
    assert_error("calling finish twice", function () obj:finish() end)
end

lunit.run()
-- vi:ts=4 sw=4 expandtab
