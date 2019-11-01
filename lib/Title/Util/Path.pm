package Title::Util::Path;

use strict;

use File::Basename;

our @ISA = qw(Exporter);

our @EXPORT = qw(
    split_path
);

sub split_path {
    my ($fullpath) = @_;

    my ($base, $dir, $ext) = fileparse($fullpath);
    if ($base =~ m/^(.*)(\..*?)$/) {
        $base = $1;
        $ext = $2;
    }

    return ($dir, $base, $ext);
}

