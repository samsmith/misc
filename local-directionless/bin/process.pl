#!/usr/bin/perl

use warnings;
use strict;
use Text::CSV;
use Digest::MD5 qw/md5_hex/;
my $csv_file= shift;
my $dir= shift || "usage: $0 file.csv pages/\n";
my %filemapping;
#use Text::Similarity::Overlaps;
#my $overlaps= Text::Similarity::Overlaps->new({'normalize' => 1});
my $authority_info;
my %pageinfo;
my %broken;

{
	&setup();
	&obviously_broken();
	&slightly_harder_to_find();
	&output();
}

sub output { 
	foreach my $hash (keys %broken) {
		print "$filemapping{$hash}->{'authority'}\t$filemapping{$hash}->{'service'}\t$filemapping{$hash}->{'url'}\t$broken{$hash}\n"
	}
}

sub setup {
	no warnings "utf8"; # because it isn't.
	my $csv = Text::CSV->new ( { binary => 1 } ) or die "Cannot use CSV: ".Text::CSV->error_diag ();


	open (my $fh, "<:encoding(utf8)", $csv_file) or die "can't open $csv_file: $!";
	while ( my $row = $csv->getline( $fh ) ) {
		# hash of md5 = url
		next if $row->[1] eq 'SNAC';

		if (defined $filemapping{md5_hex($row->[6]).".html"} and $filemapping{md5_hex($row->[6]).".html"}->{'authority'} ne $row->[0]) {
			&report_broken(md5_hex($row->[6]).".html", "cross LA link, also for $row->[0]");
			next;
		}
#warn $row->[6];
		$filemapping{md5_hex($row->[6]).".html"}->{'url'}= $row->[6];
		$filemapping{md5_hex($row->[6]).".html"}->{'authority'}= $row->[0];
		$filemapping{md5_hex($row->[6]).".html"}->{'service'}= $row->[3];
		# authority->service->{'url'}
		$authority_info->{$row->[0]}->{$row->[3]}->{'url'}= $row->[6];
		$authority_info->{$row->[0]}->{$row->[3]}->{'hash'}= md5_hex($row->[6]).".html";
	}
}
#hash of authority -> service = URL






sub obviously_broken {
	my %seen;

	# for each file in the directory, which are zero length files?
	# that can not possibly be valid
	opendir (PAGES, "$dir") || die "can't opendir $dir: $!";
	foreach my $file (readdir(PAGES)) {
		if (-z "$dir/$file") {&report_broken($file, "zero length"); next} 
		if (-s "$dir/$file" < 2048 ) { &report_broken($file, "very small file: redirect?"); next }  # all files tested were broken
		if (`grep 'cannot be found' pages/$file`) { &report_broken($file, "matches 'cannot be found'"); next } # bodge, but effective
		if (`grep 'error 404' pages/$file`) { &report_broken($file, "error 404"); next } # bodge, but effective
		if (`grep 'not found' pages/$file`) { &report_broken($file, "matches 'not found'"); next } # bodge, but effective
		if (`grep ' 404[< ] ' pages/$file`) { &report_broken($file, "404"); next } # bodge, but effective
		
		my $this_hash= `md5 -r pages/$file`;
		if (defined $seen{$this_hash}) {
			&report_broken($file, "exact duplicate of $seen{$this_hash}", "multiple ok");
			$seen{$this_hash}.= ", $filemapping{$file}->{'url'}";
		} else {
			$seen{$this_hash}= $filemapping{$file}->{'url'};
		}
		# duplicate URLs don't get counted below, but are arguably broken
		# it's also possible to crowdsource this as "does page X in the iframe below contain the informatin that should be in it according to our index"

		# additional tests here are left as an exercise for the reader or @dafyddbach
	}

}


sub slightly_harder_to_find {
	my %done_compare;

	foreach my $authority (keys %$authority_info) {
		my $now= scalar localtime;
		warn $now . " " . $authority;
		next if $authority eq ''; #warn $authority;
		my @sortish= sort values %{$authority_info->{$authority}};  # gets us services sorted by memory id  -- effectively randomly
		foreach my $service (sort keys %{$authority_info->{$authority}}) {
			#foreach my $compare (@sortish) { #[0..2]) { # all files might work better here rather than just the first 2
			foreach my $compare (@sortish[0..2]) { # all files might work better here rather than just the first 2
				next if not defined $compare; # <=2 files.
				next if $broken{$authority_info->{$authority}->{$service}->{'hash'}}; #already broken
				next if $broken{$compare->{'hash'}}; # broken compare file
				my $file1= 'pages/' . $authority_info->{$authority}->{$service}->{'hash'};
				my $file2= 'pages/' . $compare->{'hash'};
				next if ($file1 eq $file2); #don't compare with self
				next unless -e $file1; next unless -e $file2; next if -z $file1; next if -z $file2; 
				next if defined $done_compare{'matched'}->{"$service$compare"}; # no double counting duplicate URLs for different services
				$done_compare{'matched'}->{"$service$compare"}++;
#warn "hi";
				#warn "$file1 $file2";
				$done_compare{$authority}->{$service}->{'comparisons'}++;
				my $output='';

				$output = `diff -C 0 $file1 $file2`;
				my $lines_different=0;

				foreach my $line (split /\n/, $output){ 
					$lines_different+= 0.5 if $line =~ m#^!#; # lines that change all start with !, and any different line is there twice.
				}

				if ($lines_different < 15 ) {
					$file1=~ s#^pages/##;
					$file2=~ s#^pages/##;
					&report_broken($file1, "seems similar to $filemapping{$file2}->{'url'}", "multiple reports ok");
					next;
				}
			}

		}
		#for 3 files at random, diff all files against those three. (not against self);
		#if a file shows as < 5 lines different against 
	}

}




sub report_broken {
	my ($filename, $why, $multiple_reports_ok)= @_;
	return if (defined $broken{$filename} and not defined $multiple_reports_ok); # already broken for another reason
	if (defined $broken{$filename}) {
		$broken{$filename}.= ", $why";
	} else {
		$broken{$filename}.= "$why";
	}
}


