package Qinu::SMTP;

use Data::Dumper;
use Encode qw(from_to);
use File::MMagic;
use MIME::Base64;
use Qinu::MIME::Lite;

sub new {
    my ($self, %attr) = @_;
    my $attr = {
        qinu => $attr{qinu},
    };
    bless $attr, $self;
}

sub send {
    my ($self, %attr) = @_;

    my %send_attr = (
        from       => '',
        from_name  => '',
        to         => '',
        to_name    => '',
        cc         => '',
        bcc        => '',
        charset    => '',
        subject    => '',
        type       => '',
        data       => '',
        encoding   => '',
        path       => '',
        add_header => '',
        authtype   => '',
        debug      => '',
        attach     => '',
        host       => '',
        port       => '',
        user       => '',
        password   => '',
        tls        => '',
        mailer     => '',
    );

    foreach my $each (keys %send_attr) {
        $send_attr{$each} = $attr{$each} ||= $self->{qinu}{smtp}{$each};
    }

    my $from_name_encoded;
    my $to_name_encoded;
    my $subject_encoded;
    if ($send_attr{from_name}) {
	from_to($send_attr{from_name}, 'UTF8', 'ISO-2022-JP');
	$from_name_encoded = '=?ISO-2022-JP?B?' . encode_base64($send_attr{from_name}, '') . '?=';
    }
    if ($send_attr{to_name}) {
        from_to($send_attr{to_name}, 'UTF8', 'ISO-2022-JP');
        $to_name_encoded = '=?ISO-2022-JP?B?' . encode_base64($send_attr{to_name}, '') . '?=';
    }

    my $from;
    if ($send_attr{from} && $send_attr{from_name}) {
        $from = '<' . $send_attr{from} . '>';
    }
    elsif ($send_attr{from}) {
        $from = $send_attr{from};
    }

    my $to;
    if ($send_attr{to} && $send_attr{to_name}) {
        $to = '<' . $send_attr{to} . '>';
    }
    elsif ($send_attr{to}) {
        $to = $send_attr{to};
    }

    if ($send_attr{subject}) {
        from_to($send_attr{subject}, 'UTF8', 'ISO-2022-JP');
        $subject_encoded = '=?ISO-2022-JP?B?' . encode_base64($send_attr{subject}, '') . '?=';
    }

    $send_attr{charset} ||= 'ISO-2022-JP';

    if ($send_attr{data} && $send_attr{charset} && $send_attr{charset} !~ /^utf-*8$/i) {
        from_to($send_attr{data}, 'UTF8', $send_attr{charset});
    }

    my $msg = Qinu::MIME::Lite->new(
        From     => $from_name_encoded . $from,
        To       => $to_name_encoded . $to,
        Cc       => $send_attr{cc},
        Bcc      => $send_attr{bcc},
        Subject  => $subject_encoded,
        Type     => $send_attr{type},
        Data     => $send_attr{data},
        Encoding => $send_attr{encoding},
        Path     => $send_attr{path},
    );

    $msg->attr(
        content-type.charset => $send_attr{charset},
    );

    if ($send_attr{attach}) {
        my $mm = File::MMagic->new();
        foreach my $each (@{$send_attr{attach}}) {
            my %param;
            my $has_type;
            foreach my $each_key (keys %$each) {
                if ($each_key eq 'Type' && $each->{Type}) {
                    $has_type = 1;
                }
                if ($each_key eq 'Data' && $each->{Data} ne '') {
                    if ($send_attr{charset} !~ /^utf-*8$/i) {
                        from_to($each->{Data}, 'UTF8', $send_attr{charset});
                    }
                }
                $param{$each_key} = $each->{$each_key};
            }
            # file type check 
            if (!$has_type) {
               my $filetype = $mm->checktype_filename($each->{Path}); 
               $param{Type} = $filetype;
            }
            $msg->attach(
                %param
            );
        }
    }

    # add header
    if ($send_attr{add_header}) {
        $msg->add(
            #X-Original-To => $to,
            #Recieved      => 'by hogehoge',
            #Delivered-To  => $to,
            %{$send_attr{add_header}} 
        );
    }

    my $mailer = $send_attr{mailer} ||= 'Mailer';
    $msg->replace(
        X-Mailer => $mailer,
    );

    if ($send_attr{tls} == 1) { 
        eval {
            $msg->send_by_smtp_tls(
                $send_attr{host},
                Port     => $send_attr{port},
                User     => $send_attr{user},
                Password => $send_attr{password},
            )
        };
    }
    else {
        $send_attr{host} .= $send_attr{port} ? ':' . $send_attr{port} : '';
        eval {
            $msg->send(
                'smtp',
                $send_attr{host},
                AuthUser => $send_attr{user},
                AuthPass => $send_attr{password},
                AuthType => $send_attr{authtype},
                Debug    => $send_attr{debug},
	    )
        };
    }

    return $msg;
}

1;
