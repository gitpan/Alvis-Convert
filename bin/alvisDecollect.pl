
#  Strips away unneeded <documentCollection> packaging
#  in XML
# 
#
use strict;
use POSIX;
use Encode;

###################### CONFIGURATION #####################

my $GROUPELEMENT = "documentCollection";


############ END CONFIGURATION ######################

# encoding pragmas follow any includes like "use"
use encoding 'utf8';
use open ':utf8';

my $header = "";
my $collected = 0;

while ( !$collected && ($_=<>) ) {
  print;
  if ( /<$GROUPELEMENT / ){
    $collected = 1;
  }
}

while ( <> ) {
  if ( !/<?xml/ ) {
    s/<$GROUPELEMENT [^>]*>//;
    s/<\/$GROUPELEMENT>//;
    print;
  }
}

print "\n<\/$GROUPELEMENT>\n";
