package Qinu::Validate;

use Data::Dumper;
use Encode;
use Encode::Guess;
use base qw(Class::Accessor::Fast);

__PACKAGE__->mk_accessors(qw(qinu error_f));

sub new {
    my ($self, %args) = @_;

    my $qinu = defined $args{qinu} ? $args{qinu} : '';
    my $values = defined $args{values} ? $args{values} : {};

    my $attr = {
        qinu => $qinu,
        error_f => 0,
        values => $values,
        validate_types => [
            'exists',
            'exist_some_values',
            'exist_same_value',
            'email',
            'values',
            'halfwidth_alphanumeric',
            'wide_character',
            'hiragana',
            'katakana',
            'regex',
            'password',
            'length_max',
            'length_min',
            'one_and_all',
            'date',
            'accept_filetype',
            'accept_filesize',
            'accept_image_xy',
            'num',
            'code',
        ],
    };

    foreach my $validate_type ($attr->{validate_types}) {
        my $keys_and_errmsg = 'keys_and_errmsg_' . $validate_type;
        $attr->{$keys_and_errmsg} = defined $args{$keys_and_errmsg} && ref $args{$keys_and_errmsg} eq 'ARRAY' ? $args{$keys_and_errmsg} : ();
    }

    bless $attr, $self;
}

sub set_form {
    my ($self, %args) = @_;

    if (defined $args{form}) {
        $self->{form} = $args{form};

        foreach my $key_form (keys %{$self->{form}->{forms}}) {
            if (defined $self->{form}->{forms}->{$key_form}->{validate}) {
                foreach my $validate_type (@{$self->{validate_types}}) {
                    if (defined $self->{form}->{forms}->{$key_form}->{validate}->{$validate_type}) {
                        my $keys_and_errmsg = 'keys_and_errmsg_' . $validate_type;
                        $self->{$keys_and_errmsg}->{$key_form} = $self->{form}->{forms}->{$key_form}->{validate}->{$validate_type};
                    }
                }
            }
        }
    }
}

sub check_exists {
    my ($self, %args) = @_;

    my $keys_and_messages = defined $args{keys_and_messages} ? $args{keys_and_messages} : {};
    $keys_and_messages = defined $self->{keys_and_errmsg_exists} ? $self->{keys_and_errmsg_exists} : $keys_and_messages;

    my $data = defined $args{data} ? $args{data} : {};
    $data = defined $self->{values} && scalar keys %{$self->{values}} > 0 ? $self->{values} : $data;

    foreach my $key (keys %$keys_and_messages) {
        if (!defined $data->{$key} || $data->{$key} eq '') {
            $self->{error_message}->{'error_' . $key} = $keys_and_messages->{$key};
            $self->{error_messages}->{exists}->{'error_' . $key} = $keys_and_messages->{$key}->{error_message};
            $self->error_f(1);
        }
    }
    return;
}

sub check_exist_some_values {
    my ($self, %args) = @_;

    if (defined $self->{keys_and_errmsg_exist_some_values}) {
        foreach my $key (keys %{$self->{keys_and_errmsg_exist_some_values}}) {
            my $each = $self->{keys_and_errmsg_exist_some_values}->{$key};
            my $exist_f = 0;
            foreach my $data_key (@{$each->{keys}}) {
                if (defined $self->{values}->{$data_key} && $self->{values}->{$data_key} ne '') {
                    $exist_f = 1;
                    last;
                }
            }
            if (!$exist_f) {
                $self->error_f(1);
                $self->{error_message}->{$key} = $each->{error_message};
                $self->{error_messages}->{exist_some_values}->{$key} = $each->{error_message};
            }
        }
    }
}

sub check_exist_same_value {
    my ($self, %args) = @_;

    if (defined $self->{keys_and_errmsg_exist_same_value}) {
        foreach my $key (keys %{$self->{keys_and_errmsg_exist_same_value}}) {
            if (defined $self->{values}->{$key} && $self->{values}->{$key} ne '') {
                foreach my $data_key (@{$self->{keys_and_errmsg_exist_same_value}->{$key}->{keys}}) {
                    if (
                        defined $self->{values}->{$data_key} && $self->{values}->{$data_key} ne '' &&
                        $self->{values}->{$key} eq $self->{values}->{$data_key}
                    ) {
                        $self->error_f(1);
                        $serl->{error_message}->{$key} = $self->{keys_and_errmsg_exist_same_value}->{$key}->{error_message};
                        $serl->{error_messages}->{exist_same_value}->{$key} = $self->{keys_and_errmsg_exist_same_value}->{$key}->{error_message};

                        last;
                    }
                }
            }
        }
    }
}

