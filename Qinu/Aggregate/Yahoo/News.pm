package Qinu::Aggregate::Yahoo::News;

use base Qinu::Aggregate::Yahoo;

use feature qw(:5.10);
use CGI::Simple;
use Data::Dumper;
use Encode;
use HTML::TreeBuilder;
use LWP::UserAgent;

sub new {
    my ($self, %args) = @_;

    my $args_b;
    if (defined $args{b} && $args{b} =~ /^\d+$/) {
        $args_b = $args{b};
    }
    else {
        $args_b = 1;
    }

    my $attr = {
        url => 'http://news.search.yahoo.co.jp/search?fr=news_sw&ei=UTF-8&pstart=1&b=' . $args_b . '&p=',
    };

    bless $attr, $self;
}

1;
