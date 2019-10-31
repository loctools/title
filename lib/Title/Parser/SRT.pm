package Title::Parser::SRT;

sub parse {
    my $raw_srt = shift;

    my @entries = split("\n\n", $raw_srt);
    my @ssmeta = ();
    #my @srt_text = ();

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
            $from = parse_timestamp($1);
            $till = parse_timestamp($2);
        } else {
            die "Failed to parse the timestamp line `$raw_timestamps`";
        }

        # escape line breaks and surround them with spaces for readability
        #$text =~ s/\n/$TMP_NEWLINE_DELIMITER/sg;

        push @ssmeta, {
            #key => $counter,
            #raw_timestamps => $raw_timestamps,
            from => $from,
            till => $till,
            text => $text,
            #hash => md5_hex(encode_utf8($text))
        };

        #push @srt_text, $text;

        $expected_counter++;
    }

    return \@ssmeta;
}

sub generate {
    my $segments = shift;

    my @chunks;

    my $n = 0;
    foreach my $segment (@$segments) {
        $n++;
        push @chunks, $n, "\n";
        push @chunks, make_timestamp($segment->{from}) , ' --> ' , make_timestamp($segment->{till}) , "\n";
        push @chunks, $segment->{text}, "\n\n";
    }

    return join('', @chunks);
}

sub parse_timestamp {
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

sub make_timestamp {
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