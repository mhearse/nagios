#!/usr/bin/env perl

use strict;

use lib '/usr/local/nagios/lib';
use lib '/usr/local/nagios/perl/lib';

use JSON;
use Opsview::API;

package opsview_stdev;

######################################################
sub new {
######################################################
    my ($class, $args) = @_; 
    my $self;

    # Put passed arguments into object.
    $self->{args} = $args;

    @{$self->{requiredargs}} = qw(
        apiusername
        apipassword
        hostname
        servicecheck
        metric
        duration
        url_prefix
    );

    # Exit codes.
    $self->{ERRORS} = {
        OK        => 0,
        WARNING   => 1,
        CRITICAL  => 2,
        UNKNOWN   => 3,
        DEPENDENT => 4,
    };

    # Canned performance data metric command.
    $self->{cmd} = "graph?hsm=%s::%s::%s&duration=%s";

    bless $self, $class;

    # As part of this module's constructor, we will ensure 
    # the human caller provided the necessary arguments.
    $self->validateArgs();

    # Initialize Opsview API
    $self->initOpsviewAPI();

    return $self;
}

######################################################
sub validateArgs {
######################################################
    my $self = shift;
    my @missing_args;
    for my $arg (@{$self->{requiredargs}}) {
        if (! $self->{args}{$arg}) {
            push @missing_args, $arg;
        }
    }
    if (@missing_args) {
        printf(
            "opsview_stdev::validateArgs, Required arguments missing: %s",
            join(', ', @missing_args),
        );
        exit $self->{ERRORS}{CRITICAL};
    }
}

######################################################
sub initOpsviewAPI {
######################################################
    my $self = shift;
    my %args = %{$self->{args}};

    my $api = Opsview::API->new(
        username        => $args{apiusername},
        password        => $args{apipassword},
        api_min_version => "2",
        url_prefix      => $args{url_prefix},
        data_format     => "json",
    ) or die $!;
    $api->login() or die $!;
    $self->{api} = $api;
}

######################################################
sub output {
######################################################
    my $self = shift;
    print "IN OUTPUT\n";
}

######################################################
sub fetchHSM {
######################################################
    my $self = shift;
    my %args = %{$self->{args}};

    # If human hasn't passed a command, we will populate
    # our canned performance data metric command.
    my $cmd = sprintf(
        $self->{cmd},
        $args{hostname},
        $args{servicecheck},
        $args{metric},
        $args{duration}
    );

    $self->{api}->get($cmd);
    my $results = $self->{api}->content();
    $results =~ s/'/"/g;
    $results =~ s/=>/:/g;
    my $json = JSON->new->allow_nonref();
    my $ds = $json->decode($results);

    my %dataset;
    for my $elmt (@{$ds->{list}[0]{data}}) {
        if ($elmt->[1]) {
            $dataset{$elmt->[0]} = $elmt->[1];
        }
    }
    return \%dataset;
}

######################################################
sub calculateStdev {
######################################################
    my $self = shift;
    my $data = shift;
    if (! $data || (ref $data) != 'ARRAY') {
        print "opsview_stdev::calculateStdev, No data passed to method";
        exit $self->{ERRORS}{CRITICAL};
    }
    my $average = $self->calculateAverage($data);
    return 0 if ! $average;
    my $sqtotal = 0;
    for my $elmt (@$data) {
        $sqtotal += ($average - $elmt) ** 2;
    }
    my $std = ($sqtotal / (@$data-1)) ** 0.5;
    return ($std, $average);
}

######################################################
sub calculateAverage {
######################################################
    my $self = shift;
    my $data = shift;
    if (! $data || (ref $data) != 'ARRAY') {
        print "opsview_stdev::calculateAverage, No data passed to method";
        exit $self->{ERRORS}{CRITICAL};
    }
    my $total = 0;
    for my $elmt (@{$data}) {
        $total += $elmt;
    }
    if (@$data) {
        my $average = $total / @$data;
        return $average;
    }
    else {
        return 0;
    }
}

1;
