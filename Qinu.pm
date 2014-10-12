package Qinu;

use strict;
use warnings;

use Data::Dumper;
use Digest::MD5 qw(md5_hex);
use File::Basename;
use File::Slurp;
use FindBin;
use Qinu::Routing;
use Qinu::YAML;
use base qw(Class::Accessor::Fast);

__PACKAGE__->mk_accessors(qw(accept_language action_name app app_name base_path base_path_web conf controller cookie_expire current_protocol db_log env_qinu env_kolp html_scrubber is_psgi lib_path login_perm params params_escaped path_info_ary result_content server_name session));

our $VERSION = '1.0';

# constructor
sub new {
    my ($self, %args) = @_;
    #my $conf = $args{conf};
    my $conf = \%args;

    if (defined $conf->{config_yaml} && $conf->{config_yaml} ne '') {
        if (-f $conf->{config_yaml}) {
            my $conf_yaml = read_file($conf->{config_yaml});
            my $conf_yaml_loaded = '';
            eval { $conf_yaml_loaded = Qinu::YAML::Load $conf_yaml };
            %$conf = (%$conf, %{$conf_yaml_loaded->{conf}});
        }
    }

    if (defined $conf->{use_lib}) {
        eval 'use lib (' . $conf->{use_lib} . ')';
    }

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

    # is PSGI?
    if (defined $self_ref->{env_qinu}->{'psgi.input'}) {
        $self_ref->is_psgi(1);
    }

    # query
    my %vars = ();
    if ($self_ref->is_psgi) {
        my @all_params = $self_ref->cgi_psgi->param;
        foreach my $param (@all_params) {
            $vars{$param} = $self_ref->cgi_psgi->param($param);
        }
    }
    else {
        %vars = $self_ref->cgi_simple->Vars;
    }
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
    #if (!defined $attr->{conf}{cookie_expire}) {
    #    $attr->{conf}{cookie_expire} = 'Thu,31-Dec-2037 00:00:00';
    #}
    if (defined $self_ref->params->{login_perm}) {
        $self_ref->cookie_expire('Thu,31-Dec-2037 00:00:00');
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

    # time zone.
    if (!defined $self_ref->conf->{time_zone} || $self_ref->conf->{time_zone} eq '') {
        $self_ref->conf->{time_zone} = 'Asia/Tokyo';
    }
    elsif ($self_ref->accept_language eq 'en') {
        $self_ref->conf->{time_zone} = 'America/New_York';
    }

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
        $self_ref->{controller} = $controller;

        $self_ref->{routing} = new Qinu::Routing(qinu => $self_ref);

        my $request_method = '';
        if (defined $self_ref->params->{_method} && $self_ref->params->{_method} ne '') {
            $request_method = uc($self_ref->params->{_method});
        }
        elsif (defined $self_ref->env_qinu->{REQUEST_METHOD}) {
            $request_method = $self_ref->env_qinu->{REQUEST_METHOD};
        }

        $action_name = $self_ref->action_name;
        my $action_method = '';
        if (
            $request_method ne '' &&
            defined $action_name && $action_name ne '' &&
            defined $self_ref->{routing}->{config}->{$request_method}->{$action_name}->{method}
        ) {
            $action_method = $self_ref->{routing}->{config}->{$request_method}->{$action_name}->{method};
        }
        else {
            $action_method = $action_name;
        }

        no strict 'refs';
        if ($action_method ne '' && $controller->can($action_method) && $action_method !~ /^_/) {
            $controller->${action_method};
        }
        else {
            $controller->con;
        }
        use strict 'refs';
    }

    return $self_ref;
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
        require Template;
        Template->import();

	my $config = {
	    INCLUDE_PATH => $self->conf->{lib_path} . '/template',
            #INTERPOLATE  => 1,
            #POST_CHOMP   => 1,
            #PRE_PROCESS  => 'header',
            #EVAL_PERL    => 1,
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
        require CGI;
        CGI->import();

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
        require CGI::Simple;
        CGI::Simple->import();

        $cgi_simple = CGI::Simple->new();
        $self->{cgi_simple} = $cgi_simple;
    }
    else {
        $cgi_simple = $self->{cgi_simple};
    }
    return $cgi_simple;
}

sub cgi_psgi {
    my ($self) = @_;
    my $cgi_psgi;
    if (!defined $self->{cgi_psgi} || !$self->{cgi_psgi}) {
        require Qinu::CGI::PSGI;
        $cgi_psgi = Qinu::CGI::PSGI->new($self->env_qinu);
        $self->{cgi_psgi} = $cgi_psgi;
    }
    else {
        $cgi_psgi = $self->{cgi_psgi};
    }
    return $cgi_psgi;
}

