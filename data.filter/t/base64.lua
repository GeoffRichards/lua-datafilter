require "datafilter-test"
local Filter = require "data.filter"
local testcase = TestCase("Algorithms base64_decode and base64_encode")

local misc_mapping
local single_byte_mapping

function testcase:test_trivial_obj ()
    local obj = Filter:new("base64_encode")
    is("", obj:result())
    obj = Filter:new("base64_decode")
    is("", obj:result())
end

function testcase:test_encode ()
    for input, expected in pairs(misc_mapping) do
        is(expected, Filter.base64_encode(input),
           "encode value " .. string.format("%q", input))
    end
end

function testcase:test_decode ()
    for expected, input in pairs(misc_mapping) do
        is(expected, Filter.base64_decode(input),
           "decode value " .. string.format("%q", input))
    end
end

function testcase:test_single_byte_encode ()
    for input, expected in pairs(single_byte_mapping) do
        is(expected, Filter.base64_encode(input),
           "encode single byte " .. string.format("%q", input))
    end
end

function testcase:test_single_byte_decode ()
    for expected, input in pairs(single_byte_mapping) do
        is(expected, Filter.base64_decode(input),
           "decode to single byte from " .. string.format("%q", input))
    end
end

function testcase:test_oo_encode ()
    local obj = Filter:new("base64_encode")
    obj:add("Aladdin")
    obj:add(":")
    obj:add("open sesame")
    is("QWxhZGRpbjpvcGVuIHNlc2FtZQ==", obj:result())
end

function testcase:test_no_padding ()
    for input, expected in pairs(misc_mapping) do
        expected = expected:gsub("=+$", "", 1)
        is(expected, Filter.base64_encode(input, { no_padding = true }),
           "encode value without padding " .. string.format("%q", input))
    end
end

local function test_with_line_breaking (line_ending)
    for max_line_len = 1, 20 do
        for input, expected in pairs(misc_mapping) do
            local dots = ("."):rep(max_line_len)
            expected = expected:gsub("(" .. dots .. ")", "%1" .. line_ending)
            if expected ~= "" and not expected:find(line_ending .. "$") then
                expected = expected .. line_ending
            end
            local got = Filter.base64_encode(input, {
                line_ending = line_ending,
                max_line_length = max_line_len,
            })
            local desc = "encode value with " .. max_line_len ..
                         " bytes per line, line ending " ..
                         string.format("%q", line_ending) .. ", input " ..
                         string.format("%q", input)
            is(expected, got, desc)
        end
    end
end

function testcase:test_eol ()
    test_with_line_breaking("\13\10")
    test_with_line_breaking("\13")
    test_with_line_breaking("\10")
    test_with_line_breaking("foobar baz")
end

function testcase:test_eol_defaults ()
    local input = ("foobar"):rep(10)
    local result = Filter.base64_encode(input)
    is(("Zm9vYmFy"):rep(10), result, "no line breaking")
    local result = Filter.base64_encode(input, { line_ending = "\10" })
    is(("Zm9vYmFy"):rep(9) .. "Zm9v\10YmFy\10", result, "default line len")
    local result = Filter.base64_encode(input, { max_line_length = 76 })
    is(("Zm9vYmFy"):rep(9) .. "Zm9v\13\10YmFy\13\10", result,
       "default line ending, explicit default line len")
    local result = Filter.base64_encode(input, { max_line_length = 40 })
    is(("Zm9vYmFy"):rep(5) .. "\13\10" .. ("Zm9vYmFy"):rep(5) .. "\13\10",
       result, "default line ending, non-default line len")

    is("ZnJvYg==", Filter.base64_encode("frob", { no_padding = false }),
       "explicit default no_padding")
end

misc_mapping = {
    -- Test data from RFC 4648, section 10
    [""] = "",
    ["f"] = "Zg==",
    ["fo"] = "Zm8=",
    ["foo"] = "Zm9v",
    ["foob"] = "Zm9vYg==",
    ["fooba"] = "Zm9vYmE=",
    ["foobar"] = "Zm9vYmFy",
    -- Example from RFC 2617, section 2
    ["Aladdin:open sesame"] = "QWxhZGRpbjpvcGVuIHNlc2FtZQ==",
}

