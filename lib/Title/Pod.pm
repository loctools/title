package Title::Pod;

use strict;

use Encode qw(encode_utf8);
use File::Basename;
use File::Path;
use File::Spec::Functions qw(rel2abs catfile);
use Pod::Simple::XHTML;
use Pod::Text;
use Title;

sub new {
    my ($class, $self) = @_;

    $self = {} unless defined $self;

    $self->{css} = 'media/pod.css' unless exists $self->{css};

    $self->{root} = _find_doc_root();
    $self->{pod_root} = catfile($self->{root}, 'pod') unless exists $self->{pod_root};
    $self->{html_root} = catfile($self->{root}, 'html') unless exists $self->{html_root};

    bless $self, $class;
    return $self;
}

sub _find_doc_root {
    my @trydirs = (
        catfile(dirname(__FILE__), '../../doc'),
        '/usr/local/share/title/doc',
        '/usr/share/title/doc'
    );

    map {
        return $_ if -d $_;
    } @trydirs;

    return '.';
}

sub save_html {
    my ($self, $command, $podfile) = @_;

    my $outfile = $self->get_html_path($command);

    my $html;

    my $parser = Pod::Simple::XHTML->new();
    $parser->perldoc_url_prefix('');
    $parser->perldoc_url_postfix('.html');

    $parser->html_header(
qq|<html>
<head>
    <title>$command</title>
    <link rel="stylesheet" href="$self->{css}" type="text/css" />
    <meta http-equiv="Content-Type" content="text/html; charset=UTF-8" />
    <link href="media/favicon.ico" rel="shortcut icon" type="image/x-icon" />
</head>
<body>
    <div class="wrapper">
        <div class="header-bg"></div>
        <div class="header">
            <a class="logo" href="title.html"><img src="media/logo.svg" />Title</a>
        </div>

        <h1 class="command">
            <code class="command">$command</code>
        </h1>

        <div class="content">|);
    $parser->html_footer(
qq|
        </div>

        <div class="footer">
            <div class="copyright">
                &copy; 2019 Igor Afanasyev.<br/>
                All rights reserved.
            </div>
            <div class="license">
                Title is licensed under <a href="https://opensource.org/licenses/MIT">MIT license</a>
            </div>
        </div>
    </div>
</body>
</html>|);
    $parser->output_string(\$html);
    $parser->parse_file($podfile);

    my $dir = dirname($outfile);
    mkpath($dir) unless -d $dir;

    open HTML, ">$outfile" or die "Can't open file '$outfile': $!\n";
    binmode(HTML);
    print HTML encode_utf8($html); # encode manually to avoid 'Wide character in print' warnings and force Unix-style endings
    close HTML;

    return $outfile;
}

sub print_as_text {
    my ($self, $podfile, $fh) = @_;
    $fh = *STDOUT unless $fh; # otherwise some old version of Pod::Simple won't properly initialize the output

    my $parser = Pod::Text->new(sentence => 0, width => 78);
    $parser->output_fh($fh);
    $parser->parse_file($podfile); # this will render the file to the specified file handle
}

sub get_pod_path {
    my ($self, $command) = @_;

    return rel2abs(catfile($self->{pod_root}, "$command.pod"));
}

sub get_html_path {
    my ($self, $command) = @_;

    return rel2abs(catfile($self->{html_root}, "$command.html"));
}

1;