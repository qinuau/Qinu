package Qinu::MIME::Lite::SMTP;

#use strict;
use base Qinu::Net::SMTP;

# some of the below is borrowed from Data::Dumper
my %esc = ("\a" => "\\a",
            "\b" => "\\b",
            "\t" => "\\t",
            "\n" => "\\n",
            "\f" => "\\f",
            "\r" => "\\r",
            "\e" => "\\e",
);

sub _hexify {
    local $_ = shift;
    my @split = m/(.{1,16})/gs;
    foreach my $split (@split) {
        (my $txt = $split ) =~ s/([\a\b\t\n\f\r\e])/$esc{$1}/sg;
        $split =~ s/(.)/sprintf("%02X ",ord($1))/sge;
        print STDERR "M::L >>> $split : $txt\n";
    }
}

sub print {
    my $smtp = shift;
    $MIME::Lite::DEBUG and _hexify(join("", @_));
    $smtp->datasend(@_)
      or Carp::croak( "Net::CMD (Net::SMTP) DATASEND command failed.\n"
                      . "Last server message was:"
                      . $smtp->message
                      . "This probably represents a problem with newline encoding " );
}

1;
