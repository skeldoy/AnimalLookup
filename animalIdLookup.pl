#!/usr/bin/perl

# This is a boilerplate for looking up animals by looking at embedded RFID-tags and 
# matching those with online databases. This example uses a FDX/HDX-reader that connects
# to the machine as a TTY-device. The behaviour of the reader is to output version number
# of the firmware when polled with a "VER\r\n" and then output the ISO-standard animal ID
# embedded in a proximal, compatible RFID-tag when said tag is powered by the inductor.
# You might want to change the reader-specific code a bit depending on your device, but
# the principals remain the same. You also might want to find a country-specific database
# for looking up animals. In this example I have included the Norwegian database.
# This code is for educational purposes and should not be considered production worthy as it is
# not tested at all. Consider this released under an MIT-license.
# Sverre Eldøy (skeldoy@gmail.com) 2014

# we need these modules for it to work.
use HTML::Strip;
use strict;
use warnings;
use IO::Handle;
use LWP::UserAgent; 
use HTTP::Request::Common qw{ POST };
use CGI;
use utf8;
use Device::SerialPort;

# FDX/HDX-RFID-reader specific setup. You want to change this:
my $device = '/dev/tty.usbserial-A7WZR6PK';

# probably safe to assume the following settings are Kosher
my $port = Device::SerialPort->new($device);
$port->baudrate(9600);
$port->databits(8);
$port->parity("none");
$port->stopbits(1);
$| = 1; #avoid buffering - the 16 bytes of the RFID-chip might be stuck in buffer unless

# Give this the url of your countrys animal ID database. In particular the form you can POST to:
my $url = 'http://www.dogweb.no/dyreidentitet/public/openPage/view/sok.html';
my $formContainer = 'SEARCH_STRING'; # The name of the input with the ID you want to look up.

# We first poll the FDX-reader to check that it is ready. This code may vary depending on your equipment

my $waiting = 1;
$port->write("VER\r\n");
while($waiting) {
  my $byte=$port->read(3);
#  print "$byte";
  if ($byte eq "309") { $waiting = 0; }
}
print "Device is waiting for an animal...\n";
sleep 2;

# Then we go into a loop where we read 16 bytes (the standard length according to the ISO)
while(1) {
 my $animal=$port->read(16);
 if ($animal eq "") { sleep 1; } # you might want to tune this sleeptime for performance
 else { print "Got a beast: [$animal]\n"; 
  # We found an animal so we perform the lookup
  &findGoodStuff(&removeCrap(&headStrip(&trimmer(&prune(&lookUp(&cleanUp($animal)))))));	
  # lookup is done so we wait in order for the animal to clear the reader.
  sleep 3; # you might want to change this depending on your application
 }
}

# This strips out the interesting parts we need. 
sub findGoodStuff() {
my ($content) = @_;
my @data = split("\n", $content);
for (my $i = 0; $i <= $#data;$i++) {
if ($data[$i] =~ "ChipID") { print "ID: ", ($data[$i+1]), "\n"; };
if ($data[$i] =~ "Navn") { print "Navn: ", ($data[$i+1]), "\n"; };
if ($data[$i] =~ "Dyreeier") { print "Eier: ", ($data[$i+1]), "\n"; };
if ($data[$i] =~ "Telefon") { print "Navn: ", ($data[$i+1]), "\n"; };
}

}

# cleans up some of the crap from the table
sub removeCrap() {
my ($content) = @_;
$content =~ s/://g;
$content =~ s/\?//g;
return $content;
}

# A nasty way of cleaning out the http-headers
sub headStrip() {
my $counter = 0;
my @good;
my ($content) = @_;
my @data = split("\n", $content);
foreach my $line (@data) {
if ($counter > 11) { push(@good, $line); }
$counter++;
}
return join("\n", @good);
}

# We trim away the whitespace from the clear text
sub trimmer() {
my ($plaintext) = @_;
my @plain = grep { /\S/ } split(/\n/,$plaintext);
return join("\n", @plain);
}

# we need to trim away the underscore separating the country-code from the ID.
# this might vary depending on the service you poll. some might keep the underscore.
sub cleanUp() {
my ($query) = @_;
$query =~ s/_//g;
return $query;
}

# We perform the actual lookup to the web-server and get HTML back
sub lookUp() {
my ($query) = @_;
my $ua      = LWP::UserAgent->new();
my $request = POST( $url, [ $formContainer => $query ] );
my $content = $ua->request($request)->as_string();
my $cgi = CGI->new();
#print $cgi->header(), $content;
return $content;
}

# We convert the HTML to ASCII. The reason is that the HTML is so malformed that we cannot traverse it
sub prune() {
my ($content) = @_;
my $hs = HTML::Strip->new();
my $clean = $hs->parse($content);
$hs->eof;
return $clean;
}
