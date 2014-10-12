package Qinu::HTTP;

use strict;
use warnings;
use DateTime;
use File::Copy;

use base qw(Class::Accessor::Fast);
__PACKAGE__->mk_accessors(qw(qinu tag_names));

sub new {
    my ($self, %args) = @_;

    my $tag_names = [
        'a',
        'abbr',
        'acronym',
        'address',
        'applet',
        'area',
        'article',
        'aside',
        'audio',
        'b',
        'base',
        'basefont',
        'bb',
        'bdo',
        'big',
        'blockquote',
        'body',
        'br',
        'button',
        'canvas',
        'caption',
        'command',
        'comment',
        'center',
        'cite',
        'code',
        'col',
        'colgroup',
        'datagrid',
        'datalist',
        'del',
        'details',
        'dialog',
        'dir',
        'div',
        'dfn',
        'dl',
        'dt',
        'dd',
        'em',
        'embed',
        'fieldset',
        'figure',
        'font',
        'footer',
        'form',
        'frame',
        'frameset',
        'h1～h6',
        'head',
        'header',
        'hr',
        'html',
        'i',
        'iframe',
        'img',
        'input',
        'ins',
        'isindex',
        'kbd',
        'keygen',
        'label',
        'legend',
        'li',
        'link',
        'mark',
        'map',
        'menu',
        'meta',
        'meter',
        'nav',
        'noframes',
        'noscript',
        'object',
        'ol',
        'optgroup',
        'option',
        'output',
        'p',
        'param',
        'pre',
        'progress',
        'q',
        'ruby',
        'rp',
        'rt',
        's',
        'samp',
        'script',
        'section',
        'select',
        'small',
        'source',
        'span',
        'strike',
        'strong',
        'style',
        'sub',
        'sup',
        'table',
        'tbody',
        'td',
        'textarea',
        'tfoot',
        'th',
        'thead',
        'time',
        'title',
        'tr',
        'tt',
        'u',
        'ul',
        'var',
        'video',
    ];

    my $attr = {
        qinu => $args{qinu},
        header_already_f => 0,
        tag_names => $tag_names,
    };

    return bless $attr, $self;
}

