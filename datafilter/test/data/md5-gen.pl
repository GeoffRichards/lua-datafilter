#!/usr/bin/perl -w
use strict;

# Generate the MD5 hash data for the 't/md5.lua' test program.  We use the
# system 'md5sum' program since that's likely to be reliable.

sub hash {
    my ($bytes) = @_;
    open my $fh, '>', 'hashtmp' or die $!;
    my $i = 7;
    my $count = 0;
    my %seen;
    while ($count++ < $bytes) {
        die if $seen{$i}++;
        print $fh chr($i);
        $i += 23;
        $i = $i % 256;
    }
    close $fh or die $!;

    die "should be $bytes bytes" unless -s 'hashtmp' == $bytes;
    my $hash_filename = qx(md5sum hashtmp);
    $hash_filename =~ s/\s.*//s;
    return $hash_filename;
}

for my $bytes (1 .. 256) {
    my $hash = hash($bytes);
    print "    \"$hash\",\n";
}

unlink 'hashtmp' or die $!;

# vi:ts=4 sw=4 expandtab
