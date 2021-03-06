unit class URI;

use URI::Component;
use URI::InvalidSyntax;

use IETF::RFC_Grammar;
use IETF::RFC_Grammar::URI;
use URI::Escape;
need URI::DefaultPort;

has $.grammar;
has $.parse-result;
has Bool $!need-reparse;
has $.is_validating is rw = False;
has $!path;
has $!is_absolute;  # part of deprecated code scheduled for removal
has $!scheme;
has $!authority;
has $!query;
has $!frag;
has %!query_form;
has $.port;
has $!uri;  # use of this now deprecated

has @.segments;

method parse (Str $str) {

    # clear string before parsing
    my $c_str = $str;
    $c_str .= subst(/^ \s* ['<' | '"'] /, '');
    $c_str .= subst(/ ['>' | '"'] \s* $/, '');

    $!uri = $!path = $!is_absolute = $!scheme = $!authority = $!query =
        $!frag = Mu;
    %!query_form = @!segments = ();

    try {
        if ($.is_validating) {
            $!grammar.parse_validating($c_str);
        }
        else {
            $!grammar.parse($c_str);
        }

        CATCH {
            default {
                die "Could not parse URI: $str"
            }
        }
    }

    # now deprecated
    $!uri = $!grammar.parse_result;
    $!parse-result = $!grammar.parse_result;

    my $comp_container = $!grammar.parse_result<URI-reference><URI> ||
        $!grammar.parse_result<URI-reference><relative-ref>;
    $!scheme = $comp_container<scheme>;
    $!query = $comp_container<query>;
    $!frag = $comp_container<fragment>;
    $comp_container = $comp_container<hier-part> || $comp_container<relative-part>;

    $!authority = $comp_container<authority>;
    $!path =    $comp_container<path-abempty>       ||
                $comp_container<path-absolute>      ;
    $!is_absolute = ?($!path || $!scheme); # part of deprecated code

    $!path ||=  $comp_container<path-noscheme>      ||
                $comp_container<path-rootless>      ;

    @!segments = $!path<segment>.list() || ('');
    if my $first_chunk = $!path<segment-nz-nc> || $!path<segment-nz> {
        unshift @!segments, $first_chunk;
    }
    if @!segments.elems == 0 {
        @!segments = ('');
    }
#    @!segments ||= ('');

    try {
        %!query_form = split_query( ~$!query ) if $!query;
        CATCH {
            default {
                %!query_form = ();
            }
        }
    }
}

our sub split_query(Str $query) {
    my %query_form;

    for map { [split(/<[=]>/, $_) ]}, split(/<[&;]>/, $query) -> $qmap {
        for (0, 1) -> $i { # could go past 1 in theory ...
            $qmap[ $i ] = uri_unescape($qmap[ $i ]);
        }
        if %query_form{$qmap[0]}:exists {
            if %query_form{ $qmap[0] } ~~ Array  {
                %query_form{ $qmap[0] }.push($qmap[1])
            }
            else {
                %query_form{ $qmap[0] } = [
                    %query_form{ $qmap[0] }, $qmap[1]
                ]
            }
        }
        else {
            %query_form{ $qmap[0]} = $qmap[1]
        }
    }

    return %query_form;
}

# deprecated old call for parse
method init ($str) {
    warn "init method now deprecated in favor of parse method";
    $.parse($str);
}

# new can pass alternate grammars some day ...
submethod BUILD(:$!is_validating) {
    $!grammar = IETF::RFC_Grammar.new('rfc3986');
}

