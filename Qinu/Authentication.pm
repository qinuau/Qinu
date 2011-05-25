package Qinu::Authentication;

use strict;
use warnings;

use base qw(Class::Accessor::Fast);
__PACKAGE__->mk_accessors(qw(qinu));

use Data::Dumper;

sub new {
    my ($self, %args) = @_;
    my $attr = {
        qinu => $args{qinu},
    };
    bless $attr, $self;
}

sub _session {
    my ($self, %args) = @_;
    my $type = $args{type};
    my $dir = $args{dir};
    my $assign = $args{assign};
    my $dbh = $args{dbh};
    my $sid_args = defined $args{sid} ? $args{sid} : '';
    my %session;
    my $sid = '';

    if ($self->{qinu}->cgi->cookie('SID_' . $self->{qinu}->app_name)) {
        $sid = $self->{qinu}->cgi->cookie('SID_' . $self->{qinu}->app_name);
    }
    if ($sid_args ne '') {
        $sid = $sid_args;
    }

    if ($type eq 'File') {
        if ($sid ne '' && !-f $dir . '/' . $sid) {
            $sid = '';
        }

        require 'Apache/Session/File.pm';
        tie %session, 'Apache::Session::File', $sid, {
            Directory     => $dir,
            LockDirectory => $dir . '/lock',
            Transaction   => 1
        };
    }
    elsif ($type ne 'File') {
        require 'Apache/Session/' . $type . '.pm';
        tie %session, 'Apache::Session::' . $type, $sid, {
            Handle        => $dbh, 
            LockHandle => $dbh
        };
    }
    # cookie expire
    my $cookie_expire = "";
    if (defined $self->{qinu}->{cookie_expire}) {
        $cookie_expire = ' expires=' . $self->{qinu}->{cookie_expire} . ';';
        $session{cookie_expire} = $cookie_expire;
    }
    if ($self->qinu->login_perm) {
        $cookie_expire = ' expires=Thu,31-Dec-2037 00:00:00;';
        $session{cookie_expire} = $cookie_expire;
    }

    if ($session{cookie_expire}) {
        $cookie_expire = $session{cookie_expire};
    }

    print "Set-Cookie: SID_" . $self->{qinu}->app_name . "=" . $session{_session_id} . "; path=" . $self->{qinu}->base_path_web . ";" . $cookie_expire . "\n";

    if ($assign) {
        foreach (keys %$assign) {
            $session{$_} = $$assign{$_};
        }
    }
    #validate($session{visa_number});
    return %session;
}

sub _get_session {
    my ($self) = @_;
}

sub _set_session {
    my ($self) = @_;
}

1;
