require "datafilter-test"
local Filter = require "datafilter"
local testcase = TestCase("Option passing protocols")

function testcase:test_module_metadata ()
    is("string", type(Filter._VERSION))
    assert(Filter._VERSION:len() > 0)
    is("datafilter", Filter._NAME)
end

function testcase:test_ignored_options_simple ()
    local input = "foo"
    local expected = "acbd18db4cc2f85cedef654fccc4a4d8"
    is(expected, bytes_to_hex(Filter.md5(input)))
    is(expected, bytes_to_hex(Filter.md5(input, nil)))
    is(expected, bytes_to_hex(Filter.md5(input, {})))
    is(expected, bytes_to_hex(Filter.md5(input, { foo = 23, bar = "baz" })))
end

local function do_md5_simple (...)
    return bytes_to_hex(Filter.md5(...))
end

function testcase:test_ignored_options_oo ()
    local input = "foo"
    local expected = "acbd18db4cc2f85cedef654fccc4a4d8"
    is(expected, do_md5_simple(input))
    is(expected, do_md5_simple(input, nil))
    is(expected, do_md5_simple(input, {}))
    is(expected, do_md5_simple(input, { foo = 23, bar = "baz" }))
end

function testcase:test_bad_useage_simple ()
    assert_error("not enough args", function () Filter.md5() end)
    assert_error("too many args", function () Filter.md5(input, nil, true) end)
    assert_error("bad options value (true)",
                 function () Filter.md5(input, true) end)
    assert_error("bad options value (false)",
                 function () Filter.md5(input, false) end)
    assert_error("bad options value (string)",
                 function () Filter.md5(input, "foo") end)
    assert_error("bad options value (num)",
                 function () Filter.md5(input, 23) end)
end

function testcase:test_bad_useage_oo ()
    assert_error("not enough args", function () Filter:new() end)
    assert_error("too many args",
                 function () Filter:new("md5", nil, nil, true) end)
    assert_error("bad options value (true)",
                 function () Filter:new("md5", nil, true) end)
    assert_error("bad options value (false)",
                 function () Filter:new("md5", nil, false) end)
    assert_error("bad options value (string)",
                 function () Filter:new("md5", nil, "foo") end)
    assert_error("bad options value (num)",
                 function () Filter:new("md5", nil, 23) end)
end

function testcase:test_exception_in_algo_oo ()
    -- I need to make sure that this exception doesn't cause a leak.
    local obj = Filter:new("base64_decode", nil,
                           { allow_whitespace = false })
    assert_error("whitespace not allowed, options passed to :new()",
                 function () obj:add("eH l6"); obj:result() end)
end

function testcase:test_handle_init_error_oo ()
    -- The non-OO version of this is tested in each algorithms tests.
    local options = { line_ending = true }
    assert_error("bad type for line_ending option",
                 function () Filter:new("base64_encode", nil, options) end)
end

lunit.run()
-- vi:ts=4 sw=4 expandtab
