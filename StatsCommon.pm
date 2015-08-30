#!/usr/bin/perl

package StatsCommon;

use strict;
use warnings;
require File::Spec;

require Exporter;
our @ISA = qw(Exporter);
# Export by default:
our @EXPORT = qw(
			trim ExtractID BuildRegexes LoadFlatTerms BuildOneRegex BuildTerm2ID CountLines
			ComputeTermStats ComputeSegStats_TermBased ComputeSegStats_InvConfidence OutputStats  
			GetFilesFromCommandLine 
		);

sub trim
{
	my $string = shift;
	$string =~ s/^\s+//;
	$string =~ s/\s+$//;
	return $string;
}

sub ExtractID
{
	my $resource = shift; # i.e. URL
	my $delimiter = shift; # can be # or / or similar characters
	
	if (!defined $resource || !defined $delimiter)
	{
		die "resource or delimiter is undefined\n";
	}
	
	my @parts = split(/$delimiter/, $resource);
	return $parts[$#parts];
}

sub BuildRegexes
{
	my $Terms = shift;
	my $dontcompile = shift;
	
	my $regexes = {}; my %DupControl = (); my $TermCountPerLang = {};
	foreach my $termid (keys %$Terms)
	{
		my $termrec = $$Terms{$termid};
		if (ref $termrec eq 'HASH')
		{
			my $termlang = $$termrec{'lang'};
			my $term = $$termrec{'text'};
			if (defined $termlang && defined $term && $term)
			{
				my $term = lc(trim($term));
				if (!defined($DupControl{$term}))
				{
					$DupControl{$term} = 1;
					$$TermCountPerLang{$termlang}++;
					$term = quotemeta($term);
					my $langregexes = $$regexes{$termlang};
					if (!defined $langregexes)
					{
						$langregexes = {};
						$$regexes{$termlang} = $langregexes;
					}
					if ($dontcompile)
					{
						$$langregexes{$termid} = "\\b$term\\b";
					}
					else
					{
						$$langregexes{$termid} = qr/\b$term\b/;
					}
				}
			}
		}
	}
	
	return ($regexes, $TermCountPerLang);
}

sub BuildOneRegex # returns a hash with language key 
{
	my $Terms = shift;
	my $lang = shift; # optional, comma-separated text list, if unspecified all languages are used
	my $dontcompile = shift; # optional
	
	my %langs;
	%langs = map { $_ => 1 } split(/,/, $lang) if ($lang);
	my $regexes = {}; my %DupControl = (); 
	foreach my $termid (sort { ${$$Terms{$a}}{'lang'} cmp ${$$Terms{$b}}{'lang'} || length(${$$Terms{$b}}{'text'}) <=> length(${$$Terms{$a}}{'text'}) } keys %$Terms)
	{
		my $termrec = $$Terms{$termid};
		if (ref $termrec eq 'HASH')
		{
			my $termlang = $$termrec{'lang'};
			my $term = $$termrec{'text'};
			if (defined $termlang && defined $term && $term && (!$lang || $langs{$termlang}))
			{
				my $term = lc(trim($term));
				if (!defined($DupControl{$term}))
				{
					$DupControl{$term} = 1;
					$term = quotemeta($term);
					if (!defined $$regexes{$termlang})
					{
						$$regexes{$termlang} = "";
					}
					else 
					{
						$$regexes{$termlang} .= "|";
					}
					$$regexes{$termlang} .= "\\b$term\\b";
				}
			}
		}
	}
	
	if (!$dontcompile)
	{
		foreach my $l (keys %$regexes)
		{
			my $langregex = $$regexes{$l};
			$$regexes{$l} = qr/$langregex/;
		}
	}
	
	return $regexes;
}

sub BuildTerm2ID
{
	my $Terms = shift;
	my $lang = shift; # compulsory, one language only
	
	my $t2id = {};
	foreach my $termid (keys %$Terms)
	{
		my $termrec = $$Terms{$termid};
		if ($$termrec{'lang'} eq $lang)
		{
			my $term = lc($$termrec{'text'});
			my $inid = $$t2id{$term};
			if (!defined $inid)
			{
				$$t2id{$term} = $termid;
			}
			elsif ($inid < 0 && $termid > 0)
			{
				$$t2id{$term} = $termid;
			}
			elsif ($inid > 0 && $termid < 0)
			{
				# do nothing, keep $inid as it is
			}
			else
			{
				print STDERR "WARNING: Duplicate term! '$term', old ID $inid, new ID $termid (keeping old ID)\n";
			}
		}
	}
	
	return $t2id;
}

sub LoadFlatTerms
{
	my $file = shift;
	my $langs = shift; # optional, leave blank to get all langs, otherwise, specify comma separated list in string
	
	my %langs;
	%langs = map { $_ => 1 } split(/,/, $langs) if ($langs);
	
	my $Terms = {};
	open(TERMS, "<:utf8", $file) or die "Cannot open '$file': $!\n";
	<TERMS>; # skip header
	while (my $line = <TERMS>)
	{
		chomp $line;
		my ($termid, $lang, $term) = split(/\t/, $line);
		next if (!$termid || !$langs || !$term);
		if (!$langs || $langs{$langs})
		{
			$$Terms{$termid} = { 'lang' => $lang, 'text' => $term };
		}
	}
	close(TERMS);
	
	return $Terms;
}

sub CountLines
{
	my $file = shift;
	my $subtractheader = shift;
	
	my @wc = split(/\s+/, `wc -l $file`);
	my $numlines = $wc[0] - ($subtractheader ? 1 : 0);
	
	return $numlines;
}

sub ComputeTermStats
{
	my $termstats = shift;
	
	my $TermStats = {};
	open(TERMSTATS, "<:utf8", $termstats) or die "Cannot open '$termstats': $!\n";
	<TERMSTATS>; # consume header
	while (my $line = <TERMSTATS>)
	{
		chomp $line;
		my ($termid, $term, $SegFreq, $TMFreq, $IDF) = split(/\t/, $line);
		$$TermStats{$termid} = {'term' => $term, 'SegFreq' => $SegFreq, 'TMFreq' => $TMFreq, 'IDF' => $IDF};
	}
	close(TERMSTATS);
	
	return $TermStats;
}

sub ComputeSegStats_TermBased
{
	my $segterms = shift;
	my $TermStats = shift;
	my $DataCateg = shift;
	
	my $SegStat = {};
	open(SEGTERM, "<:utf8", $segterms) or die "Cannot open '$segterms': $!\n";
	<SEGTERM>; # consume header
	while (my $line = <SEGTERM>)
	{
		chomp $line;
		my ($segix, $termids) = split(/\t/, $line);
		my @termids = split(/\s+/, $termids);
		my $segstat = 0;
		foreach my $termid (@termids)
		{
			my $TermStatsRec = $$TermStats{$termid};
			$segstat += log(1 + $$TermStatsRec{$DataCateg});
		}
		$$SegStat{$segix} = $segstat;
	}
	close(SEGTERM);
	
	return $SegStat;
}

sub ComputeSegStats_InvConfidence
{
	my $transfile = shift;
	
	my $SegStat = {};
	open(TR, "<:utf8", $transfile) or die "Cannot open '$transfile': $!\n";
	my $segix = 1;
	while (my $line = <TR>)
	{
		chomp $line;
		$line =~ /\t(.+)$/;
		my $confidence = $1;
		$$SegStat{$segix} = -1 * $confidence;
		$segix++;
	}
	close(TR);
	
	return $SegStat;
}

sub OutputStats
{
	my $SegStat = shift;
	my $outfile = shift;
	
	open(SEGSTAT, ">:utf8", $outfile) or die "Cannot create '$outfile': $!\n";
	print SEGSTAT "line\tstat\n";
	foreach my $segix (sort { $$SegStat{$b} <=> $$SegStat{$a} } keys %$SegStat)
	{
		my $segstat = $$SegStat{$segix};
		print SEGSTAT "$segix\t$segstat\n";
	}
	close(SEGSTAT);
}

sub GetFilesFromCommandLine
{
	my $getrelativepaths = shift;
	
	my $TotalFiles = @ARGV;
	if ($TotalFiles <= 0)
	{
		print STDERR "\nSpecify files!\n\n";
	    exit 1;
	}
	my %FilesH = ();
	foreach my $item (@ARGV)
	{
		if (($item =~ /\*/) or ($item =~ /\?/))
		{
			my @list = glob $item;
			foreach my $i (@list)
			{
				$FilesH{$i} = 1;
			}
		}
		else
		{
			$FilesH{$item} = 1;
		}
	}
	
	my @Files;
	if ($getrelativepaths)
	{
		 # Relative paths are OK
		 @Files = sort(keys %FilesH);
	}
	else
	{
		# Get absolute path to files (assuming we have paths relative to current directory) - default behaviour
		@Files = ();
		foreach my $filename (sort(keys %FilesH))
		{
			my $abs_path = ($filename !~ /^~/) ? File::Spec->rel2abs($filename) : $filename; 
			# noticed that if ~ is the first char in the path, rel2abs doesn't work. So if ~ is first char in path, we leave it like that as that's some sort of absolute path.
			push @Files, $abs_path;
		}
	}
	
	
	return @Files;
}

1;
