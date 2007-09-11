#include "filter.h"
#include <stdio.h>
#include <string.h>
#include <errno.h>
#include <assert.h>

/* TODO - default off, control from makefile */
#define EXTRA_C_TESTS

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
    int output_func_ref;
} Filter;

#define ALGO_STATE(filter) ((void *) (((char *) (filter)) + sizeof(Filter)))

typedef int (*AlgorithmWrapperFunction) (lua_State *L);
/*typedef size_t (*AlgorithmSizeFunction) (size_t input_size);*/
typedef void (*AlgorithmInitFunction) (Filter *filter);

typedef struct AlgorithmDefinition_ {
    const char *name;
    AlgorithmFunction func;
    AlgorithmWrapperFunction wrapper_func;
    /*AlgorithmSizeFunction size_func;*/
    size_t state_size;
    AlgorithmInitFunction init_func;
    AlgorithmDestroyFunction destroy_func;
} AlgorithmDefinition;

static void
init_filter (Filter *filter, lua_State *L, const AlgorithmDefinition *def) {
    lua_Alloc alloc;
    void *alloc_ud;

    alloc = lua_getallocf(L, &alloc_ud);

    filter->filter_object_size = sizeof(Filter) + def->state_size;
    filter->L = L;
    filter->alloc = alloc;
    filter->alloc_ud = alloc_ud;
    filter->finished = 0;
    filter->c_fh = 0;
    filter->output_func_ref = LUA_NOREF;

    filter->buf_out = filter->buf_in = 0;
    filter->lbuf = 0;
    filter->destroy_func = 0;

    filter->buf_out = filter->buf_out_end = alloc(alloc_ud, 0, 0, BUFSIZ);
    assert(filter->buf_out);
    filter->buf_out_size = BUFSIZ;

    if (def->init_func)
        def->init_func(filter);
    filter->destroy_func = def->destroy_func;
    filter->func = def->func;
}

static void
filter_finished_cleanup (lua_State *L, Filter *filter) {
    unsigned char *out_max;

    filter->finished = 1;

    out_max = filter->buf_out + filter->buf_out_size;
    if (filter->buf_out_end != filter->buf_out)
        filter->do_output(filter, filter->buf_out_end, &out_max);

    if (filter->c_fh) {
        if (fclose(filter->c_fh))
            luaL_error(L, "error closing output file handle: %s",
                       strerror(errno));
        filter->c_fh = 0;
    }

    luaL_unref(L, LUA_REGISTRYINDEX, filter->output_func_ref);
    filter->output_func_ref = LUA_NOREF;
}

static void
add_input_data (Filter *filter, const unsigned char *data, size_t len) {
    if (len > 0) {
        memcpy(filter->buf_in_end, data, len);
        filter->buf_in_end += len;
    }
}

static void
do_filtering (Filter *filter, int eof) {
    size_t bytes_left_over;
    unsigned char *left_over;

    left_over = (unsigned char *) filter->func(
        filter, filter->buf_in, filter->buf_in_end,
        filter->buf_out_end, filter->buf_out + filter->buf_out_size, eof);

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

    alloc = lua_getallocf(L, &alloc_ud);

    filter = alloc(alloc_ud, 0, 0, sizeof(Filter) + def->state_size);
    assert(filter);
    init_filter(filter, L, def);

    filter->buf_in = s;
    filter->buf_in_end = s + len;
    filter->buf_in_size = len;
    filter->buf_in_free = 0;

    filter->lbuf = filter->alloc(filter->alloc_ud, 0, 0, sizeof(luaL_Buffer));
    assert(filter->lbuf);
    luaL_buffinit(L, filter->lbuf);
    filter->do_output = output_lbuf;

    do_filtering(filter, 1);
    filter_finished_cleanup(L, filter);

    luaL_pushresult(filter->lbuf);
    destroy_filter(L, filter);
    filter->alloc(filter->alloc_ud, filter, filter->filter_object_size, 0);
    return 1;
}

#include "algo/base64.c"
#include "algo/md5.c"

#define ALGO_WRAPPER_DECL(name, num) static int algowrap_##name (lua_State *L);
ALGO_WRAPPER_DECL(base64_encode, 0)
ALGO_WRAPPER_DECL(base64_decode, 1)
ALGO_WRAPPER_DECL(md5, 2)
#undef ALGO_WRAPPER_DECL

