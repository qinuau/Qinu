package Qinu::HTML;

use strict;
use warnings;
use HTML::Entities;

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
        tag_names => $tag_names,
    };

    return bless $attr, $self;
}

sub entity_tag {
    my ($self, %args) = @_;

    my $str = defined $args{str} ? $args{str} : '';
    
    my $result = '';
    my @strs = split '>', $str;
    foreach my $str_tmp (@strs) {
        $str_tmp .= '>';
        if (($str_tmp =~ /\<(?:\/|)(.+?)(?:\s{1}.+?|)\>$/ && !grep(/$1/, @{$self->tag_names})) || $str_tmp !~ /\</) {
            $result .= $self->qinu->http->encode_entity_r(value => $str_tmp); 
        }
        else {
            $result .= $str_tmp;
        }
    }

    $result;
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

    my $unsafe_chars = '<>\'"&';

    my $result;
    if (ref $value eq 'HASH') {
        foreach my $key (keys %$value) {
            if (ref $value->{$key}) {
                $self->encode_entity_r(value => $value->{$key});
            }
            else {
                $result->{$key} = encode_entities($value->{$key}, $unsafe_chars);
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
                $result->[$i] = encode_entities($each, $unsafe_chars);
            }
            $i++;
        }
    }
    else {
        $result = encode_entities($value, $unsafe_chars);
    }

    return $result;
}

1;
