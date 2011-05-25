package Qinu::Controller;

use base qw(Class::Accessor::Fast);

__PACKAGE__->mk_accessors(qw(qinu));

sub new {
    my ($self, $qinu) = @_;

    my $attr = {
        qinu => $qinu,
    };

    bless $attr, $self;
}

1;
