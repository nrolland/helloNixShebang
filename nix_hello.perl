#! /usr/bin/env nix-shell
#! nix-shell -i perl -p perl perlPackages.HTMLTokeParserSimple perlPackages.LWP perlPackages.LWPProtocolHttps
#! nix-shell -I nixpkgs=https://github.com/NixOS/nixpkgs/archive/4382ed2b7a6839d4280a9b386db49cbc5907414d.tar.gz

use HTML::TokeParser::Simple;

# Fetch nixos.org and print all hrefs.
my $p = HTML::TokeParser::Simple->new(url => 'https://nixos.org/');

while (my $token = $p->get_tag("a")) {
    my $href = $token->get_attr("href");
    print "$href\n" if $href;
}


