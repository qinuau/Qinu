use feature qw(:5.10);
use Data::Dumper;

package Controller;

use base qw(Class::Accessor::Fast);
__PACKAGE__->mk_accessors(qw(qinu));

sub new {
    my ($self, $qinu) = @_;

    my $attr = {
        qinu => $qinu,
    };

    bless $attr, $self;
}

sub con {
    my ($self, %args) = @_;

    my $result;
    my $vars = {

    };
    $self->{qinu}->view->process(output => 'index.tt', values => $vars, processed => \$result);

    # case of PSGI application.
    [% comment_psgi %]return $self->{qinu}->result_content($result);

    # case of cgi or fcgi.
    [% comment %]$self->{qinu}->http->header();
    [% comment %]print $result;
}

1;
