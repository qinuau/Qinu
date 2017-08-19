package Qinu::Authentication::OAuth::Twitter;

use strict;
use warnings;

use CGI::Lite;
use Data::Dumper;
use Digest::HMAC_SHA1;
use Digest::MD5;
use LWP::UserAgent;
use MIME::Base64;
use Net::Twitter::Lite;
use Net::Twitter::Lite::WithAPIv1_1;

use base qw(Class::Accessor::Fast);
__PACKAGE__->mk_accessors(qw(qinu));

sub new {
    my ($self, %args) = @_;

    my $qinu = $args{qinu};

    my $twitter_oauth_keys = {};
    if (defined $args{twitter_oauth_keys} && $args{twitter_oauth_keys}) {
        $twitter_oauth_keys = $args{twitter_oauth_keys};
    }

    my $attr = {
        qinu => $qinu,
        oauth_consumer_key => $twitter_oauth_keys->{consumer_key},
        oauth_signature_method => 'HMAC-SHA1',
        oauth_timestamp => time(),
        oauth_nonce => Digest::MD5::md5_hex(time()),
        oauth_version => '1.0',
        #oauth_callback => $twitter_oauth_keys->{callback},
        consumer_secret => $twitter_oauth_keys->{consumer_secret},
        url_request_token => 'https://twitter.com/oauth/request_token',
        url_authorize => 'https://twitter.com/oauth/authorize',
        url_access_token => 'https://twitter.com/oauth/access_token',
    };

    bless $attr, $self;
}

sub get_signature {
    my ($self, %args) = @_;    

    if (!defined $args{mode}) {
        return '';
    }

    my $arg;
    my $arg_tmp;

    my %params = %$self;

    foreach my $key (sort keys %params) {
        if ($key !~ /^oauth_/) {
            next;
        }
        $arg_tmp .= $key . '=' . CGI::Lite::url_encode($params{$key}) . '&';
        $arg = $arg_tmp;
    }
    $arg = substr($arg, 0, -1);
    $arg_tmp = substr($arg_tmp, 0, -1);
    $arg = CGI::Lite::url_encode($arg);
    
    my $message = 'GET&';
    if ($args{mode} eq 'request_token') {
        $message .= CGI::Lite::url_encode($self->{url_request_token});
    }
    elsif ($args{mode} eq 'access_token') {
        $message .= CGI::Lite::url_encode($self->{url_access_token});
    }
    $message .= '&' . $arg;

    my $digest;
    if ($args{mode} eq 'request_token') {
        $digest = new Digest::HMAC_SHA1($params{consumer_secret} . '&');
    }
    elsif ($args{mode} eq 'access_token') {
        $digest = new Digest::HMAC_SHA1($params{consumer_secret} . '&' . $self->{consumer_secret});
    }
    $digest->add($message);
    my $signature = MIME::Base64::encode($digest->digest);
    $signature = CGI::Lite::url_encode($signature);

    return $arg_tmp . '&oauth_signature=' . $signature;
}

sub get_request_token {
    my ($self, %args) = @_;

    my $request_args = $self->get_signature(mode => 'request_token');
    $self->get_token_base(mode => 'request_token', request_args => $request_args);
}

sub get_access_token {
    my ($self, %args) = @_;

    my $request_args = $self->get_signature(mode => 'access_token');
    my $response_value = $self->get_token_base(mode => 'access_token', request_args => $request_args);

    return $response_value;
}

sub get_token_base {
    my ($self, %args) = @_;

    my $request_args = $args{request_args};

    my $ua = LWP::UserAgent->new();

    my $request_url;
    if ($args{mode} eq 'request_token') {
        $request_url = $self->{url_request_token};
    }
    elsif ($args{mode} eq 'access_token') {
        $request_url = $self->{url_access_token};
    }
    $request_url .= '?' . $request_args;

    my $response = $ua->get($request_url);
    my $response_value = $response->decoded_content();
    my @values = split '&', $response_value;
    my %values;
    foreach my $each (@values) {
        my ($key, $value) = split '=', $each;
        $self->{$key} = $value;
    }

    return $response_value;
}

sub request_authorize {
    my ($self, %args) = @_;

    print "Location: " . $self->{url_authorize} . '?oauth_token=' . $self->{oauth_token} . "\n\n";
}

sub is_authorized {
    my ($self, %args) = @_;

    my $keys = [
        'consumer_key',
        'consumer_secret',
        'twitter_oauth_token',
        'twitter_oauth_token_secret',
    ];

    if (!$self->qinu->util->check_args_defined_and_null(keys => $keys, values => \%args)) {
        return;
    }

    my $consumer_key = $args{consumer_key};
    my $consumer_secret = $args{consumer_secret};
    my $twitter_oauth_token = $args{twitter_oauth_token};
    my $twitter_oauth_token_secret = $args{twitter_oauth_token_secret};

    my $t = Net::Twitter::Lite::WithAPIv1_1->new(
        consumer_key => $consumer_key,
        consumer_secret => $consumer_secret,
        access_token => $twitter_oauth_token,
        access_token_secret => $twitter_oauth_token_secret,
        legacy_lists_api => 0,
        ssl => 1,
    );

    eval { $t->friends };
    if ($@) {
        return;
    }
    else {
        return 1;
    }
}

1;
