package Title::Platform::Vimeo;
use parent Title::Platform;

use strict;

use JSON;

sub get_id {
    return 'Vimeo';
}

sub parse_url {
    my ($self, $url) = @_;

    if ($url =~ m|^https://vimeo.com/([^\?&]+)|) {
        return $1;
    }

    if ($url =~ m|^https://player.vimeo.com/video/([^\?&]+)|) {
        return $1;
    }

    return undef;
}

sub fetch_available_timedtext_tracks {
    my ($self, $video_id) = @_;

    my $url = "https://player.vimeo.com/video/$video_id";
    print "URL: $url\n";

    my $content = $self->get_url($url);

    my $config_json;
    if ($content =~ m|\svar config = (\{.*?\});\s|s) {
        $config_json = $1;
    } else {
        print "Remote server returned an unexpected content:\n";
        print "========================\n";
        print "$content\n";
        print "========================\n";
        return {};
    }

    my $config = from_json($config_json);

    if (!exists $config->{request} ||
        !exists $config->{request}->{text_tracks}) {
            print "No `request > text_tracks` node found\n";
            return {};
    }

    if (!exists $config->{video} ||
        !exists $config->{video}->{lang}) {
            print "No `video > lang` node found\n";
            return {};
    }

    my $tracks = {};
    my $default_lang = $config->{video}->{lang};
    foreach my $track (@{$config->{request}->{text_tracks}}) {
        if ($default_lang eq '') {
            $default_lang = $track->{lang};
        }

        $tracks->{lc($track->{lang})} = {
            url => 'https://vimeo.com'.$track->{url}
        };
    }

    return {
        tracks => $tracks,
        default_lang => $default_lang
    };
}

sub fetch_timedtext_track {
    my ($self, $url) = @_;

    print "URL: $url\n";
    my $content = $self->get_url($url);

    if ($content !~ m|^WEBVTT\s|s) {
        print "Remote server returned an unexpected content:\n";
        print "========================\n";
        print "$content\n";
        print "========================\n";
        return undef;
    }

    return ($content, '.vtt');
}

# _make_timestamp converts a time stamp
# to a string represenation like `1m25s` or `1h0m59s`
sub _make_timestamp {
    my $t = shift;

    #my $ms = $t % 1000;
    $t = int($t / 1000);

    my $s = $t % 60;
    $t = int($t / 60);

    my $m = $t % 60;
    $t = int($t / 60);

    my $h = $t;

    $h = $h > 0 ? $h.'h' : '';
    $m = $m.'m';
    $s = $s.'s';

    return $h.$m.$s;
}

sub generate_preview_link {
    my ($self, $video_id, $from, $till) = @_;

    $from = _make_timestamp($from);
    # `till` parameter not supported

    return "https://player.vimeo.com/video/$video_id?autoplay=1#t=$from";
}


1;
