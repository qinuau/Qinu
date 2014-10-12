package Qinu::Form;

use Data::Dumper;
use base qw(Class::Accessor::Fast);

__PACKAGE__->mk_accessors(qw(qinu));

sub new {
    my ($self, %args) = @_;

    my $qinu = defined $args{qinu} ? $args{qinu} : '';

    my $attr = {
        qinu => $qinu,
    };

    my $self_ref = bless $attr, $self;

    if (defined $args{forms} && ref $args{forms} eq 'ARRAY') {
        $attr->{forms} = $args{forms};
        $self_ref->build_form_parts;
    }

    return $self_ref;
}

sub build_form_parts {
    my ($self, %args) = @_;

    foreach my $key_forms (keys %{$self->{forms}}) {
        if (!defined $self->{forms}->{$key_forms}->{type} || $self->{forms}->{$key_forms}->{type} eq '') {
            next;
        }

        my %html = ();
        my $value_display = '';

        if ($self->{forms}->{$key_forms}->{type} eq 'file') {
            my $form_name = defined $self->{forms}->{$key_forms}->{form_name} && $self->{forms}->{$key_forms}->{form_name} ne '' ? $self->{forms}->{$key_forms}->{form_name} : 'main';

            # delete.
            if (
                defined $self->qinu->params->{mode} && $self->qinu->params->{mode} eq 'delete_file_' . $key_forms &&
                defined $self->qinu->params->{$key_forms} && $self->qinu->params->{$key_forms} ne '' && 
                $self->qinu->params->{$key_forms} !~ /\.\./
            ) {
                if (
                    defined $self->{forms}->{$key_forms}->{write_dir} && $self->{forms}->{$key_forms}->{write_dir} ne '' && 
                    -f $self->{forms}->{$key_forms}->{write_dir} . '/' . $self->qinu->params->{$key_forms}
                ) {
                    unlink $self->{forms}->{$key_forms}->{write_dir} . '/' . $self->qinu->params->{$key_forms};
                }
                elsif (
                    defined $self->qinu->conf->{document_root} && $self->qinu->conf->{document_root} ne '' && 
                    defined $self->qinu->conf->{file_dir_temporary} && $self->qinu->conf->{file_dir_temporary} ne '' && 
                    -d $self->qinu->conf->{document_root} . '/' . $self->qinu->conf->{file_dir_temporary} && 
                    -f $self->qinu->conf->{document_root} . '/' . $self->qinu->conf->{file_dir_temporary} . '/' . $self->qinu->params->{$key_forms}
                ) {
                    unlink $self->qinu->conf->{document_root} . '/' . $self->qinu->conf->{file_dir_temporary} . '/' . $self->qinu->params->{$key_forms};
                }

                $self->qinu->params->{$key_forms} = '';
            }

            # upload.
            # validate.
            my @files;
            my $cgi_error;
            if ($self->qinu->is_psgi) {
                push @files, $self->qinu->cgi_psgi->upload($key_forms);
                $cgi_error = $self->qinu->cgi_psgi->cgi_error;
            }
            else {
                @files = $self->qinu->cgi_simple->upload_info();
                $cgi_error = $self->qinu->cgi_simple->cgi_error;
            }
            my $filename = '';

            if (@files) {
                $filename = $files[0];
            }
            if (
                $filename ne '' && 
                defined $self->qinu->validate->{form}
            ) {
                my $form = $self->qinu->validate->{form};
                if (defined $form->{forms}->{$key_forms}->{validate}->{exist}) {
                    undef $form->{forms}->{$key_forms}->{validate}->{exist};
                }

                foreach my $key_validate_forms (keys %{$form->{forms}}) {
                    if ($key_forms ne $key_validate_forms) {
                        $form->{forms}->{$key_validate_forms}->{validate} = ();
                    }
                }

                undef $self->qinu->{validate};
                $self->qinu->validate->set_form({form => $form});
                $self->qinu->validate->values = $self->qinu->params;
                $self->qinu->validate->form_validate();
            }

            if (
                !$self->qinu->validate->error_f && 
                defined $self->qinu->params->{$key_forms} && $self->qinu->params->{$key_forms} ne '' && 
                !$cgi_error
            ) {
                if ($filename ne '') {
                    if (defined $self->{forms}->{$key_forms}->{write_dir} && $self->{forms}->{$key_forms}->{write_dir} ne '') {
                        $self->qinu->http->upload(file_src => $filename, file_dest => $self->{forms}->{$key_forms}->{write_dir} . '/' . $filename);
                    }
                    elsif (
                        defined $self->qinu->conf->{document_root} && $self->qinu->conf->{document_root} ne '' &&
                        defined $self->qinu->conf->{file_dir_temporary} && $self->qinu->conf->{file_dir_temporary} ne '' &&
                        -d $self->qinu->conf->{document_root} . '/' . $self->qinu->conf->{file_dir_temporary}
                    ) {
                        $self->qinu->http->upload(file_src => $filename, file_dest => $self->qinu->conf->{document_root} . '/' . $self->qinu->conf->{file_dir_temporary} . '/' . $filename);
                    }
                }
                else {
                    $filename = $self->qinu->params->{$key_forms};
                }

                $html{main} = '';
                $html{event_delete} = 'var mode = document.getElementById(\'mode\'); mode.value = \'delete_file_' . $self->qinu->html->encode_entity_r(value => $key_forms) . '\'; document.forms[\'' . $self->qinu->html->encode_entity_r(value => $form_name) . '\'].submit()';
                $html{button_send} = '';
                my $value_delete_button = 'delete';
                if (defined $self->{forms}->{value_delete_button} && $self->{forms}->{value_delete_button} ne '') {
                    $value_delete_button = $self->qinu->html->encode_entity_r(value => $self->{forms}->{value_delete_button});
                }
                $html{button_delete} = '<input type="button" value="' . $value_delete_button . '" onclick="' . $html{event_delete} . '"' . $self->tag_close() . '>';
                $html{hidden} = '<input type="hidden" id="' . $self->qinu->html->encode_entity_r(value => $key_forms) . '" name="' . $self->qinu->html->encode_entity_r(value => $key_forms) . '" value="' . $self->qinu->html->encode_entity_r(value => $filename) . '"' . $self->tag_close() . '>' . "\n";
                $html{name} = $self->qinu->html->encode_entity_r(value => $filename);
            }
            else {
                $html{main} = '<input type="file" name="' . $self->qinu->html->encode_entity_r(value => $key_forms) . '"' . $self->tag_close() . '>' . "\n";
                my $value_button = 'send';
                if (defined $self->{forms}->{value_button} && $self->{forms}->{value_button} ne '') {
                    $value_button = $self->qinu->html->encode_entity_r(value => $self->{forms}->{value_button});
                }
                $html{button_send} = '<input type="submit" value="' . $value_button . '" onclick="document.forms[\'' . $self->qinu->html->encode_entity_r(value => $form_name) . '\'].submit()"' . $self->tag_close() . '>';
                $html['button_delete'] = '';
                $html['hidden'] = '';
                $html['name'] = '';

                $self->qinu->validate->error_f(0);
            }
        }

        $self->{forms}->{$key_forms}->{html} = \%html;
        $self->{forms}->{$key_forms}->{value_display} = $value_display;
    }
}

sub tag_close {
    my ($self, %args) = @_;

    if (defined $self->qinu->conf->{template_type} && $self->qinu->conf->{template_type} eq 'xhtml') {
        $html = ' /';
    }
    else {
        $html = '';
    }

    return $html;
}

1;
