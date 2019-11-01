package Title::Platform;

use strict;

use LWP::UserAgent;

sub new {
    my ($class, $parent) = @_;

    die "parent not specified" unless $parent;

    my $ua = LWP::UserAgent->new();
    $ua->cookie_jar({});

    my $self = {
        parent => $parent,
        ua => $ua
    };

    bless($self, $class);
    return $self;
}

sub get_url {
    my ($self, $url) = @_;
    my $request = new HTTP::Request(GET => $url);
    my $response = $self->{ua}->request($request);
    return $response->content;
}

sub get_id {
    die "get_id() method must be redeclared in the ancestor class";
}

sub parse_url {
    die "parse_url() method must be redeclared in the ancestor class";
}

sub fetch_available_timedtext_tracks {
    die "fetch_available_timedtext_tracks() method must be redeclared in the ancestor class";
}

sub fetch_timedtext_track {
    die "fetch_timedtext_track() method must be redeclared in the ancestor class";
}

sub generate_preview_link {
    die "generate_preview_link() method must be redeclared in the ancestor class";
}

1;