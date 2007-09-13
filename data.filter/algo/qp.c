/* data.filter algorithms: qp_decode, qp_encode
 */

/* QP input shouldn't have more than 76 characters per line, so we can
 * reasonably not deal with arbitrarily long lines if that would be hard.
 * The only case this matters with is when there's a huge amount of whitespace
 * at the end of a QP line, which should be ignored.  But we can't ignore it
 * unless we keep track of where it starts, and if it's too big it won't all
 * fit in the buffer.  To deal with that, we give up ignoring whitespace that
 * might be at the end of the line if the line turns out to be longer than
 * this value.
 */
#define QP_TOLERATE_LINE_LEN 256

static const unsigned char *
qp_output_whitespace (Filter *filter,
                      const unsigned char *ws_start, const unsigned char *in,
                      unsigned char **out, unsigned char **out_max)
{
    if (*out_max - *out < QP_TOLERATE_LINE_LEN)
        *out = filter->do_output(filter, *out, out_max);
    assert(*out_max - *out >= QP_TOLERATE_LINE_LEN);
    memcpy(*out, ws_start, in - ws_start);
    *out += in - ws_start;
    return in;
}

#define my_ishex(c) (((c) >= 48 && (c) <= 57) || \
                     ((c) >= 65 && (c) <= 70) || \
                     ((c) >= 97 && (c) <= 102))
#define hex_digit_val(c) ((c) >= 48 && (c) <= 57 ? ((c) - 48) \
                        : (c) >= 65 && (c) <= 70 ? ((c) - 55) \
                                                 : ((c) - 87))

static const unsigned char *
algo_qp_decode (Filter *filter,
                const unsigned char *in, const unsigned char *in_end,
                unsigned char *out, unsigned char *out_max, int eof)
{
    const unsigned char *ws_start = in;
    unsigned char c;

    while (in != in_end) {
        if (in - ws_start == QP_TOLERATE_LINE_LEN) {
            /* Huge amounts of whitespace, so assume it's significant and
             * output it.  Can't keep track of it forever. */
            ws_start = qp_output_whitespace(filter, ws_start, in,
                                            &out, &out_max);
        }

        c = *in;
        if (c == 61) {                      /* = */
            if (ws_start != in)
                ws_start = qp_output_whitespace(filter, ws_start, in,
                                                &out, &out_max);
            if (in_end - in < 3 && !eof)
                break;      /* wait until we know what comes after */
            c = *++in;
            if (c == 13 || c == 10) {       /* soft line break, skip */
                ++in;
                if (c == 13 && *in == 10)
                    ++in;
            }
            else if (my_ishex(c) && my_ishex(*in)) {
                if (out == out_max)
                    out = filter->do_output(filter, out, &out_max);
                ++in;
                *out++ = (hex_digit_val(c) << 4) | hex_digit_val(*in);
                ++in;
            }
            else {                          /* bad encoding, treat as literal */
                if (out == out_max)
                    out = filter->do_output(filter, out, &out_max);
                *out++ = 61;
            }
            ws_start = in;
        }
        else if (c == 9 || c == 32) {       /* tab or space */
            ++in;
        }
        else if (c >= 33 && c <= 126) {     /* printable ASCII char */
            if (ws_start != in)
                ws_start = qp_output_whitespace(filter, ws_start, in,
                                                &out, &out_max);
            if (out == out_max)
                out = filter->do_output(filter, out, &out_max);
            *out++ = c;
            ws_start = ++in;
        }
        else if (c == 13 || c == 10) {      /* hard line break */
            if (c == 13 && in + 1 == in_end && !eof)
                break;  /* CR at end of buffer, wait to see if LF is next */
            ++in;
            if (c == 13 && in != in_end && *in == 10)
                ++in;                       /* CR followed by LF */
            if (out == out_max)
                out = filter->do_output(filter, out, &out_max);
            *out++ = 10;
            ws_start = in;                  /* discard trailing whitespace */
        }
        else {
            /* TODO - bad character, ignore or error at user option */
            assert(0);
        }
    }

    if (eof)
        ws_start = in;      /* discard any remaining whitespace at EOF */

    filter->buf_out_end = out;
    return ws_start;
}

typedef struct QPEncodeState_ {
    const unsigned char *line_ending;
    size_t line_ending_len, cur_line_length;
} QPEncodeState;

static void
algo_qp_encode_init (Filter *filter, int options_pos) {
    QPEncodeState *state = ALGO_STATE(filter);
    lua_State *L = filter->L;
    const char *s;

    state->line_ending = default_line_ending;
    state->line_ending_len = sizeof(default_line_ending);
    state->cur_line_length = 0;

    if (options_pos) {
        lua_getfield(L, options_pos, "line_ending");
        if (!lua_isnil(L, -1)) {
            if (!lua_isstring(L, -1))
                luaL_error(L, "bad value for 'line_ending' option,"
                           " should be a string");
            s = lua_tolstring(L, -1, &state->line_ending_len);
            if (state->line_ending_len == 0)
                state->line_ending = 0;
            else
                state->line_ending = my_strduplen(
                    filter, (unsigned char *) s, state->line_ending_len);
        }
        lua_pop(L, 1);
    }
}

