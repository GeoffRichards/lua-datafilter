/* data.filter algorithms: base64_encode, base64_decode */

static const unsigned char
base64_char_code[] = {
    65,  66,  67,  68,  69,  70,  71,  72,      /* A - H */
    73,  74,  75,  76,  77,  78,  79,  80,      /* I - P */
    81,  82,  83,  84,  85,  86,  87,  88,      /* Q - X */
    89,  90,  97,  98,  99,  100, 101, 102,     /* Y - f */
    103, 104, 105, 106, 107, 108, 109, 110,     /* g - n */
    111, 112, 113, 114, 115, 116, 117, 118,     /* o - v */
    119, 120, 121, 122, 48,  49,  50,  51,      /* w - 3 */
    52,  53,  54,  55,  56,  57,  43,  47,      /* 4 - / */
};

#define BASE64_PADDING_CHAR 61                  /* = */

/* 64 is padding character,
 * anything > 64 is character not in the normal base64 alphabet.
 */
static const unsigned char
base64_char_value[] = {
    99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99,   /* 0   */
    99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99,   /* 16  */
    99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 62, 99, 99, 99, 63,   /* 32  */
    52, 53, 54, 55, 56, 57, 58, 59, 60, 61, 99, 99, 99, 64, 99, 99,   /* 48  */
    99, 0,  1,  2,  3,  4,  5,  6,  7,  8,  9,  10, 11, 12, 13, 14,   /* 64  */
    15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 99, 99, 99, 99, 99,   /* 80  */
    99, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39, 40,   /* 96  */
    41, 42, 43, 44, 45, 46, 47, 48, 49, 50, 51, 99, 99, 99, 99, 99,   /* 112 */
    99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99,   /* 128 */
    99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99,   /* 144 */
    99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99,   /* 160 */
    99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99,   /* 176 */
    99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99,   /* 192 */
    99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99,   /* 208 */
    99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99,   /* 224 */
    99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99, 99,   /* 240 */
};

typedef struct Base64EncodeState_ {
    const unsigned char *line_ending;
    size_t line_ending_len, max_line_length, cur_line_length;
    int no_padding;
} Base64EncodeState;

typedef struct Base64DecodeState_ {
    int seen_end;
    unsigned char n[4];
    unsigned int count;
    int disallow_whitespace, allow_missing_padding;
} Base64DecodeState;

/*static size_t
algo_base64_encode_outsz (size_t input_size) {
    return (input_size + 2) / 3 * 4;
}*/

static const unsigned char default_line_ending[2] = { 13, 10 };

static void
algo_base64_encode_init (Filter *filter, int options_pos) {
    Base64EncodeState *state = ALGO_STATE(filter);
    lua_State *L = filter->L;
    const char *s;
    lua_Integer n;

    state->line_ending = 0;
    state->line_ending_len = 0;
    state->max_line_length = 0;
    state->cur_line_length = 0;
    state->no_padding = 0;

    if (options_pos) {
        lua_getfield(L, options_pos, "no_padding");
        state->no_padding = lua_toboolean(L, -1);
        lua_pop(L, 1);

        lua_getfield(L, options_pos, "line_ending");
        if (!lua_isnil(L, -1)) {
            if (!lua_isstring(L, -1))
                luaL_error(L, "bad value for 'line_ending' option,"
                           " should be a string");
            s = lua_tolstring(L, -1, &state->line_ending_len);
            state->line_ending = my_strduplen(
                filter, (unsigned char *) s, state->line_ending_len);
            state->max_line_length = 76;
        }
        lua_pop(L, 1);

        lua_getfield(L, options_pos, "max_line_length");
        if (!lua_isnil(L, -1)) {
            if (!lua_isnumber(L, -1))
                luaL_error(L, "bad value for 'max_line_length' option,"
                           " should be a number");
            n = lua_tonumber(L, -1);
            if (n <= 0)
                luaL_error(L, "bad value for 'max_line_length' option,"
                           " must be greater than zero");
            state->max_line_length = n;
            if (!state->line_ending) {
                state->line_ending = default_line_ending;
                state->line_ending_len = 2;
            }
        }
        lua_pop(L, 1);
    }
}

