package Qinu::Net::SMTP;

use base Net::SMTP;

use vars qw($VERSION @ISA);
use Socket 1.3;
use Carp;
use IO::Socket;
use Net::Cmd;
use Net::Config;

use strict;
use warnings;

sub auth {
  my ($self, $username, $password, $authtype) = @_;

  eval {
    require MIME::Base64;
    require Authen::SASL;
  } or $self->set_status(500, ["Need MIME::Base64 and Authen::SASL todo auth"]), return 0;

  my $mechanisms;
  if ( $authtype ) {
      $mechanisms = $authtype;
  }
  else {
    $mechanisms = $self->supports('AUTH', 500, ["Command unknown: 'AUTH'"]);
    return unless defined $mechanisms;
  }

  my $sasl;

  if (ref($username) and UNIVERSAL::isa($username, 'Authen::SASL')) {
    $sasl = $username;
    $sasl->mechanism($mechanisms);
  }
  else {
    die "auth(username, password)" if not length $username;
    $sasl = Authen::SASL->new(
      mechanism => $mechanisms,
      callback  => {
        user     => $username,
        pass     => $password,
        authname => $username,
      }
    );
  }

  # We should probably allow the user to pass the host, but I don't
  # currently know and SASL mechanisms that are used by smtp that need it
  my $client = $sasl->client_new('smtp', ${*$self}{net_smtp_host}, 0);
  my $str    = $client->client_start;

  # We dont support sasl mechanisms that encrypt the socket traffic.
  # todo that we would really need to change the ISA hierarchy
  # so we dont inherit from IO::Socket, but instead hold it in an attribute
  my @cmd = ("AUTH", $client->mechanism);
  my $code;

  push @cmd, MIME::Base64::encode_base64($str, '')
    if defined $str and length $str;

  while (($code = $self->command(@cmd)->response()) == CMD_MORE) {
    @cmd = (
      MIME::Base64::encode_base64(
        $client->client_step(MIME::Base64::decode_base64(($self->message)[0])), ''
      )
    );
  }
  $code == CMD_OK;
}

1;
