#!/usr/bin/perl
# script to find where we're using what variables in our matlab stuff here.
use warnings;
use strict;


foreach ( @ARGV ) {
    
    print $_."\n" ;#$varhash{$_}\n";
    my $out=`find . -iname "*.m" -exec grep -HE '.*data_buffer[.](input_)?headfile[.]$_.*' {} '\;'`;
    print $out;
}
