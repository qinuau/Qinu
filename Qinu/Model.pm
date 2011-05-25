package Qinu::Model;

use DBI;
use Data::Dumper;

use strict;
use warnings;

our $qinu;
our $db_log;

sub new {
    my $self = shift;
    $qinu = shift;
    bless {}, $self;
}

sub db_connect {
    my ($self, %args) = @_;

    my $dbd = $args{dbd} ||= $qinu->{conf}{dbd} or die "undefined dbd..";
    my $db_name = $args{db_name} ||= $qinu->{conf}{db_name} or die "udefind db_name..";
    my $db_user = $args{db_user} ||= $qinu->{conf}{db_user} or die "undefined db_user";
    my $db_passwd = $args{db_passwd} ||= $qinu->{conf}{db_passwd} or die "undefined db_passwd";
    my $db_host = $args{db_host} ||= $qinu->{conf}{db_host} ||= "localhost";
    my $db_port;
    if ($args{db_port}) {
        $db_port = $args{db_port};
    }
    elsif ($qinu->{conf}{db_port}) {
        $db_port = $qinu->{conf}{db_port};
    }
    else {
        if ($dbd =~ /^mysql$/i) {
            $db_port = 3306;
        }
        elsif ($dbd =~ /^Pg$/i) {
            $db_port = 5432;
        }
    }
    my $transaction ||= $args{transaction} ||= $qinu->{conf}{transaction} ||= 0;
    my $db_encoding ||= $args{db_encoding} ||= $qinu->{conf}{db_encoding} ||= "utf8";
    $db_log = defined $args{db_log} ? $args{db_log} : $qinu->{conf}{db_log};
    my $conf_file ||= $args{conf_file};

    my $dsn = '';
    my $dbh = '';

    if ($dbd =~ /^(mysql|Pg)$/i) {
        if ($dbd =~ /^mysql$/i) {
            $dbd = 'mysql';
        }
        elsif ($dbd =~ /^Pg$/i) {
            $dbd = 'Pg';
        }
        $dsn = "dbi:$dbd:database=$db_name;host=$db_host;port=$db_port";
    }
    elsif ($dbd =~ /^SQLite$/i) {
        $dbd = 'SQLite';
        $dsn = "dbi:$dbd:dbname=$db_name";
    }
    else {
        die 'wrong dbi..';
        return 0;
    }

    eval { $dbh = DBI->connect($dsn, $db_user, $db_passwd, {PrintError => 1}) };
    #$dbh->{AutoCommit} = $transaction;

    # exception
    if (!$dbh && defined $args{error_call_back} && ref $args{error_call_back} eq 'CODE') {
        $args{error_call_back}->($qinu); 
    }
    elsif (!$dbh) {
        #$qinu->http->header();
        #print "Connect failed.";
        return 0;
    }

    if ($dbh && $dbd eq 'mysql') {
        $self->db_exec(sql => 'SET NAMES ' . $db_encoding, dbh => $dbh);
    }
    $self->db_logging(sth => $dbh, sql => 'DB CONNECT');

    return $dbh;
}

sub db_logging {
    my ($self, %conf) = @_;

    if (!defined $qinu->{conf}{db_logging_f} || !$qinu->{conf}{db_logging_f}) {
        return 0;
    }

    my $sth = $conf{sth};
    my $sql = $conf{sql};
    my $select_f;
    if (defined $conf{select_f}) {
        $select_f = $conf{select_f};
    }

    my $connect_f;
    if (defined $conf{connect_f}) {
        $connect_f = $conf{connect_f};
    }

    my $set_f;
    if (defined $conf{set_f}) {
        $set_f = $conf{set_f};
    }

    # ロギング条件
    my $excludes;
    if (!$select_f) {
        $excludes .= $excludes ? '|' : '';
        $excludes .= '^SELECT';
    }
    if (!$connect_f) {
        $excludes .= $excludes ? '|' : '';
        $excludes .= '^DB CONNECT';
    }
    if (!$set_f) {
        $excludes .= $excludes ? '|' : '^';
        $excludes .= '^SET';
    }
    

    if ($sql !~ /$excludes/) {
        my ($sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst) = localtime(time());
        $mon += 1;
        $year += 1900;
        if ($mon =~ /^\d{1}$/) {
            $mon = '0' . $mon;
        }
        if ($mday =~ /^\d{1}$/) {
            $mday = '0' . $mday;
        }
    
        my $lock_file = $db_log . '/lock_db_logging';
        while (1) {
            if (-f $lock_file) {
                sleep 1;
            }
            else {
                last;
            }
        }
        open my $fileh_lock, '>' . $lock_file;

        my $log_file_name = $year . '_' . $mon . '_' . $mday . '_sql_log';

        if ($db_log && open DB_LOGGING_FILE, '>>' . $db_log . '/' . $log_file_name) {
            my $state = '';
            my $errstr = '';
            if ($DBI::errstr) {
                $state = 'error';
                $errstr = $DBI::errstr;
            }
            else {
                $state = 'success';
            }
            print DB_LOGGING_FILE '[' . $year . '/' . $mon . '/' . $mday . ' ' . $hour . ':' . $min . ':' . $sec . '][' . $state . ']' . $sql . ' ' . $errstr . "\n";
            close DB_LOGGING_FILE;
        }
        close $lock_file;
        unlink $lock_file;
    }
    else {
        return 0;
    }
}

sub db_exec {
    my ($self, %args) = @_;
    my $sql = $args{sql};
    my $dbh ||= $args{dbh} ||= $args{con};

    if (defined $qinu->{auto_commit} && $qinu->{auto_commit} == 0) {
        $dbh->begin_work;
    }
    my $sth;
    $sth = $dbh->prepare($sql) or $self->db_logging(sth => $sth, sql => $sql);
    $sth->execute;
    if ($qinu->{auto_commit} && $qinu->{auto_commit} == 0) {
        if (defined $DBI::errstr) {
            $dbh->rollback;
        }
        else {
            $dbh->commit;
        }
    }
    $self->db_logging(sth => $sth, sql => $sql, %args);

    if (defined $DBI::errstr && defined $args{error_call_back} && ref $args{error_call_back} eq 'CODE') {
        $args{error_call_back}->($qinu);
    }
    elsif (defined $DBI::errstr) {
        #$qinu->http->header();
        #print $DBI::errstr;
    }

    return $sth;
}

sub db_query {
    my ($self, %args) = @_;
    my $sth = $self->db_exec(%args);
    return $sth;
}

sub db_fetch {
    my ($self, %args) = @_;

    my $sth = $args{sth};
    my @val;

    while (my $val = $sth->fetchrow_hashref) {
        push(@val, $val);
    }
    #$sth->finish;
    if (wantarray) {
        return @val;
    }
    else {
        return \@val;
    }
}

sub db_fetch_simple {
    my ($self, %args) = @_;

    my $sql = $args{sql};
    my $dbh = $args{dbh} ||= $args{con};
    my $error_call_back = defined $args{error_call_back} ? $args{error_call_back} : '';

=cut
    my $sth = $dbh->prepare($sql);
    $sth->execute;
=cut

    my $sth = $self->db_exec(sql => $sql, dbh => $dbh, error_call_back => $error_call_back, %args);
    if ($sth->err) {
        return 0;
    }

    my $val;
    my @val;
    while ($val = $sth->fetchrow_hashref) {
        push(@val, $val);
    }
    #$sth->finish;
    if (wantarray) {
        return @val;
    }
    else {
        return \@val;
    }
}

1;
