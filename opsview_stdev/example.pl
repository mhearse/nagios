#!/usr/bin/env perl

use strict;
use opsview_stdev;

my %args = ( 
    apiusername  => opsview_username,
    apipassword  => opsview_password,
    hostname     => $HOSTADDRESS$,
    servicecheck => name of service check with perf data,
    metric       => metric name within stored opsview perf data,
    duration     => duration of perf data to retrieve,
    url_prefix   => opsview url,
);  

my $obj = opsview_stdev->new(\%args);
my $ds = $obj->fetchHSM();
my @values = values %{$ds};

my ($stdev, $average) = $obj->calculateStdev(\@values);
my $upper_thold = sprintf("%.2f", ($average + ($stdev * 2)));
my $lower_thold = sprintf("%.2f", ($average - ($stdev * 2)));
if ($lower_thold < 0) {
    $lower_thold = 0.00;
}

# We now have upper and lower thresholds.
