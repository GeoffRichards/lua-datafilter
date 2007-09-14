#include "datafilter.h"
#include <stdio.h>
#include <string.h>
#include <errno.h>
#include <assert.h>

#define FILTER_MT_NAME ("c3966aca-6037-11dc-9675-00e081225ce5-" VERSION)

struct Filter_;
typedef const unsigned char * (*AlgorithmFunction)
    (struct Filter_ *filter,
     const unsigned char *in, const unsigned char *in_end,
     unsigned char *out, unsigned char *out_end, int eof);
typedef unsigned char * (*FilterOutputFunc)
    (struct Filter_ *filter, const unsigned char *out_end,
     unsigned char **out_max);
typedef void (*AlgorithmDestroyFunction) (struct Filter_ *filter);

typedef struct Filter_ {
    size_t filter_object_size;
    lua_State *L;
    lua_Alloc alloc;
    void *alloc_ud;
    luaL_Buffer *lbuf;
    unsigned char *buf_in, *buf_in_end, *buf_out, *buf_out_end;
    size_t buf_in_size, buf_out_size;
    int buf_in_free;    /* true if it should be deallocated on destruction */
    AlgorithmFunction func;
    FilterOutputFunc do_output;
    AlgorithmDestroyFunction destroy_func;
    int finished;
    FILE *c_fh;
    int output_func_ref, l_fh_ref;
} Filter;

#define ALGO_STATE(filter) ((void *) (((char *) (filter)) + sizeof(Filter)))

typedef int (*AlgorithmWrapperFunction) (lua_State *L);
/*typedef size_t (*AlgorithmSizeFunction) (size_t input_size);*/
typedef int (*AlgorithmInitFunction) (Filter *filter, int options_pos);

typedef struct AlgorithmDefinition_ {
    const char *name;
    AlgorithmFunction func;
    AlgorithmWrapperFunction wrapper_func;
    /*AlgorithmSizeFunction size_func;*/
    size_t state_size;
    AlgorithmInitFunction init_func;
    AlgorithmDestroyFunction destroy_func;
} AlgorithmDefinition;

static const unsigned char default_line_ending[] = { 13, 10 };

#define EMAIL_MAX_LINE_LENGTH 76

#define my_ishex(c) (((c) >= 48 && (c) <= 57) || \
                     ((c) >= 65 && (c) <= 70) || \
                     ((c) >= 97 && (c) <= 102))
#define hex_digit_val(c) ((c) >= 48 && (c) <= 57 ? ((c) - 48) \
                        : (c) >= 65 && (c) <= 70 ? ((c) - 55) \
                                                 : ((c) - 87))

static const unsigned char
hex_char_codes_lower[16] = {
    48, 49, 50, 51, 52, 53, 54, 55, 56, 57, 97, 98, 99, 100, 101, 102
};
static const unsigned char
hex_char_codes_upper[16] = {
    48, 49, 50, 51, 52, 53, 54, 55, 56, 57, 65, 66, 67, 68, 69, 70
};

static const unsigned char *
my_strduplen (Filter *filter, const unsigned char *s, size_t len) {
    unsigned char *newstr = filter->alloc(filter->alloc_ud, 0, 0, len);
    assert(newstr);
    memcpy(newstr, s, len);
    return newstr;
}

static int
init_filter (Filter *filter, lua_State *L, const AlgorithmDefinition *def,
             int options_pos)
{
    lua_Alloc alloc;
    void *alloc_ud;
    int stacktop;

    alloc = lua_getallocf(L, &alloc_ud);

    filter->filter_object_size = sizeof(Filter) + def->state_size;
    filter->L = L;
    filter->alloc = alloc;
    filter->alloc_ud = alloc_ud;
    filter->finished = 0;
    filter->c_fh = 0;
    filter->output_func_ref = LUA_NOREF;
    filter->l_fh_ref = LUA_NOREF;

    filter->buf_out = filter->buf_in = 0;
    filter->buf_in_free = 0;
    filter->lbuf = 0;
    filter->destroy_func = 0;

    filter->buf_out = filter->buf_out_end = alloc(alloc_ud, 0, 0, BUFSIZ);
    assert(filter->buf_out);
    filter->buf_out_size = BUFSIZ;

    filter->destroy_func = def->destroy_func;
    filter->func = def->func;

    stacktop = lua_gettop(L);
    if (def->init_func && !def->init_func(filter, options_pos)) {
        /* There was an error initializing the object.  Should be an error
         * message on the top of the stack, but the init function might have
         * left other stuff below that, so tidy it away. */
        ++stacktop;
        while (lua_gettop(L) > stacktop)
            lua_remove(L, stacktop);
        return 0;
    }

    return 1;
}

