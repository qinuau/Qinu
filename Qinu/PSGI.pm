package Qinu::PSGI;

use Data::Dumper;
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

    if (defined $args{env} && %{$args{env}}) {
        %ENV = (%ENV, %{$args{env}});
    }

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
    my $header;
    if (defined $self->qinu->{psgi_header}) {
        $header = $self->qinu->{psgi_header};
    }
    elsif (defined $self->qinu->{'Content-Type'} && $self->qinu->{'Content-Type'} ne '') {
        $content_type = $self->qinu->{'Content-Type'};
    }
    elsif (defined $args{'Content-Type'} && $args{'Content-Type'} ne "") {
        $content_type = $args{'Content-Type'};
    }
    else {
        $content_type = 'text/html';
    }

    if ($content_type ne '') {
        $header{'Content-Type'} = $content_type;
    }

    return [
        200,
        [%$header],
        [$self->qinu->result_content],
    ];
}

1;
