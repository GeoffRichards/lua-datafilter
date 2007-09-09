#include "filter.h"
#include <stdio.h>
#include <string.h>
#include <errno.h>
#include <assert.h>

/* TODO - default off, control from makefile */
#define EXTRA_C_TESTS

#define FILTER_MT_NAME ("data.filter-" VERSION)

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
    /* TODO - need a destroy_output func as well, to flush any last output */
    int finished;
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
destroy_filter (Filter *filter) {
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
    unsigned char *out;
    out = filter->alloc(filter->alloc_ud, filter->buf_out, filter->buf_out_size, new_size);
    filter->buf_out = out;
    filter->buf_out_end = out + (out_end - filter->buf_out);
    filter->buf_out_size = new_size;
    *out_max = out + new_size;
    return filter->buf_out_end;
}

static int
algo_wrapper (lua_State *L, const AlgorithmDefinition *def) {
    size_t len;
    unsigned char *s = (unsigned char *) luaL_checklstring(L, 1, &len);
    Filter *filter;
    const unsigned char *end;
    lua_Alloc alloc;
    void *alloc_ud;
    unsigned char *out_max;

    alloc = lua_getallocf(L, &alloc_ud);

    filter = alloc(alloc_ud, 0, 0, sizeof(Filter) + def->state_size);
    assert(filter);
    init_filter(filter, L, def);

    filter->buf_in = filter->buf_in_end = s;
    filter->buf_in_size = len;
    filter->buf_in_free = 0;

    filter->lbuf = filter->alloc(filter->alloc_ud, 0, 0, sizeof(luaL_Buffer));
    assert(filter->lbuf);
    luaL_buffinit(L, filter->lbuf);
    filter->do_output = output_lbuf;

    end = def->func(filter, filter->buf_in,
                    filter->buf_in + filter->buf_in_size,
                    filter->buf_out_end,
                    filter->buf_out + filter->buf_out_size, 1);
    assert(end == filter->buf_in + filter->buf_in_size);
    out_max = filter->buf_out + filter->buf_out_size;
    if (filter->buf_out_end != filter->buf_out)
        filter->do_output(filter, filter->buf_out_end, &out_max);

    luaL_pushresult(filter->lbuf);
    destroy_filter(filter);
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
filter_new (lua_State *L) {
    size_t algo_name_len;
    const char *algo_name = luaL_checklstring(L, 2, &algo_name_len);
    unsigned int i;
    const AlgorithmDefinition *def;
    Filter *filter;

    for (i = 0; i < algo_name_len; ++i) {
        if (algo_name[i] == '\0')
            return luaL_error(L, "invalid algorithm name '%s'", algo_name);
    }

    def = filter_algorithms;
    for (i = 0; i < NUM_ALGO_DEFS; ++i, ++def) {
        if (!strcmp(def->name, algo_name)) {
            filter = lua_newuserdata(L, sizeof(Filter) + def->state_size);
            init_filter(filter, L, def);
            luaL_getmetatable(L, FILTER_MT_NAME);
            lua_setmetatable(L, -2);

            filter->buf_in = filter->buf_in_end
                           = filter->alloc(filter->alloc_ud, 0, 0, BUFSIZ);
            filter->buf_in_size = BUFSIZ;
            filter->buf_in_free = 1;

            filter->do_output = output_string;
            return 1;
        }
    }

    return luaL_error(L, "unrecognized algorithm name '%s'", algo_name);
}

static int
filter_add (lua_State *L) {
    Filter *filter = luaL_checkudata(L, 1, FILTER_MT_NAME);
    size_t len, load_bytes, max_bytes, bytes_left_over;
    const unsigned char *s = (unsigned char *) luaL_checklstring(L, 2, &len);
    const unsigned char *s_end = s + len;
    unsigned char *left_over;

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
        memcpy(filter->buf_in_end, s, load_bytes);
        filter->buf_in_end += load_bytes;
        s += load_bytes;

        /* Process some more data, which will free up some space for more. */
        left_over = (unsigned char *) filter->func(
            filter, filter->buf_in, filter->buf_in_end,
            filter->buf_out_end, filter->buf_out + filter->buf_out_size, 0);
        if (left_over != filter->buf_in) {
            bytes_left_over = filter->buf_in_end - left_over;
            if (bytes_left_over)
                memmove(filter->buf_in, left_over, bytes_left_over);
            filter->buf_in_end = filter->buf_in + bytes_left_over;
        }
    }

    return 0;
}

static int
filter_output (lua_State *L) {
    Filter *filter = luaL_checkudata(L, 1, FILTER_MT_NAME);
    const unsigned char *left_over;

    if (filter->do_output != output_string)
        return luaL_error(L, "output sent elsewhere, not available as a"
                          " string");

    left_over = filter->func(
        filter, filter->buf_in, filter->buf_in_end,
        filter->buf_out_end, filter->buf_out + filter->buf_out_size, 1);
    assert(left_over == filter->buf_in_end);
    filter->finished = 1;

    lua_pushlstring(L, (const char *) filter->buf_out,
                   filter->buf_out_end - filter->buf_out);
    return 1;
}

static int
filter_gc (lua_State *L) {
    Filter *filter = luaL_checkudata(L, 1, FILTER_MT_NAME);
    destroy_filter(filter);
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
    lua_pushlstring(L, "output", 6);
    lua_pushcfunction(L, filter_output);
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
