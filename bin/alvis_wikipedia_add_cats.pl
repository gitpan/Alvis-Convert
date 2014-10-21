#!/usr/bin/perl -w

use Getopt::Long;
Getopt::Long::Configure ("bundling");
use Pod::Usage;

use Alvis::Wikipedia::CatGraph;
use Alvis::Wikipedia::WikitextParser;

use strict;

my $PrintHelp=0;
my $PrintManual=0;
my $Warnings=1;
my $Suffix='alvis';
my $DumpF='CatGraph.Storable';
my $MethodName='2top';
my $Method=$Alvis::Wikipedia::CatGraph::TWO_TOP_LEVELS;
my $ScoreType='wikipedia Fundamental two top levels';
my $ListF=undef;
my $OutDir='.';
my $Root='fundamental';

GetOptions('help|?'=>\$PrintHelp, 
	   'man'=>\$PrintManual,
	   'warnings!'=>\$Warnings,
	   'out-dir=s'=>\$OutDir,
	   'alvis-suffix=s'=>\$Suffix,
	   'dump-file=s'=>\$DumpF,
	   'root=s'=>\$Root,
	   'score-type=s'=>\$ScoreType,
	   'method=s'=>\$MethodName,
	   'category-list-file=s'=>\$ListF
	   ) or 
    pod2usage(2);

pod2usage(1) if $PrintHelp;
pod2usage(-exitstatus => 0, -verbose => 2) if $PrintManual;
pod2usage(1) if (@ARGV!=1); 

if ($MethodName eq '2toplevels')
{
    $Method=$Alvis::Wikipedia::CatGraph::TWO_TOP_LEVELS;
}
elsif ($MethodName eq 'given')
{
    $Method=$Alvis::Wikipedia::CatGraph::GIVEN_LIST;
}

my $Dir=shift @ARGV;
my %Seen=();
my $Scores;

$|=1;

my $Parser=Alvis::Wikipedia::WikitextParser->new();
if (!defined($Parser))
{
    die("Instantiating Alvis::Wikipedia::WikitextParser failed.\n");
}
my $G=Alvis::Wikipedia::CatGraph->new(method=>$Method,
				      root=>$Root);
if (!defined($G))
{
    die("Instantiating Alvis::Wikipedia::CatGraph failed.\n");
}

print STDERR "Loading the graph....\r";
if (!$G->load_graph($DumpF))
{
    die("Loading the graph dump failed: " . $G->errmsg());
}
print STDERR "\n";

my $List;
if ($ListF)
{
    print STDERR "Getting the list of categories....\r";
    open(L,"<:utf8",$ListF) || die("Unable to open \"$ListF\"");;
    while (my $l=<L>)
    {
	chomp $l;
	push(@$List,$l);
    }
    close(L);
    print STDERR "\n";
}

print STDERR "Building the path length map....\r";
if (!$G->build_path_length_map($List))
{
    die("Building the path length map failed. " . 
	$G->errmsg());
}
print STDERR "\n";

system("mkdir -p $OutDir");
if (!&_add_cats_to_collection($Dir,{alvisSuffix=>$Suffix}))
{
    die("Adding categories to the collection failed. " . $G->errmsg());
}

sub _parse_entries
{
    my $entries=shift;
    my $options=shift;
    my $alvis_entries=shift;
    
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
	    &_parse_entries(\@entries,$options,$alvis_entries);
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
	    warn "Skipping non-suffixed non-directory entry \"$e\"." if 
		$Warnings;
	    next;
	}
	
	if ($suffix eq $options->{alvisSuffix})
	{
	    $alvis_entries->{$basename}{alvisF}=$e;
	}
    }
}