static void
filter_cleanup (lua_State *L, Filter *filter) {
    if (filter->c_fh) {
        if (fclose(filter->c_fh))
            luaL_error(L, "error closing output file handle: %s",
                       strerror(errno));
        filter->c_fh = 0;
    }

    luaL_unref(L, LUA_REGISTRYINDEX, filter->output_func_ref);
    filter->output_func_ref = LUA_NOREF;
    luaL_unref(L, LUA_REGISTRYINDEX, filter->l_fh_ref);
    filter->l_fh_ref = LUA_NOREF;
}

static void
filter_finished_cleanup (lua_State *L, Filter *filter) {
    unsigned char *out_max;

    filter->finished = 1;

    out_max = filter->buf_out + filter->buf_out_size;
    if (filter->buf_out_end != filter->buf_out)
        filter->do_output(filter, filter->buf_out_end, &out_max);

    filter_cleanup(L, filter);
}

static void
add_input_data (Filter *filter, const unsigned char *data, size_t len) {
    if (len > 0) {
        memcpy(filter->buf_in_end, data, len);
        filter->buf_in_end += len;
    }
}

/* This can be used by algorithms to report an error.  They should never
 * throw an exception directly because do_filtering() needs to be able to
 * do cleanup first. */
#define ALGO_ERROR(msg) do { \
    lua_pushstring(filter->L, msg); \
    return 0; \
} while (0)

/* This returns true if there was an error, which the algorithm must have
 * place as a string at the top of the stack. */
static int
do_filtering (Filter *filter, int eof) {
    size_t bytes_left_over;
    unsigned char *left_over;

    left_over = (unsigned char *) filter->func(
        filter, filter->buf_in, filter->buf_in_end,
        filter->buf_out_end, filter->buf_out + filter->buf_out_size, eof);
    if (!left_over)
        return 1;

    if (eof) {
        assert(left_over == filter->buf_in_end);
        filter->buf_in_end = filter->buf_in;
    }
    else if (left_over != filter->buf_in) {
        bytes_left_over = filter->buf_in_end - left_over;
        if (bytes_left_over)
            memmove(filter->buf_in, left_over, bytes_left_over);
        filter->buf_in_end = filter->buf_in + bytes_left_over;
    }

    return 0;
}

static void
destroy_filter (lua_State *L, Filter *filter) {
    if (!filter->finished)
        filter_finished_cleanup(L, filter);

    if (filter->destroy_func)
        filter->destroy_func(filter);
    filter->destroy_func = 0;
    if (filter->lbuf)
        filter->alloc(filter->alloc_ud, filter->lbuf, sizeof(luaL_Buffer), 0);
    filter->lbuf = 0;
    if (filter->buf_in_free)
        filter->alloc(filter->alloc_ud, filter->buf_in, filter->buf_in_size, 0);
    filter->buf_in = 0;
    filter->alloc(filter->alloc_ud, filter->buf_out, filter->buf_out_size, 0);
    filter->buf_out = 0;
}

static unsigned char *
output_lbuf (Filter *filter, const unsigned char *out_end,
             unsigned char **out_max)
{
    (void) out_max;     /* unused - it never changes */
    assert(out_end > filter->buf_out);
    assert(out_end >= filter->buf_out_end);
    luaL_addlstring(filter->lbuf, (const char *) filter->buf_out,
                    out_end - filter->buf_out);
    return filter->buf_out_end = filter->buf_out;
}

