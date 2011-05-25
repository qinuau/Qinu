package Qinu::Mobile;

use base qw(Class::Accessor::Fast);
__PACKAGE__->mk_accessors(qw(qinu));

sub new {
    my ($self, %args) = @_;
    my $qinu = $args{qinu};

    my $attr = {
        qinu => $qinu,
    };

    bless $attr, $self;
}

sub check_carrier {
    my ($self, %args) = @_;

    if ($self->qinu->env_qinu->{HTTP_USER_AGENT} =~ /^DoCoMo/) {
        return 'docomo';
    }
    elsif ($self->qinu->env_qinu->{HTTP_USER_AGENT} =~ /^(?:J-PHONE|Vodafone|SoftBank)/) {
        return 'softbank';
    }
    elsif ($self->qinu->env_qinu->{HTTP_USER_AGENT} =~ /^(?:UP\.Browser|KDDI)/) {
        return 'au';
    }
    else {
        return 0;
    }
}

1;