static void
algo_base64_encode_destroy (Filter *filter) {
    Base64EncodeState *state = ALGO_STATE(filter);
    if (state->line_ending && state->line_ending != default_line_ending)
        filter->alloc(filter->alloc_ud, (char *) state->line_ending,
                      state->line_ending_len, 0);
}

#define DO_LINE_ENDINGS(bytes_to_go) \
    if (++state->cur_line_length == state->max_line_length \
        && state->line_ending) \
    { \
        if ((size_t) (out_max - out) < state->line_ending_len + bytes_to_go) \
            out = filter->do_output(filter, out, &out_max); \
        memcpy(out, state->line_ending, state->line_ending_len); \
        out += state->line_ending_len; \
        state->cur_line_length = 0; \
    }

static const unsigned char *
algo_base64_encode (Filter *filter,
                    const unsigned char *in, const unsigned char *in_end,
                    unsigned char *out, unsigned char *out_max, int eof)
{
    Base64EncodeState *state = ALGO_STATE(filter);
    unsigned int n;

    while (in_end - in >= 3) {
        if (out_max - out < 4)
            out = filter->do_output(filter, out, &out_max);
        n = (in[0] << 16) | (in[1] << 8) | in[2];
        in += 3;
        *out++ = base64_char_code[n >> 18];
        DO_LINE_ENDINGS(3)
        *out++ = base64_char_code[(n >> 12) & 0x3F];
        DO_LINE_ENDINGS(2)
        *out++ = base64_char_code[(n >> 6) & 0x3F];
        DO_LINE_ENDINGS(1)
        *out++ = base64_char_code[n & 0x3F];
        DO_LINE_ENDINGS(0)
    }

    if (eof) {
        if (in != in_end) {
            if (out_max - out < 4)
                out = filter->do_output(filter, out, &out_max);
            if (in + 1 == in_end) {     /* 1 byte remaining */
                n = *in++;
                *out++ = base64_char_code[n >> 2];
                DO_LINE_ENDINGS(3)
                *out++ = base64_char_code[(n & 3) << 4];
                DO_LINE_ENDINGS(2)
                if (!state->no_padding) {
                    *out++ = BASE64_PADDING_CHAR;
                    DO_LINE_ENDINGS(1)
                    *out++ = BASE64_PADDING_CHAR;
                    DO_LINE_ENDINGS(0)
                }
            }
            else {                      /* 2 bytes remaining */
                n = (in[0] << 8) + in[1];
                in += 2;
                *out++ = base64_char_code[n >> 10];
                DO_LINE_ENDINGS(3)
                *out++ = base64_char_code[(n >> 4) & 0x3F];
                DO_LINE_ENDINGS(2)
                *out++ = base64_char_code[(n & 0xF) << 2];
                DO_LINE_ENDINGS(1)
                if (!state->no_padding) {
                    *out++ = BASE64_PADDING_CHAR;
                    DO_LINE_ENDINGS(0)
                }
            }
        }

        if (state->cur_line_length > 0 && state->line_ending) {
            if ((size_t) (out_max - out) < state->line_ending_len)
                out = filter->do_output(filter, out, &out_max);
            memcpy(out, state->line_ending, state->line_ending_len);
            out += state->line_ending_len;
            state->cur_line_length = 0;
        }
    }

    filter->buf_out_end = out;
    return in;
}

/*static size_t
algo_base64_decode_outsz (size_t input_size) {
    return (input_size + 3) / 4 * 3;
}*/

static void
algo_base64_decode_init (Filter *filter, int options_pos) {
    Base64DecodeState *state = ALGO_STATE(filter);
    lua_State *L = filter->L;
    (void) options_pos;     /* unused */

    state->seen_end = 0;
    state->count = 0;
    state->disallow_whitespace = 0;
    state->allow_missing_padding = 0;

    if (options_pos) {
        lua_getfield(L, options_pos, "disallow_whitespace");
        state->disallow_whitespace = lua_toboolean(L, -1);
        lua_pop(L, 1);

        lua_getfield(L, options_pos, "allow_missing_padding");
        state->allow_missing_padding = lua_toboolean(L, -1);
        lua_pop(L, 1);
    }
}

