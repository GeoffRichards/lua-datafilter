require "lunit"
lunit.import "all"

is = assert_equal

function read_file (filename)
    local fh = io.open(filename, "rb")
    local data = fh:read("*all")
    fh:close()
    return data
end

-- vim:ts=4 sw=4 expandtab filetype=lua
