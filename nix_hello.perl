#! /usr/bin/env nix-shell
#! nix-shell -i perl -p perl perlPackages.HTMLTokeParserSimple perlPackages.LWP
#! nix-shell -I nixpkgs=channel:nixos-19.09

use HTML::TokeParser::Simple;

# Fetch nixos.org and print all hrefs.
my $p = HTML::TokeParser::Simple->new(url => 'http://nixos.org/');

while (my $token = $p->get_tag("a")) {
    my $href = $token->get_attr("href");
    print "$href\n" if $href;
}