static unsigned char *
do_base64_decode_block (Filter *filter, Base64DecodeState *state,
                        unsigned char *out, unsigned char **out_max)
{
    unsigned char *n = state->n;

    if (state->seen_end)
        assert(0);  /* TODO excess stuff after padding */

    if (n[2] == 64 && n[3] != 64)
        assert(0);      /* TODO - stuff after padding */

    if (*out_max - out < 3)
        out = filter->do_output(filter, out, out_max);

    if (n[3] != 64) {       /* no padding, block of 3 bytes */
        *out++ = (n[0] << 2) | (n[1] >> 4);
        *out++ = (n[1] << 4) | (n[2] >> 2);
        *out++ = (n[2] << 6) | n[3];
    }
    else if (n[2] != 64) {  /* ends with '=', block of 2 bytes */
        if (n[2] & 3)
            assert(0);      /* TODO - spare bits set */
        state->seen_end = 1;
        *out++ = (n[0] << 2) | (n[1] >> 4);
        *out++ = (n[1] << 4) | (n[2] >> 2);
    }
    else {                  /* ends with '==', block of 1 byte */
        if (n[1] & 0xF)
            assert(0);      /* TODO - spare bits set */
        state->seen_end = 1;
        *out++ = (n[0] << 2) | (n[1] >> 4);
    }

    state->count = 0;
    return out;
}

/* Define this myself so that it's not locale dependent.  Also it doesn't
 * allow vertical tabs as whitespace, because nobody uses them. */
#define my_isspace(c) ((c) == 32 || (c) == 10 || (c) == 13 || (c) == 9 || \
                       (c) == 12)

static const unsigned char *
algo_base64_decode (Filter *filter,
                    const unsigned char *in, const unsigned char *in_end,
                    unsigned char *out, unsigned char *out_max, int eof)
{
    Base64DecodeState *state = ALGO_STATE(filter);
    unsigned char *n = state->n;
    unsigned char byte, c;

    while (in != in_end) {
        byte = *in++;
        c = base64_char_value[byte];
        if (c > 64) {
            if (state->disallow_whitespace || !my_isspace(byte))
                ALGO_ERROR("invalid character in input");
            continue;   /* skip whitespace */
        }
        else if (c == 64 && state->count < 2)
            assert(0);  /* TODO - padding in wrong place */
        n[state->count++] = c;

        if (state->count == 4)
            out = do_base64_decode_block(filter, state, out, &out_max);
    }

    if (eof) {
        if (state->count == 1)
            ALGO_ERROR("spare character at end of input");
        else if (state->count >= 2) {
            if (!state->allow_missing_padding)
                ALGO_ERROR("padding characters missing at end of input");
            while (state->count < 4)
                n[state->count++] = 64;
            out = do_base64_decode_block(filter, state, out, &out_max);
        }
    }
    
    filter->buf_out_end = out;
    return in;
}

#if 0
#ifdef EXTRA_C_TESTS
void
test_internal_base64 (void) {
    /* None of this is going to work with 16 bit integers. */
    assert(sizeof(unsigned int) >= 3);

    assert(algo_base64_encode_outsz(0) == 0);
    assert(algo_base64_encode_outsz(1) == 4);
    assert(algo_base64_encode_outsz(2) == 4);
    assert(algo_base64_encode_outsz(3) == 4);
    assert(algo_base64_encode_outsz(4) == 8);
    assert(algo_base64_encode_outsz(5) == 8);
    assert(algo_base64_encode_outsz(6) == 8);

    assert(algo_base64_decode_outsz(0) == 0);
    assert(algo_base64_decode_outsz(1) == 3);
    assert(algo_base64_decode_outsz(2) == 3);
    assert(algo_base64_decode_outsz(3) == 3);
    assert(algo_base64_decode_outsz(4) == 3);
    assert(algo_base64_decode_outsz(5) == 6);
    assert(algo_base64_decode_outsz(6) == 6);
}
#endif
#endif

/* vi:set ts=4 sw=4 expandtab: */
