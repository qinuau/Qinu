package Qinu::App;

use Data::Dumper;

sub new {
    my ($self, %args) = @_;

    my $code;
    foreach my $each (@{$args{app}}) {
        my $subname;
        my @tmp = split '::', $each;
        @tmps = map lc $_, @tmp;
        foreach my $tmp (@tmps) {
            $subname .= $tmp . "_";
        }
        $subname = substr($subname, 0, -1);

        $code = 'use Qinu::App::' . $each . ";\n";
        $code .= '$args{qinu}->{app}->{' . $subname . '} = Qinu::App::' . $each . '->new(qinu => $args{qinu});' . "\n";
        eval $code;
    }

    my $attr = {
        qinu => $args{qinu},
    };

    bless $attr, $self;
}

1;