single_byte_mapping = {
    ["\0"] = "AA==",
    ["\1"] = "AQ==",
    ["\2"] = "Ag==",
    ["\3"] = "Aw==",
    ["\4"] = "BA==",
    ["\5"] = "BQ==",
    ["\6"] = "Bg==",
    ["\7"] = "Bw==",
    ["\8"] = "CA==",
    ["\9"] = "CQ==",
    ["\10"] = "Cg==",
    ["\11"] = "Cw==",
    ["\12"] = "DA==",
    ["\13"] = "DQ==",
    ["\14"] = "Dg==",
    ["\15"] = "Dw==",
    ["\16"] = "EA==",
    ["\17"] = "EQ==",
    ["\18"] = "Eg==",
    ["\19"] = "Ew==",
    ["\20"] = "FA==",
    ["\21"] = "FQ==",
    ["\22"] = "Fg==",
    ["\23"] = "Fw==",
    ["\24"] = "GA==",
    ["\25"] = "GQ==",
    ["\26"] = "Gg==",
    ["\27"] = "Gw==",
    ["\28"] = "HA==",
    ["\29"] = "HQ==",
    ["\30"] = "Hg==",
    ["\31"] = "Hw==",
    ["\32"] = "IA==",
    ["\33"] = "IQ==",
    ["\34"] = "Ig==",
    ["\35"] = "Iw==",
    ["\36"] = "JA==",
    ["\37"] = "JQ==",
    ["\38"] = "Jg==",
    ["\39"] = "Jw==",
    ["\40"] = "KA==",
    ["\41"] = "KQ==",
    ["\42"] = "Kg==",
    ["\43"] = "Kw==",
    ["\44"] = "LA==",
    ["\45"] = "LQ==",
    ["\46"] = "Lg==",
    ["\47"] = "Lw==",
    ["\48"] = "MA==",
    ["\49"] = "MQ==",
    ["\50"] = "Mg==",
    ["\51"] = "Mw==",
    ["\52"] = "NA==",
    ["\53"] = "NQ==",
    ["\54"] = "Ng==",
    ["\55"] = "Nw==",
    ["\56"] = "OA==",
    ["\57"] = "OQ==",
    ["\58"] = "Og==",
    ["\59"] = "Ow==",
    ["\60"] = "PA==",
    ["\61"] = "PQ==",
    ["\62"] = "Pg==",
    ["\63"] = "Pw==",
    ["\64"] = "QA==",
    ["\65"] = "QQ==",
    ["\66"] = "Qg==",
    ["\67"] = "Qw==",
    ["\68"] = "RA==",
    ["\69"] = "RQ==",
    ["\70"] = "Rg==",
    ["\71"] = "Rw==",
    ["\72"] = "SA==",
    ["\73"] = "SQ==",
    ["\74"] = "Sg==",
    ["\75"] = "Sw==",
    ["\76"] = "TA==",
    ["\77"] = "TQ==",
    ["\78"] = "Tg==",
    ["\79"] = "Tw==",
    ["\80"] = "UA==",
    ["\81"] = "UQ==",
    ["\82"] = "Ug==",
    ["\83"] = "Uw==",
    ["\84"] = "VA==",
    ["\85"] = "VQ==",
    ["\86"] = "Vg==",
    ["\87"] = "Vw==",
    ["\88"] = "WA==",
    ["\89"] = "WQ==",
    ["\90"] = "Wg==",
    ["\91"] = "Ww==",
    ["\92"] = "XA==",
    ["\93"] = "XQ==",
    ["\94"] = "Xg==",
    ["\95"] = "Xw==",
    ["\96"] = "YA==",
    ["\97"] = "YQ==",
    ["\98"] = "Yg==",
    ["\99"] = "Yw==",
    ["\100"] = "ZA==",
    ["\101"] = "ZQ==",
    ["\102"] = "Zg==",
    ["\103"] = "Zw==",
    ["\104"] = "aA==",
    ["\105"] = "aQ==",
    ["\106"] = "ag==",
    ["\107"] = "aw==",
    ["\108"] = "bA==",
    ["\109"] = "bQ==",
    ["\110"] = "bg==",
    ["\111"] = "bw==",
    ["\112"] = "cA==",
    ["\113"] = "cQ==",
    ["\114"] = "cg==",
    ["\115"] = "cw==",
    ["\116"] = "dA==",
    ["\117"] = "dQ==",
    ["\118"] = "dg==",
    ["\119"] = "dw==",
    ["\120"] = "eA==",
    ["\121"] = "eQ==",
    ["\122"] = "eg==",
    ["\123"] = "ew==",
    ["\124"] = "fA==",
    ["\125"] = "fQ==",
    ["\126"] = "fg==",
    ["\127"] = "fw==",
    ["\128"] = "gA==",
    ["\129"] = "gQ==",
    ["\130"] = "gg==",
    ["\131"] = "gw==",
    ["\132"] = "hA==",
    ["\133"] = "hQ==",
    ["\134"] = "hg==",
    ["\135"] = "hw==",
    ["\136"] = "iA==",
    ["\137"] = "iQ==",
    ["\138"] = "ig==",
    ["\139"] = "iw==",
    ["\140"] = "jA==",
    ["\141"] = "jQ==",
    ["\142"] = "jg==",
    ["\143"] = "jw==",
    ["\144"] = "kA==",
    ["\145"] = "kQ==",
    ["\146"] = "kg==",
    ["\147"] = "kw==",
    ["\148"] = "lA==",
    ["\149"] = "lQ==",
    ["\150"] = "lg==",
    ["\151"] = "lw==",
    ["\152"] = "mA==",
    ["\153"] = "mQ==",
    ["\154"] = "mg==",
    ["\155"] = "mw==",
    ["\156"] = "nA==",
    ["\157"] = "nQ==",
    ["\158"] = "ng==",
    ["\159"] = "nw==",
    ["\160"] = "oA==",
    ["\161"] = "oQ==",
    ["\162"] = "og==",
    ["\163"] = "ow==",
    ["\164"] = "pA==",
    ["\165"] = "pQ==",
    ["\166"] = "pg==",
    ["\167"] = "pw==",
    ["\168"] = "qA==",
    ["\169"] = "qQ==",
    ["\170"] = "qg==",
    ["\171"] = "qw==",
    ["\172"] = "rA==",
    ["\173"] = "rQ==",
    ["\174"] = "rg==",
    ["\175"] = "rw==",
    ["\176"] = "sA==",
    ["\177"] = "sQ==",
    ["\178"] = "sg==",
    ["\179"] = "sw==",
    ["\180"] = "tA==",
    ["\181"] = "tQ==",
    ["\182"] = "tg==",
    ["\183"] = "tw==",
    ["\184"] = "uA==",
    ["\185"] = "uQ==",
    ["\186"] = "ug==",
    ["\187"] = "uw==",
    ["\188"] = "vA==",
    ["\189"] = "vQ==",
    ["\190"] = "vg==",
    ["\191"] = "vw==",
    ["\192"] = "wA==",
    ["\193"] = "wQ==",
    ["\194"] = "wg==",
    ["\195"] = "ww==",
    ["\196"] = "xA==",
    ["\197"] = "xQ==",
    ["\198"] = "xg==",
    ["\199"] = "xw==",
    ["\200"] = "yA==",
    ["\201"] = "yQ==",
    ["\202"] = "yg==",
    ["\203"] = "yw==",
    ["\204"] = "zA==",
    ["\205"] = "zQ==",
    ["\206"] = "zg==",
    ["\207"] = "zw==",
    ["\208"] = "0A==",
    ["\209"] = "0Q==",
    ["\210"] = "0g==",
    ["\211"] = "0w==",
    ["\212"] = "1A==",
    ["\213"] = "1Q==",
    ["\214"] = "1g==",
    ["\215"] = "1w==",
    ["\216"] = "2A==",
    ["\217"] = "2Q==",
    ["\218"] = "2g==",
    ["\219"] = "2w==",
    ["\220"] = "3A==",
    ["\221"] = "3Q==",
    ["\222"] = "3g==",
    ["\223"] = "3w==",
    ["\224"] = "4A==",
    ["\225"] = "4Q==",
    ["\226"] = "4g==",
    ["\227"] = "4w==",
    ["\228"] = "5A==",
    ["\229"] = "5Q==",
    ["\230"] = "5g==",
    ["\231"] = "5w==",
    ["\232"] = "6A==",
    ["\233"] = "6Q==",
    ["\234"] = "6g==",
    ["\235"] = "6w==",
    ["\236"] = "7A==",
    ["\237"] = "7Q==",
    ["\238"] = "7g==",
    ["\239"] = "7w==",
    ["\240"] = "8A==",
    ["\241"] = "8Q==",
    ["\242"] = "8g==",
    ["\243"] = "8w==",
    ["\244"] = "9A==",
    ["\245"] = "9Q==",
    ["\246"] = "9g==",
    ["\247"] = "9w==",
    ["\248"] = "+A==",
    ["\249"] = "+Q==",
    ["\250"] = "+g==",
    ["\251"] = "+w==",
    ["\252"] = "/A==",
    ["\253"] = "/Q==",
    ["\254"] = "/g==",
    ["\255"] = "/w==",
}

lunit.run()
-- vi:ts=4 sw=4 expandtab
