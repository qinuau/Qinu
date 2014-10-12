package Qinu::Model;

use strict;
use warnings;

use DBI;
use Data::Dumper;
use DateTime;

use base qw(Class::Accessor::Fast);

__PACKAGE__->mk_accessors(qw(qinu));

our $qinu;
our $db_log;

sub new {
    my $self = shift;
    $qinu = shift;

    my $attr = {
        qinu => $qinu,
    };

    bless $attr, $self;
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
    if (defined $self->qinu->conf->{db_logging_select_f} && $self->qinu->conf->{db_logging_select_f}) {
        $select_f = $self->qinu->conf->{db_logging_select_f};
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
    my $rv = $sth->execute;
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

    my $val = [];
    my @val = ();
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

sub get_data_base {
    my ($self, %args) = @_;

    my $table;
    if (defined $args{table} && $args{table} ne '') {
        $table = $args{table};
    }
    else {
        return [];
    }

    my $limit = "";
    if (defined $args{limit} && defined $args{offset} && $args{limit} ne '' && $args{offset} ne '') {
        $limit = ' LIMIT ' . $args{offset} . ', ' . $args{limit};
    }
    elsif (defined $args{limit} && $args{limit} ne '') {
        $limit = ' LIMIT ' . $args{limit};
    }

    my $where = defined $args{where} && $args{where} ne '' ? " WHERE " . $args{where} : '';
    my $having = defined $args{having} && $args{having} ne '' ? " HAVING " . $args{having} : '';
    my $orderby = defined $args{orderby} && $args{orderby} ne '' ? ' ORDER BY ' . $args{orderby} : '';

    my $dbh;
    if (defined $args{dbh} && $args{dbh}) {
        $dbh = $args{dbh};
    }
    else {
        return [];
    }

    my $select = '*';
    if (defined $args{select} && $args{select} ne '') {
        $select = $args{select};
    }

    my $sql = "SELECT " . $select . " FROM " . $table . $where . $having . $orderby . $limit;
    my $data = $self->db_fetch_simple(dbh => $dbh, sql => $sql);

    return $data;
}

sub mk_regist_data {
    my ($self, %args) = @_;

    my $key_str = defined $args{key_str} ? $args{key_str} : [];
    my $key_num = defined $args{key_num} ? $args{key_num} : [];
    my $type = defined $args{type} ? $args{type} : '';

    my $data;
    my %data;
    if (defined $args{data} && ref $args{data} eq 'HASH') {
        $data = $args{data};
        %data = %$data;
    }
    else {
        return;
    }

    my $dbh;
    if (!defined $args{dbh} || !$args{dbh}) {
        return;
    }
    else {
        $dbh = $args{dbh};
    }

    my $sql;
    my $sql_key;
    my $sql_val;

    # type of string.
    if (scalar @$key_str > 0) {
        foreach my $key (@$key_str) {
            if ($type eq 'update') {
                $sql .= $key . ' = ';
                if (defined $data{$key}) {
                    $sql .= $dbh->quote($data{$key});
                }
                else {
                    $sql .= "NULL";
                }
                $sql .= ", ";
            }
            else {
                $sql_key .= $key . ', ';
                if (defined $data{$key}) {
                    $sql_val .= $dbh->quote($data{$key});
                }
                else {
                    $sql_val .= "NULL";
                }
                $sql_val .= ", ";
            }
        }
    }

    # type of numeric.
    if (scalar @$key_num > 0) {
        foreach my $key (@$key_num) {
            if ($type eq 'update') {
                $sql .= $key . ' = ';
                if (defined $data{$key} && $data{$key} ne '') {
                    $sql .= $data{$key};
                }
                else {
                    $sql .= "NULL";
                }
                $sql .= ", ";
            }
            else {
                $sql_key .= $key . ', ';
                if (defined $data{$key} && $data{$key} ne '') {
                    $sql_val .= $data{$key};
                }
                else {
                    $sql_val .= "NULL";
                }
                $sql_val .= ", ";
            }
        }
    }

    if ($type eq 'update') {
        if ($sql) {
            $sql = substr($sql, 0, -2);
        }
    }
    else {
        if ($sql_key ne '') {
            $sql_key = substr($sql_key, 0, -2);
            $sql_val = substr($sql_val, 0, -2);

            $sql->{key} = $sql_key;
            $sql->{val} = $sql_val;
        }
    }

    return $sql;
}

sub sql_publish_span {
    my ($self, %args) = @_;

    my $dt = DateTime->now();
    $dt->set_time_zone($self->qinu->conf->{time_zone});

    my $ymdhms = $dt->ymd('-') . ' ' . $dt->hms(':');

    my $sql;
    $sql = "publish_start <= '" . $ymdhms . "' AND (publish_end IS NULL OR publish_end > '" . $ymdhms . "')";

    return $sql;
}

sub quote_like {
    my ($self, %args) = @_;

    my $value = $args{value};

    $value =~ s/(%|_)/\\$1/g;

    return $value;
}

sub mk_sql {
    my ($self, %args) = @_;

    if (
        !defined $args{type} || $args{type} eq '' ||
        $args{type} !~ /^(insert|update)$/ || 
        !defined $args{table_name} || $args{table_name} eq '' || 
        #(
        #    (!defined $args{fields_string} || scalar @{$args{fields_string}} == 0) && 
        #    (!defined $args{fields_num} || scalar @{$args{fields_num}} == 0) && 
        #    (!defined $args{fields_bool} || scalar @{$args{fields_bool}} == 0) && 
        #    (!defined $args{add_data_string} || scalar @{$args{add_data_string}} == 0) && 
        #    (!defined $args{add_data_num} || scalar @{$args{add_data_num}} == 0) && 
        #    (!defined $args{add_data_bool} || scalar @{$args{add_data_bool}} == 0)
        #) ||
        !defined $args{dbh} || !$args{dbh}
    ) {
        return 0;
    }

    my $type = $args{type};
    my $table_name = $args{table_name};
    my $fields_string = defined $args{fields_string} ? $args{fields_string} : ();
    my $fields_num = defined $args{fields_num} ? $args{fields_num} : ();
    my $fields_bool = defined $args{fields_bool} ? $args{fields_bool} : ();
    my $fields_datetime = defined $args{fields_datetime} ? $args{fields_datetime} : ();
    my $fields_date = defined $args{fields_date} ? $args{fields_date} : ();
    my $fields_time = defined $args{fields_time} ? $args{fields_time} : ();
    my $data = defined $args{data} ? $args{data} : ();
    my $add_data_string = defined $args{add_data_string} ? $args{add_data_string} : ();
    my $add_data_num = defined $args{add_data_num} ? $args{add_data_num} : ();
    my $add_data_bool = defined $args{add_data_bool} ? $args{add_data_bool} : ();
    my $sql_add = defined $args{sql_add} ? $args{sql_add} : '';
    my $config_form = defined $args{config_form} ? $args{config_form} : ();
    my $dbh = $args{dbh};

    my $quote_key = '';
    if ($self->qinu->conf->{dbd} eq 'mysql') {
        $quote_key = "`";
    }

    my $sql = "";
    if ($type =~ /^insert$/) {
        my $keys = '';
        my $vals = '';
        $sql = "INSERT INTO " . $quote_key . $table_name . $quote_key;

        foreach my $key (@$fields_string) {
            if (defined $data->{$key}) {
                $keys .= $quote_key . $key . $quote_key . ", ";
    
                my $v_data = '';
                if (ref $data->{$key} eq 'ARRAY') {
                    foreach my $v_value (@{$data->{$key}}) {
                        $v_data .= '+' . $v_value;
                    }
                    if ($v_data ne '') {
                        $v_data .= '+';
                    }
                }
                else {
                    $v_data = $data->{$key};
                }

                my $value = $v_data;
                $vals .= $dbh->quote($value) . ", ";
            }
            elsif ($key =~ /^datetime_(reg|create)$/) {
                $keys .= $quote_key . $key . $quote_key . ", ";

                my $dt = DateTime->now;
                $dt->set_time_zone($self->qinu->conf->{time_zone});
                my $datetime_reg = $dt->ymd . " " . $dt->hms;
                $vals .= $dbh->quote($datetime_reg) . ", ";
                $self->{datetime_reg} = $datetime_reg;
            }
        }
        foreach my $key (@$fields_num) {
            if (defined $data->{$key}) {
                $keys .= $quote_key . $key . $quote_key . ", ";
    
                my $value = $data->{$key};
    		$vals .= $value . ", ";
            }
        }
        foreach my $key (@$fields_bool) {
            if (defined $data->{$key} && $data->{$key}) {
                $keys .= $quote_key . $key . $quote_key . ", ";
                if ($data->{$key}) {
                    $vals .= "TRUE, ";
                }
                else {
                    $vals .= "FALSE, ";
                }
            }
        }

        foreach my $key (@$add_data_string) {
            if (defined $data->{$key}) {
                $keys .= $quote_key . $key . $quote_key . ", ";

                my $v_data = '';
                if (ref $data->{$key} eq 'ARRAY') {
                    foreach my $v_value (@{$data->{$key}}) {
                        $v_data .= '+' . $v_value;
                    }
                    if ($v_data ne '') {
                        $v_data .= '+';
                    }
                }
                else {
                    $v_data = $data->{$key};
                }

                my $value = $v_data;
                $vals .= $dbh->quote($value) . ", ";
            }
        }
        foreach my $key (@$add_data_num) {
            if (defined $data->{$key}) {
                $keys .= $quote_key . $key . $quote_key . ", ";

                my $value = $data->{$key};
                $vals .= $value . ", ";
            }
        }
        foreach my $key (@$add_data_bool) {
            if (defined $data->{$key}) {
                $keys .= $quote_key . $key . $quote_key . ", ";
                if ($data->{$key}) {
                    $vals .= "TRUE, ";
                }
                else {
                    $vals .= "FALSE, ";
                }
            }
        }

        foreach my $key (@$fields_datetime) {
            $keys .= $quote_key . $key . $quote_key . ", ";

            if (
                defined $data->{$key . '_year'} && $data->{$key . '_year'} ne '' &&
                defined $data->{$key . '_month'} && $data->{$key . '_month'} ne '' &&
                defined $data->{$key . '_day'} && $data->{$key . '_day'} ne '' && 
                defined $data->{$key . '_hour'} && $data->{$key . '_hour'} ne '' &&
                defined $data->{$key . '_minute'} && $data->{$key . '_minute'} ne '' && 
                defined $data->{$key . '_second'} && $data->{$key . '_second'} ne ''
            ) {
                $vals .= "'" . sprintf('%04d', $data->{$key . '_year'}) . "-" . sprintf('%02d', $data->{$key . '_month'}) . "-" . sprintf('%02d', $data->{$key . '_day'}) . " " . sprintf('%02d', $data->{$key . '_hour'}) . ":" . sprintf('%02d', $data->{$key . '_minute'}) . ":" . sprintf('%02d', $data->{$key . '_second'}) . "', ";
            }
            else {
                $vals .= "NULL, ";
            }
        }

        foreach my $key (@$fields_date) {
            $keys .= $quote_key . $key . $quote_key . ", ";

            if (
                defined $data->{$key . '_year'} && $data->{$key . '_year'} ne '' &&
                defined $data->{$key . '_month'} && $data->{$key . '_month'} ne '' &&
                defined $data->{$key . '_day'} && $data->{$key . '_day'} ne ''
            ) {
                $vals .= "'" . sprintf('%04d', $data->{$key . '_year'}) . "-" . sprintf('%02d', $data->{$key . '_month'}) . "-" . sprintf('%02d', $data->{$key . '_day'}) . "', ";
            }
            else {
                $vals .= "NULL, ";
            }
        }

        foreach my $key (@$fields_time) {
            $keys .= $quote_key . $key . $quote_key . ", ";

            if (
                defined $data->{$key . '_hour'} && $data->{$key . '_hour'} ne '' &&
                defined $data->{$key . '_minute'} && $data->{$key . '_minute'} ne '' &&
                defined $data->{$key . '_second'} && $data->{$key . '_second'} ne ''
            ) {
                $vals .= "'" . sprintf('%02d', $data->{$key . '_hour'}) . ":" . sprintf('%02d', $data->{$key . '_minute'}) . ":" . sprintf('%02d', $data->{$key . '_second'}) . "', ";
            }
            else {
                $vals .= "NULL, ";
            }
        }

        if ($keys || $vals) {
            $keys = substr($keys, 0, -2);
            $vals = substr($vals, 0, -2);
        }
        $sql = $sql . " (" . $keys . ") VALUES(" . $vals . ")";
    }
    elsif ($type =~ /^update$/) {
        $sql = "UPDATE " . $quote_key . $table_name . $quote_key . " SET ";
        foreach my $key (@$fields_string) {
            if ($key =~ /^datetime_(reg|create)$/) {
                next;
            }

            if (defined $data->{$key}) {
                my $v_data = '';

                if (ref $data->{$key} eq 'ARRAY') {
                    foreach my $v_value (@{$data->{$key}}) {
                        $v_data .= '+' . $v_value;
                    }
                    if ($v_data ne '') {
                        $v_data .= '+';
                    }
                }
                else {
                    $v_data = $data->{$key};
                }

                $sql .= $quote_key . $key . $quote_key . "=";

                my $value = $v_data;
                $sql .= $dbh->quote($value) . ", ";
            }
            elsif ($key eq 'datetime_update') {
                $sql .= $quote_key . $key . $quote_key . "=";

                my $dt = DateTime->now;
                $dt->set_time_zone($self->qinu->conf->{time_zone});
                my $datetime_update = $dt->ymd . " " . $dt->hms;
                $sql .= "'" . $datetime_update . "', ";
            }
        }
        foreach my $key (@$fields_num) {
            if (defined $data->{$key}) {
                $sql .= $quote_key . $key . $quote_key . "=";
    
                my $value = $data->{$key};
                $sql .= $value . ", ";
            }
        }
        foreach my $key (@$fields_bool) {
            if (defined $data->{$key}) {
                $sql .= $quote_key . $key . $quote_key . "=";
                if (defined $data->{$key} && $data->{$key}) {
                    $sql .= "TRUE, ";
                }
                else {
                    $sql .= "FALSE, ";
                }
            }
        }

        foreach my $key (@$add_data_string) {
            if (defined $data->{$key}) {
                $sql .= $quote_key . $key . $quote_key . "=";
                my $v_data = '';

                if (ref $data->{$key} eq 'ARRAY') {
                    foreach my $v_value (@{$data->{$key}}) {
                        $v_data .= '+' . $v_value;
                    }
                    if ($v_data ne '') {
                        $v_data .= '+';
                    }
                }
                else {
                    $v_data = $data->{$key};
                }

                $sql .= $quote_key . $key . $quote_key . "=";

                my $value = $v_data;
                $sql .= $dbh->quote($value) . ", ";
            }
        }
        foreach my $key (@$add_data_num) {
            if (defined $data->{$key}) {
                $sql .= $quote_key . $key . $quote_key . "=";

                my $value = $data->{$key};
                $sql .= $value . ", ";
            }
        }
        foreach my $key (@$add_data_bool) {
            if (defined $data->{$key}) {
                $sql .= $quote_key . $key . $quote_key . "=";
                if ($data->{$key}) {
                    $sql .= "TRUE, ";
                }
                else {
                    $sql .= "FALSE, ";
                }
            }
        }

        foreach my $key (@$fields_datetime) {
            if (
                defined $data->{$key . '_year'} && $data->{$key . '_year'} ne '' &&
                defined $data->{$key . '_month'} && $data->{$key . '_month'} ne '' &&
                defined $data->{$key . '_day'} && $data->{$key . '_day'} ne '' &&
                defined $data->{$key . '_hour'} && $data->{$key . '_hour'} ne '' &&
                defined $data->{$key . '_minute'} && $data->{$key . '_minute'} ne '' &&
                defined $data->{$key . '_second'} && $data->{$key . '_second'} ne ''
            ) {
                $sql .= $quote_key . $key . $quote_key . " = '" . sprintf('%04d', $data->{$key . '_year'}) . "-" . sprintf('%02d', $data->{$key . '_month'}) . "-" . sprintf('%02d', $data->{$key . '_day'}) . " " . sprintf('%02d', $data->{$key . '_hour'}) . ":" . sprintf('%02d', $data->{$key . '_minute'}) . ":" . sprintf('%02d', $data->{$key . '_second'}) . "', ";
            }
            else {
                $sql .= $quote_key . $key . $quote_key . " = NULL, ";
            }
        }

        foreach my $key (@$fields_date) {
            if (
                defined $data->{$key . '_year'} && $data->{$key . '_year'} ne '' &&
                defined $data->{$key . '_month'} && $data->{$key . '_month'} ne '' &&
                defined $data->{$key . '_day'} && $data->{$key . '_day'} ne ''
            ) {
                $sql .= $quote_key . $key . $quote_key . " = '" . sprintf('%04d', $data->{$key . '_year'}) . "-" . sprintf('%02d', $data->{$key . '_month'}) . "-" . sprintf('%02d', $data->{$key . '_day'}) . "', ";
            }
            else {
                $sql .= $quote_key . $key . $quote_key . " = NULL, ";
            }
        }

        foreach my $key (@$fields_time) {
            if (
                defined $data->{$key . '_hour'} && $data->{$key . '_hour'} ne '' &&
                defined $data->{$key . '_minute'} && $data->{$key . '_minute'} ne '' &&
                defined $data->{$key . '_second'} && $data->{$key . '_second'} ne ''
            ) {
                $sql .= $quote_key . $key . $quote_key . " = '" . sprintf('%02d', $data->{$key . '_hour'}) . ":" . sprintf('%02d', $data->{$key . '_minute'}) . ":" . sprintf('%02d', $data->{$key . '_second'}) . "', ";
            }
            else {
                $sql .= $quote_key . $key . $quote_key . " = NULL, ";
            }
        }

        if ($sql =~ /^.*, $/) {
            $sql = substr($sql, 0, -2);
        }
    }

    return $sql;
}

1;
