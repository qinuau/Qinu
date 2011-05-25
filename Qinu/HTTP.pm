package Qinu::HTTP;

use strict;
use warnings;

use base qw(Class::Accessor::Fast);
__PACKAGE__->mk_accessors(qw(qinu));

sub new {
    my ($self, %args) = @_;
    my $attr = {
        qinu => $args{qinu},
        header_already_f => 0,
    };

    return bless $attr, $self;
}

sub header {
    my ($self, %args) = @_;

    my $charset = '';
    if (defined $args{charset}) {
        $charset = '; charset=' . $args{charset} . ';';
    }

    if (!$self->{header_already_f}) {
        my $dt = DateTime->now;

        print "Expires: Fri, 26 Mar 1999 23:59:59 GMT\n";
        print "Cache-Control: no-store, no-cache, must-revalidate\n";
        print "Cache-Control: post-check=0, pre-check=0\n";
        print "Last-Modified: " . $dt->day_abbr . ', ' . $dt->day . ' ' . $dt->month_abbr . ' ' . $dt->year . ' ' . $dt->hour . ':' . $dt->minute . ':' . $dt->second . ' GMT' . "\n";
        print "Pragma: no-cache\n";
        print "Content-type: text/html" . $charset . "\n\n";

        $self->{header_already_f} = 1;
    }
}

sub nl2p {
    my ($self, %args) = @_;
    my $str = $args{str};

    $str =~ s/(\r\n|\r)/\n/gs;
    my @str = split('\n', $str);
    $str = '';
    foreach my $each_line (@str) {
        if (!$each_line) {
            $str .= '<p>&nbsp;</p>' . "\n";
        }
        else {
            $str .= '<p>' . $each_line . '</p>' . "\n";
        }
    }
    return $str;
}

sub indent2nbsp {
    my ($self, %args) = @_;
    my $str = $args{str};

    return $str;
}

sub mk_hidden {
    my ($self, %args) = @_;
    my $params_ref = defined $args{params} ? $args{params} : "";
    my $hidden = '';
    if ($params_ref) {
        my %params = %$params_ref;
        foreach my $key (sort keys %params) {
            $hidden .= '<input type="hidden" name="' . $key . '" value="' . $self->qinu->cgi->escapeHTML($params{$key}) . '">' . "\n";
        }
        $hidden = $hidden ? substr($hidden, 0, -1) : "";
    }
    return $hidden;
}

sub encode_entity {
    my ($self, %args) = @_;

    my $value_escaped_ref = '';
    if (defined $args{value}) {
        my $value_ref = $args{value};
        if (ref $args{value} eq 'HASH') {
            my %value_escaped = ();
            my %values = %$value_ref;
            foreach my $key (sort keys %values) {
                $value_escaped{$key} = $self->qinu->cgi->escapeHTML($values{$key}); 
            }
            $value_escaped_ref = \%value_escaped;
        }
        elsif (ref $args{value} eq 'ARRAY') {
            my @value_escaped = ();
            my @values = @$value_ref;
            foreach my $value (@values) {
                push(@value_escaped, $self->qinu->cgi->escapeHTML($value));
            }
            $value_escaped_ref = \@value_escaped;
        }
        else {
            my $value_escaped = $self->qinu->cgi->escapeHTML($$value_ref);
            $value_escaped_ref = \$value_escaped;
        }
    }
    return $value_escaped_ref;
}

sub encode_entity_r {
    my ($self, %args) = @_;

    my $value;
    if (defined $args{value}) {
        $value = $args{value};
    }
    else {
        return;
    }

    if (ref $value eq 'HASH') {
        foreach my $key (keys %$value) {
            if (ref $value->{$key}) {
                $self->encode_entity_r(value => $value->{$key});
            }
            else {
                $value->{$key} = $self->qinu->cgi->escapeHTML($value->{$key});
            }
        }
    }
    elsif (ref $value eq 'ARRAY') {
        my $i = 0;
        foreach my $each (@$value) {
            if (ref $each) {
                $self->encode_entity_r(value => $each);
            }
            else {
                $value->[$i] = $self->qinu->cgi->escapeHTML($each);
            }
            $i++;
        }
    }
    else {
        my $value_tmp = $self->qinu->cgi->escapeHTML($$value);
        $value = \$value_tmp;
    }
}

