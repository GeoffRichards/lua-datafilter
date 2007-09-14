require "datafilter-test"
local Filter = require "datafilter"
local testcase = TestCase("Algorithms uri_decode and uri_encode")

local default_charset_mapping

function testcase:test_empty ()
    is("", Filter.percent_encode(""))
    is("", Filter.percent_decode(""))
end

function testcase:test_encode ()
    for input, expected in pairs(default_charset_mapping) do
        is(expected, Filter.percent_encode(input),
           "encode value " .. string.format("%q", input))
    end
end

function testcase:test_decode ()
    for expected, input in pairs(default_charset_mapping) do
        is(expected, Filter.percent_decode(input),
           "decode value " .. string.format("%q", input))
    end
end

function testcase:test_encode_nondefault_safe_bytes ()
    local options = { safe_bytes = "acf" }
    is("%20a%62c%64%65f%67%25", Filter.percent_encode(" abcdefg%", options))
    options = { safe_bytes = 23 }
    is("%3123%34", Filter.percent_encode("1234", options))
end

function testcase:test_decode_hex_case_insensitive ()
    is("\171/\255\255\255", Filter.percent_decode("%ab%2f%fF%Ff%ff"))
end

function testcase:test_big ()
    for bufsize = 8185, 8194 do
        local padding = ("x"):rep(bufsize)
        is(padding .. "^\"%", Filter.percent_decode(padding .. "%5e%22%25"))
        is(padding .. "%5E%22%25", Filter.percent_encode(padding .. "^\"%"))
    end
end

function testcase:test_bad_hex_detected ()
    assert_error("no hex digits",
                 function () Filter.percent_decode("foo%", options) end)
    assert_error("only one hex digit",
                 function () Filter.percent_decode("foo%3", options) end)
    assert_error("bad first hex digit",
                 function () Filter.percent_decode("foo%G3", options) end)
    assert_error("bad second hex digit",
                 function () Filter.percent_decode("foo%3g", options) end)
end

function testcase:test_bad_usage ()
    local options = { safe_bytes = true }
    assert_error("bad value for 'safe_bytes' option",
                 function () Filter.percent_encode("x%y", options) end)
    options = { safe_bytes = "o%" }
    assert_error("can't declare '%' to be safe char",
                 function () Filter.percent_encode("x%y", options) end)
    options = { safe_bytes = "yxy" }
    assert_error("don't repeat declaration of same safe byte",
                 function () Filter.percent_encode("x%y", options) end)
end

default_charset_mapping = {
    [""] = "",
    -- All unreserved characters
    ["ABCDEFGHIJKLMNOPQRSTUVWXYZ"] = "ABCDEFGHIJKLMNOPQRSTUVWXYZ",
    ["abcdefghijklmnopqrstuvwxyz"] = "abcdefghijklmnopqrstuvwxyz",
    ["0123456789"] = "0123456789",
    ["-._~"] = "-._~",
    -- All reserved characters
    [":/?#[]@"] = "%3A%2F%3F%23%5B%5D%40",
    ["!$&'()*+,;="] = "%21%24%26%27%28%29%2A%2B%2C%3B%3D",
    -- Percent signs
    ["%%%"] = "%25%25%25",
    ["%25_%2525_%%2525"] = "%2525_%252525_%25%252525",
    -- All control characters
    ["\0\1\2\3\4\5\6\7\8\9\10\11\12\13\14\15"]
        = "%00%01%02%03%04%05%06%07%08%09%0A%0B%0C%0D%0E%0F",
    ["\16\17\18\19\20\21\22\23\24\25\26\27\28\29\30\31"]
        = "%10%11%12%13%14%15%16%17%18%19%1A%1B%1C%1D%1E%1F",
    -- Other characters, not legal in a URI
    [" a % X  X "] = "%20a%20%25%20X%20%20X%20",
    ["\"<>\\^`{|}\127"] = "%22%3C%3E%5C%5E%60%7B%7C%7D%7F",
    ["\128\129\130\131\132\133\134\135\136\137\138\139\140\141\142\143"]
        = "%80%81%82%83%84%85%86%87%88%89%8A%8B%8C%8D%8E%8F",
    ["\144\145\146\147\148\149\150\151\152\153\154\155\156\157\158\159"]
        = "%90%91%92%93%94%95%96%97%98%99%9A%9B%9C%9D%9E%9F",
    ["\160\161\162\163\164\165\166\167\168\169\170\171\172\173\174\175"]
        = "%A0%A1%A2%A3%A4%A5%A6%A7%A8%A9%AA%AB%AC%AD%AE%AF",
    ["\176\177\178\179\180\181\182\183\184\185\186\187\188\189\190\191"]
        = "%B0%B1%B2%B3%B4%B5%B6%B7%B8%B9%BA%BB%BC%BD%BE%BF",
    ["\192\193\194\195\196\197\198\199\200\201\202\203\204\205\206\207"]
        = "%C0%C1%C2%C3%C4%C5%C6%C7%C8%C9%CA%CB%CC%CD%CE%CF",
    ["\208\209\210\211\212\213\214\215\216\217\218\219\220\221\222\223"]
        = "%D0%D1%D2%D3%D4%D5%D6%D7%D8%D9%DA%DB%DC%DD%DE%DF",
    ["\224\225\226\227\228\229\230\231\232\233\234\235\236\237\238\239"]
        = "%E0%E1%E2%E3%E4%E5%E6%E7%E8%E9%EA%EB%EC%ED%EE%EF",
    ["\240\241\242\243\244\245\246\247\248\249\250\251\252\253\254\255"]
        = "%F0%F1%F2%F3%F4%F5%F6%F7%F8%F9%FA%FB%FC%FD%FE%FF",
    -- Example from RFC 2986, section 2.5
    ["\195\128_\227\130\162"] = "%C3%80_%E3%82%A2",
}

lunit.run()
-- vi:ts=4 sw=4 expandtab
