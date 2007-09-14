/* lua-datafilter algorithms: base64_encode, base64_decode */

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

/* vi:set ts=4 sw=4 expandtab: */