sub check_email {
    my ($self, %args) = @_;

    foreach my $key (keys %{$self->{keys_and_errmsg_email}}) {
        if (defined $self->{values}->{$key} && $self->{values}->{$key} ne '' && !$self->check_mail_address($self->{values}->{$key})) {
            $self->error_f(1);
            if (ref $self->{keys_and_errmsg_email}->{$key} eq 'ARRAY') {
                $self->{error_message}->{$key} = $self->{keys_and_errmsg_email}->{$key}->{error_message};
                $self->{error_messages}->{email}->{$key} = $self->{keys_and_errmsg_email}->{$key}->{error_message};
            }
            else {
                $self->{error_message}->{$key} = $self->{keys_and_errmsg_email}->{$key};
                $self->{error_messages}->{email}->{$key} = $self->{keys_and_errmsg_email}->{$key};
            }
        }
    }
}

sub check_email {
    my ($self, %args) = @_;

    my $mail = defined $args{mail} ? $args{mail} : '';

    my $pattern = '/^(?:[^(\040)<>@,;:".\\\\\[\]\000-\037\x80-\xff]+(?![^(\040)<>@,;:".\\\\\[\]\000-\037\x80-\xff])|"[^\\\\\x80-\xff\n\015"]*(?:\\\\[^\x80-\xff][^\\\\\x80-\xff\n\015"]*)*")(?:\.(?:[^(\040)<>@,;:".\\\\\[\]\000-\037\x80-\xff]+(?![^(\040)<>@,;:".\\\\\[\]\000-\037\x80-\xff])|"[^\\\\\x80-\xff\n\015"]*(?:\\\\[^\x80-\xff][^\\\\\x80-\xff\n\015"]*)*"))*@(?:[^(\040)<>@,;:".\\\\\[\]\000-\037\x80-\xff]+(?![^(\040)<>@,;:".\\\\\[\]\000-\037\x80-\xff])|\[(?:[^\\\\\x80-\xff\n\015\[\]]|\\\\[^\x80-\xff])*\])(?:\.(?:[^(\040)<>@,;:".\\\\\[\]\000-\037\x80-\xff]+(?![^(\040)<>@,;:".\\\\\[\]\000-\037\x80-\xff])|\[(?:[^\\\\\x80-\xff\n\015\[\]]|\\\\[^\x80-\xff])*\]))*$/';

    if ($mail =~ /${pattern}/) {
        return 1;
    }
    else {
        return 0;
    }
}

sub check_values {
    my ($self, %args) = @_;

    foreach my $key (keys %{$self->{keys_and_errmsg_values}}) {
        if (defined $self->{values}->{$key} && $self->{values}->{$key} ne '') {
            if (ref $self->{keys_and_errmsg_values}->{$key}->{value} eq 'ARRAY') {
                my $data_value = $self->{values}->{$key};
                if (!grep { /^${data_value}$/ } @{$self->{keys_and_errmsg_values}->{$key}->{value}}) {
                    $self->error_f(1);
                    $self->{error_message}->{$key} = $self->{keys_and_errmsg_values}->{$key}->{error_message};
                    $self->{error_messages}->{values}->{$key} = $self->{keys_and_errmsg_values}->{$key}->{error_message};
                }
            }
            else {
                if ($self->{keys_and_errmsg_values}->{$key}->{value} ne $self->{values}->{$key}) {
                    $self->error_f(1);
                    $self->{error_message}->{$key} = $self->{keys_and_errmsg_values}->{$key}->{error_message};
                    $self->{error_messages}->{values}->{$key} = $self->{keys_and_errmsg_values}->{$key}->{error_message};
                }
            }
        }
    }
}

