package Title::Command::build;
use parent Title::Command;

use strict;

use Digest::MD5 qw(md5_hex);
use Encode qw(encode_utf8);
#use File::Basename;
use File::Spec::Functions qw(catfile rel2abs);
use JSON::PP;

use Title::Recombiner;
use Title::Util::Path;

# special directory name for title config / work files
my $TITLE_DIR_NAME_SUFFIX = '.title';

# name of the config file which resides within TITLE_DIR
my $CONFIG_FILE = 'config.json';

my $LOCJSON_EXT = '.locjson';

sub get_commands {
    return {
        build => {
            handler => \&run,
            info => 'Build localized timed text files from localization files and metadata',
            need_files => 1,
        },
    }
}

sub run {
    my ($self) = @_;

    foreach my $file (@{$self->{files}}) {
        print "\n*** $file ***\n";
        $self->run_for_file($file);
    }
}

sub run_for_file {
    my ($self, $fullpath) = @_;

    my ($dir, $base, $ext) = split_path($fullpath);
    my $filename = $base.$ext;

    my $format_plugin = $self->{parent}->get_format_plugin_by_extension($ext);
    if (!$format_plugin) {
        print "Unknown file type for $filename";
        return 1;
    }

    $self->{data}->{dir} = $dir;
    $self->{data}->{base} = $base;
    $self->{data}->{ext} = $ext;

    my $title_dir = catfile($dir.$TITLE_DIR_NAME_SUFFIX, $filename);

    if (!-d $title_dir) {
        print "Directory $title_dir not found\n";
        return 1;
    }

    my $config_filename = catfile($title_dir, $CONFIG_FILE);
    if (!-f $config_filename) {
        print "Directory $title_dir doesn't contain a file called $CONFIG_FILE\n";
        return 1;
    }

    # scan for .locjson files in the Title subdirectory

    opendir(my $dh, $title_dir);
    while (my $name = readdir $dh) {
        next unless $name =~ m/$LOCJSON_EXT$/;
        my $locjson_fullpath = catfile($title_dir, $name);

        if (-f $locjson_fullpath) {
            my $code = $self->process_file($locjson_fullpath);
            return $code unless $code == 0;
        }
    }
    closedir $dh;

    return 0;
}

sub process_file {
    my ($self, $locjson_filename) = @_;

    # files should match the `<lang>.locjson` pattern
    my ($dir, $base, $ext) = split_path($locjson_filename);
    if ($base eq $self->{data}->{base}) {
        return 0; # skip inmporting the source file
    }

    print "\nReading $locjson_filename\n";
    open(IN, $locjson_filename) or die $!;
    binmode(IN);
    my $raw_locjson = join('', <IN>);
    close(IN);
    my $locjson = decode_json($raw_locjson);

    my $meta_filename = catfile($dir, $base.'.meta');

    if (!-f $meta_filename) {
        print "Meta file $meta_filename doesn't exist\n";
        $meta_filename = catfile($dir, $self->{data}->{base}.'.meta');
    }

    print "Reading $meta_filename\n";
    open(IN, $meta_filename) or die $!;
    binmode(IN);
    my $raw_meta = join('', <IN>);
    close(IN);
    my $meta = decode_json($raw_meta);

    my @chunks;
    my $n = 0;
    my $expected_total = scalar(@$meta);
    foreach my $unit (@{$locjson->{units}}) {
        my $key = $unit->{key};

        my @segments = split("\n\n", join('', @{$unit->{source}}));

        foreach my $segment (@segments) {
            push @chunks, {
                from => $meta->[$n]->{from},
                till => $meta->[$n]->{till},
                text => $segment
            };

            $n++;
        }
    }

    if ($n != $expected_total) {
        die "Number of segments in LocJSON file ($n) doesn't match the number of segments in its meta file ($expected_total)";
    }

    my $output_text;

    my $format_plugin = $self->{parent}->get_format_plugin_by_extension($self->{data}->{ext});

    $output_text = $format_plugin->generate(\@chunks);

    my $output_filename = catfile($self->{data}->{dir}, $base.$self->{data}->{ext});

    print "Saving $output_filename\n";
    open OUT, ">$output_filename" or die $!;
    binmode OUT, ':utf8';
    print OUT $output_text;
    close OUT;

    return 0;
}

1;
