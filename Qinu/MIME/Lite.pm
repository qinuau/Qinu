package Qinu::MIME::Lite;

use base qw(MIME::Lite);
use Qinu::MIME::Lite::SMTP;
use Qinu::Net::SMTP::TLS;

use Data::Dumper;

BEGIN {
    my $ATOM      = '[^ \000-\037()<>@,;:\134"\056\133\135]+';
    my $QSTR      = '".*?"';
    my $WORD      = '(?:' . $QSTR . '|' . $ATOM . ')';
    my $DOMAIN    = '(?:' . $ATOM . '(?:' . '\\.' . $ATOM . ')*' . ')';
    my $LOCALPART = '(?:' . $WORD . '(?:' . '\\.' . $WORD . ')*' . ')';
    my $ADDR      = '(?:' . $LOCALPART . '@' . $DOMAIN . ')';
    my $PHRASE    = '(?:' . $WORD . ')+';
    my $SEP       = "(?:^\\s*|\\s*,\\s*)"; ### before elems in a list

    sub my_extract_full_addrs {
        my $str = shift;
        return unless $str;
        my @addrs;
        $str =~ s/\s/ /g; ### collapse whitespace

        pos($str) = 0;
        while ($str !~ m{\G\s*\Z}gco) {
            ### print STDERR "TACKLING: ".substr($str, pos($str))."\n";
            if ($str =~ m{\G$SEP($PHRASE)\s*<\s*($ADDR)\s*>}gco) {
                push @addrs, "$1 <$2>";
            } elsif ($str =~ m{\G$SEP($ADDR)}gco or $str =~ m{\G$SEP($ATOM)}gco) {
                push @addrs, $1;
            } else {
                my $problem = substr($str, pos($str));
                die "can't extract address at <$problem> in <$str>\n";
            }
        }
        return wantarray ? @addrs : $addrs[0];
    }

    sub my_extract_only_addrs {
        my @ret = map { /<([^>]+)>/ ? $1 : $_ } my_extract_full_addrs(@_);
        return wantarray ? @ret : $ret[0];
    }
}

if (!$PARANOID and eval "require Mail::Address") {
    push @Uses, "A$Mail::Address::VERSION";
    eval q{
                sub extract_full_addrs {
                    my @ret=map { $_->format } Mail::Address->parse($_[0]);
                    return wantarray ? @ret : $ret[0]
                }
                sub extract_only_addrs {
                    my @ret=map { $_->address } Mail::Address->parse($_[0]);
                    return wantarray ? @ret : $ret[0]
                }
    };    ### q
} else {
    eval q{
        *extract_full_addrs=*my_extract_full_addrs;
        *extract_only_addrs=*my_extract_only_addrs;
    };    ### q
}    ### if

my @_mail_opts     = qw(Size Return Bits Transaction Envelope);
my @_recip_opts    = qw(SkipBad);
my @_net_smtp_opts = qw(Hello LocalAddr LocalPort Timeout
                         ExactAddresses Debug);

sub __opts {
    my $args=shift;
    return map { exists $args->{$_} ? ($_ => $args->{$_}) : () } @_;
}