sub check_one_and_all {
    my ($self, %args) = @_;

    foreach my $key (keys %{$self->{keys_and_errmsg_one_and_all}}) {
        if (defined $self->{keys_and_errmsg_one_and_all}->{$key}->{keys} && $self->{keys_and_errmsg_one_and_all}->{$key}->{keys}) {
            my $check_exists = 0;
            my $check_nothing = 0;
            foreach my $target_key (@{$self->{keys_and_errmsg_one_and_all}->{$key}->{keys}}) {
                if (defined $self->{values}->{$target_key} && $self->{values}->{$target_key} ne '') {
                    $check_exists = 1;
                }
                if (!defined $self->{values}->{$target_key} || $self->{values}->{$target_key} eq '') {
                    $check_nothing = 1;
                }
            }
            if ($check_exists && $check_nothing) {
                $self->error_f(1);
                foreach my $target_key (@{$self->{keys_and_errmsg_one_and_all}->{$key}->{keys}}) {
                    if (!defined $self->{values}->{$target_key} || $self->{values}->{$target_key} eq '') {
                        $self->{error_message}->{$key} = $self->{keys_and_errmsg_one_and_all}->{$key}->{error_message};
                        $self->{error_messages}->{one_and_all}->{$key} = $self->{keys_and_errmsg_one_and_all}->{$key}->{error_message};
                    }
                }
            }
        }
    }
}

sub check_halfwidth_alphanumeric {
    my ($self, %args) = @_;

    if (defined $self->{keys_and_errmsg_halfwidth_alphanumeric}) {
        foreach my $key (keys %{$self->{keys_and_errmsg_halfwidth_alphanumeric}}) {
            if (defined $self->{values}->{$key} && $self->{values}->{$key} !~ /^[a-zA-Z0-9]*$/) {
                $self->error_f(1);
                $self->{error_message}->{$key} = $self->{keys_and_errmsg_halfwidth_alphanumeric}->{$key}->{error_message};
                $self->{error_message}->{halfwidth_alphanumeric}->{$key} = $self->{keys_and_errmsg_halfwidth_alphanumeric}->{$key}->{error_message};
            }
        }
    }
}

sub check_wide_character {
    my ($self, %args) = @_;

    if (defined $self->{keys_and_errmsg_wide_character}) {
        foreach my $key (keys %{$self->{keys_and_errmsg_wide_character}}) {
            if (defined $self->{values}->{$key} && $self->{values}->{$key} ne '') {
                my $value_tmp = $self->{values}->{$key};
                my $encoding_src = '';
                eval { $encoding_src = guess_encoding($value_tmp, qw/euc-jp shiftjis 7bit-jis/)->name };

                if ($encoding_src eq 'ascii') {
                    $self->error_f(1);
                    $self->{error_message}->{$key} = $self->{keys_and_errmsg_wide_character}->{$key}->{error_message};
                    $self->{error_messages}->{wide_character}->{$key} = $self->{keys_and_errmsg_wide_character}->{$key}->{error_message};

                    next;
                }

                if ($encoding_src && $encoding_src ne 'utf8') {
                    eval { $value_tmp = from_to($value_tmp, $encoding_src, 'utf8') };
                }

                if ($value_tmp !~ /^(?:(?:[\xc2-\xdf]+|[\xe0-\xef]+|[\xf0-\xf7]+|[\xf8-\xfb]+|[\xfc-\xfd]+)(?:[\x80-\xbf]+|[\xa0-\xef]+|[\x90-\xbf]+|[\x88-\xbf]+|[\x84-\xbf]+)[\x80-\xbf]*[\x80-\xbf]*[\x80-\xbf]*)+$/ || $value_utf8 =~ /(?:\xEF\xBD[\xA1-\xBF]|\xEF\xBE[\x80-\x9F]|\s)+/) {
                    $self->error_f(1);
                    $self->{error_message}->{$key} = $self->{keys_and_errmsg_wide_character}->{$key}->{error_message};
                    $self->{error_messages}->{wide_character}->{$key} = $self->{keys_and_errmsg_wide_character}->{$key}->{error_message};
                }
            }
        }
    }
}

