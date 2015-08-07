use v6;
use Test;
plan 15;

use URI;
ok(1,'We use URI and we are still alive');

my $u = URI.new('http://example.com:80/about/us?foo#bar');

is($u.scheme, 'http', 'right initial scheme');
$u.scheme = 'ftp';
is($u.scheme, 'ftp', 'right new scheme');

is($u.frag, 'bar', 'right initial frag');
$u.frag = 'blaz';
is($u.frag, 'blaz', 'right new frag');

is($u.port, 80, 'right initial port');
is($u.host, 'example.com', 'right initial host');
$u.authority = 'www.perl6.org:8080';
is($u.port, 8080, 'right new port set by authority');
is($u.host, 'www.perl6.org', 'right new host set by authority');

$u.host = 'perlmonks.org';
is($u.host, 'perlmonks.org', 'right new host');
is($u.authority, 'perlmonks.org:8080', 'right new authority set by host');

$u.port = '';
is($u.port, 21, 'right new default port for ftp');
is($u.authority, 'perlmonks.org', 'right new authority set by clearing port');

$u.port = 8888;
is($u.port, 8888, 'right new port');
is($u.authority, 'perlmonks.org:8888', 'right new authority set by port');
