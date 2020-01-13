package Title::Util::JSONFile;

use strict;

use JSON::XS;

sub read {
    my ($filename) = @_;
    open(JSON, $filename) or die "Reading $filename failed: $!";
    binmode(JSON);
    my $data = decode_json(join('', <JSON>));
    close(JSON);
    return $data;
}

sub write {
    my ($data, $filename) = @_;
    open(JSON, ">$filename") or die "Writing $filename failed: $!";
    binmode(JSON);
    print JSON JSON::XS->new->utf8->pretty->encode($data);
    close(JSON);
    return $data;
}

1;