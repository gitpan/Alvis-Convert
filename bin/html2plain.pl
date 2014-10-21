#!/usr/bin/perl -w

use Getopt::Long;
Getopt::Long::Configure ("bundling");
use Pod::Usage;

use Alvis::HTML;

use strict;

my $PrintManual=0;
my $PrintHelp=0;
my $Warnings=1;
my $ODir='.';  
my $NPerOurDir=1000;
my $AssertHTML=1;
my $ConvCharEnts=1;
my $ConvNumEnts=1;
my $SourceEncoding=undef;
my $CleanWS=1;
my $AssertAss=1;
my $HTMLSuffix='html';
my $OutSuffix='plain';

GetOptions('help|?'=>\$PrintHelp, 
	   'man'=>\$PrintManual,
	   'warnings!'=>\$Warnings,
	   'html-ext=s'=>\$HTMLSuffix,
	   'assert-html!'=>\$AssertHTML,
	   'symbolic-char-entities-to-chars!'=>\$ConvCharEnts,
	   'numerical-char-entities-to-chars!'=>\$ConvNumEnts,
	   'source-encoding=s'=>\$SourceEncoding,
	   'clean-whitespace!'=>\$CleanWS,
	   'assert-assumptions!'=>\$AssertAss,
	   'out-dir=s'=>\$ODir,
	   'out-ext=s'=>\$OutSuffix,
	   'N-per-out-dir=s'=>\$NPerOurDir) or 
    pod2usage(2);
pod2usage(1) if $PrintHelp;
pod2usage(-exitstatus => 0, -verbose => 2) if $PrintManual;
pod2usage(1) if (@ARGV!=1);

my $SDir=shift @ARGV;

$|=1;

my $C=Alvis::HTML->new(alvisKeep=>1,
		       alvisRemove=>1,
		       obsolete=>1,
		       proprietary=>1,
		       xhtml=>1,
		       wml=>1,
		       keepAll=>0,
		       assertHTML=>$AssertHTML,
		       convertCharEnts=>$ConvCharEnts,
		       convertNumEnts=>$ConvNumEnts,
		       sourceEncoding=>$SourceEncoding,
		       cleanWhitespace=>$CleanWS,
		       assertSourceAssumptions=>$AssertAss
		       );

my %Seen;
my $outputN=0;
if (!&_convert_collection($SDir,{htmlSuffix=>$HTMLSuffix}))
{
    die("Conversion failed. " . $C->errmsg());
}

sub _parse_entries
{
    my $entries=shift;
    my $options=shift;
    my $html_entries=shift;
    
    for my $e (@$entries)
    {
	if ($Seen{$e})
	{
	    next;
	}
	
	$Seen{$e}=1;
	if (-d $e)
	{
	    my @entries=glob("$e/*");;
	    &_parse_entries(\@entries,$options,$html_entries);
	    next;
	}

	my ($basename,$suffix);
	if ($e=~/^(.*)\.([^\.]+)$/)
	{
	    $basename=$1;
	    $suffix=$2;
	}
	else
	{
	    warn "Skipping non-suffixed non-directory entry \"$e\".\n" if 
		$Warnings;
	    next;
	}
	
	if ($suffix eq $options->{htmlSuffix})
	{
	    $html_entries->{$basename}{htmlF}=$e;
	}
    }
}

