package Title::Recombiner;

use utf8;

use Lingua::Sentence;

# use a special delimiter symbol that will still be treated
# as a 'capital character' for Lingua::Sentence sentence breaking
# to work properly.
my $TMP_SEGMENT_DELIMITER = 'Ⓩ';

# a symbol that represents a line break within a segment
my $TMP_NEWLINE_DELIMITER = ' ↵ ';

sub combine {
    my $chunks = shift;


    my @srt_text = ();
    map {
        my $text = $_->{text};

        # escape line breaks
        $text =~ s/\n/$TMP_NEWLINE_DELIMITER/sg;

        push @srt_text, $text;
    } @$chunks;

    my $raw_content = join(' '.$TMP_SEGMENT_DELIMITER.' ', @srt_text);

    my $splitter = Lingua::Sentence->new("en");

    my @sentences = $splitter->split_array($raw_content);

    # now we must glue back sentences that do not start at the beginning of the original segment
    my @accum;
    my @merged_sentences;
    map {
        if ($_ =~ m/^$TMP_SEGMENT_DELIMITER/ && @accum > 0) {
            push @merged_sentences, join(' ', @accum);
            @accum = ();
        }
        push @accum, $_;
    } @sentences;
    if (@accum > 0) {
        push @merged_sentences, join(' ', @accum);
    }

    my $combined_chunks = [];
    my $cur_segment = 1;
    foreach my $sentence (@merged_sentences) {
        $sentence =~ s/$TMP_NEWLINE_DELIMITER/\n/g;
        my $delimiter_count = () = $sentence =~ m/$TMP_SEGMENT_DELIMITER/g;

        if ($sentence =~ m/^$TMP_SEGMENT_DELIMITER/) {
            $cur_segment++;
            $delimiter_count--;
            $sentence =~ s/^$TMP_SEGMENT_DELIMITER\s*//; # remove leading delimiter
        }
        my @segments = split(/\s*$TMP_SEGMENT_DELIMITER\s*/, $sentence);
        my $n = scalar(@segments);
        my $end_segment = $cur_segment + $n - 1;
        my $from = $chunks->[$cur_segment - 1]->{from};
        my $till = $chunks->[$end_segment - 1]->{till};

        my @ss_segments = ();
        foreach my $segment (@segments) {
            if (scalar(@ss_segments) > 0) {
                push @ss_segments, "";
            }
            push @ss_segments, split("\n", $segment);
        }

        my $last = pop @ss_segments;
        @ss_segments = map { $_ . "\n" } @ss_segments;
        push @ss_segments, $last;

        push @$combined_chunks, {
            from => $from,
            till => $till,
            from_segment => $cur_segment,
            till_segment => $end_segment,
            text => join('', @ss_segments)
        };

        $cur_segment += $delimiter_count;
    }

    return $combined_chunks;
}

1;