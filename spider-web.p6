use v6;

use HTML::Parser::XML;
use XML::Document;
use HTTP::UserAgent;

sub MAIN(:$domain="http://localhost:20000") {

	my $ua =  HTTP::UserAgent.new;
    my %url_seen;
    my @urls=($domain);

    loop {
		my @promises;
        while ( @urls ) {
            my $url = @urls.shift;
            my $p = Promise.start({crawl($ua, $domain, $url)});
            @promises.push($p);
        }
		await Promise.allof(@promises);
        for @promises.kv -> $index, $p {
            if $p.status ~~ Kept {
				my @results =  $p.result;
				dd @results;
                for @results {
					unless %url_seen{$_} {
	                    @urls.push($_); 
						%url_seen{$_}++;
					}
                }
		    }
        }
        # Terminate if no more URLs to crawl
        if @urls.elems == 0 {
            last;
        }
    }
}


#TODO strip anchor stuff
sub crawl($ua, $domain, $uri) {
	say $uri;
    my $page = $ua.get($uri);
	say $page;
    my $p = HTML::Parser::XML.new;
    my XML::Document $doc = $p.parse($page.content);
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
