package Qinu::View;

use Template;

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
                my $protocol;                if ($self->{qinu}->current_protocol eq 'https') {
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

1;
