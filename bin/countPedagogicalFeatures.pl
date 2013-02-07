#!/usr/bin/perl

use strict;
use File::Basename;

use Getopt::Long;

# ---------------------------------------;

# ---------------------------------------;
# VARIABLE DEFINITION

# -- VARIABLE DEFINITION

## -- To control program execution modes
my %opts;
my $DebugLevel;
my $OutputFormat; #to store the format in which the output file will be printed

# variables to handle file names, paths and contents
my $CG3File; # input file name
my $OutFile; # output file name (one output file for all input files)
my ($name,$path,$suffix); # name, path and suffix of input file
my $file; # input file name including path and extention (to be opened by script)
my $Text; # input file contents
my $OutputDir;

# Variables to control initial lines in files to be processed, often special lines
my (@ALLLINES); # array with all the lines in a file to be processed

# Variable where all processed contents (and result of transformation) is stored and eventually printed.
my $ToPrint = ""; # where the output string is being concatenated and printed at the end in each transcript output file
my $ToPrintAtTheEnd = ""; # where the output string is being concatenated and printed in the data summarisation output file
my $ToPrintAtTheEndIncremental = "";
my $FileLineCounter = 0;
my %FeatureCounter; #hash where pedagogical feature counts are stored
my %FeatureCounterAllFiles; #hash where pedagogical feature counts are stored

# ---------------------------------------;
# STARTING WITH READING OPTIONS
# ---------------------------------------;


GetOptions(\%opts, "help|?", "debug=s", "outformat=s", "silent");

if ($opts{'help'}) {
    print STDERR "\nPedagogical feature counting for CG3 annotated files for SPinTX\n";
    print STDERR "Version: 0.1 // Author: Martí Quixal (2012 - today) \n";
    print STDERR "This code is totally free and open. Share and enjoy!\n";
    print STDERR "\n";
    print STDERR "Usage: countPedagogicalFeatures.pl [OPTIONS]\n";
    print STDERR "\n";
    print STDERR "Options:\n";
    print STDERR " -help,-? \t\t shows this help\n";
    print STDERR " -debug \t\t shows this help\n";
    print STDERR " -outformat \t\t specifies output format, solr for SPinTX/drupal compatible format\n";
    exit;
}

if ($opts{'debug'}) {
	$DebugLevel = $opts{'debug'};
}
else{
	$DebugLevel = 0;
}

if ($opts{'outformat'}) {
	$OutputFormat = $opts{'outformat'};
}
else {
	print STDERR "\n EXECUTION ABORTED. An ouput format is required. \n";
	print STDERR " Expected format is solr.\n";
	print STDERR "\n Use -outformat=solr to declare it.\n";
    exit;
}

# ---------------------------------------;

# -- STARTING EXECUTION OF CONVERSION
print STDERR "Starting counting...\n";