sub check_hiragana {
    my ($self, %args) = @_;

    if (defined $self->{keys_and_errmsg_hiragana}) {
        foreach my $key (keys %{$self->{keys_and_errmsg_hiragana}}) {
            if (defined $self->{values}->{$key} && $self->{values}->{$key} ne '') {
                my $value_tmp = $self->{values}->{$key};
                my $encoding_src = '';
                eval { $encoding_src = guess_encoding($value_tmp, qw/euc-jp shiftjis 7bit-jis/)->name };

                if ($encoding_src eq 'ascii') {
                    $self->error_f(1);
                    $self->{error_message}->{$key} = $self->{keys_and_errmsg_hiragana}->{$key}->{error_message};
                    $self->{error_messages}->{hiragana}->{$key} = $self->{keys_and_errmsg_hiragana}->{$key}->{error_message};

                    next;
                }

                if ($encoding_src && $encoding_src ne 'utf8') {
                    eval { $value_tmp = from_to($value_tmp, $encoding_src, 'utf8') };
                }

                if ($value_tmp !~ /^(?:\xE3\x81[\x81-\xBF]|\xE3\x82[\x80-\x93]|ー)+$/) {
                    $self->error_f(1);
                    $self->{error_message}->{$key} = $self->{keys_and_errmsg_hiragana}->{$key}->{error_message};
                    $self->{error_messages}->{hiragana}->{$key} = $self->{keys_and_errmsg_hiragana}->{$key}->{error_message};
                }
            }
        }
    }
}

sub check_katakana {
    my ($self, %args) = @_;

    if (defined $self->{keys_and_errmsg_katakana}) {
        foreach my $key (keys %{$self->{keys_and_errmsg_katakana}}) {
            if (defined $self->{values}->{$key} && $self->{values}->{$key} ne '') {
                my $value_tmp = $self->{values}->{$key};
                my $encoding_src = '';
                eval { $encoding_src = guess_encoding($value_tmp, qw/euc-jp shiftjis 7bit-jis/)->name };

                if ($encoding_src eq 'ascii') {
                    $self->error_f(1);
                    $self->{error_message}->{$key} = $self->{keys_and_errmsg_hiragana}->{$key}->{error_message};
                    $self->{error_messages}->{katakana}->{$key} = $self->{keys_and_errmsg_hiragana}->{$key}->{error_message};

                    next;
                }

                if ($encoding_src && $encoding_src ne 'utf8') {
                    eval { $value_tmp = from_to($value_tmp, $encoding_src, 'utf8') };
                }

                if ($value_tmp !~ /^(?:\xE3\x82[\xA1-\xBF]|\xE3\x83[\x80-\xB6]|ー)+$/) {
                    $self->error_f(1);
                    $self->{error_message}->{$key} = $self->{keys_and_errmsg_hiragana}->{$key}->{error_message};
                    $self->{error_messages}->{katakana}->{$key} = $self->{keys_and_errmsg_hiragana}->{$key}->{error_message};
                }
            }
        }
    }    
}

sub check_regex {
    my ($self, %args) = @_;

    if (defined $self->{keys_and_errmsg_regex}) {
        foreach my $key (keys %{$self->{keys_and_errmsg_regex}}) {
            if (defined $self->{values}->{$key} && $self->{values}->{$key} ne '' && defined $self->{keys_and_errmsg_regex}->{$key}->{pattern}) {
                my $pattern = $self->{keys_and_errmsg_regex}->{$key}->{pattern};
                if ($self->{values}->{$key} !~ /${pattern}/) {
                    $self->error_f(1);
                    $self->{error_message}->{$key} = $self->{keys_and_errmsg_regex}->{$key}->{error_message};
                    $self->{error_messages}->{regex}->{$key} = $self->{keys_and_errmsg_regex}->{$key}->{error_message};
                }
            }
        }
    }
}