#define ALGODEF(name) #name, algo_##name, algowrap_##name
static const AlgorithmDefinition
filter_algorithms[] = {
    { ALGODEF(base64_encode), 0, 0, 0 },
    { ALGODEF(base64_decode), sizeof(Base64DecodeState),
      algo_base64_decode_init, 0 },
    { ALGODEF(md5), sizeof(MD5State), algo_md5_init, 0 },
};
#undef ALGODEF
#define NUM_ALGO_DEFS (sizeof(filter_algorithms) / sizeof(AlgorithmDefinition))

#define ALGO_WRAPPER_DEF(name, num) \
static int algowrap_##name (lua_State *L) { \
    return algo_wrapper(L, &filter_algorithms[num]); \
}
ALGO_WRAPPER_DEF(base64_encode, 0)
ALGO_WRAPPER_DEF(base64_decode, 1)
ALGO_WRAPPER_DEF(md5, 2)
#undef ALGO_WRAPPER_DEF

#ifdef EXTRA_C_TESTS
static int
test_internal_stuff (lua_State *L) {
    (void) L;   /* unused arg */
    /*test_internal_base64();*/
    return 0;
}
#endif

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

    luaL_argcheck(L, !contains_null_byte(algo_name, algo_name_len), 2,
                  "invalid algorithm name");

    if (num_args > 3)
        return luaL_error(L, "too many arguments to data.filter:new()");

    /* Find the definition of the named algorithm. */
    def = filter_algorithms;
    for (i = 0; i < NUM_ALGO_DEFS; ++i, ++def) {
        if (!strcmp(def->name, algo_name))
            break;
    }
    if (i == NUM_ALGO_DEFS)
        return luaL_argerror(L, 2, "unrecognized algorithm name");

    /* Create the filter object.  This is on the stack, so if anything goes
     * wrong after this Lua will be able to clean it up. */
    filter = lua_newuserdata(L, sizeof(Filter) + def->state_size);
    init_filter(filter, L, def);
    luaL_getmetatable(L, FILTER_MT_NAME);
    lua_setmetatable(L, -2);

    filter->buf_in = filter->buf_in_end
                   = filter->alloc(filter->alloc_ud, 0, 0, BUFSIZ);
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
        do_filtering(filter, 0);
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
        do_filtering(filter, 0);
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
        do_filtering(filter, 0);

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

    do_filtering(filter, 1);
    filter_finished_cleanup(L, filter);

    lua_pushlstring(L, (const char *) filter->buf_out,
                   filter->buf_out_end - filter->buf_out);
    return 1;
}

static int
filter_finish (lua_State *L) {
    Filter *filter = luaL_checkudata(L, 1, FILTER_MT_NAME);

    if (filter->finished)
        return luaL_error(L, "output has been finished");

    do_filtering(filter, 1);
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
luaopen_data_filter (lua_State *L) {
    size_t i;
    const AlgorithmDefinition *def;

    /* Reserve space for the simple algorithm functions (one per algo), and:
     *  _MODULE_NAME, _VERSION, .util, .new() */
    lua_createtable(L, 0, NUM_ALGO_DEFS + 4);

    lua_pushlstring(L, "_MODULE_NAME", 12);
    lua_pushlstring(L, "data.filter", 11);
    lua_rawset(L, -3);
    lua_pushlstring(L, "_VERSION", 8);
    lua_pushstring(L, VERSION);
    lua_rawset(L, -3);
#ifdef EXTRA_C_TESTS
    lua_pushstring(L, "_do_internal_tests");
    lua_pushcfunction(L, test_internal_stuff);
    lua_rawset(L, -3);
#endif

    def = filter_algorithms;
    for (i = 0; i < NUM_ALGO_DEFS; ++i, ++def) {
        lua_pushstring(L, def->name);
        lua_pushcfunction(L, def->wrapper_func);
        lua_rawset(L, -3);
    }

    /* TODO - .util */

    lua_pushlstring(L, "new", 3);
    lua_pushcfunction(L, filter_new);
    lua_rawset(L, -3);

    /* Create the metatable for Filter objects returned from Filter:new() */
    luaL_newmetatable(L, FILTER_MT_NAME);
    lua_pushlstring(L, "_MODULE_NAME", 12);
    lua_pushlstring(L, "TODO", 4);
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
