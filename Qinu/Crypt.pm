package Qinu::Crypt;

#use Crypt::CBC;
use Crypt::ECB;
use Digest::MD5;

sub new {
    my ($self, %args) = @_;

    my $attr = {

    };

    bless $attr, $self;
}

sub encrypt_reversible {
    my ($self, %args) = @_;

    my $str = defined $args{str} ? $args{str} : return;
    my $key = defined $args{key} ? $args{key} : return;

#    my $cbc = Crypt::CBC->new({
#        key => $key,
#        #cipher => 'Blowfish',
#        cipher => 'Crypt::OpenSSL::AES',
#        padding =>'null'
#    });

#=begin
    my $ecb = Crypt::ECB->new();
    $ecb->cipher('Crypt::OpenSSL::AES');
    $ecb->key(substr(Digest::MD5::md5_hex($key), 0, 16));
    $ecb->padding(PADDING_AUTO);

    my $crypted = '';
    eval { $crypted = $ecb->encrypt_hex($str) };

    if ($@) {
        $crypted = $str;
    }
    else {
        #$crypted = MIME::Base64::encode_base64($crypted);
    }
#=cut

#my $crypted = $str;

    return $crypted;
}

sub decrypt_reversible {
    my ($self, %args) = @_;

    my $str = defined $args{str} ? $args{str} : return;
    my $key = defined $args{key} ? $args{key} : return;

    #$str = MIME::Base64::decode_base64($str);

#    my $ecb = Crypt::CBC->new({
#        key => $key,
#        #cipher => 'Blowfish',
#        cipher => 'Crypt::OpenSSL::AES',
#        padding =>'null'
#    });

#=begin
    my $ecb = Crypt::ECB->new();
    $ecb->cipher('Crypt::OpenSSL::AES');
    $ecb->key(substr(Digest::MD5::md5_hex($key), 0, 16));
    $ecb->padding(PADDING_AUTO);

    my $decrypted = '';
    eval { $decrypted = $ecb->decrypt_hex($str) };

    if ($@) {
        $decrypted = $str;
    }
#=cut

#my $decrypted = $str;

    return $decrypted;
}

1;
