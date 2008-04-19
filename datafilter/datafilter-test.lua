-- This will load the new copy of the library on Unix systems where it's built
-- with libtool.
package.cpath = ".libs/liblua-?.so;" .. package.cpath

require "lunit"

is = lunit.assert_equal

function read_file (filename)
    local fh = io.open(filename, "rb")
    local data = fh:read("*all")
    fh:close()
    return data
end

local function int (x) return x - x % 1 end

local HEX = { "0","1","2","3","4","5","6","7","8","9",
              "a","b","c","d","e","f" }
function bytes_to_hex (s)
    local hex = ""
    for i = 1, s:len() do
        local byte = string.byte(s, i)
        hex = hex .. HEX[int(byte / 16) + 1] .. HEX[int(byte % 16) + 1]
    end
    return hex
end

-- vi:ts=4 sw=4 expandtab
