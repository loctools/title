package Title::TitleServer;

use strict;

sub generate_preview_link {
    my ($base_url, $rel_path, $lang, $from_cue, $till_cue) = @_;

    my $hl = $from_cue eq $till_cue ? $from_cue : "$from_cue-$till_cue";
    return $base_url."view/#$rel_path$lang?hl=$hl&play";
}

1;