static unsigned char *
output_string (Filter *filter, const unsigned char *out_end,
               unsigned char **out_max)
{
    size_t new_size = filter->buf_out_size * 2;
    unsigned char *out = filter->alloc(filter->alloc_ud, filter->buf_out,
                                       filter->buf_out_size, new_size);
    assert(out);
    filter->buf_out_end = out + (out_end - filter->buf_out);
    filter->buf_out = out;
    filter->buf_out_size = new_size;
    *out_max = out + new_size;
    return filter->buf_out_end;
}

static unsigned char *
output_c_fh (Filter *filter, const unsigned char *out_end,
             unsigned char **out_max)
{
    (void) out_max;     /* unused - it never changes */
    assert(out_end > filter->buf_out);
    assert(out_end >= filter->buf_out_end);
    fwrite(filter->buf_out, 1, out_end - filter->buf_out, filter->c_fh);
    return filter->buf_out_end = filter->buf_out;
}

static unsigned char *
output_lua_fh (Filter *filter, const unsigned char *out_end,
               unsigned char **out_max)
{
    lua_State *L = filter->L;
    (void) out_max;     /* unused - it never changes */
    assert(out_end > filter->buf_out);
    assert(out_end >= filter->buf_out_end);

    lua_rawgeti(L, LUA_REGISTRYINDEX, filter->l_fh_ref);
    lua_getfield(L, -1, "write");
    if (!lua_isfunction(L, -1))
        luaL_error(L, "'write' method not available on output file handle");
    lua_pushvalue(L, -2);       /* file handle as first arg */
    lua_pushlstring(L, (const char *) filter->buf_out,
                    out_end - filter->buf_out);
    lua_call(L, 2, 2);

    if (lua_isnil(L, -2)) {     /* write error, returned nil, errmsg */
        lua_pushstring(L, "error writing to output file: ");
        if (lua_isstring(L, -2))
            lua_pushvalue(L, -2);
        else
            lua_pushstring(L, "(file handle's write method didn't provide an"
                           " error message");
        lua_concat(L, 2);
        lua_error(L);
    }
    else {                      /* write ok, returned true, nil */
        lua_pop(L, 3);          /* pop return vals and file handle */
    }

    return filter->buf_out_end = filter->buf_out;
}

static unsigned char *
output_luafunc (Filter *filter, const unsigned char *out_end,
                unsigned char **out_max)
{
    (void) out_max;     /* unused - it never changes */
    assert(out_end > filter->buf_out);
    assert(out_end >= filter->buf_out_end);
    lua_rawgeti(filter->L, LUA_REGISTRYINDEX, filter->output_func_ref);
    lua_pushlstring(filter->L, (const char *) filter->buf_out,
                    out_end - filter->buf_out);
    lua_call(filter->L, 1, 0);
    return filter->buf_out_end = filter->buf_out;
}

static int
algo_wrapper (lua_State *L, const AlgorithmDefinition *def) {
    size_t len;
    unsigned char *s = (unsigned char *) luaL_checklstring(L, 1, &len);
    Filter *filter;
    lua_Alloc alloc;
    void *alloc_ud;
    int num_args = lua_gettop(L);
    int options_pos = 0;
    int had_error;

    if (num_args > 2)
        return luaL_error(L, "too many arguments to algorithm function");
    if (num_args >= 2 && !lua_isnil(L, 2)) {
        if (!lua_istable(L, 2))
            return luaL_argerror(L, 2, "options must be either nil or a table");
        options_pos = 2;
    }

    alloc = lua_getallocf(L, &alloc_ud);

    filter = alloc(alloc_ud, 0, 0, sizeof(Filter) + def->state_size);
    assert(filter);
    had_error = !init_filter(filter, L, def, options_pos);

    if (!had_error) {
        filter->buf_in = s;
        filter->buf_in_end = s + len;
        filter->buf_in_size = len;
        filter->buf_in_free = 0;

        filter->lbuf = filter->alloc(filter->alloc_ud, 0, 0,
                                     sizeof(luaL_Buffer));
        assert(filter->lbuf);
        luaL_buffinit(L, filter->lbuf);
        filter->do_output = output_lbuf;

        had_error = do_filtering(filter, 1);
    }

    filter_finished_cleanup(L, filter);
    if (!had_error)
        luaL_pushresult(filter->lbuf);

    destroy_filter(L, filter);
    filter->alloc(filter->alloc_ud, filter, filter->filter_object_size, 0);

    if (had_error)
        return lua_error(L);
    return 1;
}