sub model {
    my ($self) = @_;
    my $model;
    if (!defined $self->{model} || !$self->{model}) {
        require Qinu::Model;

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
        require Qinu::View;

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
        require Qinu::SMTP;

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
        require Qinu::Authentication;

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
        require Qinu::Authentication::OAuth::Twitter;

        $authentication_oauth_twitter = Qinu::Authentication::OAuth::Twitter->new(%attr);
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
        require Qinu::Util;

        $util = Qinu::Util->new(%args);
        $self->{util} = $util;
    }
    else {
        $util = $self->{util};
    }
    return $util;
}

sub html_scrubber {
    my ($self, %args) = @_;

    my $html_scrubber;
    if (!defined($self->{html_scrubber}) || !$self->{html_scrubber}) {
        require Qinu::HTML::Scrubber;

        $html_scrubber = Qinu::HTML::Scrubber->new(%args);
        $self->{html_scrubber} = $html_scrubber;
    }
    else {
        $html_scrubber = $self->{html_scrubber};
    }
    return $html_scrubber;
}

sub http {
    my ($self, %args) = @_;
    $args{qinu} = $self;

    my $http; 
    if (!defined($self->{http}) || !$self->{http}) {
        require Qinu::HTTP;

        $http = Qinu::HTTP->new(%args);
        $self->{http} = $http;
    }
    else {
        $http = $self->{http};
    }
    return $http;
}

sub html {
    my ($self, %args) = @_;
    $args{qinu} = $self;

    my $html; 
    if (!defined($self->{html}) || !$self->{html}) {
        require Qinu::HTML;

        $html = Qinu::HTML->new(%args);
        $self->{html} = $html;
    }
    else {
        $html = $self->{html};
    }

    return $html;
}

sub encode {
    my ($self, %args) = @_;
    $args{qinu} = $self;

    my $encode; 
    if (!defined($self->{encode}) || !$self->{encode}) {
        require Qinu::Encode;

        $encode = Qinu::Encode->new(%args);
        $self->{encode} = $encode;
    }
    else {
        $encode = $self->{encode};
    }
    return $encode;
}

sub mobile {
    my ($self, %args) = @_;
    $args{qinu} = $self;

    my $mobile;
    if (!defined($self->{mobile}) || !$self->{mobile}) {
        require Qinu::Mobile;

        $mobile = Qinu::Mobile->new(%args);
        $self->{mobile} = $mobile;
    }
    else {
        $mobile = $self->{mobile};
    }
    return $mobile;
}

sub app {
    my ($self, %args) = @_;

    $args{qinu} = $self;

    if (defined $self->conf->{app}) {
        $args{app} = $self->conf->{app};
    }
    else {
        $args{app} = [];
    }

    if (!defined($self->{app}) || !$self->{app}) {
        require Qinu::App;

        Qinu::App->new(%args);
    }

    return $self->{app};
}

sub aggregate {
    my ($self, %args) = @_;

    $args{qinu} = $self;

    my $aggregate;
    if (!defined($self->{aggregate}) || !$self->{aggregate}) {
        require Qinu::Aggregate;

        $aggregate = Qinu::Aggregate->new(%args);
        $self->{aggregate} = $aggregate;
    }
    else {
        $aggregate = $self->{aggregate};
    }
    return $aggregate;
}

sub crypt {
    my ($self, %args) = @_;

    $args{qinu} = $self;

    my $crypt;
    if (!defined($self->{crypt}) || !$self->{crypt}) {
        require Qinu::Crypt;

        $crypt = Qinu::Crypt->new(%args);
        $self->{crypt} = $crypt;
    }
    else {
        $crypt = $self->{crypt};
    }
    return $crypt;
}

sub validate {
    my ($self, %args) = @_;

    $args{qinu} = $self;

    my $validate;
    if (!defined($self->{validate}) || !$self->{validate}) {
        require Qinu::Validate;

        $args{values} = $self->params;
        $validate = Qinu::Validate->new(%args);
        $self->{validate} = $validate;
    }
    else {
        $validate = $self->{validate};
    }
    return $validate;
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

    if (!defined($self->conf->{cli}) || $self->conf->{cli} != 1) {
        require Controller;

        my @pairs_tmp = @pairs;
        my $action_name = '';
        while (my $word = shift @pairs_tmp) {
            if ($action_name ne '') {
                $action_name .= '_';
            }
            $action_name .= $word;
            my $method_name = 'Controller::' . $action_name;
            if (defined *${method_name}) {
                $self->{action_name} = $action_name;
                @pairs = @pairs_tmp;

                last;
            }
	}
    }

    if (@pairs && (!$self->{action_name} || $self->{action_name} eq '')) {
        $self->{action_name} = shift @pairs;
    }

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
