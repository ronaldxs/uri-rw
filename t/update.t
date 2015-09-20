use v6;
use Test;
plan 29;

use URI;
ok(1,'We use URI and we are still alive');

my $u = URI.new('http://example.com:80/about/us?foo#bar');

is($u.scheme, 'http', 'right initial scheme');
$u.scheme = 'ftp';
is($u.scheme, 'ftp', 'right new scheme');
try {$u.scheme='??@@'};
ok($!.message ~~ /Invalid.*syntax.*scheme/, 'recognized bad scheme');

is($u.frag, 'bar', 'right initial frag');
$u.frag = 'blaz';
is($u.frag, 'blaz', 'right new frag');
try {$u.frag='ab#de'};
ok($!.message ~~ /Invalid.*syntax.*fragment/, 'recognized bad fragment');

is($u.port, 80, 'right initial port');
is($u.host, 'example.com', 'right initial host');
$u.authority = 'www.perl6.org:8080';
is($u.port, 8080, 'right new port set by authority');
is($u.host, 'www.perl6.org', 'right new host set by authority');
try {$u.authority = '??##'};
ok($!.message ~~ /Invalid.*syntax.*authority/, 'recognized bad authority');

$u.host = 'perlmonks.org';
is($u.host, 'perlmonks.org', 'right new host');
is($u.authority, 'perlmonks.org:8080', 'right new authority set by host');
my $parse-host = $u.parse-result<URI-reference><URI><hier-part><authority><host>;
is($parse-host, 'perlmonks.org', 'test that parse tree updated as needed');
try {$u.host = '??##'};
ok($!.message ~~ /Invalid.*syntax.*host/, 'recognized bad host');

$u.port = '';
is($u.port, 21, 'right new default port for ftp');
is($u.authority, 'perlmonks.org', 'right new authority set by clearing port');

$u.port = 8888;
is($u.port, 8888, 'right new port');
is($u.authority, 'perlmonks.org:8888', 'right new authority set by port');
try {$u.port = 'nn@nn'};
ok($!.message ~~ /Invalid.*syntax.*port/, 'recognized bad port');

$u.path = '/what/about/them';
is($u.path, '/what/about/them', 'set path');
is(~$u, 'ftp://perlmonks.org:8888/what/about/them?foo#blaz', 'path set uri');
try {$u.path = '#???@&'};
ok($!.message ~~ /Invalid.*syntax.*path/, 'recognized bad path');

is($u.query, 'foo', 'right initial query');
$u.query = 'fizz=baz';
is($u.query, 'fizz=baz', 'set path');
is(~$u, 'ftp://perlmonks.org:8888/what/about/them?fizz=baz#blaz',
    'query set uri');
is($u.query_form<fizz>, 'baz', 'query set query form');
try {$u.query = '#???@&'};
ok($!.message ~~ /Invalid.*syntax.*query/, 'recognized bad query');