sub check_password {
    my ($self, %args) = @_;

    if (defined $self->{keys_and_errmsg_password}) {
        foreach my $key (keys %{$self->{keys_and_errmsg_password}}) {
            if (defined $self->{values}->{$key} && $self->{values}->{$key} ne '') {
                if ($self->{values}->{$key} !~ /^[a-zA-Z0-9!\"#$%&'()=~\|`{+*}<>?_\-\^@\[;:\],.\/\\\\]*$/) {
                    $self->error_f(1);
                    $self->{error_message}->{$key} = $self->{keys_and_errmsg_password}->{$key}->{error_message};
                    $self->{error_messages}->{password}->{$key} = $self->{keys_and_errmsg_password}->{$key}->{error_message};
                }
            }
        }
    }
}

sub check_length_max {
    my ($self, %args) = @_;

    if (defined $self->{keys_and_errmsg_length_max}) {
        foreach my $key (keys %{$self->{keys_and_errmsg_length_max}}) {
            if (defined $self->{values}->{$key} && $self->{values}->{$key} ne '' && defined $self->{keys_and_errmsg_length_max}->{$key}->{length}) {
                my $value_tmp = $self->{values}->{$key};
                $value_tmp = decode_utf8($value_tmp);
                if (length($value_tmp) > $self->{keys_and_errmsg_length_max}->{$key}->{length}) {
                    $self->error_f(1);
                    $self->{error_message}->{$key} = $self->{keys_and_errmsg_length_max}->{$key}->{error_message};
                    $self->{error_messages}->{length_max}->{$key} = $self->{keys_and_errmsg_length_max}->{$key}->{error_message};
                }
            }
        }
    }
}

sub check_length_min {
    my ($self, %args) = @_;

    if (defined $self->{keys_and_errmsg_length_min}) {
        foreach my $key (keys %{$self->{keys_and_errmsg_length_min}}) {
            if (defined $self->{values}->{$key} && $self->{values}->{$key} ne '' && defined $self->{keys_and_errmsg_length_min}->{$key}->{length}) {
                my $value_tmp = $self->{values}->{$key};
                $value_tmp = decode_utf8($value_tmp);
                if (length($value_tmp) < $self->{keys_and_errmsg_length_min}->{$key}->{length}) {
                    $self->error_f(1);
                    $self->{error_message}->{$key} = $self->{keys_and_errmsg_length_min}->{$key}->{error_message};
                    $self->{error_messages}->{length_min}->{$key} = $self->{keys_and_errmsg_length_min}->{$key}->{error_message};
                }
            }
        }
    }
}

sub check_num {
    my ($self, %args) = @_;

    if (defined $self->{keys_and_errmsg_num}) {
        foreach my $key (keys %{$self->{keys_and_errmsg_num}}) {
            if (defined $self->{values}->{$key} && $self->{values}->{$key} ne '') {
                if ($self->{values}->{$key} !~ /^\d+$/) {
                    $self->error_f(1);
                    $self->{error_message}->{$key} = $self->{keys_and_errmsg_num}->{$key}->{error_message};
                    $self->{error_messages}->{num}->{$key} = $self->{keys_and_errmsg_num}->{$key}->{error_message};
                }
            }
        }
    }
}

sub check_code {
    my ($self, %args) = @_;

    if (defined $self->{keys_and_errmsg_code}) {
        foreach my $key (keys %{$self->{keys_and_errmsg_code}}) {
            if (defined $self->{values}->{$key} && $self->{values}->{$key} ne '') {
                if (&{$self->{keys_and_errmsg_code}->{$key}->{code}}(value => $self->{values}->{$key})) {
                    $self->error_f(1);
                    $self->{error_message}->{$key} = $self->{keys_and_errmsg_code}->{$key}->{error_message};
                    $self->{error_messages}->{code}->{$key} = $self->{keys_and_errmsg_code}->{$key}->{error_message};
                }
            }
        }
    }
}

sub check_format_datetime {
    my ($self, %args) = @_;

    my $keys = [
        'datetime',
    ];
    if ($self->qinu->util->check_args_defined_and_null(keys => $keys, values => \%args)) {
        return;
    }

    my $datetime = $args{datetime};

    if ($datetime !~ /^\d{4}-\d{2}-\d{2}\s\d{2}:\d{2}:\d{2}$/) {
        $self->error_f(1);
    }

    return;
}

sub check_format_date {
    my ($self, %args) = @_;

    my $keys = [
        'date',
    ];
    if ($self->qinu->util->check_args_defined_and_null(keys => $keys, values => \%args)) {
        return;
    }

    my $date = $args{date};

    if ($date !~ /^\d{4}-\d{2}-\d{2}$/) {
        $self->error_f(1);
    }

    return;
}

sub check_format_time {
    my ($self, %args) = @_;

    my $keys = [
        'time',
    ];
    if ($self->qinu->util->check_args_defined_and_null(keys => $keys, values => \%args)) {
        return;
    }

    my $time = $args{time};

    if ($date !~ /^\d{2}:\d{2}:\d{2}$/) {
        $self->error_f(1);
    }

    return;
}

sub check_csrf {
    my ($self, %args) = @_;
}

sub form_validate {
    my ($self, %args) = @_;

    $self->check_csrf();

    foreach my $validate_type (@{$self->{validate_types}}) {
        if ($validate_type eq 'exists') {
            next;
        }
        my $validate_method = 'check_' . $validate_type;
        my $eval_method = '$self->' . $validate_method . '()';
        eval $eval_method;
    }

    $self->check_exists();
}

1;
