local _ENV = TEST_CASE "test.addfile"

function test_from_file ()
    local obj = Filter:new("md5")
    obj:addfile("test/data/random1.dat")
    is("a3f8e5cf50de466c81117093acace63a", bytes_to_hex(obj:result()),
       "addfile() on random1.dat")

    obj = Filter:new("md5")
    obj:addfile("test/data/random1.dat")
    obj:addfile("test/data/random1.dat")
    is("b9054bf8fd1941b722ec172efdb7015e", bytes_to_hex(obj:result()),
       "addfile() on random1.dat * 2")

    obj = Filter:new("md5")
    obj:addfile("test/data/random1.dat")
    obj:addfile("test/data/random1.dat")
    obj:addfile("test/data/random1.dat")
    is("b4950de76365266129ccad54c814fddc", bytes_to_hex(obj:result()),
       "addfile() on random1.dat * 3")
end

function test_mix_add_and_addfile ()
    local obj = Filter:new("md5")
    obj:add("string before the file")
    obj:addfile("test/data/random1.dat")
    obj:add("another string between two copies of the random chunk of data")
    obj:addfile("test/data/random1.dat")
    obj:add("some stuff at the end, and this nul should be included: \0")
    is("ef988d269b28ab947437648d63d68a56", bytes_to_hex(obj:result()),
       "addfile() on random1.dat * 2 with strings mixed in")
end

function test_add_from_lua_filehandle ()
    local obj = Filter:new("md5")
    local fh = io.open("test/data/random1.dat", "rb")
    obj:addfile(fh)
    fh:close()
    is("a3f8e5cf50de466c81117093acace63a", bytes_to_hex(obj:result()))

    obj = Filter:new("md5")
    fh = io.open("test/data/random1.dat", "rb")
    obj:addfile(fh)
    obj:addfile(fh)     -- no effect, data already used up
    is("a3f8e5cf50de466c81117093acace63a", bytes_to_hex(obj:result()))
    fh:close()
end

function test_add_from_bad_lua_filehandle ()
    local obj = Filter:new("md5")
    local fh = io.open("test/data/random1.dat", "rb")
    fh:close()
    assert_error("filehandle close", function () obj:addfile(fh) end)
end

local function fake_lua_filehandle_read (self, num_bytes)
    if self.data:len() == 0 then return end     -- EOF
    if num_bytes > self.data:len() then num_bytes = self.data:len() end
    local result = self.data:sub(1, num_bytes)
    self.data = self.data:sub(num_bytes + 1)
    return result
end

function test_add_from_fake_lua_filehandle_table ()
    local data = ("foobar\n"):rep(5000)
    local fh = {
        data = ("foobar\n"):rep(5000),
        read = fake_lua_filehandle_read,
    }

    local obj = Filter:new("md5")
    obj:addfile(fh)
    is("313cf5be140c1ed898c8919454809adc", bytes_to_hex(obj:result()))
end

function test_add_from_fake_lua_filehandle_metatable ()
    local fhmt = {
        data = ("foobar\n"):rep(5000),
        read = fake_lua_filehandle_read,
    }
    fhmt.__index = fhmt
    local fh = {}
    setmetatable(fh, fhmt)

    local obj = Filter:new("md5")
    obj:addfile(fh)
    is("313cf5be140c1ed898c8919454809adc", bytes_to_hex(obj:result()))
end

function test_error_in_fake_lua_filehandle ()
    local fh = { read = function () error"grumpy file handle" end }
    local obj = Filter:new("md5")
    assert_error("file handle 'read' method dies",
                 function () obj:addfile(fh) end)
end

function test_failure_in_fake_lua_filehandle ()
    local fh = { read = function () return nil, "buggerup" end }
    local obj = Filter:new("md5")
    assert_error("file handle 'read' method indicates failure",
                 function () obj:addfile(fh) end)
end

function test_immediate_eof_in_fake_lua_filehandle ()
    local fh = { read = function () return nil end }
    local obj = Filter:new("md5")
    obj:addfile(fh)
    is("d41d8cd98f00b204e9800998ecf8427e", bytes_to_hex(obj:result()))
end

function test_number_from_fake_lua_filehandle ()
    local value = 23
    local fh = { read = function () local r = value; value = nil; return r end }
    local obj = Filter:new("md5")
    obj:addfile(fh)
    is("37693cfc748049e45d87b8c7d8b9aacd", bytes_to_hex(obj:result()))
end

function test_bad_result_from_fake_lua_filehandle ()
    local fh = { read = function () return true end }
    local obj = Filter:new("md5")
    assert_error("file handle 'read' method returns something strange",
                 function () obj:addfile(fh) end)
end

function test_bad_usage ()
    local obj = Filter:new("md5")
    obj:addfile("COPYRIGHT")
    assert_error("addfile() with no args", function () obj:addfile() end)
    assert_error("addfile() with too many args",
                 function () obj:addfile("COPYRIGHT", "extra") end)
    assert_error("addfile() with bad arg", function () obj:addfile(true) end)
    assert_error("invalid input file name",
                 function () obj:addfile("COPYRIGHT\0foo") end)
    assert_error("error opening/reading input file",
                 function () obj:addfile("test") end)

    obj = Filter:new("md5")
    obj:add("foo")
    is("acbd18db4cc2f85cedef654fccc4a4d8", bytes_to_hex(obj:result()))
    assert_error("adding more after finished", function () obj:add("foo") end)
    assert_error("adding more from file after finished",
                 function () obj:addfile("COPYRIGHT") end)
    is("acbd18db4cc2f85cedef654fccc4a4d8", bytes_to_hex(obj:result()))
end
