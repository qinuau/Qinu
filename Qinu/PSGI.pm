package Qinu::PSGI;

use Qinu;
use base qw(Class::Accessor::Fast);
__PACKAGE__->mk_accessors(qw(qinu));

sub new {
    my ($self, %args) = @_;

    my $attr = {
        qinu   => "",
        config => \%args,
    };

    bless $attr, $self;
}

sub run {
    my ($self, %args) = @_;

    my $qinu;
    if (defined $self->{config} && $self->{config}) {
        my $config = $self->{config};
        $qinu = Qinu->new(%$config);
        $self->qinu($qinu);
    }
    else {
        return [
            500,
            ['Content-Type' => 'text/html'],
            [''],
        ];
    }

    my $content_type = "";
    if (defined $args{'Content-Type'} && $args{'Content-Type'} ne "") {
        $content_type = $args{'Content-Type'};
    }
    else {
        $content_type = 'text/html';
    }

    return [
        200,
        ['Content-Type' => $content_type],
        [$self->qinu->result_content],
    ];
}

1;
