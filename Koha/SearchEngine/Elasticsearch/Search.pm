package Koha::SearchEngine::ElasticSearch::Search;

# Copyright 2014 Catalyst IT
#
# This file is part of Koha.
#
# Koha is free software; you can redistribute it and/or modify it under the
# terms of the GNU General Public License as published by the Free Software
# Foundation; either version 3 of the License, or (at your option) any later
# version.
#
# Koha is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
# A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with Koha; if not, write to the Free Software Foundation, Inc.,
# 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.

=head1 NAME

Koha::SearchEngine::ElasticSearch::Search - search functions for Elasticsearch

=head1 SYNOPSIS

    my $searcher = Koha::SearchEngine::ElasticSearch::Search->new();
    my $builder = Koha::SearchEngine::Elasticsearch::QueryBuilder->new();
    my $query = $builder->build_query('perl');
    my $results = $searcher->search($query);
    print "There were " . $results->total . " results.\n";
    $results->each(sub {
        push @hits, @_[0];
    });

=head1 METHODS

=cut

use base qw(Koha::ElasticSearch);
use Koha::ItemTypes;

use Catmandu::Store::ElasticSearch;

use Data::Dumper; #TODO remove
use Carp qw(cluck);

Koha::SearchEngine::ElasticSearch::Search->mk_accessors(qw( store ));

=head2 search

    my $results = $searcher->search($query, $page, $count);

Run a search using the query. It'll return C<$count> results, starting at page
C<$page> (C<$page> counts from 1, anything less that, or C<undef> becomes 1.)

C<%options> is a hash containing extra options:

=over 4

=item offset

If provided, this overrides the C<$page> value, and specifies the record as
an offset (i.e. the number of the record to start with), rather than a page.

=back

=cut

sub search {
    my ($self, $query, $page, $count, %options) = @_;

    my $params = $self->get_elasticsearch_params();
    my %paging;
    $paging{limit} = $count || 20;
    # ES doesn't want pages, it wants a record to start from.
    if (exists $options{offset}) {
        $paging{start} = $options{offset};
    } else {
        $page = (!defined($page) || ($page <= 0)) ? 1 : $page - 1;
        $paging{start} = $page * $paging{limit};
    }
    $self->store(
        Catmandu::Store::ElasticSearch->new(
            %$params,
            trace_calls => 0,
        )
    );
    my $results = $self->store->bag->search( %$query, %paging );
    return $results;
}

=head2 search_compat

    my ( $error, $results, $facets ) = $search->search_compat(
        $query,            $simple_query, \@sort_by,       \@servers,
        $results_per_page, $offset,       $expanded_facet, $branches,
        $query_type,       $scan
      )

A search interface somewhat compatible with L<C4::Search->getRecords>. Anything
that is returned in the query created by build_query_compat will probably
get ignored here.

=cut

sub search_compat {
    my (
        $self,     $query,            $simple_query, $sort_by,
        $servers,  $results_per_page, $offset,       $expanded_facet,
        $branches, $query_type,       $scan
    ) = @_;

    my %options;
    $options{offset} = $offset;
    my $results = $self->search($query, undef, $results_per_page, %options);

    # Convert each result into a MARC::Record
    my (@records, $index);
    $index = $offset; # opac-search expects results to be put in the
        # right place in the array, according to $offset
    $results->each(sub {
            # The results come in an array for some reason
            my $marc_json = @_[0]->{record};
            my $marc = $self->json2marc($marc_json);
            $records[$index++] = $marc;
        });
    # consumers of this expect a name-spaced result, we provide the default
    # configuration.
    my %result;
    $result{biblioserver}{hits} = $results->total;
    $result{biblioserver}{RECORDS} = \@records;
    return (undef, \%result, $self->_convert_facets($results->{facets}));
}

=head2 json2marc

    my $marc = $self->json2marc($marc_json);

Converts the form of marc (based on its JSON, but as a Perl structure) that
Catmandu stores into a MARC::Record object.

=cut

sub json2marc {
    my ( $self, $marcjson ) = @_;

    my $marc = MARC::Record->new();
    $marc->encoding('UTF-8');

    # fields are like:
    # [ '245', '1', '2', 'a' => 'Title', 'b' => 'Subtitle' ]
    # conveniently, this is the form that MARC::Field->new() likes
    foreach $field (@$marcjson) {
        next if @$field < 5;    # Shouldn't be possible, but...
        if ( $field->[0] eq 'LDR' ) {
            $marc->leader( $field->[4] );
        }
        else {
            my $marc_field = MARC::Field->new(@$field);
            $marc->append_fields($marc_field);
        }
    }
    return $marc;
}

=head2 _convert_facets

    my $koha_facets = _convert_facets($es_facets);

Converts elasticsearch facets types to the form that Koha expects.
It expects the ES facet name to match the Koha type, for example C<itype>,
C<au>, C<su-to>, etc.

=cut

sub _convert_facets {
    my ( $self, $es ) = @_;

    return undef if !$es;

    # These should correspond to the ES field names, as opposed to the CCL
    # things that zebra uses.
    my %type_to_label = (
        author   => 'Authors',
        location => 'Location',
        itype    => 'ItemTypes',
        se       => 'Series',
        subject  => 'Topics',
        'su-geo' => 'Places',
    );

    # We also have some special cases, e.g. itypes that need to show the
    # value rather than the code.
    my $itypes = Koha::ItemTypes->new();
    my %special = ( itype => sub { $itypes->get_description_for_code(@_) }, );
    my @res;
    while ( ( $type, $data ) = each %$es ) {
        next if !exists( $type_to_label{$type} );
        my $facet = {
            type_id => $type . '_id',
            expand  => $type,
            expandable => 1,    # TODO figure how that's supposed to work
            "type_label_$type_to_label{$type}" => 1,
            type_link_value                    => $type,
        };
        foreach my $term ( @{ $data->{terms} } ) {
            my $t = $term->{term};
            my $c = $term->{count};
            if ( exists( $special{$type} ) ) {
                $label = $special{$type}->($t);
            }
            else {
                $label = $t;
            }
            push @{ $facet->{facets} }, {
                facet_count       => $c,
                facet_link_value  => $t,
                facet_title_value => $t . " ($c)",
                facet_label_value => $label,    # TODO either truncate this,
                     # or make the template do it like it should anyway
                type_link_value => $type,
            };
        }
        push @res, $facet if exists $facet->{facets};
    }
    return \@res;
}


1;