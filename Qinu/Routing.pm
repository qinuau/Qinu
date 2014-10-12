package Qinu::Routing;

sub new {
    my ($self, %args) = @_;

    my $attr = {
	qinu => $args{qinu},
    };

    if (-f $attr->{qinu}->conf->{lib_path} . '/conf/routing.pl') {
        require $attr->{qinu}->conf->{lib_path} . '/conf/routing.pl';
        $attr->{config} = $Qinu::Routing::config::config;
    }

    bless $attr, $self;
}

1;
