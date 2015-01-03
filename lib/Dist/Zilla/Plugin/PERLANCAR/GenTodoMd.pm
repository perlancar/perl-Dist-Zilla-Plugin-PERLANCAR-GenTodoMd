package Dist::Zilla::Plugin::PERLANCAR::GenTodoMd;

# DATE
# VERSION

use 5.010001;
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

    my $output = capturex(
        "filter-org-by-headlines",
        "--without-preamble",
        "--is-todo",
        "--isnt-done",
        "--level 2",
        "--parent-match", "proj/perl",
        $todo_org_path,
    );

    # quick hack to convert to markdown
    my $output_md = '';
    {
        for my $line (split /^/, $output) {
            if ($line =~ /\A(\*+) (.+)/) {
                $output_md .= "* $2\n";
            } else {
            }
        }
    }

    my $todo_md = Dist::Zilla::File::InMemory->new(
        name => "TODO.md", content => $output_md);
    $self->log("Generating TODO.md");
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

