/* data.filter algorithms: percent_encode, percent_decode */

/* This is the set of 'unreserved' byte values from RFC 3986. */
static const unsigned char
pctenc_default_safe_bytes[] = {
    45, 46,
    48, 49, 50, 51, 52, 53, 54, 55, 56, 57,
    65, 66, 67, 68, 69, 70, 71, 72, 73, 74, 75, 76, 77,
    78, 79, 80, 81, 82, 83, 84, 85, 86, 87, 88, 89, 90,
    95,
    97, 98, 99, 100, 101, 102, 103, 104, 105, 106, 107, 108, 109,
    110, 111, 112, 113, 114, 115, 116, 117, 118, 119, 120, 121, 122,
    126
};

typedef struct PercentEncodeState_ {
    char safe_bytes[256];
} PercentEncodeState;

static void
init_safe_bytes (Filter *filter, PercentEncodeState *state,
                 const unsigned char *s, size_t slen)
{
    char *safe_bytes = state->safe_bytes;
    unsigned char c;
    size_t i;

    for (i = 0; i < 256; ++i)
        safe_bytes[i] = 0;

    for (i = 0; i < slen; ++i) {
        c = s[i];
        if (c == 37)
            luaL_error(filter->L, "percent bytes must always be encoded");
        else if (safe_bytes[c])
            luaL_error(filter->L, "byte value listed twice in 'safe_bytes'"
                       " option");
        safe_bytes[c] = 1;
    }
}

static void
algo_percent_encode_init (Filter *filter, int options_pos) {
    PercentEncodeState *state = ALGO_STATE(filter);
    lua_State *L = filter->L;
    int safe_bytes_initialized = 0;
    const char *s;
    size_t slen;
    (void) options_pos;     /* unused */

    if (options_pos) {
        lua_getfield(L, options_pos, "safe_bytes");
        if (!lua_isnil(L, -1)) {
            if (!lua_isstring(L, -1))
                luaL_error(L, "bad value for 'safe_bytes' option,"
                           " should be a string");
            s = lua_tolstring(L, -1, &slen);
            init_safe_bytes(filter, state, (unsigned char *) s, slen);
            safe_bytes_initialized = 1;
        }
        lua_pop(L, 1);
    }

    if (!safe_bytes_initialized)
        init_safe_bytes(filter, state, pctenc_default_safe_bytes,
                        sizeof(pctenc_default_safe_bytes));
}

static const unsigned char *
algo_percent_encode (Filter *filter,
                    const unsigned char *in, const unsigned char *in_end,
                    unsigned char *out, unsigned char *out_max, int eof)
{
    PercentEncodeState *state = ALGO_STATE(filter);
    const char *safe_bytes = state->safe_bytes;
    unsigned char byte;
    (void) eof;     /* unused */

    while (in != in_end) {
        byte = *in++;
        if (safe_bytes[byte]) {
            if (out == out_max)
                out = filter->do_output(filter, out, &out_max);
            *out++ = byte;
        }
        else {
            if ((size_t) (out_max - out) < 3)
                out = filter->do_output(filter, out, &out_max);
            *out++ = 37;
            *out++ = hex_char_codes_upper[byte >> 4];
            *out++ = hex_char_codes_upper[byte & 0xF];
        }
    }

    filter->buf_out_end = out;
    return in;
}

static const unsigned char *
algo_percent_decode (Filter *filter,
                    const unsigned char *in, const unsigned char *in_end,
                    unsigned char *out, unsigned char *out_max, int eof)
{
    unsigned char byte, byte2;
    (void) eof;     /* unused */

    while (in != in_end) {
        if (out == out_max)
            out = filter->do_output(filter, out, &out_max);

        byte = *in++;
        if (byte == 37) {
            if (in_end - in < 2) {
                if (!eof)
                    break;      /* wait for more to come */
                ALGO_ERROR("percent-encoded character incomplete at end of"
                           " input");
            }
            byte = *in++;
            byte2 = *in++;
            if (!my_ishex(byte) || !my_ishex(byte2))
                ALGO_ERROR("bad percent-encoded byte in input");
            *out++ = (hex_digit_val(byte) << 4) | hex_digit_val(byte2);
        }
        else {
            *out++ = byte;
        }
    }

    filter->buf_out_end = out;
    return in;
}

/* vi:set ts=4 sw=4 expandtab: */
