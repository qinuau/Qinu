package Qinu::Util;

use strict;
use warnings;

use Moose;

has 'kolp' => (
    is  => 'rw',
    isa => 'Ref',
);

has 'qinu' => (
    is  => 'rw',
    isa => 'Ref',
);

sub new {
    my ($self, %args) = @_;
    my $attr = {
        qinu => $args{qinu},
    };

    return bless $attr, $self;
}

sub file_fetch_allline {
    my ($self, %args) = @_;

    if (defined($args{file_path}) && -f $args{file_path}) {
        open my $required_code_file_h, $args{file_path};
        my $required_code = join '', <$required_code_file_h>;
        return $required_code;    
    }
}

sub get_path_info_line {
    my ($self) = @_;
    
    my @line;
    if (defined $self->{qinu}->params->{q}) {
        @line = split(/\//, $self->{qinu}->params->{q});
    }
    return @line;
}

sub path_info_ary_shift {
    my ($self, %args) = @_;
    my $path_info_line = $args{path_info_line};

    my $num = $args{num};
    my @res;
    shift @$path_info_line;
    for (my $i = 1; $i <= $num; $i++) {
        push(@res, shift @$path_info_line);
    }

    if (@$path_info_line) {
        undef $self->{qinu}->{path_info_ary};
        while (@$path_info_line) {
            my $k = shift @$path_info_line;
            my $v = shift @$path_info_line;
            $self->{qinu}->{path_info_ary}{$k} = $v;
        }
    }
    return @res;
}

sub display_default {
    my ($self, %args) = @_;

    my $html = '';
    $html .= '&nbsp;';
    $html .= "<h1>action in: " . $self->qinu->cgi->escapeHTML($self->qinu->action_name) . "</h1><br />\n";
    $html .= "Welcome to this WebFramework.<br />\n";
    $html .= "version: " . $self->qinu->VERSION . "<br />\n";

$html .=<<EOD;
Qinu - Perl Web Framework<br />
Yotsumoto, Toshitaka "yotsumoto\@qinuau.com"<br />
Copyright (C) 2008 by Yotzmoto, Toshitaka<br />
<br />
This library is free software; you can redistribute it and/or modify<br />
it under the same terms as Perl itself, either Perl version 5.10.0 or,<br />
at your option, any later version of Perl 5 you may have available.
EOD

    return $html;
}

sub check_permission_member {
    my ($self, %args) = @_;

    if (!defined $args{dbh} || !defined $args{app_name} || !defined $args{uid}) {
        return 0;
    }

    my $dbh = $args{dbh};
    my $app_name = $args{app_name};
    my $uid = $args{uid};

    my $sql = "SELECT * FROM member WHERE uid = " . $dbh->quote($uid) . " AND permission_" . $app_name . " = 1";
    my $res = $self->qinu->model->db_fetch_simple(dbh => $dbh, sql => $sql);
    my @data = @$res;
    if (scalar @data == 0) {
        return 0;
    }
    else {
        return 1;
    }
}

sub check_mail {
    my ($self, %args) = @_;

    my $mail_regex = q{(?:[^(\040)<>@,;:".\\\\\[\]\000-\037\x80-\xff]+(?![^(\040)<>@,;:".\\\\} . q{\[\]\000-\037\x80-\xff])|"[^\\\\\x80-\xff\n\015"]*(?:\\\\[^\x80-\xff][} . q{^\\\\\x80-\xff\n\015"]*)*")(?:\.(?:[^(\040)<>@,;:".\\\\\[\]\000-\037\x} . q{80-\xff]+(?![^(\040)<>@,;:".\\\\\[\]\000-\037\x80-\xff])|"[^\\\\\x80-} . q{\xff\n\015"]*(?:\\\\[^\x80-\xff][^\\\\\x80-\xff\n\015"]*)*"))*@(?:[^(} . q{\040)<>@,;:".\\\\\[\]\000-\037\x80-\xff]+(?![^(\040)<>@,;:".\\\\\[\]\0} . q{00-\037\x80-\xff])|\[(?:[^\\\\\x80-\xff\n\015\[\]]|\\\\[^\x80-\xff])*} . q{\])(?:\.(?:[^(\040)<>@,;:".\\\\\[\]\000-\037\x80-\xff]+(?![^(\040)<>@,} . q{;:".\\\\\[\]\000-\037\x80-\xff])|\[(?:[^\\\\\x80-\xff\n\015\[\]]|\\\\[} . q{^\x80-\xff])*\]))*};

    if (defined $args{value}) {
        if ($args{value} =~ /${mail_regex}/ && $args{value} !~ /(\;|,)/) {
            return 1;
        }
        else {
            return 0;
        }
    } 
    else {
        return 0;
    }
}

sub get_file_extension {
    my ($self, %args) = @_;

    my $file = defined $args{file} ? $args{file} : '';
    if ($file eq '') {
        return '';
    }

    my $extension_tmp = '';
    if ($file =~ /^.*(\..+?)$/) {
        $extension_tmp = $1;
    }

    my $file_magic_mime = '';
    if (defined $self->qinu->conf->{file_magic_mime}) {
        $file_magic_mime = $self->qinu->conf->{file_magic_mime};
    }
    elsif (defined $args{file_mime_types}) {
        $file_magic_mime = $args{file_magic_mime};
    }

    if ($file_magic_mime eq '') {
        return '';
    }

    my $extension_fix = '';
    my $mime = `file -m ${file_magic_mime} '${file}'`;

    if ($mime =~ /^.+\s.+?\/(.+?)$/) {
        $extension_fix = '.' . $1;
        if ($extension_tmp eq '.jpg' && $extension_fix eq '.jpeg') {
            $extension_fix = '.jpg';
        }
        if ($extension_tmp ne '.jpeg' && $extension_fix eq '.jpeg') {
            $extension_fix = '.jpg';
        }
    }
    return $extension_fix;
}

1;
