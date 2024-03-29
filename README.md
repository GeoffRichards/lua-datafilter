This Lua library makes it convenient to process data using various
algorithms, and to handle arbitrarily large amounts of input and output data
with them.

Currently the algorithms supported are: MD5 and SHA-1 message digests,
Adler32 checksumming, Base64 encoding and decoding, quoted-printable
encoding and decoding, encoding binary data as hexadecimal, and percent/URI
encoding and decoding.

When you unpack the source code everything should already be ready for
compilation.  Doing `make install` as root will compile everything, and
install the compiled library and some man pages describing it.

See lua-datafilter(3) for an overview of how to use the library.  The same
documentation is available on the website, where you can also get the
latest packages:

<https://geoffrichards.co.uk/lua/datafilter/>

Send bug reports, suggestions, etc. to Geoff Richards <geoff@geoffrichards.co.uk>
