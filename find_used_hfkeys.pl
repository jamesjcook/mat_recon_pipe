#!/usr/bin/perl
# script to find where we're using what variables in our matlab stuff here.
use warnings;
use strict;
#my $nub=`grep  -E '.*data_buffer[.](input_)?headfile[.].*' rad_mat.m > rad_mat_hfcalls.txt`;
#$nub=`grep  -E '.*data_buffer[.](input_)?headfile[.].*' rad_regid.m > rad_regid_hfcalls.txt`;
my $file_s=`find . -iname "*.m" `;
#-exec grep  -E '.*data_buffer[.](input_)?headfile[.].*' {} '\;'  > rad_regid_hfcalls.txt`;
my @hfkeys;

my $db_regx='(:?data_buffer[.]|)';
$db_regx='';
my $lim_space="[\r\t]";
$lim_space="[ \t]";
my $standard_key='[\w][\w\d]*';
my $mat_string="\'$standard_key\'";

my $string_key="(?:$standard_key|$mat_string)";

my $cat_str="\[$lim_space*$string_key(:?$lim_space+$string_key)*$lim_space*\]";

my $dynamic_key="\($lim_space*$cat_str+$lim_space*\)"; #\s

my $key="(?:$standard_key|$dynamic_key)";

#print ($key."\n");
my %varhash;
for my $file ( split('\n',$file_s)){
    my $l=`cat $file`;
    my @lines=split('\n',$l);
    foreach (@lines) {
	#if ( $_ =~ /^.*?$db_regx(?:input_)?headfile[.]($key)(:?[ ,=]?).*$/x ) {
	$_ =~ /^.*?$db_regx(?:input_)?headfile[.]($key)(:?[ ,=]?).*$/x;# ) {
	#} 
	if ( defined $1) { 
 	    if ( exists($varhash{$1} ) ) {
 		$varhash{$1}++;
#		print("$_ \n");#<- $1\n");
 	    } else {
 		$varhash{$1}=1;
 	    }	    
#	    push(@hfkeys,$1);
	} elsif( defined $2 ) {
	    print( "warning 2 defined as $2\n");
	}
# 	if (	 $_ =~ /^.*?$db_regx(?:input_)?headfile[.]($dynamic_key)(:?[ ,=]?).*$/x ) { 
# 	    if (defined $1) {
# 		print ($1."\n");
# 	    }
# 	}
    }
}
#@hfkeys=sort(uniq (@hfkeys));
#print ("Important hf key list is \n".join("\n",sort(keys %varhash))."\n");
print(join("\n",sort(keys %varhash))."\n");


# my $rsout=`cat *hfcalls.txt | cut -d % -f 1 | sort -u | cut -d '=' -f2- | cut -d ';' -f1 >rout.txt`;
# my $lsout=`cat *hfcalls.txt | cut -d % -f 1 | sort -u | cut -d '=' -f1 >lout.txt`;

# my $out= `cat rout.txt lout.txt |grep headfile | cut -d '.' -f 3- | sort -u`;
# my @lines=split('\n',$out);

# my %varhash;

# foreach (@lines)
# {
#     #print $_."\n";
#     if ( $_ =~ /^.*?(\w+).*$/x ) { #[a-z_0-9]
# 	if (defined $1 ){
# 	    chomp($1);
# 	    if ( exists($varhash{$1} ) ) {
# 		$varhash{$1}++;
# #		print("$_ \n");#<- $1\n");
# 	    } else {
# 		$varhash{$1}=1;
# 	    }
# #	} elsif ( defined $2) { 
# 	}else {
# 	    print ("Ignoring $_\n");
# 	} 
#     }
# }

# #print "-----------\n";

# foreach (sort(keys %varhash)) {
#     print $_."\n" ;#$varhash{$_}\n";
 
#     #`find . -iname "*.m" -exec grep  -E '.*$db_regx(input_)?headfile[.].*?$_.*?' {} '\;'`;


# }
