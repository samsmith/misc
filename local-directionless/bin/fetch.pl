#!/usr/bin/perl

use warnings;
use strict;
use LWP::Simple;
use Digest::MD5 qw/md5_hex/;

my $filename= shift;
my $dir= shift || die "usage: $0 list.csv output/\n";

open (FILE, $filename) || die "can't open $filename: $!";
my $header= <FILE>; # ignore
foreach my $line (<FILE>) {
	chomp($line);
	my $url;
	($url)= $line=~ m#,([^,]*)$#;
	my $md5= md5_hex($url);
	next if -e "$dir/$md5.html";
	my $content;
	$content= get($url);
	warn $url;
	open OUT, ">$dir/$md5.html";
	print OUT $content;
	close(OUT);
}
