package Title::Command::import;
use parent Title::Command;

use strict;

use Cwd qw(cwd);
use Encode qw(encode_utf8);
use File::Basename;
use File::Path;
use File::Spec::Functions qw(catfile rel2abs);
use JSON::PP;

use Title::Command::enable;

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

    my ($plugin, $platform, $video_id);
    foreach my $name (keys %{$self->{parent}->{platforms}}) {
        my $p = $self->{parent}->{platforms}->{$name};
        $video_id = $p->parse_url($url);
        if ($video_id) {
            $plugin = $p;
            $platform = $name;
            last;
        }
    }

    if (!$platform) {
        print "I don't know how to import timed text from this URL.\n";
        return 1;
    }

    print "Detected platform: $platform\n";
    print "Detected video ID: $video_id\n";

    print "Downloading the list of tracks\n";

    my $result = $plugin->fetch_available_timedtext_tracks($video_id);

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
    my ($content, $extension) = $plugin->fetch_timedtext_track($url);
    if (!$content) {
        return 2;
    }

    my $filename = $lang.$extension;

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

    return Title::Command::enable::run($self);
    return 0;
}

1;
