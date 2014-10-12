package Qinu::View;

use Data::Dumper;
use Template;

use base qw(Class::Accessor::Fast);
__PACKAGE__->mk_accessors(qw(qinu));

sub new {
    my ($self, %args) = @_;

    my $qinu = $args{qinu};

    # TemplateToolkit.
    my $template_path;
    if (defined $qinu->conf->{template_path}) {
        $template_path = $qinu->conf->{template_path};
    }
    else {
        $template_path = $qinu->conf->{lib_path} . '/template';
    }

    my $config = {
        INCLUDE_PATH => $template_path,
    };
    my $template = Template->new($config);

    my $attr = {
        qinu => $qinu,
        template => $template,
    };

    bless $attr, $self;
}

sub process {
    my ($self, %args) = @_;

    my $output = defined $args{output} ? $args{output} : '';
    my $values = defined $args{values} ? $args{values} : '';
    my $processed = defined $args{processed} ? $args{processed} : '';

    $self->{template}->process($output, $values, $processed);
}

sub merge_template_variable {
    my ($self, %args) = @_;
    
    if (
        !defined $args{vars} || ref $args{vars} ne 'HASH' ||
        !defined $args{template_variable} || ref $args{template_variable} ne 'HASH' 
    ) { 
        return '';
    }

    my $vars = $args{vars};
    my $template_variable = $args{template_variable};
    my %vars = (%$vars, %$template_variable);
    $vars = \%vars;

    return $vars;
}

sub mk_link_css {
    my ($self, %args) = @_;

    my $css; 
    if (defined $args{css}) {
        $css = $args{css};
    }
    else {
        return '';
    }
    my @css = @$css;

    my $result;
    foreach my $each (@css) {
        if ($each =~ /^(http(?:s)*)\:/) {
            my $protocol_tmp = $1;
            if ($self->{qinu}->current_protocol ne $protocol_tmp) {
                my $protocol;
                if ($self->{qinu}->current_protocol eq 'https') {
                    $protocol = $self->{qinu}->conf->{protocol_secure};
                }
                else {
                    $protocol = $self->{qinu}->conf->{protocol_default};
                }
                $each =~ s/^http(?:s)*\:/${protocol}:/;
            }
        }

        $result .= '<link rel="stylesheet" href="' . $each . '" type="text/css">' . "\n";
    }
    chomp $result;
    return $result;
}

sub mk_link_js {
    my ($self, %args) = @_;
    
    my $js;
    if (defined $args{js}) { 
        $js = $args{js};
    }           
    else {      
        return '';  
    }           
    my @js = @$js;
                    
    my $result; 
    foreach my $each (@js) {
        if ($each =~ /^(http(?:s)*)\:/) {
            my $protocol_tmp = $1;
            if ($self->{qinu}->current_protocol ne $protocol_tmp) {
                my $protocol;
                if ($self->{qinu}->current_protocol eq 'https') {
                    $protocol = $self->{qinu}->conf->{protocol_secure};
                }
                else {
                    $protocol = $self->{qinu}->conf->{protocol_default};
                }
                $each =~ s/^http(?:s)*\:/${protocol}:/;
            }
        }

        $result .= '<script type="text/javascript" src="' . $each . '"></script>' . "\n";
    }
    chomp $result;
    return $result;
}

sub replace_value {
    my ($self, %args) = @_;
        
    my $template = defined $args{template} ? $args{template} : '';
    my $value_ref = defined $args{value} ? $args{value} : '';
    my %value;   
    if ($value_ref eq '' || ref $value_ref ne 'HASH') {
        return $template;
    }           
    else {          
        %value = %$value_ref;
    }           
            
    $template =~ s/\[% (.+?) %\]/$value{$1}/g;
    return $template;
}
       
sub delete_script {
    my ($self, %args) = @_;
    
    my $template = defined $args{template} ? $args{template} : '';
    $template =~ s/\<(?:script(?:\s.*?|)|\/script)\>//sg;

    return $template;
}

sub mk_option_year {
    my ($self, %args) = @_;

    my $keys = [
        'from_year',
    ];
    if (!$self->{qinu}->util->check_args_defined_and_null(keys => $keys, values => \%args)) {
        return;
    }

    my $from_year = $args{from_year};

    my $option;
    $option = $self->{qinu}->http->mk_option_num_base(from_num => $from_year, to_num => $self->{qinu}->{year_current});

    return $option;
}

sub mk_page_link {
    my ($self, %args) = @_;

    my %page_fix = ();

    my @keys = qw(data_all limit page_current);
    if (!$self->qinu->util->check_args_defined_and_null(keys => \@keys, values => \%args)) {
        return %page_fix;
    }

    if (scalar @{$args{data_all}} > $args{page_current} * $args{limit}) {
        $page_fix{page_next} = $args{page_current} + 1;
    }
    if ($args{page_current} > 1) {
        $page_fix{page_prev} = $args{page_current} - 1;
    }

    return %page_fix;
}

1;
