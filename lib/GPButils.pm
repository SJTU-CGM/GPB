#!/usr/bin/perl

package GPButils;

use strict;
use warnings;

sub check_arg {
        my ($param, $in) = @_;
        die "Parameter '$param' not found. Please check your input and try again.\n" if !defined($in);
}

sub check_file {
        my ($param, $in) = @_;
        check_arg($param, $in);
        if($in ne "NULL"){
                die "\"$in\": No such file.\n" if !(-e $in);
        }
}


1;