#include "algo/base64.c"
#include "algo/qp.c"
#include "algo/pctenc.c"
#include "algo/md5.c"
#include "algo/sha1.c"
#include "algo/adler32.c"
#include "algo/hex.c"
#include "algorithms.c"

static int
contains_null_byte (const char *s, size_t len) {
    size_t i;

    for (i = 0; i < len; ++i) {
        if (s[i] == '\0')
            return 1;
    }

    return 0;
}

static int
filter_new (lua_State *L) {
    size_t algo_name_len, filename_len;
    const char *algo_name = luaL_checklstring(L, 2, &algo_name_len);
    const char *filename;
    unsigned int i;
    const AlgorithmDefinition *def;
    Filter *filter;
    int num_args = lua_gettop(L);
    int arg_type;
    int options_pos = 0;

    luaL_argcheck(L, !contains_null_byte(algo_name, algo_name_len), 2,
                  "invalid algorithm name");

    if (num_args > 4)
        return luaL_error(L, "too many arguments to datafilter:new()");

    /* Find the definition of the named algorithm. */
    def = filter_algorithms;
    for (i = 0; i < NUM_ALGO_DEFS; ++i, ++def) {
        if (!strcmp(def->name, algo_name))
            break;
    }
    if (i == NUM_ALGO_DEFS)
        return luaL_argerror(L, 2, "unrecognized algorithm name");

    /* Check the options table. */
    if (num_args >= 4 && !lua_isnil(L, 4)) {
        if (!lua_istable(L, 4))
            return luaL_argerror(L, 4, "options must be either nil or a table");
        options_pos = 4;
    }

    /* Create the filter object.  If there's an error initializing it, make
     * sure the userdata is cleaned up properly. */
    filter = lua_newuserdata(L, sizeof(Filter) + def->state_size);
    if (!init_filter(filter, L, def, options_pos)) {
        destroy_filter(L, filter);
        return lua_error(L);
    }

    luaL_getmetatable(L, FILTER_MT_NAME);
    lua_setmetatable(L, -2);

    filter->buf_in = filter->buf_in_end
                   = filter->alloc(filter->alloc_ud, 0, 0, BUFSIZ);
    assert(filter->buf_in);
    filter->buf_in_size = BUFSIZ;
    filter->buf_in_free = 1;
    filter->do_output = 0;

    /* Figure out where to send the output to. */
    if (num_args >= 3 && !lua_isnil(L, 3)) {
        arg_type = lua_type(L, 3);
        if (arg_type == LUA_TSTRING || arg_type == LUA_TNUMBER) {
            filename = lua_tolstring(L, 3, &filename_len);
            luaL_argcheck(L, !contains_null_byte(filename, filename_len), 3,
                          "invalid file name");
            filter->c_fh = fopen(filename, "wb");
            if (!filter->c_fh)
                return luaL_error(L, "error opening file '%s': %s", filename,
                                  strerror(errno));
            filter->do_output = output_c_fh;
        }
        else if (arg_type == LUA_TFUNCTION) {
            lua_pushvalue(L, 3);
            filter->output_func_ref = luaL_ref(L, LUA_REGISTRYINDEX);
            filter->do_output = output_luafunc;
        }
        else if (arg_type == LUA_TTABLE || arg_type == LUA_TUSERDATA) {
            lua_getfield(L, 3, "write");
            if (lua_isnil(L, -1))
                return luaL_argerror(L, 2, "not a file handle object, has no"
                                     " 'write' method");
            else if (!lua_isfunction(L, -1))
                return luaL_argerror(L, 2, "not a file handle object, 'write'"
                                     " method is not a function");
            lua_pop(L, 1);

            lua_pushvalue(L, 3);
            filter->l_fh_ref = luaL_ref(L, LUA_REGISTRYINDEX);
            filter->do_output = output_lua_fh;
        }
        else
            return luaL_argerror(L, 2, "invalid type for output destination");
    }
    else
        filter->do_output = output_string;

    return 1;
}

