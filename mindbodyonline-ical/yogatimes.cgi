#!/usr/bin/perl

# you probably want to hack the code to disable the alarms.

my $cache_file=''; #"/home/sams/public_html/cgi-bin/cached.ics";
my $studio_id=10070; # you need to change this
my $location= 'CamYoga, CB2 1HH';
my $username='yourusername';
my $password='yourpassword';
my $want_alarm_before= 45; # want alarm 45 minutes before
my $want_alarm_after= 0; # my choice of alarms

use warnings;
use strict;

if (defined $ENV{'USER_AGENT'} and $ENV{'USER_AGENT'} =~ m#iOS# and $cache_file != '') {
	print "Content-Type: text/calendar\n\n";
	open OUT, $cache_file;
	print join '', <OUT>;
	close OUT;
	exit;
}

use Data::Dumper;
use LWP::UserAgent;
use DateTime::TimeZone;
use HTTP::Request;
use HTTP::Request::Common;
use Date::ICal;
use Data::ICal::Entry::Event;
use Data::ICal::Entry::Alarm::Audio;
use Data::ICal;
use Date::Calc qw(Add_Delta_DHMS);
use DateTime;
use Time::HiRes;
use HTML::Scrubber;

my $ua = LWP::UserAgent->new;
$ua->cookie_jar({});
my $calendar = Data::ICal->new();
my $tz = DateTime::TimeZone->new(name => 'Europe/London');
my $scrubber = HTML::Scrubber->new( allow => [ qw[ ] ] ); #

print "Content-Type: text/calendar\n\n";

#print Dumper 
$ua->get("https://clients.mindbodyonline.com/ASP/logout.asp?studioid=$studio_id&isJson=false"); #->res->content;
$ua->request(POST 'https://clients.mindbodyonline.com/ASP/login_p.asp?studioID='.$studio_id, [date=>'1/1/2012', trn=>0, 'requiredtxtPassword'=> $password, 'requiredtxtUserName'=>$username, optRememberMe=>'on','justloggedin'=>'']);

my $content= $ua->get('https://clients.mindbodyonline.com/ASP/my_sch.asp')->content;