static void
algo_qp_encode_destroy (Filter *filter) {
    QPEncodeState *state = ALGO_STATE(filter);
    if (state->line_ending && state->line_ending != default_line_ending)
        filter->alloc(filter->alloc_ud, (char *) state->line_ending,
                      state->line_ending_len, 0);
}

static const unsigned char *
algo_qp_encode (Filter *filter,
                const unsigned char *in, const unsigned char *in_end,
                unsigned char *out, unsigned char *out_max, int eof)
{
    QPEncodeState *state = ALGO_STATE(filter);
    unsigned char c = 13;   /* default avoids soft line break in empty input */
    unsigned int room, needed;
    const unsigned char *in_tmp;

    while (in != in_end) {
        /* Decide whether to output a soft line break. */
        if (in_end - in < 4 && !eof)
            break;      /* wait for more */
        room = EMAIL_MAX_LINE_LENGTH - state->cur_line_length;
        if (room <= 4) {
            in_tmp = in;
            needed = 0;
            while (in_tmp != in_end) {
                c = *in_tmp++;
                if (c >= 33 && c <= 126 && c != 61)
                    ++needed;
                else if (c == 32 || c == 9) {
                    if (in_tmp != in_end && (*in_tmp == 13 || *in_tmp == 10))
                        needed += 3;
                    else
                        ++needed;
                }
                else if (c != 13 && c != 10)
                    needed += 3;
                break;
            }
            if (in_tmp == in_end || (*in_tmp != 13 && *in_tmp != 10))
                --room;     /* space for '=' at end of line */
            if ((needed > 0 && room == 0) || needed > room) {
                /* Output soft line break */
                if ((size_t) (out_max - out) < state->line_ending_len + 1)
                    out = filter->do_output(filter, out, &out_max);
                *out++ = 61;
                if (state->line_ending_len > 0) {
                    memcpy(out, state->line_ending, state->line_ending_len);
                    out += state->line_ending_len;
                }
                state->cur_line_length = 0;
            }
        }

        c = *in++;
        if (c >= 33 && c <= 126 && c != 61) {       /* printable ASCII char */
            if (out == out_max)
                out = filter->do_output(filter, out, &out_max);
            *out++ = c;
            ++state->cur_line_length;
        }
        else if (c == 13 || c == 10) {
            if (c == 13) {
                if (in == in_end && !eof) {
                    --in;
                    break;      /* wait for more */
                }
                if (in != in_end && *in == 10)
                    ++in;
            }

            /* Output hard line break */
            if (state->line_ending_len > 0) {
                if ((size_t) (out_max - out) < state->line_ending_len)
                    out = filter->do_output(filter, out, &out_max);
                memcpy(out, state->line_ending, state->line_ending_len);
                out += state->line_ending_len;
            }
            state->cur_line_length = 0;
        }
        else if (c == 9 || c == 32) {       /* tab or space */
            if (in == in_end && !eof) {
                --in;
                break;      /* wait to see what comes next */
            }
            if (in == in_end || *in == 13 || *in == 10) {
                /* Escape it so that it won't end up as ignoreably whitespace
                 * on the end of a line. */
                if (out_max - out < 3)
                    out = filter->do_output(filter, out, &out_max);
                *out++ = 61;
                *out++ = hex_char_codes_upper[c >> 4];
                *out++ = hex_char_codes_upper[c & 0xF];
                state->cur_line_length += 3;
            }
            else {
                if (out == out_max)
                    out = filter->do_output(filter, out, &out_max);
                *out++ = c;
                ++state->cur_line_length;
            }
        }
        else {
            if (out_max - out < 3)
                out = filter->do_output(filter, out, &out_max);
            *out++ = 61;
            *out++ = hex_char_codes_upper[c >> 4];
            *out++ = hex_char_codes_upper[c & 0xF];
            state->cur_line_length += 3;
        }
    }

    /* If the input stream doesn't end with a line break then we need
     * to add a soft one to make it explicit that there's no real line
     * break (in case one would get added anyway during transit). */
    if (eof && in == in_end && c != 13 && c != 10) {
        if ((size_t) (out_max - out) < state->line_ending_len + 1)
            out = filter->do_output(filter, out, &out_max);
        *out++ = 61;
        if (state->line_ending_len > 0) {
            memcpy(out, state->line_ending, state->line_ending_len);
            out += state->line_ending_len;
        }
        state->cur_line_length = 0;
    }

    filter->buf_out_end = out;
    return in;
}

/* vi:set ts=4 sw=4 expandtab: */
