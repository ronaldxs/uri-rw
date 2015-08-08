unit class URI::InvalidSyntax is Exception;

use URI::Component;

has URI::Component $.c;

method message {
    'Invalid URI syntax for component ' ~ $!c.key
}
