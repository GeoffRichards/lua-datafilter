/* lua-datafilter algorithm: sha1
 */

#include <stdint.h>

#define rotate(D, num) ((D << num) | (D >> (32 - num)))

static const uint32_t
sha1_K[4] = { 0x5A827999, 0x6ED9EBA1, 0x8F1BBCDC, 0xCA62C1D6 };

static void
sha1_word32tobytes (const uint32_t *input, unsigned char *output) {
    int j = 0;
    while (j < 20) {
        uint32_t v = *input++;
        output[j++] = v >> 24;
        output[j++] = (v >> 16) & 0xFF;
        output[j++] = (v >> 8) & 0xFF;
        output[j++] = v & 0xFF;
    }
}

static void
sha1_bytestoword32 (uint32_t *x, const unsigned char *pt) {
    int i;
    for (i = 0; i < 16; i++) {
        int j = i * 4;
        x[i] = ((uint32_t) pt[j] << 24) |
               ((uint32_t) pt[j + 1] << 16) |
               ((uint32_t) pt[j + 2] << 8) |
               ((uint32_t) pt[j + 3]);
    }
}

static void
sha1_digest (uint32_t *w, uint32_t *h) {
    uint32_t a, b, c, d, e;
    uint32_t temp, f;
    int t;

    for (t = 16; t < 80; ++t) {
        temp = w[t - 3] ^ w[t - 8] ^ w[t - 14] ^ w[t - 16];
        w[t] = rotate(temp, 1);
    }

    a = h[0];  b = h[1];  c = h[2];  d = h[3];  e = h[4];

    for (t = 0; t < 80; ++t) {
        if (t < 20)
            f = (b & c) | ((~b) & d);
        else if (t < 40)
            f = b ^ c ^ d;
        else if (t < 60)
            f = (b & c) | (b & d) | (c & d);
        else
            f = b ^ c ^ d;
        temp = rotate(a, 5) + f + e + w[t] + sha1_K[t / 20];
        e = d;  d = c;  c = rotate(b, 30);  b = a; a = temp;
    }

    h[0] += a;  h[1] += b;  h[2] += c;  h[3] += d;  h[4] += e;
}

typedef struct SHA1State_ {
    uint32_t h[5];
    uint32_t len_low, len_high;
} SHA1State;

static int
algo_sha1_init (Filter *filter, int options_pos) {
    SHA1State *state = ALGO_STATE(filter);
    (void) options_pos;     /* unused */

    state->h[0] = 0x67452301;
    state->h[1] = 0xEFCDAB89;
    state->h[2] = 0x98BADCFE;
    state->h[3] = 0x10325476;
    state->h[4] = 0xC3D2E1F0;

    state->len_low = state->len_high = 0;
    return 1;
}

static const unsigned char *
algo_sha1 (Filter *filter,
           const unsigned char *in, const unsigned char *in_end,
           unsigned char *out, unsigned char *out_max, int eof)
{
    SHA1State *state = ALGO_STATE(filter);
    uint32_t *h = state->h;
    unsigned char buff[64];
    const unsigned char *in_start = in;
    unsigned long num_bits;

    /* Only the first 16 words of this are loaded here, the rest is only used
     * inside sha1_digest. */
    uint32_t wbuff[80];

    while (in_end - in >= 64) {
        sha1_bytestoword32(wbuff, in);
        sha1_digest(wbuff, h);
        in += 64;
    }

    if (eof)
        num_bits = (in_end - in_start) * 8;     /* everything that's left */
    else
        num_bits = (in - in_start) * 8;         /* just what's done so far */

    state->len_low += num_bits;
    state->len_low &= 0xFFFFFFFF;
    if (state->len_low < num_bits) {
        ++state->len_high;
        state->len_high &= 0xFFFFFFFF;
    }

    if (eof) {
        int numbytes = in_end - in;
        memcpy(buff, in, numbytes);
        in += numbytes;
        memset(buff + numbytes, 0, 64 - numbytes);
        buff[numbytes] = 0x80;
        sha1_bytestoword32(wbuff, buff);

        if (numbytes > 64 - 9) {
            sha1_digest(wbuff, h);
            memset(buff, 0, 64);
            sha1_bytestoword32(wbuff, buff);
        }

        wbuff[14] = state->len_high;
        wbuff[15] = state->len_low;
        sha1_digest(wbuff, h);

        if (out_max - out < 20)
            out = filter->do_output(filter, out, &out_max);
        sha1_word32tobytes(h, out);
        filter->buf_out_end = out + 20;
    }

    return in;
}

#undef rotate