my %info;
my $line;
foreach my $line ( $content=~ m#<tr class="scheduleRow ?"(.*?)</tr>#mscgi) {
#	print $line;
	($info{'class'}) = $line =~ m#classNameCell">(.*?)</td>#i;
	($info{'teacher'}) = $line =~ m#teacherCell">(.*?)</td>#i;
	($info{'date'}) = $line =~ m#dateCell">\w* ?(\d+/\d+/\d+)</td>#i;
	($info{'time'}) = $line =~ m#timeCell">(\d+:\d+)#i;


	$info{'class'}=~ s#<font.*##;
	$info{'class'}=~ s#&nbsp;# #g;
	$info{'class'}=~ s# \-\s*$##g;

	foreach my $p (keys %info) {
        	$info{$p}= $scrubber->scrub($info{$p}); 
	}
	# class - teacher
	# start as date - time
	# then print ical
	#print Dumper \%info;
	my $count++;

	my ($startday, $startmonth, $startyear, $starthour, $startmin) = split /[\/:]/, "$info{'date'}/$info{'time'}";

	my ($endyear, $endmonth, $endday, $endhour, $endmin, $endsec) = Add_Delta_DHMS($startyear, $startmonth, $startday, $starthour, $startmin, 0, 0, 1, 30, 0);
	my ($alarmyear, $alarmmonth, $alarmday, $alarmhour, $alarmmin, $alarmsec) = Add_Delta_DHMS($startyear, $startmonth, $startday, $starthour, $startmin, 0, 0, 0, -$want_alarm_before, 0);
	my ($alarm2year, $alarm2month, $alarm2day, $alarm2hour, $alarm2min, $alarm2sec) = Add_Delta_DHMS($startyear, $startmonth, $startday, $starthour, $startmin, 0, 0, +$want_alarm_after, 0, 0);


	my $event = Data::ICal::Entry::Event->new();
	my @tm = localtime();
	my $uid = sprintf("2-%d%02d%02d%02d%02d%02d%s%02d\@mindbodyonlinescraper.msmith.net",
                    $tm[5] + 1900, $tm[4] + 1, $tm[3], $tm[2],
                    $tm[1], $tm[0], scalar(Time::HiRes::gettimeofday()), $count);
	my @stamp = localtime();
	my $dstamp = sprintf("%d%02d%02dT%02d%02d%02dZ", $stamp[5] + 1900, $stamp[4] + 1, $stamp[3], $stamp[2], $stamp[1], $stamp[0]); 


	my $offset = $tz->offset_for_datetime( DateTime->new(
             				year       => $startyear,
             				month      => $startmonth,
             				day        => $startday,
             				hour       => $starthour,
             				minute     => $startmin,
             				second     => 00,
             				nanosecond => 0,
             				time_zone  => 'Europe/London',
         	)  	);


	$event->add_properties(
            uid => $uid,
            summary => $info{'class'} . ' - ' . $info{'teacher'},
            location => $location,
            dtstamp => $dstamp,
            dtstart => Date::ICal->new(
                            year => $startyear,
                            month => $startmonth,
                            day => $startday,
                            hour => $starthour,
                            min => $startmin,
                            sec => 0,
                            #offset => $offset
			    )->ical,
            dtend => Date::ICal->new(
                            year => $endyear,
                            month => $endmonth,
                            day => $endday,
                            hour => $endhour,
                            min => $endmin,
                            sec => 0,
                           # offset =>$offset 
			    )->ical
            );


	if ($want_alarm_before) {
		my $valarm = Data::ICal::Entry::Alarm::Audio->new();
		$valarm->add_properties(
    			trigger   => [ Date::ICal->new( year => $alarmyear, month => $alarmmonth, day => $alarmday, hour => $alarmhour, min => $alarmmin, sec => 0,# offset => "+0000"
			)->ical],
			action	=> 'DISPLAY', 
			#description => "$info{'class'} at $info{time}"
		);
		$event->add_entry($valarm);
	}
	if ( $want_alarm_after) { # || $info{'class'} =~ m#\bhot #i) {
		my $event2 = Data::ICal::Entry::Event->new();
		$event2->add_properties(
            	uid => 'second-'.$uid,
            	summary => "take yoga stuff from bag",
            	dtstamp => $dstamp,
            	dtstart => Date::ICal->new(
                            	year => $alarm2year,
                            month => $alarm2month,
                            day => $alarm2day,
                            hour => $alarm2hour,
                            min => $alarm2min,
                            sec => 0,
                           # offset => $offset
			    )->ical,
            dtend => Date::ICal->new(
                            year => $alarm2year,
                            month => $alarm2month,
                            day => $alarm2day,
                            hour => $alarm2hour,
                            min => $alarm2min+10,
                            sec => 0,
                           # offset =>$offset 
			   )->ical
            );
		my $valarm2 = Data::ICal::Entry::Alarm::Audio->new();
		$valarm2->add_properties( trigger   => [ Date::ICal->new( year => $alarm2year, month => $alarm2month, day => $alarm2day, hour => $alarm2hour, min => $alarm2min, sec => 0, offset => "+0000")->ical], action	=> 'DISPLAY', #description => "{time}"
		);
		$event2->add_entry($valarm2);
		$calendar->add_entry($event2);
	}

	$calendar->add_entry($event);

}


$calendar->add_properties(
        calscale => 'GREGORIAN',
	method => 'PUBLISH',
	'X-WR-CALNAME' => "$location Schedule"
);
print $calendar->as_string;
if ($cache_file ne '') {
	open OUT, ">$cache_file";
	print OUT $calendar->as_string;
	close (OUT);
}

