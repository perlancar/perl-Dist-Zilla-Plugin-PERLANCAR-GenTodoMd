package Dist::Zilla::Plugin::PERLANCAR::GenTodoMd;

# DATE
# VERSION

use 5.010001;
use autodie;
use strict;
use warnings;

use Moose;
with (
        'Dist::Zilla::Role::FileGatherer',
);

use IPC::System::Simple qw(capturex);

# XXX config: todo.org path

use namespace::autoclean;

sub gather_files {
    my ($self, $arg) = @_;

    my $todo_org_path = "$ENV{HOME}/organizer/todo.org";
    (-f $todo_org_path) or do {
        $self->log_debug("Skipped generating TODO.md ($todo_org_path not found)");
        return;
    };

    my $name = $self->zilla->name;

    # find out dist's short name (i keep short names in ~/proj/perl/dists/)
    my $shortname;
    {
        my $dists_dir = "$ENV{HOME}/proj/perl/dists";
        last unless (-d $dists_dir);
        opendir my($dh), $dists_dir;
        for (sort readdir $dh) {
            if ((-l "$dists_dir/$_") &&
                    readlink("$dists_dir/$_") =~ m!/perl-\Q$name\E\z!) {
                $shortname = $_;
                last;
            }
        }
    }

    my @cmd = (
        "filter-org-by-headlines",
        "--without-preamble",
        "--is-todo",
        "--isnt-done",
        "--level", 2,
        "--parent-match", "proj/perl",
        "--match",
        "/(".quotemeta($name).
            ($shortname ? "|".quotemeta($shortname):"").")(, \\S+)*:/",
        $todo_org_path,
    );
    #$self->log_debug(["cmd: %s", \@cmd]);
    $self->log_debug(["cmd: %s", join(" ", @cmd)]);
    my $output = capturex(@cmd);

    $output or do {
        $self->log_debug("Skipped generating TODO.md (no todo items)");
        return;
    };

    # quick hack to convert to markdown
    my $output_md = '';
    my $num_hls = 0;
    {
        my $prev_is_hl;
        my $prev_is_verbatim;
        my $prev_hl_has_text;
        for my $line (split /^/, $output) {
            if ($line =~ /\A(\*+) (.+)/) {
                $output_md .= "\n" if $prev_hl_has_text;
                $output_md .= "* $2\n";
                $num_hls++;
                $prev_is_hl++;
                $prev_hl_has_text = 0;
                $prev_is_verbatim = 0;
            } else {
                $prev_hl_has_text++;
                $output_md .= "\n" if $prev_is_hl;
                # change verbatim ": ..." to markdown style
                if ($line =~ s/^\s*: (.*)/    $1/) {
                    $output_md .= "\n" unless $prev_is_verbatim;
                    $prev_is_verbatim++;
                } else {
                    $prev_is_verbatim = 0;
                }
                $line =~ s/^/  /g;
                $output_md .= $line;
                $prev_is_hl = 0;
            }
        }
    }

    # just an arbitrary sanity check that prevents a mistake of e.g. exporting
    # my whole proj/perl entries, or even worse my whole todo.org entries
    if ($num_hls > 300) {
        die "There might be something wrong, there are > 300 todo entries";
    }

    my $todo_md = Dist::Zilla::File::InMemory->new(
        name => "TODO.md", content => $output_md);
    $self->add_file($todo_md);
}

__PACKAGE__->meta->make_immutable;
1;
# ABSTRACT: Generate TODO.md

=for Pod::Coverage .+

=head1 SYNOPSIS

In C<dist.ini>:

 [PERLANCAR::GenTodoMd]


=head1 DESCRIPTION

Currently this is specific to my setup (e.g. the location and format of the
C<todo.org> document, the short dist's name). Eventually I'll make it generic
and configurable enough.

If there is no C<todo.org> file, nothing will be generated.


=head1 SEE ALSO

L<http://neilb.org/2014/12/13/todo-convention-for-cpan.html>
