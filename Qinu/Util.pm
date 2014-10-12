package Qinu::Util;

use strict;
use warnings;

use Data::Dumper;
use DateTime;
use Image::Size;

use base qw(Class::Accessor::Fast);

__PACKAGE__->mk_accessors(qw(qinu));

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
    my $mime = `/usr/bin/file -m ${file_magic_mime} '${file}'`;

    if ($mime =~ /^.+\s.+?\/(.+?)$/) {
        $extension_fix = '.' . $1;

        if ($extension_tmp eq '.jpg' && $extension_fix eq '.jpeg') {
            $extension_fix = '.jpg';
        }
        if ($extension_tmp ne '.jpeg' && $extension_fix eq '.jpeg') {
            $extension_fix = '.jpg';
        }
    }

    if ($extension_fix eq '') {
        $extension_fix = $extension_tmp;
    }

    return $extension_fix;
}

sub check_numeric {
    my ($self, %args) = @_;

    my $value = defined $args{value} ? $args{value} : '';

    if ($value =~ /^(?:\+|\-)*\d+(?:\.{1})*\d*$/) {
        return 1;
    }
    else {
        return;
    }
}

sub check_bool {
    my ($self, %args) = @_;

    my $value = defined $args{value} ? $args{value} : '';

    if ($value  =~ /^(0|1)$/) {
        return 1;
    }
    else {
        return;
    }
}

sub resize_img_montage {
    my ($self, %args) = @_;

    my $img;
    if (defined $args{img} && $args{img} ne '') {
        $img = $args{img};
    }
    else {
        return;
    }

    my $img_dest;
    if (defined $args{img_dest} && $args{img_dest} ne '') {
        $img_dest = $args{img_dest};
    }
    else {
        $img_dest = $img;
    }

    my $color_bg;
    if (defined $args{color_bg} && $args{color_bg} ne '') {
        $color_bg = ' -background "' . $args{color_bg} . '"';
    }
    else {
        $color_bg = ' -background "#000000"';
    }

    my $x_dest;
    if (defined $args{x_dest} && $args{x_dest} > 0) {
        $x_dest = $args{x_dest};
    }
    else {
        return;
    }

    my $y_dest;
    if (defined $args{y_dest} && $args{y_dest} > 0) {
        $y_dest = $args{y_dest};
    }
    else {
        $y_dest = $x_dest;
    }

    my $convert;
    if (defined $args{convert} && -f $args{convert}) {
        $convert = $args{convert};
    }
    elsif (defined $self->qinu->conf->{convert_path} && -f $self->qinu->conf->{convert_path}) {
        $convert = $self->qinu->conf->{convert_path};
    }
    else {
        $convert = `which convert`;
    }

    my $montage;
    if (defined $args{montage} && -f $args{montage}) {
        $montage = $args{montage};
    }
    elsif (defined $self->qinu->conf->{montage_path} && -f $self->qinu->conf->{montage_path}) {
        $montage = $self->qinu->conf->{montage_path};
    }
    else {
        $montage = `which montage`;
    }

    if (!-f $img) {
        return;
    }

    my ($x, $y) = imgsize($img);

    my $size;
    if ($x > $y) {
        $size = $x_dest . 'x';
    }
    elsif ($x <= $y) {
        $size = 'x' . $y_dest;
    }

    if ($x > $x_dest || $y > $y_dest) {
        my $cmd_convert = $convert . ' -quality 100 -resize ' . $size . ' ' . $img . ' ' . $img_dest;
        `${cmd_convert}`;
    }

    if ($x != $x_dest && $y != $y_dest) {
        my $x_padding;
        my $y_padding;
        if ($x > $y) {
            $x_padding = 0;
            $y_padding = ($y_dest - $y) / 2;
        }
        elsif ($x < $y) {
            $x_padding = ($x_dest - $x) / 2;
            $y_padding = 0;
        }
        else {
            $x_padding = ($x_dest - $x) / 2;
            $y_padding = ($y_dest - $y) / 2;
        }

        my ($x_current, $y_current) = imgsize($img_dest);

        my $cmd_montage = $montage . ' -quality 100 -geometry ' . $x_current . 'x' . $y_current . '+' . $x_padding . '+' . $y_padding . $color_bg . ' ' . $img_dest . ' ' . $img_dest;
        `${cmd_montage}`;
    }
}

