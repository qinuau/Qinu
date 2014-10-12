package Qinu::Encode;

use strict;
use warnings;
require URI::Escape;

use base qw(Class::Accessor::Fast);
__PACKAGE__->mk_accessors(qw(qinu));

sub new {
    my ($self, %args) = @_;

    my $attr = {
        qinu => $args{qinu},
    };

    return bless $attr, $self;
}

sub uri_escape {
    my ($self, %args) = @_;

    my $value = defined $args{value} ? $args{value} : return;

    my $result = URI::Escape::uri_escape($value);

    return $result;
}

sub uri_unescape {
    my ($self, %args) = @_;

    my $value = defined $args{value} ? $args{value} : return;

    my $result = URI::Escape::uri_unescape($value);

    return $result;
}

1;
