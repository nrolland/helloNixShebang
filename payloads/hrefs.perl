use HTML::TokeParser::Simple;

# Fetch nixos.org and print all hrefs.
my $p = HTML::TokeParser::Simple->new(url => 'https://nixos.org/');

while (my $token = $p->get_tag("a")) {
    my $href = $token->get_attr("href");
    print "$href\n" if $href;
}