sub resize_img {
    my ($self, %args) = @_;

    my $img;
    if (defined $args{img} && $args{img} ne '') {
        $img = $args{img};
    }
    else {
        return;
    }

    my $img_dest;
    if (defined $args{img_dest} && $args{img_dest} ne '') {
        $img_dest = $args{img_dest};
    }
    else {
        $img_dest = $img;
    }

    my $x_dest;
    if (defined $args{x_dest} && $args{x_dest} > 0) {
        $x_dest = $args{x_dest};
    }
    else {
        return;
    }

    my $y_dest;
    if (defined $args{y_dest} && $args{y_dest} > 0) {
        $y_dest = $args{y_dest};
    }
    else {
        $y_dest = $x_dest;
    }

    my $convert;
    if (defined $args{convert} && -f $args{convert}) {
        $convert = $args{convert};
    }
    elsif (defined $self->qinu->conf->{convert_path} && -f $self->qinu->conf->{convert_path}) {
        $convert = $self->qinu->conf->{convert_path};
    }
    else {
        $convert = `which convert`;
    }

    my ($x, $y) = imgsize($img);

    my $xy_resize = '';
    if ($x != $x_dest && $y != $y_dest) {
        if ($x < $x_dest && $y < $y_dest) {
            if ($x > $y) {
                $xy_resize = 'x' . $y_dest;
            } 
            else {
                $xy_resize = $x_dest . 'x';
            }
        }
        elsif ($x < $x_dest) {
            $xy_resize = $x_dest . 'x';
        }
        elsif ($y < $y_dest) {
            $xy_resize = 'x' . $y_dest;
        }
        elsif ($x < $y)  {
            $xy_resize = $x_dest . 'x';
        }
        elsif ($x > $y) {
            $xy_resize = 'x' . $y_dest;
        }
        else {
            $xy_resize = $x_dest . 'x' . $y_dest;
        }
    }

    my $cmd;
    if ($xy_resize) {
        $cmd = $convert . ' -geometry ' . $xy_resize . ' -quality 100 ' . $img . ' ' . $img_dest;
        while ($x != $x_dest && $y != $y_dest) {
            `${cmd}`;
            ($x, $y) = imgsize($img_dest);
        }
    }
    else {
        $img = $img_dest;
    }

    ($x, $y) = imgsize($img_dest);
    my $x_offset;
    if ($x > $x_dest) {
        $x_offset = ($x - $x_dest) / 2;
    }
    else {
        $x_offset = 0;
    }

    my $y_offset;
    if ($y > $y_dest) {
        $y_offset = ($y - $y_dest) / 2;
    }
    else {
        $y_offset = 0;
    }

    $cmd = $convert . ' -quality 100 -crop ' . $x_dest . 'x' . $y_dest . '+' . $x_offset . '+' . $y_offset . ' ' . $img_dest . ' ' . $img_dest;
    `${cmd}`;
}

