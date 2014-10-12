#!/usr/bin/env perl

use strict;
use warnings;

use feature qw(:5.10);

use Qinu;

if (!defined $ARGV[0] || !defined $ARGV[1]) {
    print <<EOD;
usage: ./qinu.pl [create] app_name
EOD
    exit;
}

if ($ARGV[0] eq 'create') {
    my $dir = './' . $ARGV[1];

    if (-d $dir) {
        print <<EOD;
${ARGV[1]} is exists.
EOD
        exit;
    }

    mkdir $dir; 
    mkdir $dir . '/lib';
    mkdir $dir . '/lib/site_lib';
    mkdir $dir . '/lib/site_lib/Qinu';
    mkdir $dir . '/lib/site_lib/Qinu/App';
    mkdir $dir . '/lib/site_lib/Qinu/App/' . ucfirst($ARGV[1]);
    mkdir $dir . '/lib/inc';
    mkdir $dir . '/lib/log';
    mkdir $dir . '/lib//controller';

    my $file_h;

    open $file_h, '>' . $dir . '/index.html';
    close $file_h;

    open $file_h, '>' . $dir . '/.htaccess';
    close $file_h;

    open $file_h, '>' . $dir . '/lib/controller/Controller.pm';
    close $file_h;

    open $file_h, '>' . $dir . '/lib/site_lib/Qinu/App/' . ucfirst($ARGV[1]) . '.pm';
    close $file_h;

    open $file_h, '>' . $dir . '/lib/site_lib/Qinu/App/' . ucfirst($ARGV[1]) . '/Validate.pm';
    close $file_h;
}
else {
    print <<EOD;
${ARGV[0]} is undefined action.
EOD
}