foreach $file (@ARGV) {
    
    #debug levels, have to be controlled later
    if ($DebugLevel == 1) {
        print STDERR "DL1: Reading new file...\n";
    }
    if ($DebugLevel > 1) {
        print STDERR "DL2: Current file " . $file . " read.\n";
    }
    # filling/reading filename, file path and file suffix variable
    ($name,$path,$suffix) = fileparse($file, qw/out/);
    
    # working only with files with 'txt' as extension
    if ($suffix eq "out") {
        
        # debug level 3
        if ($DebugLevel > 1) {
            print STDERR "DL2: File " . $file . " will be proccessed.\n";
        }
        # generating name for output file, cpr stands for compressed
        if ($OutputFormat eq "solr") {
            $OutputDir = "";
            $OutFile = $path.$OutputDir.$name."solr";
        }
        elsif ($OutputFormat eq "cloud") {
            $OutputDir = "";
            $OutFile = $path.$OutputDir.$name."cloud";
        }
        else {
            print STDERR "\n EXECUTION ABORTED. Unexpected ouput format. \n";
            print STDERR " The only available format is solr.\n";
            #            print STDERR "\n Use -outformat=cg3 or cqp to declare it.\n";
            exit;
        }
        
        
        # reading contents of the file to be processed
        open (FILE,"$file");
        sysread(FILE,$Text,(-s FILE));
        close (FILE);
        
        # split file contents into line. each line is an annotated token
        @ALLLINES = split(/\n/,$Text);

        $FileLineCounter = 0;
        my $WordForm;
        my $Lemma;
        my $LemmaAnnotations;
        my @AllLemmaAnnotations;
        my @AllPedagogicalFeaturesInAReading;
        
        foreach my $CG3Line (@ALLLINES) {
            if ($CG3Line =~ m/^<(text|speaker|lang)>/) {
                if ($DebugLevel > 1) {
                    print STDERR "\n DL2: Line " . $FileLineCounter . " is a SGML-tag line and will be ignored.";
                }
            }
            elsif ($CG3Line =~ m/^\"<([^>]+)>\"$/) {
                $WordForm = $1;
                if ($DebugLevel > 2) {
                    print STDERR "\n DL3: Line " . $FileLineCounter . " is a wordform line and will be ignored.";
                    print STDERR "\n Word is: " . $WordForm ;
                }
            }
            elsif  ($CG3Line =~ m/^\t\"([^\"]+)\"(.+)$/) {
                $Lemma = $1;
                $LemmaAnnotations = $2;
                if ($LemmaAnnotations =~ m/(@|R:)/) {
                    @AllLemmaAnnotations = split(/ /,$LemmaAnnotations);
                    foreach my $Annotation (@AllLemmaAnnotations) {

                        #if it has an @-symbol at the beginning it is a pedagogical feature annotation                    
                        if ($Annotation =~ m/^(@|R:)/) {
                            if ($DebugLevel > 1) {
                                print STDERR "\n DL2: Working on annotation: " . $Annotation;
                            }

                            @AllPedagogicalFeaturesInAReading = split(/:/,$Annotation);

                            if ($DebugLevel > 1) {
                                print STDERR "\n DL2: list of atom features.\n";
                                print STDERR "  List: ";
                                print STDERR join("|",@AllPedagogicalFeaturesInAReading);
                                print STDERR "\n List finished.\n";
                            }

                            my $CurrentFeature;
                            my $IgnoredFeature = "";
                            my $TokenFeatureCounter = 0;
                            
                            foreach my $feature (@AllPedagogicalFeaturesInAReading) {
                                $TokenFeatureCounter++;
                                if ($TokenFeatureCounter == 1) {
                                    if ($DebugLevel > 1) {
                                        print STDERR "\n DL2: Current feature is the first to be handled on the list.";
                                    }
                                    if ($feature eq "R"){
                                        if ($DebugLevel > 1) {
                                            print STDERR "\n DL2: Current feature is " . $feature . "\n";
                                            print STDERR "   So it should be IGNORED.\n";
                                        }
                                        $IgnoredFeature = $feature;
                                        next;
                                    }
                                    else {
                                        $CurrentFeature = $feature;
                                        if ($DebugLevel > 1) {
                                            print STDERR "\n DL2: Current feature is " . $CurrentFeature . "\n";
                                            print STDERR "   So it WILL BE COUNTED.\n";
                                        }
                                    }
                                }
                                else {
                                    if ($IgnoredFeature eq "R") {
                                        $CurrentFeature .= $IgnoredFeature. ":" . $feature;
                                        $IgnoredFeature = "";
                                    }
                                    elsif ($feature =~ m/^[0-9]+$/) {
                                        if ($DebugLevel > 1) {
                                            print STDERR "\n DL2: Current feature is a number "  . $feature . "\n";
                                            print STDERR "   So it should be IGNORED.\n";
                                        }
                                        next;
                                    }
                                    else {
                                        $CurrentFeature .= ":" . $feature;
                                    }
                                }
                                $FeatureCounter{$CurrentFeature}++;
                                $FeatureCounterAllFiles{$CurrentFeature}++;
                            } # end of foreach that iterates through peadgogical feature atoms
                            
                        }
                    }
                }
                else{
                    if ($DebugLevel > 2) {
                        print STDERR "\n DL3: Line " . $FileLineCounter . "for lemma " . $Lemma . " has no pedagogical features." ;
                        print STDERR "\n Contents: " . $CG3Line ;
                    }
                }

            }
        } #end of foreach that iterates through all lines in each file
        ($ToPrint,$ToPrintAtTheEnd) = &PrintDataForFile($file,%FeatureCounter);
        $ToPrintAtTheEndIncremental .= $ToPrintAtTheEnd;
        open (FOUT,">$OutFile");
        print FOUT $ToPrint;
        close (FOUT);
        undef (%FeatureCounter);
    }
} #end of foreach $file (@ARGV), foreach that iterates through all the input files

print STDOUT "GlobalStats";
foreach my $key (sort (keys(%FeatureCounterAllFiles))){
    print STDOUT "\t" . $key . " | " . $FeatureCounterAllFiles{$key};
}
print STDOUT "\n";

open (FOUT,">SpintxPedagogicalMetadata.csv");
print FOUT $ToPrintAtTheEndIncremental;
close (FOUT);

undef (%FeatureCounterAllFiles);



###-----------------------------------------------;

sub PrintDataForFile {
    my ($FileName,%HashWithCounts) = @_;
    my ($PrintToReturn,$PrintToReturnForOneFileInfo);
    
    $FileName =~ s/^([^\.]+)\.out$/$1/ig;
    $PrintToReturn = $FileName;
    $PrintToReturnForOneFileInfo = $FileName . "\t"; 
    
    foreach my $key (sort (keys(%HashWithCounts))){
        $PrintToReturn .= "\n" . $key . " : " . $HashWithCounts{$key};
        # This was the original printing format, which included
        #$PrintToReturnForOneFileInfo .= "," . $key . "," . $HashWithCounts{$key};
    }

    my @TempSortedArray;
    @TempSortedArray = sort keys(%HashWithCounts);
    $PrintToReturnForOneFileInfo .= join(",",@TempSortedArray );
        
    $PrintToReturn .= "\n";
    $PrintToReturnForOneFileInfo .= "\n";
    
    return ($PrintToReturn,$PrintToReturnForOneFileInfo);
}
