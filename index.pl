#!/usr/bin/env perl
# See README
use strict; use warnings;
use XML::LibXML;
use Date::Parse;
use File::stat;
#use Time::HiRes qw(gettimeofday tv_interval); # For run time tracking
use CGI::Compress::Gzip; # Change to just "use CGI;" if you do not have/want this module
#use CGI::Carp qw(warningsToBrowser fatalsToBrowser);  # uncomment to spit errors at the user instead of the Web server log

#my $start = [gettimeofday];

my @mabbr = qw(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec);
my %habbr = ( # header abbreviations
    LastLogOutTime => 'LastSeen',
    AchievementScore => 'AchScore',
    );
my $html = new CGI::Compress::Gzip; # Change to just "... new CGI;" if you do not have/want this module
print $html->header; # HTTP header

my $guildxml = "guild.xml"; 
my $cachehtml = "cache.html";

unless (-e $guildxml) { die "$guildxml not found or not readable\n"; }
# check for cached version
if (-e $cachehtml) {
  my $cachets = stat($cachehtml)->mtime;
  my $gxmlts = stat($guildxml)->mtime;
  if ($cachets >= $gxmlts) { 
    local $/ = undef; # get the whole file at once
    open CACHE, "<$cachehtml" or die "$!";
    binmode CACHE;
    print <CACHE>; # send the whole file at once, then we're done
    close CACHE;
#    print "\n<!-- Cached: " . (tv_interval( $start )) . "s -->";
    exit;
  }
}

# Okay, start constructing some HTML
my $page = "";
$page = $html->start_html(
    -title => "RIFT Guild Info",
    -script => { -type =>'JAVASCRIPT', -src => "sorttable.js", },
    -style => { -src => 'style.css'},
    -onLoad => 'javascript:var myTH = document.getElementsByTagName("th")[0]; sorttable.innerSortFunction.apply(myTH, []);', # browser sort by name after load - cheat
    );

my $parser = XML::LibXML->new();
my $xml = $parser->parse_file($guildxml) or die "$!";
$page .= "<center><h1>" . $xml->findnodes('/Guild/Name')->to_literal . ", level " .  $xml->findnodes('/Guild/Level')->to_literal . "</h1><em>Click table headers to sort.</em></center>\n";

# populate rank ID -> Name map
my %ranks = ();
foreach my $rank ($xml->findnodes('/Guild/Ranks/Rank')) {
  $ranks{ $rank->findnodes('./Id')->to_literal } = $rank->findnodes('./Name')->to_literal;
}

my @headers = qw(Name Rank Level Calling Joined LastLogOutTime AchievementScore PersonalNotes);
# start printing a table
$page .= "<table class='sortable'><thead><tr>\n";

foreach my $header (@headers) {
  my $fname = $header; # don't modify the array
  if (defined($habbr{$header})) { $fname = $habbr{$header}; } 
  $page .= "<th>$fname</th>";
}

$page .= "</tr></thead><tbody>\n";

# Traverse all members
foreach my $member ($xml->findnodes('/Guild/Members/Member')) {
  $page .= "<tr>";
  foreach my $header (@headers) {
    if ($header eq "Rank") { # Map rank ID to Name, still sort on ID
      my $num = $member->findnodes("./$header")->to_literal;
      $page .= "<td sorttable_customkey=\"$num\">" . $ranks{ $num } . "</td>"; 
    }
    elsif ($header eq "Joined" or $header eq "LastLogOutTime") { # Display more friendly date, but still sort on the given
      my $time = $member->findnodes("./$header")->to_literal;
      my ($ss,$mm,$hh,$day,$month,$year,$zone) = strptime($time);
      $page .= "<td sorttable_customkey=\"$time\">" . "$day " . $mabbr[$month - 1] . " " . ($year - 100) . "</td>";
    }
    else { $page .= "<td>" . $member->findnodes("./$header")->to_literal . "</td>"; }
  }
  $page .= "</tr>\n";
}
$page .= "</tbody></table>\n";

$page .= $html->end_html;
print $page;
# print '<!-- Not cached: ' . (tv_interval( $start )) . 's -->';

open CACHE, ">$cachehtml" or die "$!";
print CACHE $page;
close CACHE;
