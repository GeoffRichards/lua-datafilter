local _ENV = TEST_CASE "test.qp"

local x70 = ("x"):rep(70)

-- This test data was borrowed from the Perl module MIME::Base64 version 3.07.
local mapping_both_ways = {
    -- plain ascii should not be encoded
    [""] = "",
    ["quoted printable"]  =
        "quoted printable=\13\10",

    -- 8-bit chars should be encoded
    ["v\229re kj\230re norske tegn b\248r \230res"] =
        "v=E5re kj=E6re norske tegn b=F8r =E6res=\13\10",

    -- trailing space should be encoded
    ["  "] = " =20=\13\10",
    ["\tt\t"] = "\tt=09=\13\10",
    ["test  \ntest\n\t \t \n"] = "test =20\13\10test\13\10\t \t=20\13\10",

    -- "=" is special an should be decoded
    ["=30\n"] = "=3D30\13\10",
    ["\0\2550"] = "=00=FF0=\13\10",

    -- Very long lines should be broken (not more than 76 chars
    ["The Quoted-Printable encoding is intended to represent data that largly consists of octets that correspond to printable characters in the ASCII character set."] =
        "The Quoted-Printable encoding is intended to represent data that largly con=\13\10" ..
        "sists of octets that correspond to printable characters in the ASCII charac=\13\10" ..
        "ter set.=\13\10",

    -- Long lines after short lines were broken through 2.01.
    ["short line\10" ..
     "In America, any boy may become president and I suppose that's just one of the risks he takes. -- Adlai Stevenson"] =
        "short line\13\10" ..
        "In America, any boy may become president and I suppose that's just one of t=\13\10" ..
        "he risks he takes. -- Adlai Stevenson=\13\10",

    -- My (roderick@argon.org) first crack at fixing that bug failed for
    -- multiple long lines.
    ["College football is a game which would be much more interesting if the faculty played instead of the students, and even more interesting if the\n" ..
        "trustees played.  There would be a great increase in broken arms, legs, and necks, and simultaneously an appreciable diminution in the loss to humanity. -- H. L. Mencken"] =
        "College football is a game which would be much more interesting if the facu=\13\10" ..
        "lty played instead of the students, and even more interesting if the\13\10" ..
        "trustees played.  There would be a great increase in broken arms, legs, and=\13\10" ..
        " necks, and simultaneously an appreciable diminution in the loss to humanit=\13\10" ..
        "y. -- H. L. Mencken=\13\10",

    -- Don't break a line that's near but not over 76 chars.
    [x70.."!23"]       = x70.."!23=\13\10",
    [x70.."!234"]      = x70.."!234=\13\10",
    [x70.."!2345"]     = x70.."!2345=\13\10",
    [x70.."!23456"]    = x70.."!2345=\13\10".."6=\13\10",
    [x70.."!234567"]   = x70.."!2345=\13\10".."67=\13\10",
    [x70.."!23456="]   = x70.."!2345=\13\10".."6=3D=\13\10",
    [x70.."!23\n"]     = x70.."!23\13\10",
    [x70.."!234\n"]    = x70.."!234\13\10",
    [x70.."!2345\n"]   = x70.."!2345\13\10",
    [x70.."!23456\n"]  = x70.."!23456\13\10",
    [x70.."!234567\n"] = x70.."!2345=\13\10".."67\13\10",
    [x70.."!23456=\n"] = x70.."!2345=\13\10".."6=3D\13\10",

    -- Not allowed to break =XX escapes using soft line break
    [x70.."===xxxxx"]  = x70.."=3D=\13\10=3D=3Dxxxxx=\13\10",
    [x70.."!===xxxx"]  = x70.."!=3D=\13\10=3D=3Dxxxx=\13\10",
    [x70.."!2===xxx"]  = x70.."!2=3D=\13\10=3D=3Dxxx=\13\10",
    [x70.."!23===xx"]  = x70.."!23=\13\10=3D=3D=3Dxx=\13\10",
    [x70.."!234===x"]  = x70.."!234=\13\10=3D=3D=3Dx=\13\10",
    [x70.."!2=\n"]     = x70.."!2=3D\13\10",
    [x70.."!23=\n"]    = x70.."!23=3D\13\10",
    [x70.."!234=\n"]   = x70.."!234=\13\10=3D\13\10",
    [x70.."!2345=\n"]  = x70.."!2345=\13\10=3D\13\10",
    [x70.."!23456=\n"] = x70.."!2345=\13\10".."6=3D\13\10",
    --                               ^
    --                       70123456|
    --                              max
    --                           line width

    -- some extra special cases we have had problems with
    [x70.."!2=x=x"] = x70.."!2=3D=\13\10x=3Dx=\13\10",
    [x70.."!2345"..x70.."!2345"..x70.."!23456\n"]
        = x70.."!2345=\13\10"..x70.."!2345=\13\10"..x70.."!23456\13\10",

    -- trailing whitespace
    ["foo \t "] = "foo \t=20=\13\10",
    ["foo\t \10 \t"] = "foo\t=20\13\10 =09=\13\10",
}

local mapping_encoded_to_decoded = {
    -- Some extra testing for a case that was wrong until libwww-perl-5.09
    ["foo  \n\nfoo =\n\nfoo=20\n\n"] = "foo\n\nfoo \nfoo \n\n",

    -- Same test but with "\r\n" terminated lines
    ["foo  \r\n\r\nfoo =\r\n\r\nfoo=20\r\n\r\n"] = "foo\n\nfoo \nfoo \n\n",

    -- Trailing whitespace
    ["foo  "] = "foo  ",
    ["foo  \n"] = "foo\n",
    ["foo = \t\32\nbar\t\32\n"] = "foo bar\n",
    ["foo = \t\32\r\nbar\t\32\r\n"] = "foo bar\n",
    ["foo = \t\32\n"] = "foo ",
    ["foo = \t\32\r\n"] = "foo ",
    ["foo = \t\32y\r\n"] = "foo = \t\32y\n",
    ["foo =xy\n"] = "foo =xy\n",
}

function test_encode ()
    for input, expected in pairs(mapping_both_ways) do
        is(expected, Filter.qp_encode(input),
           "encode value " .. string.format("%q", input))
    end
end

function test_decode ()
    for expected, input in pairs(mapping_both_ways) do
        is(expected, Filter.qp_decode(input),
           "decode value " .. string.format("%q", input))
    end
end

function test_alternate_line_break ()
    is(x70.."!2345=***"..x70.."***",
       Filter.qp_encode(x70.."!2345"..x70.."\n", { line_ending = "***" }))
end

function test_no_line_breaks ()
--    is(x70.."!2345"..x70.."=0A",
--       Filter.qp_encode(x70.."!2345"..x70.."\n", { line_ending = "" }))
end

-- Test binary encoding
--"foo", undef, 1) eq "foo=\n";
--"foo\nbar\r\n", undef, 1) eq "foo=0Abar=0D=0A=\n";
--join("", map chr, 0..255), undef, 1) eq <<'EOT';
--=00=01=02=03=04=05=06=07=08=09=0A=0B=0C=0D=0E=0F=10=11=12=13=14=15=16=17=18=
--=19=1A=1B=1C=1D=1E=1F !"#$%&'()*+,-./0123456789:;<=3D>?@ABCDEFGHIJKLMNOPQRS=
--TUVWXYZ[\]^_`abcdefghijklmnopqrstuvwxyz{|}~=7F=80=81=82=83=84=85=86=87=88=
--=89=8A=8B=8C=8D=8E=8F=90=91=92=93=94=95=96=97=98=99=9A=9B=9C=9D=9E=9F=A0=A1=
--=A2=A3=A4=A5=A6=A7=A8=A9=AA=AB=AC=AD=AE=AF=B0=B1=B2=B3=B4=B5=B6=B7=B8=B9=BA=
--=BB=BC=BD=BE=BF=C0=C1=C2=C3=C4=C5=C6=C7=C8=C9=CA=CB=CC=CD=CE=CF=D0=D1=D2=D3=
--=D4=D5=D6=D7=D8=D9=DA=DB=DC=DD=DE=DF=E0=E1=E2=E3=E4=E5=E6=E7=E8=E9=EA=EB=EC=
--=ED=EE=EF=F0=F1=F2=F3=F4=F5=F6=F7=F8=F9=FA=FB=FC=FD=FE=FF=
--EOT

function test_bad_usage ()
    local options = { line_ending = true }
    assert_error("bad type for line_ending option",
                 function () Filter.qp_encode("foo", options) end)
end
