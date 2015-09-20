
# Perl6 realization of URI handler

URI - Uniform Resource Identifiers

### A URI implementation using Perl 6 grammars to implement RFC 3986 BNF.

Now handles both parsing and some modification.

examples:

    use URI;
    my $u = URI.new('http://here.com/foo/bar?tag=woow#bla');

    my $scheme = $u.scheme;
    my $authority = $u.authority;
    my $host = $u.host;
    my $port = $u.port;
    my $path = $u.path;
    my $query = $u.query;
    my $frag = $u.frag; # or $u.fragment;
    my $tag = $u.query_form<tag>; # should be woow

    # something p5 URI without grammar could not easily do !
    my $host_in_grammar =
        $u.parse-result<URI-reference><URI><hier-part><authority><host>;
    if ($host_in_grammar<reg-name>) {
        say 'Host looks like registered domain name - approved!';
    }
    else {
        say 'Sorry we do not take ip address hosts at this time.';
        say 'Please use registered domain name!';
    }

Modification examples:

    # now with updateable URI components
    my $u = URI.new('http://here.com/foo/bar?tag=woow#bla');
    $u.scheme = 'ftp';
    $u.host = 'there.com';
    $u.port = 8080;
    $u.frag = '';
    # say $u now yields ftp://there.com:8080/foo/bar?tag=woow

