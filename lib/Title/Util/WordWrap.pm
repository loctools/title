package Title::Util::WordWrap;

use strict;

our @ISA = qw(Exporter);

our @EXPORT = qw(
    wrap
);

sub wrap {
    my ($s, $length) = @_;
    return $s unless $length > 0;

    return ('') if $s eq '';

    # Wrap by '\n' explicitly
    if ($s =~ m{^(.*?(?:\\n|\n))(.+)$}s) {
        my $a = $1;
        my $b = $2;
        return wrap($a, $length), wrap($b, $length);
    }

    # split by whitespace
    my @a = split(/(\s+)/, $s);

    my @lines;
    my $accum = '';
    while (scalar(@a) > 0) {

        # Take the next chunk and append the
        # following whitespace chunk to it, if any
        my $chunk = shift @a;
        if (@a > 0 && $a[0] =~ m/^\s*$/) {
            $chunk .= shift @a;
        }

        if (length($accum) + length($chunk) > $length) {
            push @lines, $accum if $accum ne '';

            while (length($chunk) >= $length) {
                push @lines, substr($chunk, 0, $length, '');
            }

            $accum = $chunk;
        } else {
            $accum .= $chunk;
        }
    }
    push @lines, $accum if $accum ne '';

    return @lines;
}

