#!/usr/bin/perl

use strict;
use warnings;
use FindBin;
use lib $FindBin::RealBin;
use Getopt::Long;
use StatsCommon;

my $termfile = "";
my $lang = "";
my $outprefix = "";
my $outputPath = "";
GetOptions(
	   "termfile:s" => \$termfile,
	   "lang:s" => \$lang,
	   "outprefix:s" => \$outprefix,
           "outputpath:s" => \$outputPath
	   );

my @TMfiles = GetFilesFromCommandLine();
print "Loading terminology ...\n";
my $Terms = LoadFlatTerms($termfile, $lang);
print "Building regex ...\n";
my $regexes = BuildOneRegex($Terms, $lang); 
my $term2id = BuildTerm2ID($Terms, $lang);

open(REGEX, ">:utf8", $outputPath . "$outprefix.regexes.txt");
print REGEX "DEBUG REGULAR EXPRESSIONS:\n";
foreach my $l (%$regexes)
{
	my $pre = $$regexes{$l};
	print REGEX "$l:\n$pre\n" if (defined $pre);
}
foreach my $term (sort keys %$term2id)
{
	my $id = $$term2id{$term};
	print REGEX "$id\t$term\n";
}
close(REGEX);

my $bigregex = $$regexes{$lang};
my %SegmentsFreq = (); # aka document frequency - number of segments in the TM that term occurs in
my %TMFreq = (); # aka collection frequency - total number of occurrences of term in the TM

print "Matching terms in TM ...\n";
my $numsegs = 1;
my $segtermsfile = $outputPath . "$outprefix.segterms.txt";
foreach my $TMfile (@TMfiles)
{
	my $TMfileFH;
	open($TMfileFH, "<:utf8", $TMfile) or die "Cannot open '$TMfile': $!\n";
	open(SEGTERM, ">:utf8", $segtermsfile) or die "Cannot create '$segtermsfile': $!\n";
	print SEGTERM "segix\ttermids\n";
	while (my $line = <$TMfileFH>)
	{
		chomp $line;
		my @matches = ($line =~ /$bigregex/ig);
		my $segterms = "";
		foreach my $match (@matches)
		{
			my $termid = $$term2id{$match};
			die "Matched term '$match' not found !!!\n" if (!defined $termid);
			$segterms .= "$termid ";
		}
		chop $segterms;
		print SEGTERM "$numsegs\t$segterms\n";
		$numsegs++;
	}
	$numsegs--; # to correct for 1-index
	close($TMfileFH);
	close(SEGTERM);
	
	print "Terms per segments in file $segtermsfile\n";
	
	print "Counting terms in this file\n";
	open(SEGTERM, "<:utf8", $segtermsfile) or die "Cannot open '$segtermsfile': $!\n";
	<SEGTERM>; # consume header
	while (my $line = <SEGTERM>)
	{
		chomp $line;
		$line =~ /\t(.*)$/;
		my $termIDstxt = $1;
		my @termIDs = split(/\s/, $termIDstxt);
		my %UniqueTermIDs = ();
		foreach my $termID (@termIDs)
		{
			$UniqueTermIDs{$termID} = 1;
			$TMFreq{$termID}++;
		}
		foreach my $termID (keys %UniqueTermIDs)
		{
			$SegmentsFreq{$termID}++;
		}
	}
	close(SEGTERM);
}

my $outtermfile = $outputPath . "$outprefix.termstats.txt";
open(TERMS, ">:utf8", $outtermfile) or die "Cannot create '$outtermfile': $!\n";
print TERMS "termid\tterm\tSegFreq\tTMFreq\tIDF\n";
#foreach my $termid (sort { ${$$Terms{$a}}{'text'} cmp ${$$Terms{$b}}{'text'} } keys %$Terms)
foreach my $termid (sort { $TMFreq{$b} <=> $TMFreq{$a} } keys %TMFreq)
{
	my $termrec = $$Terms{$termid};
	# next if ((!defined $$termrec{'lang'}) || $$termrec{'lang'} ne $lang);
	my $termtype = $$termrec{'text'};
	
	my $segfreq = $SegmentsFreq{$termid};
	# $segfreq = 0 if (!defined $segfreq);
	my $tmfreq = $TMFreq{$termid};
	# $tmfreq = 0 if (!defined $tmfreq);
	# next if ($segfreq == 0 && $tmfreq == 0);
	
	# my $idf = $segfreq != 0 ? log($numsegs / $segfreq) : "";
	my $idf = log($numsegs / $segfreq);
	
	print TERMS "$termid\t$termtype\t$segfreq\t$tmfreq\t$idf\n";
}
close(TERMS);
print "Global term statistics in $outtermfile\n";

# RankSegs_TermBased.pl funcionality inserted below
my $termcat = 'SegFreq';
my $outfile = $outputPath . "results$outprefix.txt";
my $TermStats = ComputeTermStats($outtermfile);
my $SegStat = ComputeSegStats_TermBased($segtermsfile, $TermStats, $termcat);
OutputStats($SegStat, $outfile);