sub _convert_collection
{
    my $root_dir=shift;
    my $options=shift;

    my @entries=glob("$root_dir/*");
    my %html_entries=();
    %Seen=();
    print "Parsing the source directory entries...\r";
    &_parse_entries(\@entries,$options,\%html_entries);	
    print "                                       \r";

    for my $base_name (keys %html_entries)
    {
	my ($html_txt,$plain_txt,$header);

	if (exists($html_entries{$base_name}{htmlF}))
	{
	    my $html_txt;
	    if (!defined(open(F,"<$html_entries{$base_name}{htmlF}")))
	    {
		warn "Unable to open \"$html_entries{$base_name}{htmlF}\".\n";
		next;
	    }
	    while (my $l=<F>)
	    {
		$html_txt.=$l;
	    }
	    close(F);

	    ($plain_txt,$header)=$C->clean($html_txt);
	    if (!defined($plain_txt))
	    {
		warn "Getting the plain text for basename \"$base_name\" failed. " .
		    $C->errmsg() if 
		    $Warnings;
		$C->clearerr();
		next;
	    }
	}
	else
	{
	     warn "No HTML file for basename \"$base_name\".\n" if 
		$Warnings;
	     next;
	}

	if (!&_output_plain($plain_txt))
	{
	    warn "Outputting the Alvis records for base name \"$base_name\" failed. " . $C->errmsg() if 
		$Warnings;
	    $C->clearerr();
	    next;
	}
    }

    return 1;
}

sub _output_plain
{
    my $plain_txt=shift;

    my $out_f;
    my $dir=$ODir . '/' . 
	int($outputN / $NPerOurDir);
    if ($outputN % $NPerOurDir==0)
    {
	mkdir($dir);
    }
    $out_f=$dir . '/' . $outputN . '.' .
	$OutSuffix;
    
    if (!defined(open(OUT,">:utf8",$out_f)))
    {
	warn "Cannot open output file \"$out_f\".\n";
	return 0;
    }
    print OUT $plain_txt;
    close(OUT);
    
    $outputN++;
    print "$outputN\r";
}

__END__

=head1 NAME
    
    html2plain.pl - HTML to plain text converter
    
=head1 SYNOPSIS
    
    html2plain.pl [options] [source directory ...]

  Options:

    --html-ext                HTML file identifying filename extension
    --out-ext                 output filename extension
    --out-dir                 output directory
    --N-per-out-dir           # of records per output directory
    --source-encoding         the encoding of the HTML files
    --[no]assert-html         assert that the document is HTML
    --[no]symbolic-char-entities-to-chars
                              convert symbolic character entities to UTF-8
                              characters
    --[no]numerical-char-entities-to-chars
                              convert numerical character entities to UTF-8
                              characters
    --[no]clean-whitespace    remove redundant whitespace
    --[no]assert-assumptions  assert that the document is in UTF-8 and contains
                              before actually converting to plain text
    --help                    brief help message
    --man                     full documentation
    --[no]warnings            warnings output flag
    
=head1 OPTIONS
    
=over 8

=item B<--html-ext>

    Sets the HTML file identifying filename extension. 
    Default value: 'html'.

=item B<--out-ext>

    Sets the output filename extension. 
    Default value: 'plain'.

=item B<--out-dir>

    Sets the output directory. Default value: '.'.

=item B<--N-per-out-dir>

    Sets the # of records per output directory. Default value: 1000.

=item B<--source-encoding>

    Specifies the encoding of the HTML files. Default value undef,
    which means that the encoding is guessed for each document.

=item B<--[no]assert-html>

    Specifies whether it is asserted that the document actually looks like
    HTML before trying to convert. Default: yes.

=item B<--[no]symbolic-char-entities-to-chars>

    Specifies whether symbolic character entities are converted to 
    UTF-8 characters. Default: yes.

=item B<--[no]numerical-char-entities-to-chars>

    Specifies whether numerical character entities are converted to 
    UTF-8 characters. Default: yes.

=item B<--[no]clean-whitespace>

    Specifies whether redundant whitespace is removed from the output.
    Default: yes.

=item B<--[no]assert-assumptions>

    Specifies whether assumptions about the source are validated before
    trying to convert (that it is in UTF-8 (converted to internally) and
    contains no '\0's. Default: yes.

=item B<--help>

    Prints a brief help message and exits.

=item B<--man>

    Prints the manual page and exits.

=item B<--[no]warnings>

    Output (or suppress) warnings. Default value: yes.

=back

=head1 DESCRIPTION

    Goes recursively through the HTML files under the source directory
    and converts their textual content to plain text files. 
    The output is in UTF-8.

=cut