sub send_by_smtp {
    require Qinu::Net::SMTP;
    my ($self,$hostname,%args)  = @_;
    # We may need the "From:" and "To:" headers to pass to the
    # SMTP mailer also.
    $self->{last_send_successful}=0;

    my @hdr_to = extract_only_addrs(scalar $self->get('To'));
    if ($AUTO_CC) {
        foreach my $field (qw(Cc Bcc)) {
            push @hdr_to, extract_only_addrs($_) for $self->get($field);
        }
    }
    Carp::croak "send_by_smtp: nobody to send to for host '$hostname'?!\n"
        unless @hdr_to;

    $args{To} ||= \@hdr_to;
    $args{From} ||= extract_only_addrs(scalar $self->get('Return-Path'));
    $args{From} ||= extract_only_addrs(scalar $self->get('From')) ;

    # Create SMTP client.
    # MIME::Lite::SMTP is just a wrapper giving a print method
    # to the SMTP object.

    my %opts = __opts(\%args, @_net_smtp_opts);
    my $smtp = Qinu::MIME::Lite::SMTP->new($hostname, %opts)
      or Carp::croak "SMTP Failed to connect to mail server: $!\n";

    # Possibly authenticate
    if (defined $args{AuthUser} and defined $args{AuthPass}
         and !$args{NoAuth})
    {
        if ($smtp->supports('AUTH',500,["Command unknown: 'AUTH'"])) {
            $smtp->auth($args{AuthUser}, $args{AuthPass}, $args{AuthType})
                or die "SMTP auth() command failed: $!\n"
                   . $smtp->message . "\n";
        } else {
            die "SMTP auth() command not supported on $hostname\n";
        }
    }

    # Send the mail command
    %opts = __opts(\%args, @_mail_opts);
    $smtp->mail($args{From}, %opts ? \%opts : ())
      or die "SMTP mail() command failed: $!\n"
             . $smtp->message . "\n";

    # Send the recipients command
    %opts = __opts(\%args, @_recip_opts);
    $smtp->recipient(@{ $args{To} }, %opts ? \%opts : ())
      or die "SMTP recipient() command failed: $!\n"
             . $smtp->message . "\n";

    # Send the data
    $smtp->data()
      or die "SMTP data() command failed: $!\n"
             . $smtp->message . "\n";
    $self->print_for_smtp($smtp);

    # Finish the mail
    $smtp->dataend()
      or Carp::croak "Net::CMD (Net::SMTP) DATAEND command failed.\n"
      . "Last server message was:"
      . $smtp->message
      . "This probably represents a problem with newline encoding ";

    # terminate the session
    $smtp->quit;

    return $self->{last_send_successful} = 1;
}

sub send_by_smtp_tls {
    my @_mail_opts     = qw(Size Return Bits Transaction Envelope);
    my @_recip_opts    = qw(SkipBad);
    my @_net_smtp_opts = qw(Hello LocalAddr LocalPort Timeout ExactAddresses Debug Port User Password);
    # internal:  qw(NoAuth AuthUser AuthPass To From Host);

    my ($self,$hostname,%args)  = @_;
    $self->{last_send_successful}=0;

    my @hdr_to = MIME::Lite::extract_only_addrs(scalar $self->get('To'));
    if ($AUTO_CC) {
        foreach my $field (qw(Cc Bcc)) {
            my $value = MIME::Lite::get($field);
            push @hdr_to, MIME::Lite::extract_only_addrs($value)
                if defined($value);
        }
    }
    Carp::croak "send_by_smtp: nobody to send to for host '$hostname'?!\n"
      unless @hdr_to;

    $args{To} ||= \@hdr_to;
    $args{From} ||= MIME::Lite::extract_only_addrs(scalar $self->get('Return-Path'));
    $args{From} ||= MIME::Lite::extract_only_addrs(scalar $self->get('From')) ;

    # Create SMTP client.
    my %opts = MIME::Lite::__opts(\%args, @_net_smtp_opts);
    my $smtp = Qinu::Net::SMTP::TLS->new($hostname, %opts)
        or Carp::croak "SMTP Failed to connect to mail server: $!\n";

    # Send the mail command
    %opts = MIME::Lite::__opts(\%args, @_mail_opts);
    $smtp->mail($args{From}, %opts ? \%opts : ());

    # Send the recipients command
    %opts = MIME::Lite::__opts(\%args, @_recip_opts);
    $smtp->recipient(@{ $args{To} }, %opts ? \%opts : ());

    # Send the data
    $smtp->data();
    $self->print_for_smtp($smtp);

    # Finish the mail
    $smtp->dataend();

    # terminate the session
    $smtp->quit;

    return $self->{last_send_successful} = 1;

    sub Qinu::Net::SMTP::TLS::print {
        my $smtp = shift;
        $MIME::Lite::DEBUG and Qinu::Net::SMTP::TLS::_hexify(join("", @_));
        $smtp->datasend(@_);
    }
}

1;
