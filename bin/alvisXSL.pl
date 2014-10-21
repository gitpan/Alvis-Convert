#!/usr/bin/perl

# Reads a list of files, either all gzipped, all bzip2ed or text.
# Runs XSL translation on them using the input XSL script,
# and outputs the result to a file.
#
# Uses xsltproc run using stdin.
# 
#
use strict;
use POSIX;
use Encode;
use IO::Handle;

use Alvis::Utils;

###################### CONFIGURATION #####################

my $XSL = "xsl/alvisLinks.xsl";
my $XSLARGS = "-param CUTOFF 8.5 -stringparam SCORETYPE 'standard'";

#  records per group sent to one XSLTPROC instance
my $MAXSIZE = 10000000;

my $RECORDELEMENT = "documentRecord";
my $GROUPELEMENT = "documentCollection";
#  toss out whatever else was included, and add this
my $GROUPELEMENTEXTRA = " xmlns=\"http://alvis.info/enriched/\" version=\"1.1\"";


############ END CONFIGURATION ######################

#  autoflush
select((select(STDERR), $| = 1)[0]);

# encoding pragmas follow any includes like "use"
use encoding 'utf8';
use open ':utf8';


my $USAGE = "alvisXSL [--gzip|--bzip2|--dir] [--xslargs ARGS] [--xsl XSL-FILE] XML-FILE+\n" 
  . "   Runs xsltproc multiple times on inputs.   To convert into\n"
  . "   into XML, use alvisDecollect as a post-processor.\n" 
  . "   dir = descend into directories, but not recursively\n"
  . "   xsl = $XSL\n"
  . "   xslargs = $XSLARGS\n";

#  command line inputs
my $usegzip = 0;
my $usebzip2 = 0;
my $usedir = 0;

#################################################################
#
#  file feeder
#
#################################################################

my @files = ();
my @dirfiles = ();
my $usingdir = 0;
my $withdir = "";

sub morefiles () {
  if ( $#files>=0 ) {
    return 1;
  }
  if ( $usingdir ) {
    return 1;
  }
  return 0;
}
sub nextfile () {
  my $nf;
  if ( $usingdir ) {
    #print STDERR "Using dir\n";
    while ( ($nf=shift(@dirfiles))  ) {
      if ( -f $nf ) {
	return $nf;
      }
    }
    $usingdir = 0;
    $withdir = "";
    return nextfile();
  } 
  $nf = shift(@files);
  #print STDERR "Got $nf\n";
  if ( !$nf ) {
    return $nf;
  }
  if ( -d $nf ) {
    #print STDERR "Is dir\n";
    if ( $usedir ) {
      @dirfiles = sort(glob("$nf/*")); 
      $withdir = $nf;
      $usingdir = 1;
      return nextfile();
    } else {
      #print STDERR "Open on $nf failed\n";
      return nextfile();
    }
  }
  if ( -f $nf ) {
    #print STDERR "Done\n";
    return $nf;
  }
  #print STDERR "Recurse\n";
  return nextfile();
}

my $xslbuff = "";
my $reading = 0;
my $fullhead = "";

sub nextline () {
  if ( $xslbuff ) {
    # print STDERR "Nextline() restarting: $xslbuff\n";
    $_ = $xslbuff;
    $xslbuff = "";
  } else {
    if ( !$reading ) {
      #  when opening, have to filter initial stuff
      $reading = 1;
      if ( !$fullhead ) {
	while ( ($_ = <XIN>) && 
		( /<\?xml/ || /<$GROUPELEMENT/ ) ) {
	  $fullhead .= $_;
	}
	#  discard whatever was in the header element before
	$fullhead =~ s/<$GROUPELEMENT([^>]*)>/<$GROUPELEMENT $GROUPELEMENTEXTRA>/;
	print FOUT $fullhead;
      } else {
	while ( ($_ = <XIN>) && 
		( /<\?xml/ || /<$GROUPELEMENT/ ) ) {
	  ;
	}
      }
    } else {
      $_ = <XIN>;
      #  clean off end element and close if needed
      if (  /<\/$GROUPELEMENT>/ ) {
	s/<\/$GROUPELEMENT>.*//;
	close(XIN);
	$reading = 0;
      }
    }
  }
  # print STDERR "Starting: $_";
  return $_;
}

sub endofline() {
  if ( eof(XIN) ) {
    return 1;
  }
}

