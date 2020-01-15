package Title::Command::publish;
use parent Title::Command;

use strict;

use Cwd qw(cwd);
use Digest::MD5 qw(md5_hex);
use Encode qw(encode_utf8);
use File::Basename;
use File::Path;
use File::Spec::Functions qw(catfile rel2abs);
use Getopt::Long;
use HTTP::Message;
use JSON::XS qw(decode_json encode_json);

use Loctools::Net::OAuth2::Session::Google;
use Loctools::Net::HTTP::Client;

use Title::Command::enable;
use Title::Util::JSONFile;

sub get_commands {
    return {
        publish => {
            handler => \&run,
            info => 'Publish localized timed text on a remote service',
            need_target_files => 1,
        },
    }
}

sub validate_data {
    my ($self) = @_;

    my ($dry_run, $force);
    GetOptions(
        'dry-run' => \$dry_run,
        'force' => \$force,
    ) or die "Failed to parse some command-line parameters.";

    $self->SUPER::validate_data;

    $self->{data} = {
        dry_run => $dry_run,
        force => $force,
    };

    $self->{state} = {};
}

sub run {
    my ($self) = @_;

    foreach my $file (sort keys %{$self->{files}}) {
        print "\n*** $file ***\n\n";
        $self->run_for_file($file);
    }
}

sub _subst_macros {
    my ($s) = @_;
    $s =~ s/%ENV:(\w+)%/$ENV{$1}/sge;
    return $s;
}