sub header {
    my ($self, %args) = @_;

    my $content_type = '';
    if (defined $args{content_type} && $args{content_type} ne '') {
        $content_type = $args{content_type};
    }
    else {
        $content_type = "text/html";
    }

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
        print "Content-type: " . $content_type . $charset . "\n\n";

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

    $str =~ s/.*(\<pre(?:\s.+?|)\>).*/$1/g;
    $str =~ s/.*(<\/pre>).*/$1/g;

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
        my $extension = $self->qinu->util->get_file_extension(file => $file);
        $mime = $self->get_mime_type_httpd(extension => substr($extension, 1));
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

    my $file_h;
    open $file_h, $file_mime_types;
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

    my $mime = `/usr/bin/file -m ${file_magic_mime} ${file}`;

    if ($mime && $mime =~ /^.+ (.+?\/.+?)$/) {
        my $mime_result = $1;
        return $mime_result;
    }
    elsif (!$mime) {
        my $extension = $self->qinu->util->get_file_extension(file => $file);
        $mime = $self->get_mime_type_httpd(extension => substr($extension, 1));
        return $mime;
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

    my $file_h;
    open $file_h, $file;
    binmode $file_h;
    my $content = '';
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

sub url_current {
    my ($self, %args) = @_;

    my $url = $self->qinu->{current_protocol} . "://" . $self->qinu->env_qinu->{SERVER_NAME} . '/';

    return $url;
}

sub url_default {
    my ($self, %args) = @_;

    my $url = $self->qinu->conf->{protocol_default} . "://" . $self->qinu->env_qinu->{SERVER_NAME} . '/';

    return $url;
}

sub url_secure {
    my ($self, %args) = @_;

    my $url = $self->qinu->conf->{protocol_secure} . "://" . $self->qinu->env_qinu->{SERVER_NAME} . '/';

    return $url;
}

sub location_referer_or_top {
    my ($self, %args) = @_;

    my $referer = '';
    if (defined $args{referer}) {
       $referer = $args{referer};
    }

    if ($referer ne '') {
        $referer =~ s/\|/\//g;
        print "Location: " . $referer . "\n\n";
    }
    else {
        print "Location: " . $self->qinu->current_protocol . '://' . $self->qinu->server_name . "/\n\n";
    }
}

sub mk_hidden_referer {
    my ($self, %args) = @_;

    my $referer;
    if (defined $args{referer} && $args{referer} ne '') {
        $referer = $args{referer};
    }
    else {
        $referer = $self->get_referer_from_pathinfo_or_post();
    }
    my $referer_escaped = $self->qinu->cgi->escapeHTML($referer);
    my $referer_hidden = '<input type="hidden" name="r" value="' . $referer_escaped . '">';

    return $referer_hidden;
}

sub get_referer_from_pathinfo_or_post {
    my ($self, %args) = @_;

    my $referer;
    if (defined $self->qinu->path_info_ary->{r} && $self->qinu->path_info_ary->{r} ne '') {
        $referer = $self->qinu->path_info_ary->{r};
    }
    elsif (defined $self->qinu->params->{r} && $self->qinu->params->{r} ne '') {
        $referer = $self->qinu->params->{r};
    }
    else {
        $referer = $self->qinu->current_protocol . '://' . $self->qinu->server_name . '/';
    }

    $referer =~ s/\|/\//g;

    return $referer;
}

sub mk_option_num_base {
    my ($self, %args) = @_;

    my $keys = [
        'from_num',
        'to_num',
    ];
    if (!$self->qinu->util->check_args_defined_and_null(keys => $keys, values => \%args)) {
        return;
    }

    my $from_num = $args{from_num};
    my $to_num = $args{to_num};

    my $option;
    my $i;
    for ($i = $from_num; $i <= $to_num; $i++) {
        $option .= '<option value="' . $i . '">' . $i . '</option>' . "\n";
    }

    return $option;
}

sub mk_option_span_day {
    my ($self, %args) = @_;

    return $self->mk_option_num_base(from_num => 1, to_num => 31);
}

sub mk_option_span_hour {
    my ($self, %args) = @_;

    return $self->mk_option_num_base(from_num => 1, to_num => 23);
}

sub mk_option_span_minute {
    my ($self, %args) = @_;

    return $self->mk_option_num_base(from_num => 1, to_num => 59);
}

sub entity_leave_tag {
    my ($self, %args) = @_;

    my $str = defined $args{value} ? $args{value} : '';
    
    my $result = '';

    while ($str =~ /(.*?\>)/gs) {
        my $str_tmp = $1;
        if ($str_tmp =~ /\<(?:\/|)(.+?)(?:\s.*?|)\>/ && grep(/^${1}$/, @{$self->tag_names})) {
            if ($str_tmp =~ /^(.*)(\<.+?)$/s) {
                $result .= ${$self->qinu->http->encode_entity(value => \$1)} . $2;
            }
            else {
                $result .= ${$self->qinu->http->encode_entity_r(value => \$str_tmp)};
            }
        }
        else {
            $result .= ${$self->qinu->http->encode_entity_r(value => \$str_tmp)};
        }
    }
    if ($str =~ /^(.*\>)(.+?)$/s && $str !~ /\>$/) {
        my $escaped = $self->qinu->cgi->escapeHTML($2);
        $result .= $escaped;
    }

    if ($str ne '' && $str !~ /\>/) {
        $result = ${$self->qinu->http->encode_entity_r(value => \$str)};
    }

    $result;
}

sub preprocess_file_upload {
    my ($self, %args) = @_;

    my $key_file;
    if (defined $args{key_file}) {
        $key_file = $args{key_file};
    }
    else {
        return {};
    }

    my $uid = '';
    if (defined $args{uid}) {
        $uid = $args{uid};
    }

    my $dir_item;
    if (!defined $self->qinu->conf->{dir_item} || $self->qinu->conf->{dir_item} eq '') {
        return;
    }
    $dir_item = $self->qinu->conf->{dir_item};
    if ($uid ne '') {
        $dir_item .= '/' . $uid;
    }
    #my $file01 = $self->qinu->cgi_simple->param($key_file);
    my $file01 = $key_file;

    $file01 =~ s/\s//g;
    
    # tmp is location.
    if ($file01 eq 'tmp') {
        print "Location: /\n\n";
        return 0;
    }
    
    my $filename_tmp01;
    my $suffix01;
    if ($file01 =~ /^(.+)(\..+?)$/) {
        if ($1 ne '') {
            $filename_tmp01 = $1;
        }
    
        if ($2 ne '') {
            $suffix01 = $2;
        }
    }
    else {
        $filename_tmp01 = $file01;
    }
    
    if (!-d $dir_item) {
        mkdir $dir_item;
    }
    if (!-d $dir_item . '/tmp') {
        mkdir $dir_item . '/tmp';
    }
    
    if ($self->qinu->is_psgi) {
        $self->qinu->cgi_psgi->upload($key_file, $dir_item . '/tmp/' . $file01);
    }
    else {
        $self->qinu->cgi_simple->upload($key_file, $dir_item . '/tmp/' . $file01);
    }
    my $suffix01_fix = $self->qinu->util->get_file_extension(file => $dir_item . '/tmp/' . $file01);
    
    if ($suffix01 eq '' || ($suffix01 ne $suffix01_fix)) {
        $suffix01 = $suffix01_fix;
    }
    
    my $result = {};
    $result->{file} = $file01;
    $result->{dir_item} = $dir_item;
    $result->{suffix} = $suffix01;
    $result->{filename_tmp} = $filename_tmp01;

    return $result;
}

sub get_incremented_filename {
    my ($self, %args) = @_;

    my $dir_item;
    if (defined $args{dir_item}) {
        $dir_item = $args{dir_item};
    }
    else {
        return;
    }

    my $filename_tmp01;
    if (defined $args{filename_tmp}) {
        $filename_tmp01 = $args{filename_tmp};
    }
    else {
        return;
    }

    my $suffix01;
    if (defined $args{suffix}) {
        $suffix01 = $args{suffix};
    }
    else {
        return;
    }

    my $filename_no01;
    if (-f $dir_item . '/' . $filename_tmp01 . $suffix01) {
        my $proc_increment_filename = sub {
            my %args = @_;
            my $filename = $args{filename};
            my $filename_num;

            if ($filename =~ /^(.+)_(\d+?)$/) {
                $filename = $1;
                $filename_num = $2;
                $filename_num++;
            }
            else {
                $filename_num = '1';
            }
            $filename = $filename . '_' . $filename_num;

            return $filename;
        };

        my @files = `ls ${dir_item}/${filename_tmp01}*`;
        @files = sort {$b cmp $a} @files;
        my $filename_pre01 = $files[0];
        while (1) {
            $filename_tmp01 = &$proc_increment_filename(filename => $filename_tmp01);
            if (!-f $dir_item . '/' . $filename_tmp01 . $suffix01) {
                last;
            }
        }
    }
    my $filename = $filename_tmp01 . $filename_no01 . $suffix01;

    return $filename;
}

sub copy_and_delete_file_tmp_to_live {
    my ($self, %args) = @_;

    my $file;
    if (defined $args{file} && $args{file} ne '') {
        $file = $args{file};
    }
    else {
        return;
    }

    my $filename;
    if (defined $args{filename} && $args{filename} ne '') {
        $filename = $args{filename};
    }
    else {
        return;
    }

    my $dir_item;
    if (defined $args{dir_item} && $args{dir_item} ne '') {
        $dir_item = $args{dir_item};
    }
    else {
        return;
    }

    my $file_tmp = $file;
    $file_tmp =~ s/ //g;
    copy($dir_item . "/tmp/" . $file_tmp, $dir_item . "/" . $filename);
    unlink $dir_item . '/tmp/' . $file_tmp;
    chmod 0644, $dir_item . '/' . $filename;

    return 1;
}

sub upload {
    my ($self, %args) = @_;

    my $file_src = defined $args{file_src} ? $args{file_src} : '';
    my $file_dest = defined $args{file_dest} ? $args{file_dest} : '';

    if ($self->qinu->is_psgi) {
        move $self->qinu->cgi_psgi->tmpFileName($file_src), $file_dest;
    }
    else {
        $self->qinu->cgi_simple->upload($file_src, $file_dest);
    }
}

1;

__END__
=head1 NAME

Qinu::HTTP - Hyper Text Transport Protocol Class.

=head1 SYNOPSIS

header()
nl2p()
indent2nbsp()
mk_hidden()
encode_entity()
encode_entity_r()
get_language()
get_mime_type()
get_hash_from_url_args()
url_current()
url_default()
url_secure()

=head1 AUTHOR

Yotsumoto, Toshitaka "yotsumoto@qinuau.com"

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2008 by Yotsumoto, Toshitaka

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.10.0 or,
at your option, any later version of Perl 5 you may have available.


=cut
