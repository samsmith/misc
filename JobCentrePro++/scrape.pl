#!/usr/bin/perl

use warnings;
use strict;
use Mojo::UserAgent;
use Digest::MD5 qw/md5_hex/;
use JSON;
use Data::Dumper;
my $ua = Mojo::UserAgent->new(max_redirects => 5);
my @jobs;
my %jobs; # yes to both
my @localtime= localtime;
my ($year, $month)=($localtime[5]+1900, $localtime[4]+1);
my $basedir='/data/vhost/findGovJobs/docs/';
$ENV{MOJO_MAX_MESSAGE_SIZE} = 1073741824;

my $results= $ua->post_form('https://jobs.civilservice.gov.uk/company/nghr/jobs.cgi' => {
		"vac_nghr.nghr_dept" => '-', 
		"submitSearchForm" => 1,
		"vac_nghr.nghr_job_category" => '-', 
		"vac_nghr.nghr_emp_typ" => '-', 
		"vac_nghr.nghr_grade" => '-', 
		"vac_nghr.nghr_salary" => '-', 
		"vac_nghr.nghr_region" => '-', 
		"vac_nghr.nghr_town" => '-', 
		"submitSearchForm" => 'Search'} )->res->body;

while ($results =~ m#"(https://jobs[^"]+SID[^"]+)"#mcig) { # be lazy
	my $fetch = $ua->get($1)->res;
	foreach my $jobpage ($fetch->dom) {
		my %this_job;

		$this_job{'link'}= $1;
		if ($this_job{'title'}= $jobpage->find('h1')->[1]) {
			$this_job{'title'}= $jobpage->find('h1')->[1]->text;
		} elsif ($this_job{'title'}= $jobpage->find('h1')->[0]) {
			$this_job{'title'}= $jobpage->find('h1')->[0]->text;
		} else {
			sleep 5;
			next;
		}
		if ($this_job{'title'} =~ m#Ref:(\d+)\s*#) {
			$this_job{'their_site_ref'}= $1;
			$this_job{'site_ref'}= $1;
		} else {
			$this_job{'site_ref'}= "$year-$month-" . md5_hex("$year-$month-$this_job{'title'}");
		}
		foreach my $field ($jobpage->find('.vac_desc > div')->each) {
			if ($field->find('.field_title')->[0]) {
				$this_job{$field->find('.field_title')->[0]->text}=$field->find('.field_value')->[0]->all_text;
			}
		}
		($this_job{'link_person_spec'})= $fetch->content =~ m# href="([^"])">Person Specification#i;

		$this_job{'Person Specification Link'}= "http://findGovJobs.ne.disruptiveproactivity.com/specfiles/$this_job{'site_ref'}-person.doc";
		my $jobspec_file= "$basedir/specfiles/$this_job{'site_ref'}-person.doc";

		if (defined $this_job{'link_person_spec'} and ! -e $jobspec_file) {
			# get and stash
			my $tx = $ua->get($this_job{'link_person_spec'});
			warn "grabbing $this_job{'link_person_spec'}";
			$tx->res->content->asset->move_to($jobspec_file);
		}

		push @jobs, \%this_job;
		push @{$jobs{$this_job{"Department"}}}, \%this_job;
	}
#	last;

}

open (JSON, ">/data/vhost/findGovJobs/docs/current.json") || die "can't open json output: $!";
print JSON encode_json \@jobs;
close (JSON);


open (LIST, ">/data/vhost/findGovJobs/docs/generated/list.html") || die "can't open list file: $!";

foreach my $dept (sort keys %jobs) {
	print LIST "</ul>\n\n<h3 id=\"$dept\"><a href=\"#$dept\">$dept</h3><ul>";
	foreach my $showjob (@{$jobs{$dept}}) {
		print LIST "<li><a href=\"/jobs/$showjob->{'site_ref'}/\">$showjob->{'title'}</a></li>\n";
		#warn $showjob->{"site_ref"};
		mkdir "$basedir/jobs/$showjob->{'site_ref'}";
		open (OUT,">$basedir/jobs/$showjob->{'site_ref'}/index.shtml");
		print OUT "<h1>$showjob->{'title'}</h1>\n";
		print OUT "<h2>$showjob->{'department'}</h2>\n";
		print OUT "<p>Closes on $showjob->{'Closing date'}. <a href=\"$showjob->{'link_person_spec'}\">Person Specification</a>\n</p>";

		print OUT "<h4>Full details</h4>\n";
		print OUT "<dl>\n";
		foreach my $field (sort { lc($a) cmp lc($b) } keys %$showjob) {
			if ($showjob->{$field} =~ m#^http#) {
				$showjob->{$field}= "<a href='$showjob->{$field}'>$showjob->{$field}</a>";
			}
			print OUT "<dt>$field</dt><dd>$showjob->{$field}</dd>\n";
		}
		print OUT "</dl>\n";
	}
	print "</ul>\n";
}

