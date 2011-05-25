package Qinu::Plugins::Foo;

sub new {
    my $self = shift;
    my $attr = {

    };
    bless $attr, $self;
}

sub foo {
    my $self = shift;
    return "Foooofsdgvsdfljgv";
}

1;
