#!/usr/bin/perl -w
use strict;

# Generate the Adler32 hash data for the 't/adler32.lua' test program.
# There's no standard 'adler32sum' program, so use the Perl module.
use Digest::Adler32;

sub hash {
    my ($bytes) = @_;
    my $digest = Digest::Adler32->new;
    my $i = 7;
    my $count = 0;
    my %seen;
    while ($count++ < $bytes) {
        die if $seen{$i}++;
        $digest->add(chr($i));
        $i += 23;
        $i = $i % 256;
    }

    return $digest->hexdigest;
}

for my $bytes (1 .. 256) {
    my $hash = hash($bytes);
    print "    \"$hash\",\n";
}
