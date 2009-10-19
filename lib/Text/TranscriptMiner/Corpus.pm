package Text::TranscriptMiner::Corpus;

use Moose;
use MooseX::Types -declare => [qw/CorpusDir Str/];
use MooseX::Types::Moose qw/Str/;
use aliased 'Text::TranscriptMiner::Document::Interview';
use Path::Class;
use aliased 'Tree::Simple::Visitor::LoadDirectoryTree';
use Tree::Simple;
use Tree::Simple::Visitor::PathToRoot;
use List::MoreUtils qw/all/;
use Carp;

class_type CorpusDir, { class => 'Path::Class::Dir'} ;
coerce CorpusDir, from Str, via { Path::Class::Dir->new($_)};

=head1 Text::TranscriptMiner::Corpus

Represents a corpus of transcripts

=head2 ATTRIBUTES

start_dir (required Path::Class::Dir object or string)
doctree (hashref created from start_dir)

=head2 METHODS

=head3 new( { startdir => [Path::Class::Dir or string representing path to file])

=cut

has start_dir  => (isa => CorpusDir,
                   is => 'ro',
                   coerce => 1,
                   required => 1);
has doctree    => (isa => 'Tree::Simple',
                   is => 'ro',
                   lazy_build => 1);
has pathfinder => (isa => 'Tree::Simple::Visitor::PathToRoot',
                   is  => 'ro',
                   lazy => 1,
                   default => sub { Tree::Simple::Visitor::PathToRoot->new() }
                 );



=head3 _build_doctree

creates a hashref with the following structure:

...

=cut

sub _build_doctree {
    my ($self) = @_;
    my $tree = Tree::Simple->new($self->start_dir);
    my $visitor = LoadDirectoryTree->new();
    $visitor->setSortStyle($visitor->SORT_FILES_FIRST);
    $visitor->setNodeFilter(
        sub {
            my ($item) = @_;
            return 0 if $item =~ /^\.|mp3/;
            return 1;
        });
    $tree->accept($visitor);
    return $tree;
}

=head2 get_files_info

Grabs metadata from the file names and paths.  Directory names are assumed to contain information.  File names have words delimited by '_' characters, and only words in all capitals are assumed to be worth collecting;

=cut


sub get_files_info {
    my ($self) = @_;
    my $nodes = $self->get_subnodes;
    my $data = {};
    foreach my $n (@$nodes) {
        my @data = split '/', $n;
        my $file = pop @data;
        $file =~ s/\.txt$//;
        my @fileinfo = split '_', $file;
        @fileinfo =  grep { /^[A-Z]+$/ } @fileinfo;
        $DB::single=1;
        $data->{$_}++ for (@data, @fileinfo);
    }
    return $data;
}

sub get_subnodes {
    my ($self, $node, $data) = @_;
    $node ||= $self->doctree;
    $data ||= [];
    foreach my $n ($node->getAllChildren) {
        $node->accept($self->pathfinder);
        my $col = $self->pathfinder->getPathAsString('/') . '/' . $n->getNodeValue;
        $col =~ s/^\///;
        push @$data, $col;
        if ($node->getAllChildren) {
            $self->get_subnodes($n, $data);
        }
    }
    return $data;
}

sub search_for_subnodes {
    my ($self, $tags, $doctree) = @_;
    croak "not an array reference" unless ref($tags) eq 'ARRAY';
    my @tags;
    @tags = grep { $_ ne '_remove'} @$tags;
    my $pages = $self->get_subnodes;
    my @pages;
    # if all of @tags are in each $page then add to @pages;
    foreach my $p (@$pages) {
        push @pages, $p if (all { $p =~ /$_/} @tags);
    }
    return \@pages;
}

__PACKAGE__->meta->make_immutable;

1;
