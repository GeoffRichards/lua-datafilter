require "datafilter-test"
local Filter = require "datafilter"
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

function testcase:test_output_filename_write_error ()
    assert_error("trying to write to a directory",
                 function () Filter:new("base64_encode", "test") end)
end

function testcase:test_output_file_handle ()
    local tmpname = os.tmpname()
    local fh = assert(io.open(tmpname, "wb"))
    local obj = Filter:new("base64_encode", fh)
    obj:add("foobar")
    obj:add("and some more")
    obj:finish()
    fh:close()
    is("Zm9vYmFyYW5kIHNvbWUgbW9yZQ==", read_file(tmpname))
    assert_error("output sent elsewhere", function () obj:result() end)
    assert(os.remove(tmpname))
end

function testcase:test_output_file_handle_big ()
    local tmpname = os.tmpname()
    local fh = assert(io.open(tmpname, "wb"))
    local obj = Filter:new("base64_encode", fh)
    for _ = 1, 8192 do obj:add("abcdefghijkl") end
    obj:finish()
    fh:close()
    local got = read_file(tmpname)
    is(131072, got:len())
    is(big_expected, got)
    assert(os.remove(tmpname))
end

local function fake_file_handle_write (self, arg, extra)
    assert_string(arg)
    assert_nil(extra)
    self.data = self.data .. arg
    return true
end

function testcase:test_output_fake_file_handle ()
    local fh = { data = "", write = fake_file_handle_write }
    local obj = Filter:new("md5", fh)
    obj:add("foobar")
    obj:finish()
    is("3858f62230ac3c915f300c664312c63f", bytes_to_hex(fh.data))
end

function testcase:test_output_fake_file_handle_mt ()
    local fhmt = { write = fake_file_handle_write }
    fhmt.__index = fhmt
    local fh = { data = "" }
    setmetatable(fh, fhmt)
    local obj = Filter:new("md5", fh)
    obj:add("foobar")
    obj:finish()
    is("3858f62230ac3c915f300c664312c63f", bytes_to_hex(fh.data))
end

function testcase:test_output_fake_file_handle_fail ()
    local fh = { write = function () return nil, "buggerup" end }
    local obj = Filter:new("md5", fh)
    obj:add("foobar")
    assert_error("'write' method reports failure",
                 function () obj:finish() end)
end

function testcase:test_output_fake_file_handle_error ()
    local fh = { write = function () error"grumpy write method" end }
    local obj = Filter:new("md5", fh)
    obj:add("foobar")
    assert_error("'write' method dies", function () obj:finish() end)
end

function testcase:test_output_fake_file_handle_bad_write_method ()
    local fh = { data = "", write = 123 }
    assert_error("'write' method is not a function",
                 function () Filter:new("md5", fh) end)
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
                 function () Filter:new("md5", "test") end)

    local obj = Filter:new("md5", function () end)
    obj:add("foo")
    obj:finish()
    assert_error("calling finish twice", function () obj:finish() end)
end

function testcase:test_reusing_file_handle ()
    local tmpname = os.tmpname()
    local fh = assert(io.open(tmpname, "wb"))
    local obj = Filter:new("base64_encode", fh)
    obj:add("foobar")
    obj:finish()
    fh:write("\n")
    obj = Filter:new("base64_encode", fh)
    obj:add("frobnitz")
    obj:finish()
    fh:write("\n")
    fh:close()
    is("Zm9vYmFy\nZnJvYm5pdHo=\n", read_file(tmpname))
    assert(os.remove(tmpname))
end

lunit.run()
-- vi:ts=4 sw=4 expandtab
