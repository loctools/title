package Title::Command::import;
use parent Title::Command;

use strict;

use Cwd qw(cwd);
use Encode qw(encode_utf8);
use File::Basename;
use File::Path;
use File::Spec::Functions qw(catfile rel2abs);
use JSON::PP;

use Title::Command::parse;
use Title::Platform::Vimeo::Util;
use Title::Platform::YouTube::Util;

sub get_commands {
    return {
        import => {
            handler => \&run,
            info => 'Import timed text from a remote service',
        },
    }
}

sub validate_data {
    my ($self) = @_;

    $self->SUPER::validate_data;

    my $url = $ARGV[0];

    die "Please provide the URL as a first argument to the command" if $url eq '';

    $self->{data} = {
        url => $url
    };
}

sub run {
    my ($self) = @_;

    my $url = $self->{data}->{url};

    my @plugins = (
        'Title::Platform::Vimeo::Util',
        'Title::Platform::YouTube::Util',
    );

    my ($platform, $video_id);
    foreach my $plugin (@plugins) {
        eval('($platform, $video_id) = '.$plugin.'::parse_video_url($url)');
        die "Can't run plugin $plugin: $@" if $@;
        last if $platform;
    }

    if (!$platform) {
        print "I don't know how to import timed text from this URL.\n";
        return 1;
    }

    print "Detected platform: $platform\n";
    print "Detected video ID: $video_id\n";

    print "Downloading the list of tracks\n";

    my $result;
    if ($platform eq 'Vimeo') {
        $result = Title::Platform::Vimeo::Util::fetch_available_timedtext_tracks($video_id);
    }

    if ($platform eq 'YouTube') {
        $result = Title::Platform::YouTube::Util::fetch_available_timedtext_tracks($video_id);
    }

    if (!exists $result->{tracks} || scalar(keys %{$result->{tracks}}) == 0) {
        print "No timed text found for the given URL.\n";
        return 0;
    }

    print "Detected timed text tracks:\n";
    map {
        print "\t* ", $_;
        print " (default)" if $_ eq $result->{default_lang};
        print "\n";

    } sort keys %{$result->{tracks}};

    my $lang = $result->{default_lang};
    # or pass via parameter
    # ...

    my $url = $result->{tracks}->{$lang}->{url};

    print "Downloading the track for '$lang' language\n";
    my ($content, $extension);
    if ($platform eq 'Vimeo') {
        ($content, $extension) = Title::Platform::Vimeo::Util::fetch_timedtext_track($url);
    }

    if ($platform eq 'YouTube') {
        ($content, $extension) = Title::Platform::YouTube::Util::fetch_timedtext_track($url);
    }
    my $filename = $lang.$extension;

    if (!$content) {
        return 2;
    }

    # use current directory for now
    my $dir = cwd;
    my $full_filename = catfile($dir, $filename);

    print "Saving timed text to $full_filename\n";
    open(OUT, ">$full_filename");
    binmode(OUT, ':utf8');
    print OUT $content;
    close(OUT);

    $self->{data}->{filename} = $full_filename;
    $self->{data}->{platform} = $platform;
    $self->{data}->{video_id} = $video_id;

    return Title::Command::initialize::run($self);
    return 0;
}

#sub make_json_encoder {
#    return JSON::PP->new->
#    indent(1)->indent_length(4)->space_before(0)->space_after(1)->
#    escape_slash(0)->canonical;
#}

1;