sub change_datetime_timezone {
    my ($self, %args) = @_; 

    my $datetime_src;
    if (defined $args{datetime_src} && $args{datetime_src} ne '') {
        $datetime_src = $args{datetime_src};
    }   
    else {
        return;
    }   

    my $timezone_src;
    if (defined $args{timezone_src} && $args{timezone_src} ne '') {
        $timezone_src = $args{timezone_src};
    }
    else {
        return;
    }

    my $timezone_dest;
    if (defined $args{timezone_dest} && $args{timezone_dest} ne '') {
        $timezone_dest = $args{timezone_dest};
    }   
    else {
        return;
    }

    my $datetime_dest;

    my ($date_src, $time_src) = split ' ', $datetime_src;
    my ($year_src, $month_src, $day_src) = split '-', $date_src;
    my ($hour_src, $minute_src, $second_src) = split ':', $time_src;

    my $dt;
    eval {
        $dt = DateTime->new(
            year => $year_src,
            month => $month_src,
            day => $day_src,
            hour => $hour_src,
            minute => $minute_src,
            second => $second_src,
            nanosecond => 0,
            time_zone => $timezone_src,
        );
    };

    if ($@) {
        return;
    }

    my $epoch_src = $dt->epoch;

    my $dt_dest = DateTime->from_epoch(epoch => $epoch_src);
    $dt_dest->set_time_zone($timezone_dest);

    $datetime_dest = $dt_dest->ymd('-') . ' ' . $dt_dest->hms(':');

    return $datetime_dest;
}

sub check_args_defined_and_null {
    my ($self, %args) = @_;

    my $keys;
    if (!defined $args{keys} || !$args{keys}) {
        return;
    }
    else {
        $keys = $args{keys};
    }

    my $values;
    if (!defined $args{values} || !$args{values}) {
        return;
    }
    else {
        $values = $args{values};
    }

    foreach my $key (@$keys) {
        if (!defined $values->{$key} || $values->{$key} eq '') {
            return;
        }
    }

    return 1;
}

sub page_current {
    my ($self, %args) = @_;

    my @keys = qw(limit data);
    if (!$self->check_args_defined_and_null(keys => \@keys, values => \%args)) {
        return 1;
    }

    my $limit = $args{limit};
    my @data = @{$args{data}};

    my $page = 1;
    if (
        defined $self->qinu->path_info_ary->{p} && $self->qinu->path_info_ary->{p} =~ /^\d+$/ &&
        scalar @data > ($self->qinu->path_info_ary->{p} - 1) * $limit &&  
        $self->qinu->path_info_ary->{p} !~ /^(0+|1)$/
    ) { 
        $page = $self->qinu->path_info_ary->{p};
    }   

    return $page;
}

sub paging_array {
    my ($self, %args) = @_;

    my @fix_array = ();

    my @keys = qw(limit array page);
    if (!$self->check_args_defined_and_null(keys => \@keys, values => \%args)) {
        return @fix_array;
    }

    my $limit = $args{limit};
    my $page = $args{page} - 1;
    my $array = $args{array};

    my $num_begin_tag;
    if (
        $page =~ /^\d+$/ &&  
        scalar @$array > $page * $limit
    ) {
        $num_begin_tag = $page * $limit;
    }
    else {
        $num_begin_tag = 0;
    }
    my $num_end_tag = $limit + $num_begin_tag;

    for (my $i = $num_begin_tag; $i < $num_end_tag; $i++) {
        if (defined $array->[$i]) {
            push @fix_array, $array->[$i];
        }
        else {
            last;
        }
    }

    return @fix_array;
}

sub paging_offset {
    my ($self, %args) = @_;

    my @keys = qw(limit page);
    if (!$self->check_args_defined_and_null(keys => \@keys, values => \%args)) {
        return;
    }

    my $offset = ($args{page} - 1) * $args{limit};

    return $offset;
}

sub in_span_datetime {
    my ($self, %args) = @_;

    my @keys = qw(datetime datetime_start);
    if (!$self->check_args_defined_and_null(keys => \@keys, values => \%args)) {
        return;
    }

    my $datetime = $args{datetime};
    my $datetime_start = $args{datetime_start};
    my $datetime_end = '';
    if (defined $args{datetime_end} && $args{datetime_end} ne '') {
        $datetime_end = $args{datetime_end};
    }

    if ($datetime_start le $datetime && ($datetime_end eq '' || $datetime_end gt $datetime)) {
        return 1;
    }
    else {
        return;
    }
}

1;