#################################################################
#
#  XSLT routine
#
#  This is kind of stupid,, couldn't find an XSLT + Sax + Perl
#  setup, so we split the records into small chunks and pass
#  them off to a separate XSLT program without SAX.
#
#  Badly needs to be rewritten.
#
#################################################################


#   each call is one execution of XSLTPROC
sub XSLfill {
    my $size = 0;
    #print STDERR "Starting XSLfill\n";

    #   set up new XSLT instance
    #   note we need to set this up with open/waitpid
    #   combination say that one STDOUT is finished before
    #   the next one is started
    my $pid = 0;
    if ($pid = open(FOUT, "|-") ) {
	#  goal is to fill up the XSLTPROC with one XML file
	my $filled = 0;
	if ( eof(XIN) ) {
	    close(XIN);
	    my $nf;
	    while ( eof(XIN) && ($nf=&nextfile()) ) {

		#  more input XML
		if ( $usegzip ) {
		    open(XIN,"zcat $nf |");
		} elsif ( $usebzip2 ) {
		    open(XIN,"bzcat $nf |");
		} else {
			*XIN = Alvis::Utils::open_file($nf);
			#open(XIN, "<$nf");
		} 
		if ( eof(XIN) ) {
		  print STDERR "Open on $nf failed\n";
		}
		
		 
	    }
	    if ( $usedir == 0 ) {
	      print STDERR "Reading $nf for $XSL\n";
	    }
	    $reading = 0;
	}
	print FOUT $fullhead;
	$_ = &nextline();
	while ( $_ && $filled==0 ) {
	    if ( /<\/$RECORDELEMENT>/o ) {
		if ( $size>$MAXSIZE ) {
		    # termination condition:  too many records, so
		    #      force a file break
		    $filled = 1;
		    my $ending = $_;
		    $ending =~ s/<\/$RECORDELEMENT>.*/<\/$RECORDELEMENT>\n/o;
		    # print STDERR "FOUT: $ending";
		    print FOUT $ending; 
		    $size += length($ending);
		    #  build a new start for the next file
		    s/.*<\/$RECORDELEMENT>//o;
		    s/.*<$RECORDELEMENT /<$RECORDELEMENT /o;
		    $xslbuff = $_;
		    # print STDERR "Ending file set for $XSL\n";
		    # print STDERR "Restart buff line set to $xslbuff\n==========\n";
		} 
	    } 
	    if ( $filled == 0 ) {
		#  print STDERR "FOUT: $_";
		print FOUT;		
		$size += length($_);
		$_ = &nextline();
		if ( &endofline() ) {
		    #  termination condition:  end of current file
		    #  print STDERR "FOUT: $_\n";
		    print FOUT;
		    $size += length($_);
		    $filled = 1; 
		}
	    }
	}
	#  print STDERR "SIZE: $size\n";
	print FOUT "</$GROUPELEMENT>\n";
	close(FOUT);
    } else {
	# print STDERR "Starting xsltproc with PID $pid\n";
        # print "#######################################\n";
        # exec("cat ");
	exec("xsltproc $XSLARGS $XSL - ");
	print STDERR "xsltproc exec failed\n";
	exit(1);
    }
    waitpid($pid,0);
    if ( WEXITSTATUS($?) && WEXITSTATUS($?)!=255 ) {
	print STDERR "Finished one xsltproc with " . WEXITSTATUS($?) . "\n";
	exit(1);
    }
}

#################################################################
#
#  Run
#
#################################################################

my $arg1=shift();
while ( $arg1 =~ /^-/ ) {
    if ( $arg1 eq "--xslargs" ) {
	$XSLARGS = shift();
    } elsif ( $arg1 eq "--xsl" ) {
	$XSL = shift();
    } elsif ( $arg1 eq "--gzip" ) {
	$usegzip = 1;
    } elsif ( $arg1 eq "--dir" ) {
	$usedir = 1;
    } elsif ( $arg1 eq "--bzip2" ) {
	$usebzip2 = 1;
    } elsif ( $arg1 eq "-h" || $arg1 eq "--help" ) {
	print $USAGE;
	exit(0);
    } else {
	print $USAGE;
	exit(1);
    }
    $arg1=shift();
}

if ( !$arg1 )  {
    print $USAGE;
    exit(1);
} 
push(@files,$arg1);
push(@files,@ARGV);
#  print STDERR "Files: " . join(" ",@files) . "\n";
if ( ! $XSL || $#files<0 ) {
    print $USAGE;
    exit(1);
} 

&XSLfill();
while ( ! eof(XIN) || $xslbuff || &morefiles() ) {
    &XSLfill();
}

1;
