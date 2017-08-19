package Qinu::Aggregate::Yahoo;

use feature qw(:5.10);
use CGI::Simple;
use Data::Dumper;
use DateTime;
use Encode;
use HTML::TreeBuilder;
use LWP::UserAgent;

sub new {
    my ($self, %args) = @_;

    my $attr = {

    };

    bless $attr, $self;
}

sub get_data {
    my ($self, %args) = @_;

    my $dt_now = DateTime->now();
    my ($year_now, $month_now, $day_now) = split(':', $dt_now->ymd(":"));

    my $keyword;
    if (!defined $args{keyword} || $args{keyword} eq '') {
        return;
    }
    else {
        $keyword = $args{keyword};
    }

    my $cgi_simple = CGI::Simple->new();
    
    my $url = $self->{url} . $cgi_simple->url_encode($keyword);

    my $ua = LWP::UserAgent->new();
    
    $res =  $ua->get($url);
    my $html =  $res->decoded_content;

    $tree = HTML::TreeBuilder->new_from_content($html);
    
    my @data_fix;
    for my $data ($tree->look_down("class", "l cf")) {
        my @divs;
        eval { @divs = $data->find("_tag", "div") };
        if (!$@) {
            my $i = 0;
            for my $div (@divs) {
                if ($i % 2 != 0) {
                    $i += 1;
                    next;
                }

                my $date_each;
                my $url_each;
                my $title_each;
                my $title_each_tmp;
                my $detail_each;

                $title_each_tmp = $div->as_text;

                if (Encode::is_utf8($title_each_tmp)) {
                    $title_each_tmp = Encode::encode_utf8($title_each_tmp);
                }

                my $abbreviation_code = '';

                if ($title_each_tmp =~ /…/) {
                    $abbreviation_code = '…';
                }
                elsif ($title_each_tmp =~ / ... /) {
                    $abbreviation_code = ' ... ';
                }

                my ($title_each, $detail_each) = split $abbreviation_code, $title_each_tmp;
    
                my @spans = $div->look_down("_tag", "span", "class", "d");
                $date_each = $spans[0]->as_text;
                if (Encode::is_utf8($date_each)) {
                    $date_each = Encode::encode_utf8($date_each);
                }

                $date_each =~ /(\d+)月/;
                my $month = sprintf("%02d", $1);

                $date_each =~ /(\d+)日/;
                my $day = sprintf("%02d", $1);

                $date_each =~ /(\d+)時/;
                my $hour = sprintf("%02d", $1);

                $date_each =~ /(\d+)分/;
                my $minute = sprintf("%02d", $1);

                $date_each_fix = $year_now . "-" . $month . "-" . $day . " " . $hour . ":" . $minute . ":00";

                my @urls = $div->look_down("_tag", "a");

                $url_each = $urls[0]->{href} if $urls[0]->{href} ne '';
    
                push @data_fix, {title => $title_each, link => $url_each, date => $date_each_fix};
                $i += 1;
            }
        }
    }
    
    return @data_fix;
}

1;
