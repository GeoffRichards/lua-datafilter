/* lua-datafilter algorithm: adler32 */

typedef struct Adler32State_ {
    unsigned int s1, s2;
} Adler32State;

static int
algo_adler32_init (Filter *filter, int options_pos) {
    Adler32State *state = ALGO_STATE(filter);
    (void) options_pos;     /* unused */

    state->s1 = 1;
    state->s2 = 0;

    return 1;
}

static const unsigned char *
algo_adler32 (Filter *filter,
              const unsigned char *in, const unsigned char *in_end,
              unsigned char *out, unsigned char *out_max, int eof)
{
    Adler32State *state = ALGO_STATE(filter);

    while (in != in_end) {
        state->s1 = (state->s1 + *in++) % 65521;
        state->s2 = (state->s2 + state->s1) % 65521;
    }

    if (eof) {
        if (out_max - out < 4)
            out = filter->do_output(filter, out, &out_max);
        *out++ = state->s2 >> 8;
        *out++ = state->s2 & 0xFF;
        *out++ = state->s1 >> 8;
        *out++ = state->s1 & 0xFF;
        filter->buf_out_end = out;
    }

    return in;
}

/* vi:set ts=4 sw=4 expandtab: */
