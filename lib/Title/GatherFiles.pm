package Title::GatherFiles;

use strict;

use Cwd qw(abs_path);
use File::Basename;
use File::Spec::Functions qw(rel2abs catfile);

sub new {
    my ($class, $self) = @_;

    $self = {} unless defined $self;

    bless $self, $class;
    return $self;
}

sub run {
    my ($self, @paths) = @_;

    $self->{found_files} = [];

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

sub process_subdir {
    my ($self, $dir) = @_;

    opendir(my $dh, $dir);
    my @files = sort readdir $dh;
    closedir $dh;

    foreach my $name (@files) {
        next if $name =~ m/^\./;

        my $fullpath = catfile($dir, $name);

        if (-d $fullpath) {
            $self->process_subdir($fullpath);
        } elsif (-f $fullpath) {
            $self->process_file($fullpath);
        }
    }
}

sub process_file {
    my ($self, $file) = @_;
    my ($basename, $dir) = fileparse($file);
    if (-d catfile($dir, '.title', $basename)) {
        push @{$self->{found_files}}, abs_path($file);
    }
}


1;