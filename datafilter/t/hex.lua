require "datafilter-test"
local Filter = require "datafilter"
local testcase = TestCase("Algorithms hex_lower and hex_upper")

local misc_binary_data

function testcase:test_trivial_obj ()
    local obj = Filter:new("hex_lower")
    is("", obj:result())
    obj = Filter:new("hex_upper")
    is("", obj:result())
end

function testcase:test_misc_lowercase ()
    for num, input in ipairs(misc_binary_data) do
        local expected = bytes_to_hex(input)
        is(expected, Filter.hex_lower(input),
           "lowercase hex for binary test datum " .. num)
    end
end

function testcase:test_misc_uppercase ()
    for num, input in ipairs(misc_binary_data) do
        local expected = bytes_to_hex(input):upper()
        is(expected, Filter.hex_upper(input),
           "uppercase hex for binary test datum " .. num)
    end
end

function testcase:test_single_byte_lowercase ()
    for code = 0, 255 do
        local input = string.char(code)
        local expected = bytes_to_hex(input)
        is(expected, Filter.hex_lower(input),
           "lowercase hex for single byte " .. code)
    end
end

function testcase:test_single_byte_uppercase ()
    for code = 0, 255 do
        local input = string.char(code)
        local expected = bytes_to_hex(input):upper()
        is(expected, Filter.hex_upper(input),
           "uppercase hex for single byte " .. code)
    end
end

function testcase:test_hex_big ()
    local input = ""
    for code = 0, 255 do input = input .. string.char(code) end
    local reps = 35     -- big enough to blow the input and output buffers
    input = input:rep(reps)

    local expected = bytes_to_hex(input)
    local got = Filter.hex_lower(input)
    is(reps * 256 * 2, got:len(), "lowercase hex of large amount of input")
    is(expected, got, "lowercase hex of large amount of input")

    expected = expected:upper()
    got = Filter.hex_upper(input)
    is(reps * 256 * 2, got:len(), "uppercase hex of large amount of input")
    is(expected, got, "uppercase hex of large amount of input")
end

misc_binary_data = {
    "",
    "x\0y",
    "\0\15\240\255",
}

lunit.run()
-- vi:ts=4 sw=4 expandtab
