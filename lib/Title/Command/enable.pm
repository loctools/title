package Title::Command::enable;
use parent Title::Command;

use strict;

use Encode qw(encode_utf8);
#use File::Basename;
use File::Path;
use File::Spec::Functions qw(catfile rel2abs);
use JSON::PP;

use Title::Command::parse;
use Title::Config;
use Title::Util::Path;

sub get_commands {
    return {
        enable => {
            handler => \&run,
            info => 'Enable localization for a specified source file',
        },
    }
}

sub validate_data {
    my ($self) = @_;

    $self->SUPER::validate_data;

    my $filename = $ARGV[0];

    die "Please provide the name of the file as a first argument to the command" if $filename eq '';
    die "The provided path doesn't point to a valid file" unless -f $filename;

    $self->{data} = {
        filename => rel2abs($filename)
    };
}

sub run {
    my ($self) = @_;

    my $fullpath = $self->{data}->{filename};

    my ($dir, $base, $ext) = split_path($fullpath);
    my $filename = $base.$ext;

    my $format_plugin = $self->{parent}->get_format_plugin_by_extension($ext);
    if (!$format_plugin) {
        print "Unknown file type for $filename";
        return 1;
    }

    my $root_title_dir = $dir.$Title::Config::TITLE_DIR_NAME;

    if (!-d $root_title_dir) {
        print "Creating directory $root_title_dir\n";
        mkpath($root_title_dir);
    }

    my $title_dir = catfile($root_title_dir, $filename);

    if (!-d $title_dir) {
        print "Creating directory $title_dir\n";
        mkpath($title_dir);
    }

    my $config = {
        locjsonFileComments => []
    };

    if ($self->{data}->{platform} ne '') {
        $config->{platform} = $self->{data}->{platform};
    }

    if ($self->{data}->{video_id} ne '') {
        $config->{videoId} = $self->{data}->{video_id};
    }

    my $config_filename = catfile($title_dir, $Title::Config::CONFIG_FILE_NAME);
    if (!-f $config_filename) {
        print "Creating file $config_filename\n";
        open(OUT, ">$config_filename") or die $!;
        binmode(OUT);
        print OUT _make_json_encoder()->utf8->encode($config);
        close OUT;
    }

    return Title::Command::parse::run_for_file($self, $fullpath);
}

sub _make_json_encoder {
    return JSON::PP->new->
    indent(1)->indent_length(4)->space_before(0)->space_after(1)->
    escape_slash(0)->canonical;
}

1;
