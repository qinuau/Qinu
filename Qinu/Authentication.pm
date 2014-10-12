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
    my $get_header_setcookie_f = defined $args{get_header_setcookie_f} && $args{get_header_setcookie_f} ? 1 : 0;

    if ($self->{qinu}->cgi->cookie('SID_' . $self->{qinu}->app_name)) {
        $sid = $self->{qinu}->cgi->cookie('SID_' . $self->{qinu}->app_name);
=for
        my $ref = $self->dbi_simple("SELECT * FROM sessions WHERE id='$sid'", $dbh);
        if (!$ref) {
            $session{failed} = 1;
            #return %session;
        }
=cut
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
    elsif ($type eq 'Memcached') {
        require 'Apache/Session/Memcached.pm';
        tie %session, 'Apache::Session::Memcached', $sid, {
            Servers => '127.0.0.1:11211',
            NoRehash => 1,
            Readonly => 0,
            Debug => 1,
            CompressThreshold => 10_000
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

    #if (!defined $self->qinu->{already_set_cookie_f} || !$self->qinu->{already_set_cookie_f}) {
        my $cookie_domain = '';
        if (defined $self->{qinu}->{conf}->{cookie_domain}) {
            $cookie_domain = ' domain=' . $self->{qinu}->{conf}->{cookie_domain} . ';';
        }

        my $header_setcookie = "Set-Cookie: SID_" . $self->{qinu}->app_name . "=" . $session{_session_id} . "; path=" . $self->{qinu}->base_path_web . ";" . $cookie_expire . $cookie_domain . "\n";
        if ($get_header_setcookie_f) {
            $self->{header_setcookie} = $header_setcookie;
        }
        else {
            print $header_setcookie;
        }
        $self->qinu->{already_set_cookie_f} = 1;
    #}

    if ($assign) {
        foreach (keys %$assign) {
            $session{$_} = $$assign{$_};
        }
    }
    #validate($session{visa_number});
    return %session;
}

sub auth {
    my ($self) = @_;
#    my $db_schema = shift;
#    my($form_id, $form_passwd) = @_;
#    my $dsn = shift;
#    #my $dsn = "DBI:mysql:uploadium";
#    #my $schema = DB::Main->connect($dsn, $db_user, $db_passwd);
#    my $result = $db_schema->resultset('Auth')->search({id => $form_id, passwd => $form_passwd});
#
#    if ($result > 0) {
#        my $assign = {
#            auth => '1',
#            id    => $form_id
#        };
#        my %session = $self->session('File', $assign);
#        return %session;
#    }
}

sub logout {
    my ($self, %args) = @_;
    my $type = $args{type};
    my $dbh_session = $args{dbh_session};
    my $dir = $args{dir};
    my $sid = $self->{qinu}->cgi->cookie('SID_' . $self->{qinu}->app_name);
    my %session;

    if ($type eq 'File') {
        tie %session, 'Apache::Session::File', $sid, {
            Directory     => $dir,
            LockDirectory => $dir . '/lock',
            Transaction   => 1
        };
    }
    else {
        tie %session, 'Apache::Session::' . $type, $sid, {
            Handle        => $dbh_session, 
            LockHandle => $dbh_session
        };
    }

    $session{'auth_' . $self->qinu->app_name} = '0';
    $session{id} = '';
    $session{name} = '';
    $session{cookie_expire} = '';
    #tied(%session)->delete;

    #print "Set-Cookie: SID_" . $self->{qinu}->app_name . "=; path=" . $self->{qinu}->base_path_web . ";\n";
}

sub _get_session {
    my ($self) = @_;
}

sub _set_session {
    my ($self) = @_;
}

sub check_login {
    my ($self, %args) = @_;

    my $member_table = 'member';
    if (defined $args{member_table} && $args{member_table} ne '') {
        $member_table = $args{member_table};
    }

    my $session;
    if (defined $args{session} && $args{session}) {
        $session = $args{session};
    }
    else {
        return;
    }

    my $key_uid = 'id';
    if (defined $args{key_uid} && $args{key_uid} ne '') {
        $key_uid = $args{key_uid}
    }

    my $uid;
    if (defined $session->{$key_uid} && $session->{$key_uid} ne '') {
        $uid = $session->{$key_uid};
    }
    else {
        return;
    }
    
    my $dbh;
    if (defined $args{dbh} && $args{dbh}) {
        $dbh = $args{dbh};
    }
    else {
        return;
    }

    my $sql = "SELECT * FROM " . $member_table . " WHERE uid = " . $dbh->quote($session->{$key_uid});
    my @member_data = $self->qinu->model->db_fetch_simple(dbh => $dbh, sql => $sql);
    if (scalar @member_data <= 0) {
        return;
    }

    if (!defined $session->{'auth_' . $self->qinu->app_name} || $session->{'auth_' . $self->qinu->app_name} != 1) {
        return;
    }

    return 1;
}

sub check_login_with_other_domain {
    my ($self, %args) = @_;

    my $assign = {}; 
    my $path_session = $args{dir_session};
    my %session = $self->qinu->authentication->_session(type => 'File', dir => $path_session, assign => $assign);
    my $app_name_session = $args{app_name};
    my $url_exchange_auth = $args{url_exchange_auth};

    if (defined $self->qinu->path_info_ary->{i} && defined $self->qinu->path_info_ary->{a}) {
        $self->qinu->app_name($self->qinu->path_info_ary->{a});
        %session = $self->qinu->authentication->_session(type => 'File', dir => $path_session, assign => $assign, sid => $self->qinu->path_info_ary->{i});
        $self->qinu->session(\%session);
    }
    else {
        $self->qinu->session(\%session);
    }

    my $dbh;
    if (defined $args{dbh} && $args{dbh}) {
        $dbh = $args{dbh};
    }
    else {
        return;
    }

    #if (!defined $session{'auth_' . $app_name_session} || $session{'auth_' . $app_name_session} ne '1') {
    if (!$self->qinu->authentication->check_login(dbh => $dbh, session => \%session)) {
        my $request_uri = $self->qinu->env_qinu->{REQUEST_URI};
        $request_uri =~ s/\//\|/g;
        my $refer = $self->qinu->current_protocol . ':' . $self->qinu->env_qinu->{SERVER_NAME} . $request_uri;
        $refer = $self->qinu->cgi_simple->url_encode($refer);

        print "Location: " . $url_exchange_auth . "/r/" . $refer . "/\n\n";
        exit;
    }
    if (defined $self->qinu->path_info_ary->{i} && defined $self->qinu->path_info_ary->{a} && defined $session{'auth_' . $app_name_session} && $session{'auth_' . $app_name_session} eq '1') {
        my $request_uri = $self->qinu->env_qinu->{REQUEST_URI};
        #$request_uri =~ s/index\/.+$//;
        if ($request_uri =~ /^\/index\/.+$/) {
            $request_uri =~ s/^\/index\/.+$//;
        }
        elsif ($request_uri =~ /^\/.+?\/(?:i|a)\/.+$/) {
            $request_uri =~ s/(^\/(.+?)\/)(?:i|a)\/.+$/$1/;
        }

        print "Location: " . $self->qinu->current_protocol . "://" . $self->qinu->env_qinu->{SERVER_NAME} . $request_uri . "\n\n";
    }
}

sub check_permission_member {
    my ($self, %args) = @_;

    if (!defined $args{dbh} || !defined $args{app_name} || !defined $args{uid}) {
        return 0;
    }

    my $dbh = $args{dbh};
    my $app_name = $args{app_name};
    my $uid = $args{uid};
    my $member_table = 'member';
    if (defined $args{member_table} && $args{member_table} ne '') {
        $member_table = $args{member_table};
    }

    my $sql = "SELECT * FROM " . $member_table . " WHERE uid = " . $dbh->quote($uid) . " AND permission_" . $app_name . " = 1";
    my @data_member = $self->qinu->model->db_fetch_simple(dbh => $dbh, sql => $sql);
    if (scalar @data_member == 0) {
        return 0;
    }
    else {
        return 1;
    }
}

sub check_cookie_password {
    my ($self, %args) = @_;

    if (!$self->qinu->cgi->cookie('password')) {
        return;
    }
    return 1;
}

1;
