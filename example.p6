use v6;

my $p1 = Promise.new;
say $p1.status;         # OUTPUT: «Planned» 
$p1.keep('This is the result');
say $p1.status;         # OUTPUT: «Kept» 
say $p1.result;

say "\n------------------\n";

my $p2 = Promise.new;
say $p2.status;         # OUTPUT: «Planned» 
$p2.break('I broke my promise');
say $p2.status;         # OUTPUT: «Broken» 
say $p2.result;
