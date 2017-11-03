use v6;

use LWP::Simple;
use HTML::Parser::XML;
use XML::Document;

sub MAIN(:$domain="https://perl6.org", :$concurrent=20) {
   say "Crawling: $domain";
   my $page = LWP::Simple.get($domain);
   my $p = HTML::Parser::XML.new;
   my XML::Document $doc = $p.parse($page);
   # URLs to crawl 
   my @anchors = $doc.elements(:TAG<a>, :RECURSE);
   my %visited;
   for @anchors -> $anchor {
	  next unless $anchor<href>.defined;
	  my $href =  $anchor<href>.Str;

	  # Convert rel to abs urls
	  if $href.starts-with('/') {
		  $href = $domain ~ $href;
	  }

      # Put URL in 'visited' hash if it's local
	  if $href.starts-with($domain) {
		  %visited{$href} = 1;
	  }
  }
	# say %visited.keys;
	crawl(%visited.keys);
}

sub crawl(@links) {
	for @links -> $link {
		say $link;
	}
}