static int
filter_add (lua_State *L) {
    Filter *filter = luaL_checkudata(L, 1, FILTER_MT_NAME);
    size_t len, load_bytes, max_bytes;
    const unsigned char *s = (unsigned char *) luaL_checklstring(L, 2, &len);
    const unsigned char *s_end = s + len;

    if (filter->finished)
        return luaL_error(L, "output has been finalized, it's too late to"
                          " add more input");

    while (s < s_end) {
        /* Top up the input buffer with as much as we can fit in. */
        max_bytes = filter->buf_in_size - (filter->buf_in_end - filter->buf_in);
        load_bytes = s_end - s;
        if (load_bytes > max_bytes)
            load_bytes = max_bytes;
        assert(load_bytes > 0);

        add_input_data(filter, (const unsigned char *) s, load_bytes);
        s += load_bytes;
        if (do_filtering(filter, 0))
            return lua_error(L);
    }

    return 0;
}

static void
filter_addfile_filename (lua_State *L, Filter *filter, const char *filename) {
    size_t max_bytes, bytes_read;
    FILE *f;

    f = fopen(filename, "rb");
    if (!f)
        luaL_error(L, "error opening file '%s': %s", filename, strerror(errno));

    while (!feof(f)) {
        /* Top up the input buffer with as much as we can fit in. */
        max_bytes = filter->buf_in_size - (filter->buf_in_end - filter->buf_in);
        errno = 0;
        bytes_read = fread(filter->buf_in_end, 1, max_bytes, f);
        if (errno) {
            fclose(f);
            luaL_error(L, "error reading from file '%s': %s", filename,
                       strerror(errno));
        }

        filter->buf_in_end += bytes_read;
        if (do_filtering(filter, 0)) {
            fclose(f);
            lua_error(L);
        }
    }

    fclose(f);
}

static void
filter_addfile_function (lua_State *L, Filter *filter,
                         int handlepos, int funcpos)
{
    size_t bytes_read;
    const char *data;

    while (1) {
        /* Top up the input buffer with as much as we can fit in. */
        lua_pushvalue(L, funcpos);
        lua_pushvalue(L, handlepos);
        lua_pushinteger(L, filter->buf_in_size -
                                (filter->buf_in_end - filter->buf_in));
        lua_call(L, 2, 2);

        if (lua_isnil(L, -2)) {
            if (lua_isnil(L, -1)) {     /* EOF */
                lua_pop(L, 2);
                return;
            }
            else {                      /* read error */
                lua_pushstring(L, "error reading from file: ");
                lua_pushvalue(L, -2);   /* error message from :read() */
                lua_concat(L, 2);
                lua_error(L);
            }
        }
        else if (!lua_isstring(L, -2)) {
            luaL_error(L, "'read' method return unexpected value (should"
                       " always be a strnig or nil)");
        }

        data = lua_tolstring(L, -2, &bytes_read);
        add_input_data(filter, (const unsigned char *) data, bytes_read);
        if (do_filtering(filter, 0))
            lua_error(L);

        lua_pop(L, 2);
    }
}

static int
filter_addfile (lua_State *L) {
    Filter *filter = luaL_checkudata(L, 1, FILTER_MT_NAME);
    size_t filename_len;
    const char *filename;
    int num_args = lua_gettop(L);
    int arg_type;

    if (num_args != 2)
        return luaL_error(L, "wrong number of arguments to :addfile()");

    if (filter->finished)
        return luaL_error(L, "output has been finalized, it's too late to"
                          " add more input");

    arg_type = lua_type(L, 2);
    if (arg_type == LUA_TSTRING || arg_type == LUA_TNUMBER) {
        filename = luaL_checklstring(L, 2, &filename_len);
        luaL_argcheck(L, !contains_null_byte(filename, filename_len), 2,
                      "invalid file name");
        filter_addfile_filename(L, filter, filename);
    }
    else if (arg_type == LUA_TTABLE || arg_type == LUA_TUSERDATA) {
        lua_getfield(L, 2, "read");
        if (lua_isnil(L, -1))
            return luaL_argerror(L, 2, "not a file handle object, has no"
                                 " 'read' method");
        else if (!lua_isfunction(L, -1))
            return luaL_argerror(L, 2, "not a file handle object, 'read'"
                                 " method is not a function");
        filter_addfile_function(L, filter, 2, 3);
    }
    else
        return luaL_argerror(L, 2, "bad type of file input, should be a"
                             " filename or file handle object");

    return 0;
}

