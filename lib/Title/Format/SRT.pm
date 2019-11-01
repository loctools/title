package Title::Format::SRT;
use parent Title::Format;

sub get_id {
    return 'SubRip';
}

sub get_extensions {
    return ('.srt');
}

sub parse {
    my ($self, $raw_srt) = @_;

    my @entries = split("\n\n", $raw_srt);
    my @ssmeta = ();

    my $expected_counter = 1;
    foreach my $entry (@entries) {
        my ($counter, $raw_timestamps, $text) = split("\n", $entry, 3);

        # validate the counter
        if ($counter ne $expected_counter) {
            die "Expected entry $expected_counter, got `$counter`";
        }

        # parse the raw timestamps line,
        # which should be in the following format:
        # HH:MM:SS,ZZZ --> HH:MM:SS,ZZZ
        my ($from, $till);
        if ($raw_timestamps =~ m/^(\S+) --> (\S+)$/) {
            $from = _parse_timestamp($1);
            $till = _parse_timestamp($2);
        } else {
            die "Failed to parse the timestamp line `$raw_timestamps`";
        }

        push @ssmeta, {
            #key => $counter,
            #raw_timestamps => $raw_timestamps,
            from => $from,
            till => $till,
            text => $text,
            #hash => md5_hex(encode_utf8($text))
        };

        $expected_counter++;
    }

    return \@ssmeta;
}

sub generate {
    my ($self, $segments) = @_;

    my @chunks;

    my $n = 0;
    foreach my $segment (@$segments) {
        $n++;
        push @chunks, $n, "\n";
        push @chunks, _make_timestamp($segment->{from}) , ' --> ' , _make_timestamp($segment->{till}) , "\n";
        push @chunks, $segment->{text}, "\n\n";
    }

    return join('', @chunks);
}

sub _parse_timestamp {
    my $ts = shift;

    my ($h, $m, $s, $ms);
    if ($ts =~ m /^(\d\d):(\d\d):(\d\d),(\d\d\d)$/) {
        $h = $1;
        $m = $2;
        $s = $3;
        $ms = $4;
    } else {
        die "Failed to parse timestamp `$ts`";
    }

    return (($h * 60 + $m) * 60 + $s) * 1000 + $ms;
}

sub _make_timestamp {
    my $t = shift;

    my $ms = $t % 1000;
    $t = int($t / 1000);

    my $s = $t % 60;
    $t = int($t / 60);

    my $m = $t % 60;
    $t = int($t / 60);

    my $h = $t;

    return sprintf("%02d:%02d:%02d,%03d", $h, $m, $s, $ms);
}

1;