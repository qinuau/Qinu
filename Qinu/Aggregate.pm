package Qinu::Aggregate;

use Encode;

use base qw(Class::Accessor::Fast);

__PACKAGE__->mk_accessors(qw(qinu));

sub new {
    my ($self, %args) = @_;

    my $qinu;
    if (defined $args{qinu} && $args{qinu}) {
        $qinu = $args{qinu};
    }

    my $attr = {
        qinu => $qinu,
    };

    bless $attr, $self;
}

1;
