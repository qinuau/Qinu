package Qinu;

use strict;
use warnings;

use CGI;
use CGI::Simple;
use Data::Dumper;
use DateTime;
use Digest::MD5 qw(md5_hex);
use File::Basename;
use HTML::FillInForm;
use Qinu::Authentication;
use Qinu::Authentication::OAuth::Twitter;
#use Qinu::MIME::Lite;
use Qinu::HTTP;
use Qinu::Mobile;
use Qinu::Model;
use Qinu::SMTP;
use Qinu::Util;
use Qinu::View;
use Template;
use base qw(Class::Accessor::Fast);

__PACKAGE__->mk_accessors(qw(accept_language action_name app app_name base_path base_path_web conf cookie_expire current_protocol db_log env_qinu env_kolp lib_path login_perm params params_escaped path_info_ary result_content server_name session));

our $VERSION = '1.0';

# constructor
sub new {
    my ($self, %args) = @_;
    #my $conf = $args{conf};
    my $conf = \%args;

    my $env_qinu;
    if (defined($conf->{fcgi_request})) {
        $env_qinu = $conf->{fcgi_request}->GetEnvironment();
    }
    elsif (defined($args{env})) {
        $env_qinu = $args{env};
    }
    else {
        $env_qinu = \%ENV;
    }
    my $env_kolp = $env_qinu;

    my $attr = {
        conf           => $conf,
        env_qinu       => $env_qinu,
        env_kolp       => $env_kolp,
        action_name    => '',
        path_info_ary  => {},
        params         => {},
        params_escaped => {},
    };

    my $self_ref = bless $attr, $self;

    # query
    my %vars = $self_ref->cgi_simple->Vars;
    $self_ref->params(\%vars);
    $self_ref->params_escaped($self_ref->http->encode_entity(value => \%vars));
    $self_ref->get_path_info();

    # application name
    my $app_name;
    if (defined $attr->{env_qinu}{SCRIPT_NAME}) {
        my $path_script = $attr->{env_qinu}{SCRIPT_NAME};
        $app_name = $path_script;
        $app_name =~ s/^\///;
        $app_name =~ s/\./-/;
        $app_name = Digest::MD5::md5_hex($app_name);
    }

    $self_ref->app_name($app_name);
    
    # base_path
    if (defined $attr->{env_qinu}{SCRIPT_FILENAME}) {
        $self_ref->base_path(dirname($attr->{env_qinu}{SCRIPT_FILENAME}));
    }

    # base_path_web
    if (defined $attr->{env_qinu}{SCRIPT_NAME}) {
        $self_ref->base_path_web(dirname($attr->{env_qinu}{SCRIPT_NAME}));
    }

    # lib path
    $self_ref->lib_path($attr->{conf}{lib_path});

    # sever name
    $self_ref->server_name($attr->{env_qinu}{SERVER_NAME});

    # cookie expire
    if (!defined $attr->{conf}{cookie_expire}) {
        #$attr->{conf}{cookie_expire} = 'Thu,31-Dec-2037 00:00:00';
    }
    else {
        $self_ref->cookie_expire($attr->{conf}{cookie_expire});
    }

    # current protocol
    if (defined $self_ref->env_qinu->{SERVER_PORT} && $self_ref->env_qinu->{SERVER_PORT} =~ /(443|4430)/) {
        $self_ref->current_protocol('https');
    }
    else {
        $self_ref->current_protocol('http');
    }

    if (!defined $self_ref->conf->{protocol_secure}) {
        $self_ref->conf->{protocol_secure} = 'https';
    }
    if (!defined $self_ref->conf->{protocol_default}) {
        $self_ref->conf->{protocol_default} = 'http';
    }

    # accept language.
    my $accept_language = defined $self_ref->env_qinu->{HTTP_ACCEPT_LANGUAGE} ? $self_ref->env_qinu->{HTTP_ACCEPT_LANGUAGE} : '';
    $self_ref->accept_language($self_ref->http->get_language(language => $accept_language));

    my $dir_session;
    my %session;
    my $controller;
    my $action_name;
    if (!defined($self_ref->conf->{cli}) || $self_ref->conf->{cli} != 1) {
        require Controller;

        # session
        $dir_session ||= $attr->{conf}{session} ||= $attr->{conf}{lib_path} . '/sessions';
        #%session = $self_ref->authentication->_session(type => 'File', dir => $dir_session);
        #%session = $self_ref->_session(type => 'File', dir => $dir_session);
        #$self_ref->session(%session);
    
        # dispatch
        $controller = Controller->new($self_ref);
        no strict 'refs';
        $action_name = $self_ref->action_name;
        if (defined $action_name && $controller->can($action_name) && $action_name !~ /^_/) {
            $controller->${action_name};
        }
        else {
            $controller->con;
        }
        use strict 'refs';
    }

    $self_ref;
}

