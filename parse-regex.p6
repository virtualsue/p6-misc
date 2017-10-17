use v6;

use LWP::Simple;
use HTML::Parser::XML;
use XML::Document;
use Data::Dump;

sub MAIN(:$domain="https://golang.org", :$concurrent=20) {
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

	  # REPL good for "foo".^name (Str) & "foo".^methods

	  # Convert rel to abs urls
	  if $href ~~ m/^ '/' / {
		  $href = $domain ~ $href;
	  }

      # Put URL in 'visited' hash if it's local
	  if $href ~~ m/^ $domain / {
		  %visited{$href} = 1;
	  }
  }
   dd %visited;
}

