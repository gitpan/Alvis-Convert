#!/usr/bin/perl -w

use Getopt::Long;
Getopt::Long::Configure ("bundling");
use Pod::Usage;

use Alvis::Convert;
use Alvis::Wikipedia::XMLDump;

use strict;

#
# Language-dependent identifiers. Add to these according to your needs.
# TO BE DONE: add a configuration option so these can be read from a file...
#
my %LangSettings=('en'=>{rootCategory=>'fundamental',
                         categoryWord=>'Category',
                         templateWord=>'Template'},
                  'fr'=>{rootCategory=>'principale',
                         categoryWord=>'Cat�gorie',
                         templateWord=>'Mod�le'},
                  'sl'=>{rootCategory=>'temeljna',
                         categoryWord=>'Category'} );


my $PrintManual=0;
my $PrintHelp=0;
my $Warnings=1;
my $ODir='.';  
my $NPerOutDir=1000;
my $IncOrigDoc=0;
my $ExpandTemplates=0;
my $TemplateDumpF='Templates.storable';
my $OutputFormat="HTML";
my $ConvertViaHTML=1;
my $Date=undef;
my $DumpCatGraph=1;
my $DumpTemplates=0;
my $CatGraphDumpF="CategoryGraph.storable";
my $Language='en';
my $RootCategory='fundamental';
my $CategoryWord="Category";
my $TemplateWord='Template';
my @Namespaces=('');   
my $NamespacesTxt=undef;          # Namespaces to include, default 'Articles'

GetOptions('help|?'=>\$PrintHelp, 
	   'man'=>\$PrintManual,
	   'warnings!'=>\$Warnings,
	   'out-dir=s'=>\$ODir,
	   'namespaces=s'=>\$NamespacesTxt,
	   'N-per-out-dir=s'=>\$NPerOutDir,
	   'original!'=>\$IncOrigDoc,
	   'expand-templates-fully!'=>\$ExpandTemplates,
	   'dump-templates!'=>\$DumpTemplates,
	   'template-dump-file=s'=>\$TemplateDumpF,
	   'convert-via-html!'=>\$ConvertViaHTML,
	   'language=s'=>\$Language,
	   'category-word=s'=>\$CategoryWord,
	   'root-category=s'=>\$RootCategory,
	   'template-word=s'=>\$TemplateWord,
	   'date=s'=>\$Date,
	   'dump-category-graph!'=>\$DumpCatGraph,
	   'category-graph-dump-file=s'=>\$CatGraphDumpF
	   ) or 
    pod2usage(2);
pod2usage(1) if $PrintHelp;
pod2usage(-exitstatus => 0, -verbose => 2) if $PrintManual;
pod2usage(1) if (@ARGV!=1);

#
# If we don't want to dump the templates, signal it like this
#
if (!$DumpTemplates)
{
    undef $TemplateDumpF;
}
# 
# Check that we know this language
#
if (!exists($LangSettings{$Language}))
{
    die("Unrecognized language abbreviation \"$Language\".\n");
}
else
{
    $RootCategory=$LangSettings{$Language}{rootCategory};
    $CategoryWord=$LangSettings{$Language}{categoryWord};
    $TemplateWord=$LangSettings{$Language}{templateWord};
}
#
# Speed vs. (possibly) quality
#
if ($ConvertViaHTML)
{
    $OutputFormat=$Alvis::Wikipedia::XMLDump::OUTPUT_HTML;
}
else
{
    $OutputFormat=$Alvis::Wikipedia::XMLDump::OUTPUT_ALVIS;
}
if ($NamespacesTxt)
{
    for my $ns (split(/,/,$NamespacesTxt))
    {
	$ns=~s/^\s+//isgo;
	$ns=~s/\s+$//isgo;
	push(@Namespaces,$ns);
    }
}


my $XMLDumpF=shift @ARGV;

$|=1;

my $C=Alvis::Convert->new(outputRootDir=>$ODir,
                          outputNPerSubdir=>$NPerOutDir,
                          outputAtSameLocation=>0,
			  includeOriginalDocument=>$IncOrigDoc);
if (!defined($C))
{
    die("Instantiating Alvis::Convert failed.\n");
}

my %Seen;

my $N=0;
$C->init_output();
if (!$C->wikipedia($XMLDumpF,
		   [\&_output_wikipedia_article],
		   {expandTemplates=>$ExpandTemplates,
		    templateDumpF=>$TemplateDumpF,
		    outputFormat=>$OutputFormat,
		    categoryWord=>$CategoryWord,
                    date=>$Date,
		    namespaces=>[@Namespaces],
                    dumpCatGraph=>$DumpCatGraph,
		    catGraphDumpF=>$CatGraphDumpF},
		   [\&_wikipedia_progress]
		   ))
{
    die("Conversion failed. " . $C->errmsg());
}
print "\n";


