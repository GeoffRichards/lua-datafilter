PACKAGE=Lua-Data-Filter
VERSION=$(shell head -1 Changes | sed 's/ .*//')
RELEASEDATE=$(shell head -1 Changes | sed 's/.* //')
PREFIX=/usr/local
DISTNAME=$(PACKAGE)-$(VERSION)

LIBDIR = $(PREFIX)/lib

# Uncomment this to run the regression tests with valgrind.
#VALGRIND = valgrind -q --leak-check=yes --show-reachable=yes --num-callers=10

OBJECTS = filter.lo
SOURCES := $(OBJECTS:.lo=.c)

LIBTOOL := libtool --quiet

CFLAGS := -ansi -pedantic -Wall -W -Wshadow -Wpointer-arith \
          -Wcast-align -Wwrite-strings -Wstrict-prototypes \
          -Wmissing-prototypes -Wnested-externs -Wno-long-long \
          $(shell pkg-config --cflags lua5.1) \
          -DVERSION=\"$(VERSION)\"
LDFLAGS := $(shell pkg-config --libs lua5.1)

# Uncomment these lines to enable optimization.  Comment them out when running
# the test suite because it makes the assert() errors clearer and avoids
# warnings about ridiculously long string constants with some versions of gcc.
#CFLAGS := $(CFLAGS) -O3 -fomit-frame-pointer
#LDFLAGS := $(LDFLAGS)

# Uncomment these lines to enable debugging.
CFLAGS := $(CFLAGS) -g
LDFLAGS := $(LDFLAGS) -g

# Uncomment one of these pairs of lines to enable profiling and/or gcov
# coverage testing.
#CFLAGS := $(CFLAGS) -pg
#LDFLAGS := $(LDFLAGS) -pg
#CFLAGS := $(CFLAGS) -fprofile-arcs -ftest-coverage
#LDFLAGS := $(LDFLAGS) -fprofile-arcs -ftest-coverage

all: liblua-data.filter.la

doc/lua-TODO.3: doc/TODO.pod
	sed 's/E<copy>/(c)/g' <$< | \
	    pod2man --center="Lua module for parsing ISBN numbers" \
	            --name="LUA-ISBN" --section=3 \
	            --release="$(VERSION)" --date="$(RELEASEDATE)" >$@

test: all
	for f in t/*.lua; do $(VALGRIND) lua $$f; done

install: all
	mkdir -p $(LUA_SPATH)/ISBN
	install --mode=644 ISBN.lua $(LUA_SPATH)/
	install --mode=644 ISBN/_data.lua $(LUA_SPATH)/ISBN/
	mkdir -p $(PREFIX)/share/man/man3
	gzip -c doc/lua-isbn.3 >$(PREFIX)/share/man/man3/lua-isbn.3.gz


dist: all
	@if [ -e tmp ]; then \
	    echo "Can't proceed if file 'tmp' exists"; \
	    false; \
	fi
	mkdir -p tmp/$(DISTNAME)
	tar cf - --files-from MANIFEST | (cd tmp/$(DISTNAME) && tar xf -)
	cd tmp && tar cf - $(DISTNAME) | gzip -9 >../$(DISTNAME).tar.gz
	cd tmp && tar cf - $(DISTNAME) | bzip2 -9 >../$(DISTNAME).tar.bz2
	rm -f $(DISTNAME).zip
	cd tmp && zip -q -r ../$(DISTNAME).zip $(DISTNAME)
	rm -rf tmp

# Dependencies.
%.d: %.c
	@echo 'DEP>' $@
	@$(CC) -M $(CFLAGS) $< | \
	   sed -e 's,\($*\)\.o[ :]*,\1.lo $@ : ,g' > $@
-include $(SOURCES:.c=.d)

%.lo: %.c
	@echo 'CC>' $@
	@$(LIBTOOL) --mode=compile $(CC) $(CFLAGS) -c -o $@ $<
liblua-data.filter.la: filter.lo
	@echo 'LD>' $@
	@$(LIBTOOL) --mode=link $(CC) $(LDFLAGS) -o $@ $< -rpath $(LIBDIR)

clean:
	rm -f *.o *.lo *.d core
	source .libs/liblua-data.filter.lai && \
	    linkname=$$(echo $$library_names | sed 's/.* //') ; \
	    rm -f $$linkname
	rm -rf liblua-data.filter.la .libs
	rm -f doc/lua-TODO.3
	rm -f gmon.out *.bb t/*.bb *.bbg t/*.bbg *.da t/*.da *.gcov t/*.gcov
realclean: clean
	rm -f enctables.c

.PHONY: all test install dist clean realclean
