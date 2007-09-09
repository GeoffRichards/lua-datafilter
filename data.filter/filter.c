#include "filter.h"
#include <stdio.h>
#include <string.h>
#include <errno.h>
#include <assert.h>

/* TODO - default off, control from makefile */
#define EXTRA_C_TESTS

struct Filter_;
typedef unsigned char * (*FilterOutputFunc)
    (struct Filter_ *filter, const unsigned char *out_end);
typedef void (*AlgorithmDestroyFunction) (struct Filter_ *filter);

typedef struct Filter_ {
    size_t filter_object_size;
    lua_State *L;
    lua_Alloc alloc;
    void *alloc_ud;
    luaL_Buffer *lbuf;
    unsigned char *buf_in, *buf_in_end, *buf_out, *buf_out_end, *buf_out_max;
    size_t buf_in_size, buf_out_size;
    int buf_in_free;    /* true if it should be deallocated on destruction */
    FilterOutputFunc do_output;
    AlgorithmDestroyFunction destroy_func;
} Filter;

#define ALGO_STATE(filter) ((void *) (((char *) (filter)) + sizeof(Filter)))

typedef int (*AlgorithmWrapperFunction) (lua_State *L);
typedef const unsigned char * (*AlgorithmFunction)
    (Filter *filter, const unsigned char *in, const unsigned char *in_end,
     unsigned char *out, unsigned char *out_end, int eof);
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

static Filter *
make_filter (lua_State *L, const AlgorithmDefinition *def) {
    lua_Alloc alloc;
    void *alloc_ud;
    Filter *filter;
    size_t filter_object_size;

    alloc = lua_getallocf(L, &alloc_ud);

    filter_object_size = sizeof(Filter) + def->state_size;
    filter = alloc(alloc_ud, 0, 0, filter_object_size);
    assert(filter);

    filter->filter_object_size = filter_object_size;
    filter->L = L;
    filter->alloc = alloc;
    filter->alloc_ud = alloc_ud;

    filter->buf_out = filter->buf_out_end = alloc(alloc_ud, 0, 0, BUFSIZ);
    assert(filter->buf_out);
    filter->buf_out_size = BUFSIZ;
    filter->buf_out_max = filter->buf_out + filter->buf_out_size;

    filter->lbuf = 0;

    if (def->init_func)
        def->init_func(filter);
    filter->destroy_func = def->destroy_func;

    return filter;
}

static void
destroy_filter (Filter *filter) {
    if (filter->destroy_func)
        filter->destroy_func(filter);
    if (filter->lbuf)
        filter->alloc(filter->alloc_ud, filter->lbuf, sizeof(luaL_Buffer), 0);
    if (filter->buf_in_free)
        filter->alloc(filter->alloc_ud, filter->buf_in, filter->buf_in_size, 0);
    filter->alloc(filter->alloc_ud, filter->buf_out, filter->buf_out_size, 0);
    filter->alloc(filter->alloc_ud, filter, filter->filter_object_size, 0);
}

static unsigned char *
output_lbuf (Filter *filter, const unsigned char *out_end) {
    assert(out_end > filter->buf_out);
    assert(out_end >= filter->buf_out_end);
    luaL_addlstring(filter->lbuf, (const char *) filter->buf_out,
                    out_end - filter->buf_out);
    return filter->buf_out_end = filter->buf_out;
}

static int algo_wrapper (lua_State *L, const AlgorithmDefinition *def) {
    size_t len;
    unsigned char *s = (unsigned char *) luaL_checklstring(L, 1, &len);
    Filter *filter = make_filter(L, def);
    const unsigned char *end;

    filter->buf_in = s;
    filter->buf_in_size = len;
    filter->buf_in_end = s + len;
    filter->buf_in_free = 0;

    filter->lbuf = filter->alloc(filter->alloc_ud, 0, 0, sizeof(luaL_Buffer));
    assert(filter->lbuf);
    luaL_buffinit(L, filter->lbuf);
    filter->do_output = output_lbuf;

    end = def->func(filter, filter->buf_in, filter->buf_in_end,
                    filter->buf_out_end, filter->buf_out_max, 1);
    assert(end == filter->buf_in_end);
    if (filter->buf_out_end != filter->buf_out)
        filter->do_output(filter, filter->buf_out_end);

    luaL_pushresult(filter->lbuf);
    destroy_filter(filter);
    return 1;
}

#include "algo/base64.c"

#define ALGO_WRAPPER_DECL(name, num) static int algowrap_##name (lua_State *L);
ALGO_WRAPPER_DECL(base64_encode, 0)
ALGO_WRAPPER_DECL(base64_decode, 1)
#undef ALGO_WRAPPER_DECL

#define ALGODEF(name) #name, algo_##name, algowrap_##name
static const AlgorithmDefinition filter_algorithms[] = {
    { ALGODEF(base64_encode), 0, 0, 0 },
    { ALGODEF(base64_decode), sizeof(Base64DecodeState),
      algo_base64_decode_init, 0 },
};
#undef ALGODEF
#define NUM_ALGO_DEFS (sizeof(filter_algorithms) / sizeof(AlgorithmDefinition))

#define ALGO_WRAPPER_DEF(name, num) \
static int algowrap_##name (lua_State *L) { \
    return algo_wrapper(L, &filter_algorithms[num]); \
}
ALGO_WRAPPER_DEF(base64_encode, 0)
ALGO_WRAPPER_DEF(base64_decode, 1)
#undef ALGO_WRAPPER_DEF

#ifdef EXTRA_C_TESTS
static int
test_internal_stuff (lua_State *L) {
    (void) L;   /* unused arg */
    /*test_internal_base64();*/
    return 0;
}
#endif

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
    /* TODO - .new() */

    return 1;
}

/* vi:set ts=4 sw=4 expandtab: */
