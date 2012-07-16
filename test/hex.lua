require "datafilter-test"
local Filter = require "datafilter"

module("test.hex", lunit.testcase, package.seeall)

local misc_binary_data = {
    "",
    "x\0y",
    "\0\15\240\255",
}

function test_trivial_obj ()
    local obj = Filter:new("hex_lower")
    is("", obj:result())
    obj = Filter:new("hex_upper")
    is("", obj:result())
end

function test_misc_lowercase ()
    for num, input in ipairs(misc_binary_data) do
        local expected = bytes_to_hex(input)
        is(expected, Filter.hex_lower(input),
           "lowercase hex for binary test datum " .. num)
    end
end

function test_misc_uppercase ()
    for num, input in ipairs(misc_binary_data) do
        local expected = bytes_to_hex(input):upper()
        is(expected, Filter.hex_upper(input),
           "uppercase hex for binary test datum " .. num)
    end
end

function test_single_byte_lowercase ()
    for code = 0, 255 do
        local input = string.char(code)
        local expected = bytes_to_hex(input)
        is(expected, Filter.hex_lower(input),
           "lowercase hex for single byte " .. code)
    end
end

function test_single_byte_uppercase ()
    for code = 0, 255 do
        local input = string.char(code)
        local expected = bytes_to_hex(input):upper()
        is(expected, Filter.hex_upper(input),
           "uppercase hex for single byte " .. code)
    end
end

function test_hex_big ()
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

function test_decode_hex ()
    -- Create some test input and expected binary data that matches.
    local input = " \t\n\r "
    local expected = ""
    for code = 0, 255 do
        input = input .. string.format("%02x%02X", code, code)
        expected = expected .. string.char(code, code)
    end
    input = input .. "\n"
    for _, data in ipairs(misc_binary_data) do
        input = input .. Filter.hex_lower(data) ..
                         Filter.hex_upper(data) .. "\n"
        expected = expected .. data .. data
    end

    -- Enough repetitions to make it big enough to deal with in chunks.
    input = input:rep(100)
    expected = expected:rep(100)

    is(expected, Filter.hex_decode(input))

    -- Test for digits of the same byte separated by whitespace.
    is("xyz", Filter.hex_decode("7 87 9\n7\na\n"))

    -- Check empty input.
    is("", Filter.hex_decode(""))
    is("", Filter.hex_decode(" \n\t \r "))
end

function test_decode_hex_bad ()
    assert_error("bad character instead of first digit",
                 function () Filter.hex_decode("01 *3 78") end)
    assert_error("bad character instead of second digit",
                 function () Filter.hex_decode("01 2* 78") end)
    assert_error("odd number of digits",
                 function () Filter.hex_decode("01 23 7 ") end)
end

-- vi:ts=4 sw=4 expandtab