sub _add_cats_to_collection
{
    my $root_dir=shift;
    my $options=shift;

    my @entries=glob("$root_dir/*");
    my %alvis_entries=();
    %Seen=();
    print "Parsing the source directory entries...\r";
    &_parse_entries(\@entries,$options,\%alvis_entries);	
    print "                                       \r";

    for my $base_name (keys %alvis_entries)
    {
	my $alvisXML;
	
	if (exists($alvis_entries{$base_name}{alvisF}))
	{
	    my $f=$alvis_entries{$base_name}{alvisF};
	    open(W,"<:utf8",$f) || die("Unable to open \"$f\"");
	    my $out=$f;
	    $out=~s/^.*\///sgo;
	    open(OUT,">:utf8","$OutDir/$out") || 
		die("Unable to open \"$OutDir/$out\"");

	    my $new_rec="";
	    my $N=1;
	    while (my $record=&_get_next_rec(*W))
	    {
		my $cats=&_get_cats($record);
		if (!defined($cats))
		{
		    warn "Getting the categories of record #$N in file " .
			"\"$f\" failed."; 
		    next;
		}

		$Scores=$G->get_relative_scores($cats);
		if (!defined($Scores))
		{
		    warn "Getting the relative scores of record #$N in file " .
			"\"$f\" failed."; 
		    next;
		}
		
		$new_rec=&_output_rec_with_new_scores($record,$Scores);
		if (!defined($new_rec))
		{
		     warn "Getting the new, category-added version " .
			 "of record #$N in file " .
			 "\"$f\" failed."; 
		    next;
		}

		print OUT $new_rec;
		print STDERR "$N\r";
		$N++;
	    }
	    close(W);
	    print STDERR "\n";
	    close(OUT);
	}
    }

    return 1;
}

sub _output_rec_with_new_scores
{
    my $rec=shift;

    my $new_rec="";
    my @lines=split(/\n/,$rec);
    for my $l (@lines)
    {
	if ($l=~/<\/relevance>/)
	{
	    $new_rec.="      <scoreset type=\"$ScoreType\">\n";
	    for my $c (sort _c_score_cmp keys %$Scores)
	    {
		my $score=sprintf("%.1f",$Scores->{$c});
		$new_rec.="          <score topicId=\"$c\">$score</score>\n";
	    }
	    $new_rec.="      </scoreset>\n";
	}
	$new_rec.="$l\n";
    }

    return $new_rec;
}

sub _c_score_cmp
{
    if ($Scores->{$a}>$Scores->{$b})
    {
	return -1;
    }
    elsif ($Scores->{$a}<$Scores->{$b})
    {
	return 1;
    }
    else
    {
	return 0;
    }
}

sub _get_next_rec
{
    my $fh=shift;

    while (my $l=<$fh>)
    {
	if ($l!~/<documentRecord/)
	{
	    print OUT $l;
	}
	else
	{
	    my $rec=$l;
	    while (my $l=<$fh>)
	    {
		$rec.=$l;
		if ($l=~/<\/documentRecord/)
		{
		    return $rec;
		}
	    }
	}
    }
}

sub _get_cats
{
    my $rec=shift;

    my @cats=();
    my @lines=split(/\n/,$rec);
    for my $l (@lines)
    {
	if ($l=~/<location>wikipedia\/[cC]ategory:(.*?)<\/location>/)
	{
	    my $c=$1;
	    my $old_c=$c;
	    $c=$Parser->normalize_title($c);
	    if (!defined($c))
	    {
		warn "Normalizing title \"$old_c\" failed: " . 
		    $Parser->errmsg();
		next;
	    }
	    push(@cats,$c);
	}
    }

    return \@cats;
}


__END__

=head1 NAME
    
    alvis_wikipedia_add_cats.pl - adds relevance scores for categories 
                                  to an Alvis version of a Wikipedia dump
    
=head1 SYNOPSIS
    
    alvis_wikipedia_add_cats.pl [options] [Alvis XML root directory]

  Options:

    --out-dir                      output directory
    --alvis-suffix                 the suffix of Alvis XML source files
    --dump-file                    category graph dump file
    --score-type                   name of the score type added
    --method                       category picking method
    --category-list-file           file containing (prepicked) categories     
    --help                         brief help message
    --man                          full documentation
    --[no]warnings                 warnings output flag
    
=head1 OPTIONS
    
=over 8

=item B<--out-dir>

    Sets the output directory. Default value: '.'.

=item B<--alvis-suffix>

    The suffix of the source Alvis XML files. Default: 'alvis'.

=item B<--dump-file>

    The loadable (in Storable format) category graph dump file.
    Default: 'CatGraph.Storable'.

=item B<--score-type>

    The name of the new score type to be added to the Alvis XML
    files. Default: 'wikipedia Fundamental two top levels'.

=item B<--method>

    The method of determining the categories whose relevance to add.
    Choices: '2toplevels' (two top levels starting from the root). 


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
