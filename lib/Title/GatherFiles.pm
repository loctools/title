package Title::GatherFiles;

use strict;

use Cwd qw(abs_path);
use File::Basename;
use File::Spec::Functions qw(rel2abs catfile);

use Title::Util::Path;

my $TITLE_DIR = '.title';

sub new {
    my ($class, $self) = @_;

    $self = {
        need_source_files => 1,
        need_target_files => 1,
    } unless defined $self;

    bless $self, $class;
    return $self;
}

sub run {
    my ($self, @paths) = @_;

    $self->{found_files} = {};
    $self->{processed_dirs} = {};

    foreach my $path (@paths) {
        $self->process_path(rel2abs($path));
    }
}

sub process_path {
    my ($self, $path) = @_;

    if (-d $path) {
        $self->process_subdir($path);
    } elsif (-f $path) {
        $self->process_file($path);
    }
}

sub process_file {
    my ($self, $fullpath) = @_;

    my ($dir, $base, $ext) = split_path($fullpath);

    my $title_dir = catfile($dir, $TITLE_DIR);
    if (-d $title_dir) {
        my $files = $self->gather_files_from_dir($dir);

        if (exists $files->{$fullpath}) {
            $self->{found_files}->{$fullpath} = $files->{$fullpath};
        }
    }
}

sub process_subdir {
    my ($self, $dir) = @_;

    # if .title subdirectory exists, gather source/target files
    # from current directory
    my $title_dir = catfile($dir, $TITLE_DIR);
    if (-d $title_dir) {
        my $files = $self->gather_files_from_dir($dir);
        foreach my $fullpath (keys %$files) {
            my $fileinfo = $files->{$fullpath};
            if ($fileinfo->{is_source} && $self->{need_source_files} ||
                $fileinfo->{is_target} && $self->{need_target_files}) {
                $self->{found_files}->{$fullpath} = $fileinfo;
            }
        }
    }

    # process subdirectories
    opendir(my $dh, $dir);
    my @files = sort readdir $dh;
    closedir $dh;

    foreach my $name (@files) {
        next if $name =~ m/^\./;

        my $fullpath = catfile($dir, $name);

        if (-d $fullpath) {
            $self->process_subdir($fullpath);
        }
    }
}

sub gather_files_from_dir {
    my ($self, $base_dir) = @_;

    if (exists $self->{processed_dirs}->{$base_dir}) {
        return $self->{processed_dirs}->{$base_dir};
    }

    my $files = {};

    my $title_dir = catfile($base_dir, $TITLE_DIR);

    opendir(my $dh, $title_dir);
    my @title_subdirs = sort readdir $dh;
    closedir $dh;

    foreach my $subdir (@title_subdirs) {
        my $title_subdir = catfile($title_dir, $subdir);
        next unless -d $title_subdir;

        my ($source_lang, $source_ext);
        ($_, $source_lang, $source_ext) = split_path($title_subdir);

        # test if the file matching the directory name exists in the base
        # project directory; if it does, mark it as a source file
        my $source_filepath = catfile($base_dir, $subdir);
        if (-f $source_filepath) {
            $files->{$source_filepath} = {} unless exists $files->{$source_filepath};
            my $f = $files->{$source_filepath};
            $f->{is_source} = 1;
            $f->{lang} = $source_lang;
            $f->{config_dir} = $title_subdir;
        }

        opendir(my $dh, $title_subdir);
        my @subdir_files = sort readdir $dh;
        closedir $dh;

        foreach my $name (@subdir_files) {
            next unless $name =~ m/\.locjson$/;
            $name =~ s/\.locjson$//;

            next if $name eq $source_lang;

            # test if the matching file exists in the base
            # project directory; if it does, mark it as a target file
            my $target_filepath = catfile($base_dir, $name.$source_ext);
            if (-f $target_filepath) {
                $files->{$target_filepath} = {} unless exists $files->{$target_filepath};
                my $f = $files->{$target_filepath};
                $f->{is_target} = 1;
                $f->{lang} = $name;
                $f->{config_dir} = $title_subdir;
                $f->{source_path} = $source_filepath;
            }
        }
    }

    $self->{processed_dirs}->{$base_dir} = $files;
}

1;