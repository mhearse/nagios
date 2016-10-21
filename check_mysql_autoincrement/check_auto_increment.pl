#!/usr/bin/perl

# Check tables in db to determine how close they are to 
# the maximum value of numeric data types.

use DBI;
use Getopt::Long;

package check_auto_increment;

######################################################
sub new {
######################################################
    my ($class, $args) = @_; 
    my $self;

    my %opts;
    Getopt::Long::GetOptions(
        \%opts,
        'username=s',
        'password=s',
        'database=s',
        'host=s',
        'critical=i',
        'warning=i',
        'verbose',
    );
    $self->{opts} = \%opts;

    @{$self->{requiredopts}} = qw(
        username
        password
        database
        host
        critical
        warning
    );

    $self->{ERRORS} = {
        OK        => 0,
        WARNING   => 1,
        CRITICAL  => 2,
        UNKNOWN   => 3,
        DEPENDENT => 4,
    };

    # Data structure for numeric data types.  We could roll our
    # own by calculating 2^32 for a 4 byte data type.
    $self->{dt} = {
        'signed' => {
            'tinyint'   => 127,
            'smallint'  => 32767,
            'int'       => 2147483647,
            'mediumint' => 8388607,
            'bigint'    => 9223372036854775807,
        },
        'unsigned' => {
            'tinyint'   => 255,
            'smallint'  => 65535,
            'int'       => 4294967295,
            'mediumint' => 16777215,
            'bigint'    => 18446744073709551615,
        },
    };

    # DBI connect attributes
    $self->{dbiattr} = {
        RaiseError => 1,
        AutoCommit => 0,
    }; 

    $self->{tablecount} = 0;
    $self->{output} = '';
    $self->{alert} = 'OK';

    bless $self, $class;
    $self->validateArgs();
    return $self;
}

######################################################
sub initMySQL {
######################################################
    my $self = shift;

    $self->{dbh} = DBI->connect(
        sprintf(
            "DBI:mysql:%s:%s",
            $self->{opts}{database},
            $self->{opts}{host},
        ),
        $self->{opts}{username},
        $self->{opts}{password},
        $self->{dbiattr},
    ) or die $!;
}

######################################################
sub disconnetctMySQL {
######################################################
    my $self = shift;
    $self->{dbh}->disconnect();
}

######################################################
sub validateArgs {
######################################################
    my $self = shift;
    # All options are required.
    for my $opt (@{$self->{requiredopts}}) {
        if (!$self->{opts}{$opt}) {
            $self->{output} = 'Required arguments missing';
            $self->{alert} = 'CRITICAL';
            $self->output();
        }
    }
}

######################################################
sub output {
######################################################
    my $self = shift;
    my %tables = %{$self->{tables}};

    my ($max_table, $max_percent);
    for my $table (keys %tables) {
        if ($tables{$table} > $max_percent) {
            $max_table = $table;
            $max_percent = $tables{$table};
        }
    }

    if (!$self->{output}) {
        if ($max_table) {
            $self->{output} = sprintf(
                "All %s tables with auto increment columns are within limits.  Max table %s: %s%% | %s = %s%%",
                $self->{tablecount},
                $max_table,
                $tables{$max_table},
                $max_table,
                $tables{$max_table},
            );
        }
        else {
            $self->{output} = sprintf(
                "All %s tables with auto increment columns are within limits.  All tables: 0%%",
                $self->{tablecount},
            );
        }
    }
    printf("%s - %s", $self->{alert}, $self->{output});
    exit $self->{ERRORS}{$self->{alert}};
}

######################################################
sub fetchTables {
######################################################
    my $self = shift;
    my $sth = $self->{dbh}->prepare('SHOW TABLES');
    $sth->execute();
    while (my ($table) = $sth->fetchrow_array()) {
        $self->{tables}{$table} = 0;
    }
}

######################################################
sub checkAutoIncrementColumns {
######################################################
    my $self = shift;
    for my $table (keys %{$self->{tables}}) {
        my $sth = $self->{dbh}->prepare("DESC $table");
        $sth->execute();
        while ( my $rec = $sth->fetchrow_hashref() ) {
            if ($rec->{Extra} eq "auto_increment") {
               $self->{tablecount}++;
                my $sth = $self->{dbh}->prepare(
                    sprintf(
                        "SELECT MAX(%s) FROM %s",
                        $rec->{Field},
                        $table,
                    )
                );
                $sth->execute();
                my ($maxrowid) = $sth->fetchrow_array();
        
                my $datatype = $rec->{Type};
                $datatype =~ s/\(.*//;
                $datatype = lc($datatype);
                my $signed = 'signed';
                if ($rec->{Type} =~ /unsigned/i) {
                    $signed = 'unsigned';
                }

                my $float = ($maxrowid / $self->{dt}{$signed}{$datatype}) * 100;
                my $rounded = int($float + 0.5);
                $self->{tables}{$table} = $rounded;
                my $message = sprintf(
                    "%s.%s: %s%%  ",
                    $self->{opts}{database},
                    $table,
                    $rounded,
                );
                if ($self->{opts}{verbose}) {
                    print $message;
                }
                if ($self->{alert} ne 'CRITICAL') {
                    if ($rounded > $self->{opts}{critical}) {
                        $self->{alert} = 'CRITICAL';
                        $self->{output} .= $message;
                    }
                    elsif ($rounded > $self->{opts}{warning}) {
                        $self->{alert} = 'WARNING';
                        $self->{output} .= $message;
                    }
                }
            }
        }
    }
}

1;

# Do the work.
my $obj = check_auto_increment->new();
$obj->initMySQL();
$obj->fetchTables();
$obj->checkAutoIncrementColumns();
$obj->disconnetctMySQL();
$obj->output();
