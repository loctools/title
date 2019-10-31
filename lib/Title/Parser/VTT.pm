package Title::Parser::VTT;

use strict;

sub parse {
    my $raw_srt = shift;

    if ($raw_srt !~ m|^WEBVTT\s|s) {
        die "WEBVTT signature not found at the beginning of the file";
    }

    my @entries = split("\n\n", $raw_srt);
    my @ssmeta = ();
    shift @entries; # remove the header chunk

    foreach my $entry (@entries) {
        # skip comment and style chunks
        if ($entry =~ m!^(NOTE|STYLE)\s!s) {
            next;
        }

        my ($id, $raw_timestamps, $text);

        # check if the entry starts with an optional identifier
        if ($entry !~ m/^(\S+) --> (\S+)\n/) {
            ($id, $raw_timestamps, $text) = split("\n", $entry, 3);
        } else {
            ($raw_timestamps, $text) = split("\n", $entry, 2);
        }

        # parse the raw timestamps line,
        # which should be in the following format:
        # HH:MM:SS,ZZZ --> HH:MM:SS,ZZZ
        my ($from, $till);
        if ($raw_timestamps =~ m/^(\S+) --> (\S+)$/) {
            $from = parse_timestamp($1);
            $till = parse_timestamp($2);
        } else {
            die "Failed to parse the timestamp line `$raw_timestamps`";
        }

        push @ssmeta, {
            from => $from,
            till => $till,
            text => $text,
        };
    }

    return \@ssmeta;
}

sub generate {
    my $segments = shift;

    my @chunks;

    push @chunks, "WEBVTT\n\n";

    foreach my $segment (@$segments) {
        push @chunks, make_timestamp($segment->{from}) , ' --> ' , make_timestamp($segment->{till}) , "\n";
        push @chunks, $segment->{text}, "\n\n";
    }

    return join('', @chunks);
}

sub parse_timestamp {
    my $ts = shift;

    my ($h, $m, $s, $ms);
    if ($ts =~ m /^(\d\d):(\d\d):(\d\d)\.(\d\d\d)$/) {
        $h = $1;
        $m = $2;
        $s = $3;
        $ms = $4;
    } elsif ($ts =~ m /^(\d\d):(\d\d)\.(\d\d\d)$/) {
        $h = 0;
        $m = $1;
        $s = $2;
        $ms = $3;
    } else {
        die "Failed to parse timestamp `$ts`";
    }

    return (($h * 60 + $m) * 60 + $s) * 1000 + $ms;
}

sub make_timestamp {
    my $t = shift;

    my $ms = $t % 1000;
    $t = int($t / 1000);

    my $s = $t % 60;
    $t = int($t / 60);

    my $m = $t % 60;
    $t = int($t / 60);

    my $h = $t;

    return sprintf("%02d:%02d:%02d.%03d", $h, $m, $s, $ms);
}

1;