sub get_language {
    my ($self, %args) = @_;

    my $language = 'en';

    if (defined $args{language}) {
        if ($args{language} =~ /^ja/) {
            $language = 'ja';
        }
    }

    return $language;
}

sub get_mime_type {
    my ($self, %args) = @_;

    my $file = '';
    if (defined $args{file} && -f $args{file}) {
        $file = $args{file};
    }
    else {
        return '';
    }

    my $mime = '';
    $mime = $self->get_mime_type_file(file => $file);
    if (!$mime) {
        my $extension = $self->qinu->util->get_file_extention(file => $file);
        $mime = $self->get_mime_type_httpd(extention => substr($extension, 0, 1));
    }

    if (!$mime) {
        return '';
    }
    else {
        return $mime;
    }
}

sub get_mime_type_httpd {
    my ($self, %args) = @_;

    my $file_mime_types = '';
    if (defined $self->qinu->conf->{file_mime_types}) {
        $file_mime_types = $self->qinu->conf->{file_mime_types};
    }
    elsif (defined $args{file_mime_types}) {
        $file_mime_types = $args{file_mime_types};
    }

    my $extension = '';
    if (defined $args{extension}) {
        $extension = $args{extension};
    }

    if ($file_mime_types eq '' || $extension eq '') {
        return '';
    }

    open my $file_h, $file_mime_types;
    my @mime_types = <$file_h>;
    foreach my $each (@mime_types) {
        if ($each =~ /^.*?([\w\+-_]+?\/[\w\+-_]+?)\t+?(\s|\w)*?\s${extension}(\r\n|\r|\n|\s)/) {
            my $mime = $1;
            return $mime;
        }
    }
}

sub get_mime_type_file {
    my ($self, %args) = @_;

    my $file = '';
    my $file_magic_mime = '';
    if (defined $args{file_magic_mime}) {
        $file_magic_mime = $args{file_magic_mime};
    }
    elsif (defined $self->qinu->conf->{file_magic_mime}) {
        $file_magic_mime = $self->qinu->conf->{file_magic_mime};
    }

    if (defined $args{file}) {
        $file = $args{file};
    }

    if ($file_magic_mime eq '' || $file eq '') {
        return '';
    }

    my $mime = `file -m ${file_magic_mime} ${file}`;
    if ($mime =~ /^.+ (.+?\/.+?)$/) {
        my $mime_result = $1;
        return $mime_result;
    }
}

sub response_file {
    my ($self, %args) = @_;

    my $file = '';
    if (defined $args{file} && -f $args{file}) {
        $file = $args{file};
    }
    else {
        return '';
    }

    $file =~ /^.*\/(.+?)$/;
    my $filename = $1;

    open my $file_h, $file;
    my $content = '';
    binmode $content;
    $content = join '', <$file_h>; 

    my $mime = $self->get_mime_type(file => $file);

    my $size = length($content);

    my $content_disposition = 'inline';
    if (defined $args{content_disposition}) {
        $content_disposition = $args{content_disposition};
    }

    print 'Content-type: ' . $mime . "\n";
    print 'Content-Length: ' . $size . "\n";
    print 'Content-Disposition: ' . $content_disposition . '; filename=' . $filename . "\n";
    print "\n";
    print $content;
}

sub get_hash_from_url_args {
    my ($self, %args) = @_;

    my %params;
    my @params = split '&', $args{args};
    foreach my $each (@params) {
        my ($key, $value) = split '=', $each;
        $params{$key} = $value;
    }

    return %params;    
}

1;
