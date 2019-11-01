package Title::Platform::YouTube;
use parent Title::Platform;

use strict;

sub get_id {
    return 'YouTube';
}

sub parse_url {
    my ($self, $url) = @_;

    if ($url =~ m|^https://www.youtube.com/watch\?v=([^&]+)$|) {
        return $1;
    }

    if ($url =~ m|^https://youtu.be/([^\?&]+)$|) {
        return $1;
    }

    return undef;
}

sub fetch_available_timedtext_tracks {
    my ($self, $video_id) = @_;

    my $url = "https://www.youtube.com/api/timedtext?type=list&v=$video_id";

    my $content = $self->get_url($url);

    if ($content !~ m|^<\?xml\s|s) {
        print "Remote server returned an unexpected content:\n";
        print "========================\n";
        print "$content\n";
        print "========================\n";
        return {};
    }

    my $tracks = {};
    my $default_lang;
    while ($content =~ m|(<track[^>]+>)|sg) {
        my $track = $1;
        my $lang;
        if ($track =~ m|lang_code="([^"]+)"|) {
            $lang = $1;
        }
        if ($track =~ m|lang_default="true"|) {
            $default_lang = $lang;
        }
        if (!$lang) {
            die "Failed to parse the <track> tag $track";
        }

        $tracks->{$lang} = {
            url => "https://www.youtube.com/api/timedtext?v=$video_id&key=yt8&lang=$lang&fmt=vtt"
        };
    }

    return {
        tracks => $tracks,
        default_lang => $default_lang
    };
}

sub fetch_timedtext_track {
    my ($self, $url) = @_;

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

sub generate_preview_link {
    my ($self, $video_id, $from, $till) = @_;

    my $start = int($from / 1000); # convert ms to seconds, round to lowest integer value
    my $end = int($till / 1000) + 1; # convert ms to seconds, round to higher integer value

    return "https://www.youtube.com/embed/$video_id?start=$start&end=$end&autoplay=1";
}


1;