static int
filter_result (lua_State *L) {
    Filter *filter = luaL_checkudata(L, 1, FILTER_MT_NAME);

    if (filter->do_output != output_string)
        return luaL_error(L, "output sent elsewhere, not available as a"
                          " string");

    if (!filter->finished) {
        if (do_filtering(filter, 1)) {
            filter_cleanup(L, filter);
            return lua_error(L);
        }
        filter_finished_cleanup(L, filter);
    }

    lua_pushlstring(L, (const char *) filter->buf_out,
                   filter->buf_out_end - filter->buf_out);
    return 1;
}

static int
filter_finish (lua_State *L) {
    Filter *filter = luaL_checkudata(L, 1, FILTER_MT_NAME);

    if (filter->finished)
        return luaL_error(L, "output has been finished");

    if (do_filtering(filter, 1)) {
        filter_cleanup(L, filter);
        return lua_error(L);
    }
    filter_finished_cleanup(L, filter);

    return 0;
}

static int
filter_gc (lua_State *L) {
    Filter *filter = luaL_checkudata(L, 1, FILTER_MT_NAME);
    destroy_filter(L, filter);
    return 0;
}

int
luaopen_datafilter (lua_State *L) {
    size_t i;
    const AlgorithmDefinition *def;

    /* Reserve space for the simple algorithm functions (one per algo), and:
     *  _MODULE_NAME, _VERSION, .new() */
    lua_createtable(L, 0, NUM_ALGO_DEFS + 3);

    lua_pushlstring(L, "_MODULE_NAME", 12);
    lua_pushlstring(L, "datafilter", 11);
    lua_rawset(L, -3);
    lua_pushlstring(L, "_VERSION", 8);
    lua_pushstring(L, VERSION);
    lua_rawset(L, -3);

    def = filter_algorithms;
    for (i = 0; i < NUM_ALGO_DEFS; ++i, ++def) {
        lua_pushstring(L, def->name);
        lua_pushcfunction(L, def->wrapper_func);
        lua_rawset(L, -3);
    }

    lua_pushlstring(L, "new", 3);
    lua_pushcfunction(L, filter_new);
    lua_rawset(L, -3);

    /* Create the metatable for Filter objects returned from Filter:new() */
    luaL_newmetatable(L, FILTER_MT_NAME);
    lua_pushlstring(L, "_MODULE_NAME", 12);
    lua_pushlstring(L, "datafilter-object", 4);
    lua_rawset(L, -3);
    lua_pushlstring(L, "add", 3);
    lua_pushcfunction(L, filter_add);
    lua_rawset(L, -3);
    lua_pushlstring(L, "addfile", 7);
    lua_pushcfunction(L, filter_addfile);
    lua_rawset(L, -3);
    lua_pushlstring(L, "result", 6);
    lua_pushcfunction(L, filter_result);
    lua_rawset(L, -3);
    lua_pushlstring(L, "finish", 6);
    lua_pushcfunction(L, filter_finish);
    lua_rawset(L, -3);
    lua_pushlstring(L, "__gc", 4);
    lua_pushcfunction(L, filter_gc);
    lua_rawset(L, -3);
    lua_pushlstring(L, "__index", 7);
    lua_pushvalue(L, -2);
    lua_rawset(L, -3);
    lua_pop(L, 1);

    return 1;
}

/* vi:set ts=4 sw=4 expandtab: */
