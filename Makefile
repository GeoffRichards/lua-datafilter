PACKAGE=lua-datafilter
VERSION=$(shell head -1 Changes | sed 's/ .*//')
RELEASEDATE=$(shell head -1 Changes | sed 's/.* //')
PREFIX=/usr/local
DISTNAME=$(PACKAGE)-$(VERSION)

# The path to where the module's source files should be installed.
LUA_CPATH:=$(shell pkg-config lua5.1 --define-variable=prefix=$(PREFIX) \
                              --variable=INSTALL_CMOD)

LIBDIR = $(PREFIX)/lib

# Uncomment this to run the regression tests with valgrind.
#VALGRIND = valgrind -q --leak-check=yes --show-reachable=yes --num-callers=10

OBJECTS = filter.lo
SOURCES := $(OBJECTS:.lo=.c)

LIBTOOL := libtool --quiet

CC := gcc
CFLAGS := -ansi -pedantic -Wall -W -Wshadow -Wpointer-arith \
          -Wcast-align -Wwrite-strings -Wstrict-prototypes \
          -Wmissing-prototypes -Wnested-externs -Wno-long-long \
          $(shell pkg-config --cflags lua5.1) \
          -DVERSION=\"$(VERSION)\"
LDFLAGS := $(shell pkg-config --libs lua5.1)

# Uncomment this line to enable optimization.  Comment it out when running
# the test suite because it makes the assert() errors clearer and avoids
# warnings about ridiculously long string constants with some versions of gcc.
#CFLAGS := $(CFLAGS) -O3 -fomit-frame-pointer
CFLAGS := $(CFLAGS) -O2

# Uncomment this line to enable debugging.
#DEBUG := -g

# Uncomment one of these lines to enable profiling and/or gcov coverage testing.
#DEBUG := $(DEBUG) -pg
#DEBUG := $(DEBUG) -fprofile-arcs -ftest-coverage

all: liblua-datafilter.la manpages

manpages: doc/lua-datafilter.3 doc/lua-datafilter-base64.3 doc/lua-datafilter-pctenc.3 doc/lua-datafilter-qp.3
doc/lua-datafilter.3: doc/lua-datafilter.pod Changes
	sed 's/E<copy>/(c)/g' <$< | sed 's/E<ndash>/-/g' | \
	    pod2man --center="Lua module for munging data" \
	            --name="LUA-DATAFILTER" --section=3 \
	            --release="$(VERSION)" --date="$(RELEASEDATE)" >$@
doc/lua-datafilter-base64.3: doc/lua-datafilter-base64.pod Changes
	sed 's/E<copy>/(c)/g' <$< | sed 's/E<ndash>/-/g' | \
	    pod2man --center="Base64 algorithms for Lua" \
	            --name="LUA-DATAFILTER-BASE64" --section=3 \
	            --release="$(VERSION)" --date="$(RELEASEDATE)" >$@
doc/lua-datafilter-pctenc.3: doc/lua-datafilter-pctenc.pod Changes
	sed 's/E<copy>/(c)/g' <$< | sed 's/E<ndash>/-/g' | \
	    pod2man --center="Percent encoding algorithms for Lua" \
	            --name="LUA-DATAFILTER-PCTENC" --section=3 \
	            --release="$(VERSION)" --date="$(RELEASEDATE)" >$@
doc/lua-datafilter-qp.3: doc/lua-datafilter-qp.pod Changes
	sed 's/E<copy>/(c)/g' <$< | sed 's/E<ndash>/-/g' | \
	    pod2man --center="Quoted-printable algorithms for Lua" \
	            --name="LUA-DATAFILTER-QP" --section=3 \
	            --release="$(VERSION)" --date="$(RELEASEDATE)" >$@

test: all
	echo 'lunit.main({...})' | $(VALGRIND) lua -llunit - test/*.lua

install: all
	mkdir -p $(LUA_CPATH)
	install --mode=644 .libs/liblua-datafilter.so.0.0.0 $(LUA_CPATH)/datafilter.so
	mkdir -p $(PREFIX)/share/man/man3
	for manpage in datafilter datafilter-base64 datafilter-qp datafilter-pctenc; do \
	    gzip -c doc/lua-$$manpage.3 >$(PREFIX)/share/man/man3/lua-$$manpage.3.gz; \
	done


checktmp:
	@if [ -e tmp ]; then \
	    echo "Can't proceed if file 'tmp' exists"; \
	    false; \
	fi
dist: all checktmp
	mkdir -p tmp/$(DISTNAME)
	tar cf - --files-from MANIFEST | (cd tmp/$(DISTNAME) && tar xf -)
	cd tmp && tar cf - $(DISTNAME) | gzip -9 >../$(DISTNAME).tar.gz
	cd tmp && tar cf - $(DISTNAME) | bzip2 -9 >../$(DISTNAME).tar.bz2
	rm -rf tmp


%.lo: %.c
	@echo 'CC>' $@
	@$(LIBTOOL) --mode=compile $(CC) $(CFLAGS) $(DEBUG) -c -o $@ $<
liblua-datafilter.la: filter.lo
	@echo 'LD>' $@
	@$(LIBTOOL) --mode=link $(CC) $(LDFLAGS) $(DEBUG) -o $@ $< -rpath $(LIBDIR)

filter.lo: filter.c datafilter.h algorithms.c algo/base64.c algo/qp.c algo/pctenc.c algo/md5.c algo/sha1.c algo/adler32.c algo/hex.c algorithms.c

algorithms.c: algorithms.txt algorithms.pl
	./algorithms.pl $< $@

clean:
	rm -f *.o *.lo
	rm -rf liblua-datafilter.la .libs
	rm -f gmon.out *.bb *.bbg *.da *.gcov
realclean: clean
	rm -f algorithms.c
	rm -f doc/lua-datafilter*.3

.PHONY: all manpages test install checktmp dist clean realclean
