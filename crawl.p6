#!/usr/bin/env perl6
use v6;
use LWP::Simple;

my $t0 = DateTime.now.Instant;

#my @urls = "http://www.yahoo.com", "http://www.msn.com";
my @urls = 0..99;

my @promises;
for @urls -> $url {
    my $p = Promise.start({ &doit($url) });
    @promises.push($p);
}

await Promise.allof(@promises);

say DateTime.now.Instant-$t0 ~ " sec(s)";

sub doit($url) {
    $url.say;
    sleep 2;
}
