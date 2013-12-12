#!/usr/bin/perl 

chdir($ENV{HOME} . "/work/cycling/");
use warnings;
use strict;
use LWP::Simple;
use Data::Dumper;
use XML::Simple;
#my $key= '4d0b91407a15ce76';
my $key= shift || die "usage -- pipe output to a shell:\n $0 api_key | sh\n";

my $original_xml= get('http://www.tfl.gov.uk/tfl/syndication/feeds/cycle-hire/livecyclehireupdates.xml');
`curl http://www.tfl.gov.uk/tfl/syndication/feeds/cycle-hire/livecyclehireupdates.xml > output/structure.xml`;

my $ref= XMLin($original_xml) ;
my @items;
my $max_id=1;

foreach my $name (keys %{$ref->{'station'}} ) {
	my $item;
	$item->{'lat'}= $ref->{'station'}->{$name}->{lat} ;
	$item->{'long'}=$ref->{'station'}->{$name}->{long};
	$item->{'id'}=$ref->{'station'}->{$name}->{id} ;
	$item->{'name'}=$name;

	@items[$item->{id}] = $item;

	if ($max_id < $item->{'id'}) {
	 	$max_id= $item->{'id'};
	}
}

foreach my $from (1 .. $max_id) {
	foreach my $to (1 .. $max_id) {

		next if $to == $from; 


		#next if $to <= $from; # if we care about one way systems, comment out.
				       # depends on whether 1-way gyratories matter to your app

		next if not defined $items[$from]->{'name'};
		next if not defined $items[$to]->{'name'};

		next if -e "output/$from/$from-$to.xml";
print "echo $from-$to;\n";
		mkdir "output/$from";
		print ("curl -s 'http://www.cyclestreets.net/api/journey.xml?key=$key&plan=balanced&itinerarypoints=" .  $items[$from]->{long}. ",". $items[$from]->{lat} . "|" .  $items[$to]->{long}.",".$items[$to]->{lat} , "' > output/$from/$from-$to.xml ;\n");
	}
}

