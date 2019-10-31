package Title::Application;

use strict;

use Cwd;
use File::Basename;
use File::Find qw(find);
use File::Spec::Functions qw(rel2abs catfile);
use Getopt::Long qw(:config no_auto_abbrev no_ignore_case pass_through);

use Title;
use Title::GatherFiles;

sub new {
    my ($class) = @_;

    my $self = {};

    $self->{commands} = {};

    bless $self, $class;

    return $self;
}

sub run {
    my ($self) = @_;

    my ($help, $debug, $version);
    my $result = GetOptions(
        'help' => \$help,
        'debug' => \$debug,
        'version' => \$version,
    );

    my $command = shift @ARGV;

    # print out version when passing the flag to a bare `title` command
    if ($version && $command eq '') {
        print "Title $Title::VERSION\n";
        exit(0);
    }

    if (!$result) {
        $self->error("Failed to parse some command-line parameters.");
    }

    if ($debug) {
        $self->{debug} = 1;
        eval('use Carp::Always;');
        warn "Hint: please install 'Carp::Always' module to get extended backtrace information on die()\n" if $@;
    }

    # convert --help parameter anywhere in the path
    # to an equivalent of 'title help <rest of params>'

    unshift @ARGV, 'help' if $help;

    $self->load_command_plugins;

    my $handler = $self->{commands}->{$command};
    if (!$handler) {
        $self->error("Unknown command: $command\n");
    }

    $handler->{plugin}->{debug} = 1 if $debug;

    my @commands = ($command);
    if (exists $handler->{combine_with}) {
        my %combine;
        @combine{@{$handler->{combine_with}}} = @{$handler->{combine_with}};
        while (scalar @ARGV && exists $combine{$ARGV[0]}) {
            push @commands, shift @ARGV;
        }
    }

    if ($handler->{need_files}) {
        my $gatherer = Title::GatherFiles->new();
        if (scalar @ARGV == 0) {
            push @ARGV, '.';
        }
        $gatherer->run(@ARGV);
        my @files = @{$gatherer->{found_files}};
        $handler->{plugin}->{files} = \@files;
        if (scalar @files == 0) {
            $self->error("This command expects project files to work against, but none were provided");
        }
    }

    eval {
        map {
            $handler->{plugin}->init($_);
        } @commands;
    };
    $self->error($@) if $@;

    eval {
        map {
            $handler->{plugin}->validate_data($_);
        } @commands;
    };
    $self->error($@) if $@;


    my $funcref = $handler->{handler};
    # run the commands in the context of the plugin object
    return &$funcref(
        $handler->{plugin},
        exists $handler->{combine_with} ? \@commands : $command,

    );
}

sub load_command_plugins {
    my ($self) = @_;

    my @plugins;

    # find plugins in the 'Command' subfolder relative to the location of the current file (Application.pm)

    find(sub {
        if(-f $_ && /\.pm$/) {
            $_ =~ s/\.pm$//i;
            push @plugins, $_;
        }
    }, catfile(dirname(rel2abs(__FILE__)), 'Command'));

    foreach my $plugin (@plugins) {
        print "Loading command plugin: $plugin\n" if $self->{debug};

        my $class = 'Title::Command::'.$plugin;

        my $p;
        eval('use '.$class.'; $p = '.$class.'->new($self);');
        die "Can't create instance for '$class': $@" if $@;

        my $exported_commands = $p->get_commands;
        foreach my $command (keys %$exported_commands) {
            my $handler = $exported_commands->{$command};

            die "Definition for '$command' command already exists" if exists $self->{commands}->{$command};
            die "No 'handler' parameter defined for '$command' command handler" unless exists $handler->{handler};

            $handler->{plugin} = $p;
            $self->{commands}->{$command} = $handler;
        }
    }
}

sub known_command {
    my ($self, $command) = @_;
    return exists $self->{commands}->{$command};
}

sub show_synopsis {
    my ($self) = @_;

    print qq|
Usage:
    title <command> [command-specific-options] [--debug]

Get help:
    title help [command]

|;
}

sub error {
    my ($self, $message, $exitstatus, $no_synopsis) = @_;
    $exitstatus = 1 unless defined $exitstatus;
    chomp $message;
    print $message."\n";
    $self->show_synopsis unless $no_synopsis;
    exit($exitstatus);
}

1;