method new(Str $uri_pos1?, Str :$uri, :$is_validating) {
    my $obj = self.bless;

    if $is_validating.defined {
        $obj.is_validating = ?$is_validating;
    }

    if $uri.defined and $uri_pos1.defined {
        die "Please specify the uri by name or position but not both.";
    }
    elsif $uri.defined or $uri_pos1.defined {
        $obj.parse($uri // $uri_pos1);
    }

    return $obj;
}

method scheme is rw {
    Proxy.new(
        FETCH => -> $self { ~$!scheme.lc },
        STORE => -> $self, Str $new-scheme {
            my $scheme-parse-rc = IETF::RFC_Grammar::URI.parse(
                $new-scheme, :rule<scheme>
            ) or die URI::InvalidSyntax.new(c => URI::Component::scheme);
            $!scheme = $scheme-parse-rc;
            $!need-reparse = True;
        }
    );
}

method authority is rw {
    Proxy.new(
        FETCH => -> $self { ~$!authority.lc },
        STORE => -> $self,
                    Str $new-authority {
            my $auth-parse-rc = IETF::RFC_Grammar::URI.parse(
                $new-authority, :rule<authority>
            ) or die URI::InvalidSyntax.new(c => URI::Component::authority);
            $!authority = $auth-parse-rc;
            $!need-reparse = True;
        }
    );
}

sub rebuild-authority-str(Str $userinfo, Str $host, Str $port) {
    my Str $rc = $host;
    $rc = $userinfo ~ '@' ~ $rc if $userinfo;
    $rc ~= ':' ~ $port if ($port);
    $rc;
}

method host is rw {
    Proxy.new(
        FETCH => -> $self { ($!authority<host> || '').lc },
        STORE => -> $self, Str $new-host {
            $new-host ~~ /^<IETF::RFC_Grammar::URI::host>$/ or
                die URI::InvalidSyntax.new(c => URI::Component::host);
            my $auth-parse-rc = IETF::RFC_Grammar::URI.parse(
                rebuild-authority-str(
                    ~($!authority<userinfo> // ''),
                    $new-host, ~($!authority<port> // '')
                ),
                :rule<authority>
            );
            if ($auth-parse-rc) {
                $!authority = $auth-parse-rc;
                $!need-reparse = True;
            }
            else {
                die "host not valid for URI authority";
            }
            $!need-reparse = True;
        }
    );
}

method default_port {
    URI::DefaultPort::_scheme_port($.scheme)
}

method _port {
    # port 0 is off limits and see also RT 96424
    # $!authority<port>.Int doesn't work because of RT 96472
    $!authority<port> ?? ($!authority<port> ~ '').Int !! Int;
}

method port is rw {
    Proxy.new(
        FETCH => -> $self { $._port // $.default_port; },
        STORE => -> $self, Cool $new-port {
            $new-port ~~ /^<IETF::RFC_Grammar::URI::port>$/ or
                die URI::InvalidSyntax.new(c => URI::Component::port);
            my $auth-parse-rc = IETF::RFC_Grammar::URI.parse(
                rebuild-authority-str(
                    ~($!authority<userinfo> // ''),
                    ~($!authority<host> // ''),
                    ~$new-port
                ),
                :rule<authority>
            );
            if ($auth-parse-rc) {
                $!authority = $auth-parse-rc;
                $!need-reparse = True;
            }
            else {
                die "port not valid for URI authority";
            }
            $!need-reparse = True;
        }
    );
}

method path {
    Proxy.new(
        FETCH => -> $self { ~($!path || '') },
        STORE => -> $self, Str $new-path {
            $new-path ~~ /^<IETF::RFC_Grammar::URI::path-abempty>$/ or
                die URI::InvalidSyntax.new(c => URI::Component::path);
            $!path = $new-path;
            my Str $new-uri-str = $.Str;
            $.parse($new-uri-str);
        }
    );
}

my $warn-deprecate-abs-rel = q:to/WARN-END/;
    The absolute and relative methods are artifacts carried over from an old
    version of the p6 module.  The perl 5 module does not provide such
    functionality.  The Ruby equivalent just checks for the presence or
    absence of a scheme.  The URI rfc does identify absolute URIs and
    absolute URI paths and these methods somewhat confused the two.  Their
    functionality at the URI level is no longer seen as needed and is
    being removed.
WARN-END

method absolute {
    warn "deprecated -\n$warn-deprecate-abs-rel";
    return Bool.new;
}

method relative {
    warn "deprecated -\n$warn-deprecate-abs-rel";
    return Bool.new;
}

method query {
    Proxy.new(
        FETCH => -> $self { ~($!query || '') },
        STORE => -> $self, Str $new-query {
            $new-query ~~ /^<IETF::RFC_Grammar::URI::query>$/ or
                die URI::InvalidSyntax.new(c => URI::Component::query);
            $!query = $new-query;
            my Str $new-uri-str = $.Str;
            $.parse($new-uri-str);
        }
    );
}

method path_query {
    $.query ?? $.path ~ '?' ~ $.query !! $.path
}


method frag {
    Proxy.new(
        FETCH => -> $self { ~($!frag // '').lc },
        STORE => -> $self, Str $new-fragment {
            $new-fragment ~~ /^<IETF::RFC_Grammar::URI::fragment>$/ or
                die URI::InvalidSyntax.new(c => URI::Component::fragment);
            $!need-reparse = True; 
            $!frag = $new-fragment
        }
    );
}

method fragment { $.frag }

method gist() {
    my $str;
    $str ~= $.scheme if $.scheme;
    $str ~= '://' ~ $.authority if $.authority;
    $str ~= $.path;
    $str ~= '?' ~ $.query if $.query;
    $str ~= '#' ~ $.frag if $.frag;
    return $str;
}

method Str() {
    return $.gist;
}

# chunks now strongly deprecated
# it's segments in p5 URI and segment is part of rfc so no more chunks soon!
method chunks {
    warn "chunks attribute now deprecated in favor of segments";
    return @!segments;
}

method uri {
    warn "uri attribute now deprecated in favor of .parse-result";
    return $!uri;
}

method query_form {
    return %!query_form;
}

method parse-result {
    if $!need-reparse {
        $.parse($.Str);
        $!need-reparse = False;
    }
    return $!parse-result;
}

=begin pod

=head1 NAME

URI — Uniform Resource Identifier

=head1 SYNOPSIS

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

    # require whole string matches URI and throw exception otherwise ..
    my $u_v = URI.new('http://?#?#', :is_validating<1>);# throw exception


    # now with updateable URI components
    my $u = URI.new('http://here.com/foo/bar?tag=woow#bla');
    $u.scheme = 'ftp';
    $u.host = 'there.com';
    $u.port = 8080;
    $u.frag = '';
    # say $u now yields ftp://there.com:8080/foo/bar?tag=woow

=end pod


# vim:ft=perl6