sub _output_wikipedia_article
{
    my $title=shift;
    my $date=shift;
    my $output_format=shift;
    my $record_txt=shift;
    my $is_redir=shift;
    my $namespace=shift;

    warn "TITLE:$title";
    
    my $alvis_XML;
    if ($output_format eq $Alvis::Wikipedia::XMLDump::OUTPUT_HTML)
    {
	my $meta_txt;
	$meta_txt.="title\t$title\n";
	$meta_txt.="date\t$date\n";
	my $ns_txt="";
	if ($namespace ne '')
	{
	    $ns_txt="$namespace/";
	}
	$meta_txt.="url\twikipedia/$ns_txt$title\n";

	$alvis_XML=$C->HTML($record_txt,$meta_txt,{sourceEncoding=>'utf8'});
        if (!defined($alvis_XML))
        {
            warn "Obtaining the Alvis version of the " .
                "HTML version of an article failed. " . $C->errmsg() if
                $Warnings;
            $C->clearerr();
            return 1;
        }

    }
    elsif ($output_format eq $Alvis::Wikipedia::XMLDump::OUTPUT_ALVIS)
    {
	$alvis_XML=$record_txt;
    }
    else
    {
	die("Internal inconsistency: output format of a Wikipedia article " .
	    "is an unrecognized one: \"$output_format\".");
    }

    $title=~s/\//_/isgo;
    my $dir=$ODir . "/" . (int($N/$NPerOutDir)+1);
    system("mkdir -p $dir");  # fix this laziness for portability

    my $base_name=$dir . "/" . $title;

    if (!$C->output_Alvis([$alvis_XML],$base_name))
    {
	warn "Outputting the Alvis records for base name " .
	    "\"$base_name\" failed. " . $C->errmsg();
	$C->clearerr();
    }

    $N++;

    return 1;
}

sub _wikipedia_progress
{
    my $prog_txt=shift;
    my $total_nof_records=shift;
    my $nof_hits=shift;
    my $mess=shift;

    if (defined($total_nof_records) && defined($nof_hits))
    {
        print sprintf("%s Total:%d Found:%d",$prog_txt,
		      $total_nof_records,$nof_hits) . "\r";
    }
    else
    {
        if (!defined($mess))
        {
            $mess="";
        }
        print sprintf("%s %-70s",$prog_txt,$mess) . "\r";
    }
}


__END__

=head1 NAME
    
    wikipedia2alvis.pl - Wikipedia XML dump to Alvis XML converter
    
=head1 SYNOPSIS
    
    wikipedia2alvis.pl [options] [Wikipedia XML dump file]

  Options:

    --out-dir                      output directory
    --namespaces                   list of namespaces to extract
    --N-per-out-dir                # of records per output directory
    --[no-]original                include original document?
    --[no-]expand-templates-fully  do we try to expand templates fully?
    --[no-]dump-templates          do we dump the templates?
    --template-dump-file           the file to dump the templates to
    --[no-]convert-via-html        do we convert via HTML or directly to Alvis? 
    --date                         the date of the Wikipedia dump
    --[no-]dump-category-graph     do we dump the category graph?
    --category-graph-dump-file     the file to dump the category graph to
    --category-word                category namespace identifier
    --root-category                root category identifier
    --template-word                template namespace identifier
    --language                     the language of the Wikipedia dump
    --help                         brief help message
    --man                          full documentation
    --[no]warnings                 warnings output flag
    
=head1 OPTIONS
    
=over 8

=item B<--out-dir>

    Sets the output directory. Default value: '.'.

=item B<--namespaces>

    Sets the namespaces whose records to extract. Given as a ','-separated
    list. The namespace names have to be the exact identifiers. 
    Articles are always extracted. Default value: '''', i.e. articles.

=item B<--N-per-out-dir>

    Sets the # of records per output directory. Default value: 1000.

=item B<--[no-]original>

    Shall the original document be included in the output? Default
    value: no.

=item B<--[no-]expand-templates-fully>

    Do we try to expand templates fully or do we simply insert a list of
    the template parameter values given in the call? Default value: no.

=item B<--[no-]dump-templates>

    Do we dump the templates onto disk in a loadable format? 
    Default value: no.

=item B<--template-dump-file>

    The name of the (possible) template dump file. Default value: 
   'Templates.storable'.

=item B<--[no-]convert-via-html>

    Do we sacrifice speed for quality (possibly) by converting from 
    Wikitext to Alvis XML via an intermediate HTML version. 
    Default value: yes.

=item B<--language>

    The language of the Wikipedia dump. Affects category and template
    extraction. Possible values: 'en' (English), 'fr' (French), 'sl'
    (Slovenian). Default value: 'en'.

=item B<--category-word>

    The identifier for the category namespace. Overruled by '--language'.
    Default value: 'Category'.

=item B<--root-category>

    The identifier for the root category of the category graph. 
    Overruled by '--language'. Default value: 'fundamental'.

=item B<--template-word>

    The identifier for the template namespace. Overruled by '--language'.
    Default value: 'Template'.

=item B<--date>

    The date of the Wikipedia dump as YYYYMMDD. Default value: undefined 
    (means: use current date).

=item B<--[no-]dump-category-graph>

    Do we dump the category graph onto disk in a loadable format?. 
    Default value: yes.

=item B<--category-graph-dump-file>

    The name of the (possible) category graph dump file. Default value: 
    'CategoryGraph.storable'.

=item B<--help>

    Prints a brief help message and exits.

=item B<--man>

    Prints the manual page and exits.

=item B<--[no]warnings>

    Output (or suppress) warnings. Default value: yes.

=back

=head1 DESCRIPTION

    Converts the articles in the Wikipedia XML dump to Alvis records.
    
=cut


