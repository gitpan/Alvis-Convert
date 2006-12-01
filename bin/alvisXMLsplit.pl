#!/usr/bin/perl

use strict;
use Encode;
use Pod::Usage;

use Alvis::Utils qw(open_file); 

###################### CONFIGURATION #####################

my $report = 0;    #  switch off STDERR status
my $CollectionHeader="<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n" .
               "<documentCollection  xmlns=\"http://alvis.info/enriched/\" version=\"1.1\">\n";

#  NOTE:  also documentRecord and documentCollection are hardwired
#         into matches and such below

###################### END CONFIGURATION #####################

my $F=shift @ARGV;
my $bz = 0;
my $bz_in = 0;
if ( $F eq "--bzip2" ) {
  $bz = 1;
  $F=shift @ARGV;
} 
elsif ($F eq '--bzip2-in') {
	$bz_in = 1;
	$F=shift @ARGV;
}
pod2usage(1) if @ARGV != 2;

my $Size=shift @ARGV;
my $ODir=shift @ARGV;
$report = 0;    #  switch off STDERR status

use encoding 'utf8';
use open ':utf8';

#  have to make sure documentRecord elements one per line
if ( $bz || $bz_in ) {
  open(W,"bzcat $F | perl -p -e \"s/<documentRecord/\n<documentRecord/g;\" |") 
    || die("Unable to open \"$F\"");
} else {
	*W = open_file($F);
  #open(W,"perl -p -e \"s/<documentRecord/\n<documentRecord/g;\" $F |") 
  #  || die("Unable to open \"$F\"");
} 

system("mkdir -p $ODir");

my $N=1;
my $Collection = $CollectionHeader;
while (my $record=&get_next_rec(*W))
{
    $Collection.=$record;
    if ($N%$Size==0)
    {
 	$Collection.="</documentCollection>\n";
	my $out_f="$ODir/" . int($N/$Size) . ".xml";
	open(OUT,">:utf8",$out_f) || die("Unable to open $out_f");
	print OUT $Collection;
	close(OUT);
	if ( $bz ) {
		system("bzip2 $out_f");
        }
	$Collection=$CollectionHeader;
    }
    if ( $report ) { print STDERR "$N\r"; }
    $N++;
}
if ( $report ) { print STDERR "\n"; }

if (($N-1)%$Size)
{
    $Collection.="</documentCollection>\n";
    my $out_f="$ODir/" . (int($N/$Size) + 1) . ".xml";
    open(OUT,">:utf8",$out_f) || die("Unable to open $out_f");
    print OUT $Collection;
    close(OUT);
    if ( $bz ) {
      system("bzip2 $out_f");
    }
}

my $recleft = "";

sub get_next_rec
{
    my $fh=shift;
    my $rec = "";

    if ( $recleft =~/<documentRecord/ ) {
      $rec = $recleft;
    } else {
      my $l;
      while ($rec eq "" &&  ($l=<$fh>)) {
	# print "IN: $l";
	if ($l=~/<documentRecord/) {
	  $rec=$l;
	}
      }
    }
    if ( $rec =~/<documentRecord[^>]+\/>/ ) {
      $recleft = $rec;
      $recleft =~ s/.*<documentRecord[^>]+\/>//; 
      $rec =~ s/(<documentRecord[^>]+\/>).*/$1/; 
      return $rec . "\n";
    }
    # print STDERR "Start 1 with $rec\n"; 
    $recleft = "";
    while (my $l=<$fh>) {
      # print "IN: $l";
      if ($l=~/<\/documentRecord/)
	{
	  $recleft = $l;
	  $recleft =~ s/.*<\/documentRecord>//;
	  $l =~ s/<\/documentRecord>.*/<\/documentRecord>/;
	  $rec.=$l;
	  # print STDERR "Got 1, left $recleft\n"; 
	  if ( $rec !~ /\n$/ ) {
	    $rec .= "\n";
	  }
	  return $rec;
	} else {
	  $rec.=$l;
	}
    }
  }

__END__

=head1 NAME
    
  alvisXMLsplit -- splits a big file into pieces in a directory for easier processing.

=head1 SYNOPSIS
    
    alvisXMLsplit [--bzip2]  <Alvis XML file> <N per file> <out-dir>
    
    Split a large file into N documentRecords per file into a directory.
    Set --bzip2 if both input and output are bzip2'ed
    Output file is UTF8 and Perl friendly, so one <documentRecord> or
    </documentRecord> per line to facilitate processing.

=head1 DESCRIPTION

Script to split a big file into pieces in a directory for easier processing.
Algorithm is simple, but a bit slow because each document is
built up in memory before being dumped, and this is
not efficient in Perl.

=head1 AUTHOR

Wray Buntine

=cut
