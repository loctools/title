package Title::Platform::Vimeo::Util;

use strict;

use JSON;
use LWP::UserAgent;

my $ua = LWP::UserAgent->new();
#'timeout' => ($self->{timeout} / 1000),
#'agent' => 'Perl/THttpClient'

#$ua->default_header('Accept' => 'application/x-thrift');
#$ua->default_header('Content-Type' => 'application/x-thrift');
$ua->cookie_jar({}); # hash to remember cookies between redirects

sub get_url {
    my ($url) = @_;
    my $request = new HTTP::Request(GET => $url);
    my $response = $ua->request($request);
    return $response->content;
}

sub generate_preview_link {
    my ($video_id, $from, $till) = @_;

    $from = make_timestamp($from);
    # `till` parameter not supported

    return "https://player.vimeo.com/video/$video_id?autoplay=1#t=$from";
}

sub get_timedtext_file_extenstion {
    return ".vtt";
}

sub get_platform_id {
    return 'Vimeo';
}

sub parse_video_url {
    my ($url) = @_;

    if ($url =~ m|^https://vimeo.com/([^\?&]+)|) {
        return (get_platform_id(), $1);
    }

    if ($url =~ m|^https://player.vimeo.com/video/([^\?&]+)|) {
        return (get_platform_id(), $1);
    }

    return undef;
}

sub fetch_available_timedtext_tracks {
    my ($video_id) = @_;

    my $url = "https://player.vimeo.com/video/$video_id";
    print "URL: $url\n";

    my $content = get_url($url);

    my $config_json;
    if ($content =~ m|\svar config = ({.*?});\s|s) {
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
    my ($url) = @_;

    print "URL: $url\n";
    my $content = get_url($url);

    if ($content !~ m|^WEBVTT\s|s) {
        print "Remote server returned an unexpected content:\n";
        print "========================\n";
        print "$content\n";
        print "========================\n";
        return undef;
    }

    return ($content, get_timedtext_file_extenstion());
}

# make_timestamp converts a time stamp
# to a string represenation like `1m25s` or `1h0m59s`
sub make_timestamp {
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

1;