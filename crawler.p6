use v6;

use LWP::Simple;
use HTML::Parser::XML;
use XML::Document;

my %visited;

sub MAIN(:$domain="https://perl6.org", :$concurrent=20) {
	my $t0 = DateTime.now.Instant;

	my $page = LWP::Simple.get($domain);
    my @urls = extract($domain,$page);

	my @promises;
	for @urls -> $url {
		my $p = Promise.start({ &fetch($domain,$url) });
		@promises.push($p);
	}

	await Promise.allof(@promises);

	say DateTime.now.Instant-$t0 ~ " sec(s)";

}

sub extract($domain,$page) {
    my $p = HTML::Parser::XML.new;
    my XML::Document $doc = $p.parse($page);
    # URLs to crawl 
    my %todo;
    my @anchors = $doc.elements(:TAG<a>, :RECURSE);
    for @anchors -> $anchor {
        next unless $anchor<href>.defined;
        my $href =  $anchor<href>.Str;

        # Convert rel to abs urls
        if $href.starts-with('/') {
            $href = $domain ~ $href;
        }

        # unique list from page
        if $href.starts-with($domain) {
            %todo{$href}++;
        }
    }
    my @urls = %todo.keys;

    return @urls;

}

sub fetch($domain,$url) {
    return if %visited{$url};
    dd $url;
    my $html = LWP::Simple.get($url);
    %visited{$url}++;
    my @urls = extract($domain, $html);
    # ...
}