sub run_for_file {
    my ($self, $fullpath) = @_;

    my $fileinfo = $self->{files}->{$fullpath};
    #use Data::Dumper; print Dumper($fileinfo);

    my $config = $self->{parent}->{config}->get_config_for_dir($fileinfo->{config_dir});
    #use Data::Dumper; print Dumper($config);

    my $dry_run = $self->{data}->{dry_run};

    print "Target platform: $config->{platform}\n";
    print "Target video ID: $config->{videoId}\n";

    my $videoId = $config->{videoId};

    # FIXME: refactor
    if ($config->{platform} ne 'YouTube') {
        print "Publishing to $config->{platform} is not supported\n";
        return
    }
    # /FIXME

    if (!exists $config->{pluginData} || !exists $config->{pluginData}->{YouTube}) {
        die "pluginData->YouTube section is missing from your configuration file chain";
    }

    my $data = $config->{pluginData}->{YouTube};

    my $client_id = _subst_macros($data->{clientId});
    my $client_secret = _subst_macros($data->{clientSecret});
    my $session_file = _subst_macros($data->{sessionFile});

    if ($client_id eq '') {
        die "YouTube client ID (pluginData->YouTube->clientId) is missing or evaluates to an empty value";
    }

    if ($client_secret eq '') {
        die "YouTube client ID (pluginData->YouTube->clientSecret) is missing or evaluates to an empty value";
    }

    if ($self->{debug}) {
        print "Client ID: $client_id\n";
        #print "Client Secret: $client_secret\n";
        print "Session File: $session_file\n";
    }

    my $session = Loctools::Net::OAuth2::Session::Google->new(
        client_id     => $client_id,
        client_secret => $client_secret,
        scope         => 'https://www.googleapis.com/auth/youtube.force-ssl',
        session_file  => $session_file,
    );

    # this will automatically load the session,
    # renew the token if it is expired,
    # or show the authorization prompt in the console
    my $client = Loctools::Net::HTTP::Client->new(session => $session);

    $self->preload_existing_youtube_state($client, $videoId);

    print "Reading file contents\n";
    open(IN, $fullpath) or die $!;
    binmode IN;
    my $rawContent = join('', <IN>);
    close IN;

    my $md5 = md5_hex($rawContent);

    my $lang = $fileinfo->{lang};
    if (exists $data->{languageMap} && exists $data->{languageMap}->{$lang}) {
        $lang = $data->{languageMap}->{$lang};
    }

    my $cache;
    my $cache_file = catfile($fileinfo->{config_dir}, "cache.json");

    if (-f $cache_file) {
        print "Reading cache file $cache_file\n";
        $cache = Title::Util::JSONFile::read($cache_file);
    } else {
        print "Cache file $cache_file doesn't exist\n";
        $cache = {
            uploaded => {}
        };
    }

    my $lang_state = $self->{state}->{$videoId}->{lc($lang)} || {};
    my $lang_cache = $cache->{uploaded}->{$lang} || {};

    my $has_local_changes = $lang_cache->{md5} ne $md5;
    my $has_remote_changes = $lang_cache->{etag} ne $lang_state->{etag};

    if ($has_local_changes && $lang_cache->{md5} ne '') {
        print "Subtitles file has changed locally since last upload\n";
    }

    if ($has_local_changes && $lang_cache->{md5} eq '') {
        print "Subtitles file has never been uploaded yet\n";
    }

    if ($has_remote_changes && $lang_state->{etag} ne '') {
        print "Subtitles have changed remotely since last upload\n";
    }

    if ($has_remote_changes && $lang_state->{etag} eq '') {
        print "Subtitles are missing from the server\n";
    }

    if (!$has_local_changes && !$has_remote_changes) {
        if ($self->{data}->{force}) {
            print "Subtitles didn't change since last upload, but force mode is ON\n";
        } else {
            print "Subtitles didn't change since last upload, skipping\n";
            return;
        }
    }

    my $update_mode = $lang_state->{id} ne '';
    my $method = $update_mode ? 'PUT' : 'POST';
    my $url = 'https://www.googleapis.com/upload/youtube/v3/captions?part=snippet';

    if ($dry_run) {
        if ($update_mode) {
            print "DRY RUN: Updating subtitles on a server\n";
        } else {
            print "DRY RUN: Creating subtitles on a server\n";
        }
        return;
    }

    my $snippet = {
        snippet => {
            videoId => $videoId,
            language => $lang,
            name => '', # name can be empty; YouTube will just show the language name
            #isDraft => 'true',
        }
    };

    if ($update_mode) {
        $snippet = {
            id => $lang_state->{id}
        }
    }

    if ($self->{debug}) {
        print "$method $url\n";
        print  JSON::XS->new->pretty->encode($snippet);
        print "(+ subtitles as a second part in a multipart body)\n";
        return;
    }

    my $msg = HTTP::Message->new([
        'Content-Type' => 'multipart/related',
    ]);

    $msg->add_part(
        HTTP::Message->new(
            ['Content-Type' => 'application/json'],
            encode_json($snippet)
        )
    );

    $msg->add_part(
        HTTP::Message->new(
            ['Content-Type' => 'application/octet-stream'],
            $rawContent
        )
    );

    print "Doing a remote API call\n";
    my ($code, $raw_response) = $client->request($method, $url, $msg->content, $msg->headers);

    if ($self->{debug}) {
        print "Returned code: $code\n";
        print "Raw response: $raw_response\n";
    }

    die "Unhandled error" if ($code != 200);

    my $response = decode_json($raw_response);
    if ($response->{id}) {
        $cache->{uploaded}->{$lang} = {
            id => $response->{id},
            etag => $response->{etag},
            md5 => $md5
        };

        $self->{state}->{$videoId}->{lc($lang)} = {
            id => $response->{id},
            etag => $response->{etag}
        }
    }

    print "Subtitle data uploaded successfully\n";

    Title::Util::JSONFile::write($cache, $cache_file);
}

sub preload_existing_youtube_state {
    my ($self, $client, $videoId) = @_;

    return if exists $self->{state}->{$videoId};

    print "Getting the list of already uploaded captions for the video\n";
    my ($code, $raw_response) = $client->get(
        'https://www.googleapis.com/youtube/v3/captions?part=snippet&videoId='.$videoId
    );

    if ($self->{debug}) {
        print "Returned code: $code\n";
        print "Raw response: $raw_response\n";
    }

    die unless $code == 200;

    my $response = decode_json($raw_response);
    die "No items" unless exists $response->{items};

    my $state = $self->{state}->{$videoId} = {};

    foreach my $item (@{$response->{items}}) {
        my $lang = $item->{snippet}->{language};
        $state->{lc($lang)} = {
            id => $item->{id},
            etag => $item->{etag}
        };
    }
}

1;
