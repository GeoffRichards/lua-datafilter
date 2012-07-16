/* lua-datafilter algorithms: base64_encode, base64_decode */

typedef struct HexDecodeState_ {
    int got_first_digit, first_digit_val;
} HexDecodeState;

static const unsigned char *
algo_hex_lower (Filter *filter,
                const unsigned char *in, const unsigned char *in_end,
                unsigned char *out, unsigned char *out_max, int eof)
{
    unsigned int n;
    (void) eof;     /* unused arg */

    while (in < in_end) {
        if (out_max - out < 2)
            out = filter->do_output(filter, out, &out_max);
        n = *in++;
        *out++ = hex_char_codes_lower[n >> 4];
        *out++ = hex_char_codes_lower[n & 0xF];
    }

    filter->buf_out_end = out;
    return in;
}

static const unsigned char *
algo_hex_upper (Filter *filter,
                const unsigned char *in, const unsigned char *in_end,
                unsigned char *out, unsigned char *out_max, int eof)
{
    unsigned int n;
    (void) eof;     /* unused arg */

    while (in < in_end) {
        if (out_max - out < 2)
            out = filter->do_output(filter, out, &out_max);
        n = *in++;
        *out++ = hex_char_codes_upper[n >> 4];
        *out++ = hex_char_codes_upper[n & 0xF];
    }

    filter->buf_out_end = out;
    return in;
}

static int
algo_hex_decode_init (Filter *filter, int options_pos) {
    HexDecodeState *state = ALGO_STATE(filter);
    state->got_first_digit = 0;
    (void) options_pos;     /* unused */
    return 1;
}

static const unsigned char *
algo_hex_decode (Filter *filter,
                 const unsigned char *in, const unsigned char *in_end,
                 unsigned char *out, unsigned char *out_max, int eof)
{
    HexDecodeState *state = ALGO_STATE(filter);
    int got_first_digit = state->got_first_digit,
        first_digit_val = state->first_digit_val;
    unsigned char c;
    int val;
    (void) eof;     /* unused arg */

    while (in < in_end) {
        c = *in++;
        if (isspace(c))
            continue;
        val = hex_char_value[c];
        if (val == -1)
            ALGO_ERROR("unexpected character in input (not hex digit)");
        if (got_first_digit) {
            if (out_max - out < 1)
                out = filter->do_output(filter, out, &out_max);
            *out++ = (first_digit_val << 4) + val;
            got_first_digit = 0;
        }
        else {
            got_first_digit = 1;
            first_digit_val = val;
        }
    }

    if (eof && got_first_digit)
        ALGO_ERROR("spare character at end of input");

    state->got_first_digit = got_first_digit;
    state->first_digit_val = first_digit_val;
    filter->buf_out_end = out;
    return in;
}

/* vi:set ts=4 sw=4 expandtab: */
