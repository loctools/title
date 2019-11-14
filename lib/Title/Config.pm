package Title::Config;

use strict;

use Getopt::Long;
use File::Spec::Functions qw(catfile);
use JSON::PP;

use Title::Util::Path;

# special directory name for title config / work files
our $TITLE_DIR_NAME = '.title';

# name of the config file which resides within TITLE_DIR
our $CONFIG_FILE_NAME = 'config.json';

sub new {
    my ($class) = @_;

    my $self = {
        cache => {}
    };

    my $config;
    my $result = GetOptions(
        'config=s' => \$config,
    );

    if ($config ne '') {
        print "Override config: $config\n";
        if (!-f $config) {
            die "$config doesn't point to a config file\n";
        }

        $self->{override_config} = _read_json($config);
    }

    bless $self, $class;

    return $self;
}

sub internal_get_config_for_dir {
    my ($self, $dir) = @_;

    $dir = _remove_trailing_path_delimiter($dir);

    return $self->{cache}->{$dir} if exists $self->{cache}->{$dir};

    my $config = {};
    if ($dir ne '') {
        my ($parent_dir) = split_path($dir);
        my $parent_config = $self->internal_get_config_for_dir($parent_dir);
        _merge_hash($config, $parent_config);
    }

    my $config_filename = catfile($dir, $TITLE_DIR_NAME, $CONFIG_FILE_NAME);
    if (-f $config_filename) {
        print "Reading config file $config_filename\n";
        my $dir_config = _read_json($config_filename);
        _merge_hash($config, $dir_config);
    }

    $self->{cache}->{$dir} = $config;
    return $config;
}

sub get_config_for_dir {
    my ($self, $dir) = @_;

    # gather a default config from all directories
    my $config = $self->internal_get_config_for_dir($dir);

    # apply an override, if any
    if (exists $self->{override_config}) {
        _merge_hash($config, $self->{override_config});
    }

    # apply a config for the current directory (i.e. file-specific config)
    my $config_filename = catfile($dir, $CONFIG_FILE_NAME);
    if (-f $config_filename) {
        print "Reading config file $config_filename\n";
        my $dir_config = _read_json($config_filename);
        _merge_hash($config, $dir_config);
    }

    return $config;
}

sub _remove_trailing_path_delimiter {
    my $path = shift;
    $path =~ s/[\\\/]$//;
    return $path;
}

sub _merge_hash {
    my ($h1, $h2) = @_;
    foreach my $key (keys %$h2) {
        if (ref($h2->{$key}) eq 'HASH') {
            if (ref($h1->{$key}) ne 'HASH') {
                $h1->{$key} = {};
            }
            _merge_hash($h1->{$key}, $h2->{$key});
            next;
        }

        $h1->{$key} = $h2->{$key};
    }
}

sub _subst_macros_in_hash {
    my $h = shift;
    foreach my $key (keys %$h) {
        $h->{$key} = _subst_macros($h->{$key}, @_);
    }
}

sub _subst_macros_in_array {
    my $a = shift;
    for (my $i = 0; $i < scalar @$a; $i++) {
        $a->[$i] = _subst_macros($a->[$i], @_);
    }
}

sub _subst_macros_in_scalar {
    my ($s, $dir) = @_;
    $s =~ s/%CONFIG_DIR%/$dir/sg;
    return $s;
}

sub _subst_macros {
    my $v = shift;

    if (ref($v) eq 'HASH') {
        _subst_macros_in_hash($v, @_);
        return $v;
    }

    if (ref($v) eq 'ARRAY') {
        _subst_macros_in_array($v, @_);
        return $v;
    }

    return _subst_macros_in_scalar($v, @_);
}

sub _read_json {
    my ($filename) = @_;
    open(JSON, $filename) or die "Reading $filename failed: $!";
    binmode(JSON);
    my $data = decode_json(join('', <JSON>));
    close(JSON);
    my ($config_dir) = split_path($filename);
    $data = _subst_macros($data, _remove_trailing_path_delimiter($config_dir));
    return $data;
}

1;