sub AUTOLOAD {
    my ($self) = @_;

    my $method = our $AUTOLOAD;
    $method =~ s/Kolp/Qinu/;
    $method =~ /Qinu::(.+)/;
    $method = $1;

    my $plugin_f = 0;
    foreach (@INC) {
        my $lib_path_perl = $_;
        if (-f $lib_path_perl . '/Qinu/Plugins/' . $method . '.pm') {
            $plugin_f = 1;
        }
    }

    if ((!defined $self->{$method} || !$self->{$method}) && $plugin_f == 1) {
        require 'Qinu/Plugins/' . $method . '.pm';
        my $name_plugin = 'Qinu::Plugins::' . $method;
        $self->{$method} = $name_plugin->new($self);

        # attribute auto set
        if ($self->conf->{$method}) {
            my $conf_plugin = $self->conf->{$method};
            foreach my $conf_each (sort keys %$conf_plugin) {
                $self->{$method}->{$conf_each} = $conf_plugin->{$conf_each};
            }
        }
    }
    return $self->{$method};
}

sub template {
    my ($self) = @_;
    my $template;
    if (!defined $self->{template} || !$self->{template}) {
	my $config = {
	    INCLUDE_PATH => $self->conf->{lib_path} . '/template',
	};
        $template = Template->new($config);
    }
    else {
        $template = $self->{template};
    }
    return $template;
}


sub cgi {
    my ($self) = @_;
    my $cgi;
    if (!defined $self->{cgi} || !$self->{cgi}) {
        $cgi = CGI->new();
        $cgi->charset('utf8'); # default is UTF-8.
        $self->{cgi} = $cgi;
    }
    else {
        $cgi = $self->{cgi};
    }
    return $cgi;
}

sub cgi_simple {
    my ($self) = @_;

    if (defined $self->conf->{max_upload_file_size_default}) {
        $CGI::Simple::POST_MAX = $self->conf->{max_upload_file_size_default};
    }

    $CGI::Simple::DISABLE_UPLOADS = 0;

    my $cgi_simple;
    if (!defined $self->{cgi_simple} || !$self->{cgi_simple}) {
        $cgi_simple = CGI::Simple->new();
        $self->{cgi_simple} = $cgi_simple;
    }
    else {
        $cgi_simple = $self->{cgi_simple};
    }
    return $cgi_simple;
}

sub model {
    my ($self) = @_;
    my $model;
    if (!defined $self->{model} || !$self->{model}) {
	$self->db_log($self->conf->{db_log}); # db log path
        $model = Qinu::Model->new($self);
        $self->{model} = $model;
    }
    else {
        $model = $self->{model};
    }
    return $model;
}

sub view {
    my ($self) = @_;
    my $view;
    if (!defined $self->{view} || !$self->{view}) {
        $view = Qinu::View->new(qinu => $self);
        $self->{view} = $view;
    }
    else {
        $view = $self->{view};
    }
    return $view;
}

sub smtp {
    my ($self, %attr) = @_;
    $attr{qinu} = $self;
    my $smtp;
    if (!defined $self->{smtp} || !$self->{smtp}) {
        $smtp = Qinu::SMTP->new(%attr);
        $self->{smtp} = $smtp;
    }
    else {
        $smtp = $self->{smtp};
    }
    return $smtp;
}

sub authentication {
    my ($self, %attr) = @_;
    $attr{qinu} = $self;
    my $authentication;
    if (!defined($self->{authentication}) || !$self->{authentication}) {
        $authentication = Qinu::Authentication->new(%attr);
        $self->{authentication} = $authentication;
    }
    else {
        $authentication = $self->{authentication};
    }
    return $authentication;
}

