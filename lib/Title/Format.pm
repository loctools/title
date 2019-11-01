package Title::Format;

use strict;

sub new {
    my ($class, $parent) = @_;

    die "parent not specified" unless $parent;

    my $self = {
        parent => $parent
    };

    bless($self, $class);
    return $self;
}

sub get_id {
    die "get_id() method must be redeclared in the ancestor class";
}

sub get_extensions {
    die "get_extensions() method must be redeclared in the ancestor class";
}

sub parse {
    die "parse() method must be redeclared in the ancestor class";
}

sub generate {
    die "generate() method must be redeclared in the ancestor class";
}

1;