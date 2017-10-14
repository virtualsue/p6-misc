use v6;

use LWP::Simple;
use HTML::Parser::XML;
use XML::Document;
use Data::Dump;

sub MAIN(:$domain="https://perl6.org", :$concurrent=20) {
   say "Crawling: $domain";
   my $page = LWP::Simple.get($domain);
   my $p = HTML::Parser::XML.new;
   my XML::Document $doc = $p.parse($page);
   # URLs to crawl 
   my @anchors = $doc.elements(:TAG<a>, :RECURSE);
   for @anchors -> $anchor {
      # Put URL in 'visited' hash
      say $anchor<href>;
   }
   # Page assets
   say "Page assets";
   my @assets = $doc.elements(:TAG<link>, :TAG<script>, :TAG<img>, :RECURSE);
   for @assets -> $asset {
      say $asset.name;
   }
}

