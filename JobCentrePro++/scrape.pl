#!/usr/bin/perl

use warnings;
use strict;
use Mojo::UserAgent;
use JSON;
use Data::Dumper;
my $ua = Mojo::UserAgent->new;
my @jobs;


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
	foreach my $jobpage ($ua->get($1)->res->dom) {
		my %this_job;

		$this_job{'link'}= $1;
		$this_job{'title'}= $jobpage->find('h1')->[1]->text;

		foreach my $field ($jobpage->find('.vac_desc > div')->each) {
			if ($field->find('.field_title')->[0]) {
				$this_job{$field->find('.field_title')->[0]->text}=$field->find('.field_value')->[0]->all_text;
			}
		}
		push @jobs, \%this_job;
	}
	#last;
}

print encode_json \@jobs;