sub authentication_oauth_twitter {
    my ($self, %attr) = @_;
    $attr{qinu} = $self;
    my $authentication_oauth_twitter;
    if (!defined($self->{authentication_oauth_twitter}) || !$self->{authentication_oauth_twitter}) {
        $authentication_oauth_twitter = new Qinu::Authentication::OAuth::Twitter(%attr);
        $self->{authentication_oauth_twitter} = $authentication_oauth_twitter;
    }
    else {
        $authentication_oauth_twitter = $self->{authentication_oauth_twitter};
    }
    return $authentication_oauth_twitter;
}

sub util {
    my ($self, %args) = @_;
    $args{qinu} = $self;

    my $util; 
    if (!defined($self->{util}) || !$self->{util}) {
        $util = Qinu::Util->new(%args);
        $self->{util} = $util;
    }
    else {
        $util = $self->{util};
    }
    return $util;
}

sub http {
    my ($self, %args) = @_;
    $args{qinu} = $self;

    my $http; 
    if (!defined($self->{http}) || !$self->{http}) {
        $http = Qinu::HTTP->new(%args);
        $self->{http} = $http;
    }
    else {
        $http = $self->{http};
    }
    return $http;
}

sub mobile {
    my ($self, %args) = @_;
    $args{qinu} = $self;

    my $mobile;
    if (!defined($self->{mobile}) || !$self->{mobile}) {
        $mobile = Qinu::Mobile->new(%args);
        $self->{mobile} = $mobile;
    }
    else {
        $mobile = $self->{mobile};
    }
    return $mobile;
}

sub get_path_info {
    my ($self) = @_;
    
    my @pairs;
    if (defined $self->params->{q}) {
        @pairs = split(/\//, $self->params->{q});
    }
    else {
        my $current_dir;
        if (defined $self->env_qinu->{SCRIPT_NAME}) {
            $current_dir = $self->env_qinu->{SCRIPT_NAME};
            $current_dir =~ s/\/index.html//;
        }
        my $request_uri;
        if (defined $self->env_qinu->{REQUEST_URI}) {
            $request_uri = $self->env_qinu->{REQUEST_URI};
            $request_uri =~ s/$current_dir\///;
            @pairs = split(/\//, $request_uri);
        }
    }

    $self->{action_name} = shift @pairs;
    if (!$self->action_name) {
        if (defined $self->env_qinu->{QUERY_STRING}) {
            my @pairs_action_name = split(/=/, $self->env_qinu->{QUERY_STRING});
            if (defined $pairs_action_name[1]) {
                $pairs_action_name[1] =~ s/\///g;
                $self->action_name($pairs_action_name[1]);
            }
        }
    }

    while (my ($k, $v) = @pairs) {
        $k = shift @pairs;
        $v = shift @pairs;
        $self->{path_info_ary}{$k} = $v;
    }
    1;
}

sub query {
    my ($self) = @_;
    my $buffer;
    my %params;
    
    if (defined $self->env_qinu->{REQUEST_METHOD} && $self->env_qinu->{REQUEST_METHOD} eq "POST") {
        read(STDIN, $buffer, $self->env_qinu->{CONTENT_LENGTH});
    }
    else {
        $buffer = $self->env_qinu->{QUERY_STRING};
    }
    
    my @pairs;
    if ($buffer) {
        @pairs = split(/&/, $buffer);
    }
    
    foreach my $pair (@pairs) {
        my ($name, $value) = split(/=/, $pair);
        $value =~ tr/+/ /;
        $value =~ s/%([a-fA-F0-9][a-fA-F0-9])/pack("C", hex($1))/eg;
        $params{$name} = $value;
    }
    \%params;
}

1;
__END__
=head1 NAME

Qinu - Perl Plugable Environment/Web Framework.

=head1 AUTHOR

Yotsumoto, Toshitaka "yotsumoto@qinuau.com"

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2008 by Yotsumoto, Toshitaka

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.10.0 or,
at your option, any later version of Perl 5 you may have available.


=cut
