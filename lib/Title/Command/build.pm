package Title::Command::build;
use parent Title::Command;

use strict;

use Digest::MD5 qw(md5_hex);
use Encode qw(encode_utf8);
#use File::Basename;
use File::Spec::Functions qw(catfile rel2abs);
use JSON::PP;

use Title::Config;
use Title::Recombiner;
use Title::Util::Path;

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

    my $title_dir = catfile($dir.$Title::Config::TITLE_DIR_NAME, $filename);

    if (!-d $title_dir) {
        print "Directory $title_dir not found\n";
        return 1;
    }

    my $config_filename = catfile($title_dir, $Title::Config::CONFIG_FILE_NAME);
    if (!-f $config_filename) {
        print "Directory $title_dir doesn't contain a file called $Title::Config::CONFIG_FILE_NAME\n";
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
        print "WARNING: Number of segments in LocJSON file ($n) doesn't match the number of segments in its meta file ($expected_total)\n";

        # read the base LocJSON file and comapre it unit-by-unit to report
        # misaligned segments

        my $base_locjson_filename = catfile($dir, $self->{data}->{base}.$LOCJSON_EXT);
        print "\nReading $base_locjson_filename\n";
        open(IN, $base_locjson_filename) or die $!;
        binmode(IN);
        my $base_raw_locjson = join('', <IN>);
        close(IN);
        my $base_locjson = decode_json($base_raw_locjson);

        my $total = scalar @{$base_locjson->{units}};
        for (my $i = 0; $i < $total; $i++) {
            my $source_unit = $base_locjson->{units}->[$i];
            my $target_unit = $locjson->{units}->[$i] || {};

            my $source_text = join('', @{$source_unit->{source}});
            my $target_text = join('', @{$target_unit->{source}});

            my @source_segments = split("\n\n", $source_text);
            my @target_segments = split("\n\n", $target_text);

            if (scalar(@source_segments) != scalar(@target_segments)) {
                warn "Unit #$i from $base_locjson_filename:\n========\n$source_text\n========\n\n";
                warn "Unit #$i from $locjson_filename:\n========\n$target_text\n========\n\n";
            }
        }
        print "Please correct the units above and run `title build` again.\n\n";
        return 1;
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
