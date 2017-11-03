use v6;

use LWP::Simple;
use HTML::Parser::XML;
use XML::Document;

sub MAIN(:$domain="https://perl6.org", :$concurrent=20) {
    say "Crawling: $domain";
    my $page = LWP::Simple.get($domain);
	my @urls = extract_links($domain, $page);
    my @promises;
    for @urls -> $url {
	    my $p = Promise.start({ &crawl($url) });
        @promises.push($p);
    }
    my $finished = Promise.allof(@promises);
    await $finished;
    for @promises -> $p {
        my @urls = extract_links($domain, $p.result);
		say @urls;
		say '---------';
    }
    say "Done";
}

sub crawl($url) {
	say $url;
	return LWP::Simple.get($url);
}

sub extract_links($domain, $page) {
    my $p = HTML::Parser::XML.new;
    my XML::Document $doc = $p.parse($page);
    # <a> elements (might) have URLs to crawl 
    my @anchors = $doc.elements(:TAG<a>, :RECURSE);
    my @urls = normalise($domain, @anchors);
	return @urls;
}

sub normalise($domain, @urls) {
    my @normalised;
    for @urls -> $url {
        next unless $url<href>.defined;
        my $href =  $url<href>.Str;

        # Convert rel to abs urls
        if $href.starts-with('/') {
            $href = $domain ~ $href;
        }

        # Keep URL if it's local to start domain
        if $href.starts-with($domain) {
            push @normalised, $href
        }
    }
    return @normalised;
}

