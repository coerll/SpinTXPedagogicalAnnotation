#!/usr/bin/perl

use utf8;
use strict;
use File::Basename;
use warnings;

use Getopt::Long;
use Time::localtime;

# ---------------------------------------;
# Reading configuration paths from the enviroment variable $SPINTX_HOME as set in ~/.profile (in unix-like OS)
my $OutputDir = $ENV{SPINTX_HOME} . "corpus/SpinTXCorpusData/";
my $OutputDirCQP = $OutputDir . "ClipCQP/"; #we will dump results in the wla folder under corpus/ClipTags

# ---------------------------------------;
# VARIABLE DEFINITION

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


# Variables to control initial lines in files to be processed, often special lines
my (@ALLLINES); # array with all the lines in a file to be processed

# Variable where all processed contents (and result of transformation) is stored and eventually printed.
my $ToPrint = ""; # where the output string is being concatenated and printed at the end in each transcript output file
my $ToPrintAtTheEnd = ""; # where the output string is being concatenated and printed in the data summarisation output file
my $ToPrintAtTheEndIncremental = "";
my $FileLineCounter = 0;
my %FeatureCounter; #hash where pedagogical feature counts are stored
my %FeatureCounterAllFiles; #hash where pedagogical feature counts are stored
my %LemmaList;
my %LemmaTypeCounter;
my $BooleanInWord = "FALSE";
my (@WordReadings);
my @ProcessedInfoReadings;
my $CurrentForm;

##my (@OneWordAnnotations,@MultiWordAnnotations,@CompletionInfo);

my %HashForJSON; #this is a silly hash used to generate data in JSON format for compatibility with DRUPAL/solr
my %HashForJSONTwoLevels; #this is a silly hash used to generate data in JSON format for compatibility with DRUPAL/solr
my @JSONStringsWholeCorpus; # this is a scalar to store the JSON data at the corpus level printed in a file at the very end of the process
my @CSVStringsWholeCorpus; # this is a scalar to store the JSON data at the corpus level printed in a file at the very end of the process
my @JSONStringsWholeFileArray;
my @CSVStringsWholeFileArray;
my $VocabListSingleFileForWholeCorpusToPrint = "ClipId\tVocab\n";
my @ForVocabListSingleFileForWholeCorpus;

# TEST

my @ResultingAnnotationRecords;
my @PendingAnnotationRecords;
my @MultiwordRecordCompletionInfo;
my ($LemmaInPair,$POSInPair,$TTIDInPair,$ClipIDInPair);

# ---------------------------------------;
# STARTING WITH READING OPTIONS
# ---------------------------------------;


GetOptions(\%opts, "help|?", "debug=s", "silent");

if ($opts{'help'}) {
    print STDERR "\nGeneration of word-level information for the autoamtically 
    annotated pedagogical features in SPinTX transcripts. 
    Takes *.out file as input.
    \n";
    print STDERR "Version: 0.1 // Author: Martí Quixal (2012 - today) \n";
    print STDERR "This code is totally free and open. Share and enjoy!\n";
    print STDERR "\n";
    print STDERR "Usage: wordLevelPedagogAnnotations.pl [OPTIONS]\n";
    print STDERR "\n";
    print STDERR "Options:\n";
    print STDERR " -help,-? \t\t shows this help\n";
    print STDERR " -debug \t\t debug level 0 (default), 1, 2, 3 or 4\n";
    exit;
}

if ($opts{'debug'}) {
	$DebugLevel = $opts{'debug'};
}
else{
	$DebugLevel = 0;
}

# ---------------------------------------;

# -- STARTING EXECUTION OF CONVERSION
print STDERR "Generating word level annotation files in CQP format...\n";

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
        
        # debug level 2
        if ($DebugLevel > 1) {
            print STDERR "DL2: File " . $file . " will be proccessed.\n";
        }

        $OutFile = $OutputDirCQP.$name."cqp"; # *.wla, word level annotations file
        
        if ($DebugLevel > 1) {
            print STDERR "DL2: Output file name will be " . $OutFile . "\n";
        }
        
        # reading contents of the file to be processed
        open (FILE,"$file") || warn "Could not open $file\n";
        sysread(FILE,$Text,(-s FILE));
        close (FILE);
        
        # split file contents into line. each line is an annotated token
        @ALLLINES = split(/\n/,$Text);
        
        $FileLineCounter = 0;
        undef @ResultingAnnotationRecords;
        undef @PendingAnnotationRecords;
        undef @MultiwordRecordCompletionInfo;
        
        foreach my $CG3Line (@ALLLINES) {
            
            $FileLineCounter++;
            
            # print XML lines as is and do nothing else if we are not in word reading, that is $BooleanInWord is FALSE
            if ($CG3Line =~ m/^<[^>]+>$/ & $BooleanInWord eq "FALSE"){
                if ($DebugLevel > 2) {
                    print STDERR "DL3: Current line is an SGML tag. Will be printed as is.\n";
                    print STDERR "DL3: Line number: " . $FileLineCounter . "\n";
                }

                $ToPrint .= $CG3Line . "\n";
            }
            
            # if $BooleanInWord is TRUE and find and XML line
            ## 1. Process and print word reading
            ## 2. Print XML as is
            elsif ($CG3Line =~ m/^<[^>]+>$/ & $BooleanInWord eq "TRUE"){
                
                if ($DebugLevel > 2) {
                    print STDERR "DL3: Current line is an SGML tag. Will be ignored.\n";
                    print STDERR "DL3: Line number: " . $FileLineCounter . "\n";
                }
                
                # Sometimes wordreadings might be empty ( *** I DONT KNOW WHY/WHEN)
                if (scalar(@WordReadings) == 0){}
                
                # if @WordReadings is full then process and print its contents
                else{
                    if ($DebugLevel > 2) {
                        print STDERR "DL3: Previous one will be processed before going on.\n";
                    }
                 
                    @ProcessedInfoReadings = &ProcessReadingsForPreviousWord(@WordReadings);
                    $ToPrint .= join ("\t",@ProcessedInfoReadings);
                    $ToPrint .= "\n";
                    undef @WordReadings;
                }
                
                $ToPrint .= $CG3Line . "\n";
                $BooleanInWord = "FALSE";
            }
            
            
            # if $BooleanInWord is FALSE and find a word form line ("<tengo>")
            ## 1. Print XML as is
            ## 2. Set variable $BooleanInWord to TRUE
            elsif ($CG3Line =~ m/^\"<(.*)>\"$/ & $BooleanInWord eq "FALSE"){
                $CurrentForm = $1;
                $CurrentForm =~ s/\$([^[a-z0-9])/$1/ig;
#                $CurrentForm =~ s/\$([\.,\:\?\!¡])/$1/ig;
#                $CurrentForm =~ s/\$(¿)/$1/ig;

                if ($DebugLevel > 2) {
                    print STDERR "DL3: Current line is word form.\n";
                    print STDERR "DL3: Line number: " . $FileLineCounter . "\n";
                }
                $ToPrint .= $CurrentForm . "\t";
                $BooleanInWord = "TRUE";
            }
            
            # if $BooleanInWord is TRUE and find a word form line ("<tengo>")
            ## 1. Print XML as is
            ## 2. Set variable $BooleanInWord to TRUE
            elsif ($CG3Line =~ m/^\"<(.*)>\"$/ & $BooleanInWord eq "TRUE"){

                $CurrentForm = $1;
                $CurrentForm =~ s/\$([^[a-z0-9])/$1/ig;

                if ($DebugLevel > 2) {
                    print STDERR "DL3: Current line is new word.\n";
                    print STDERR "DL3: Line number: " . $FileLineCounter . "\n";
                }

                # Sometimes wordreadings might be empty ( *** I DONT KNOW WHY/WHEN)
                if (scalar(@WordReadings) == 0)
                {
                    $ToPrint .= $CurrentForm . "\t";
                }
                
                # if @WordReadings is full then process and print its contents
                else{
                    
                    if ($DebugLevel > 2) {
                        print STDERR "DL3: Previous one will be processed before going on.\n";
                    }

                    # 1. Print previous word readings
                    @ProcessedInfoReadings = &ProcessReadingsForPreviousWord(@WordReadings);
                    $ToPrint .= join ("\t",@ProcessedInfoReadings);
                    $ToPrint .= "\n";
                    
                    # 2. Print current word form
                    $ToPrint .= $CurrentForm . "\t";

                    # empty list of word readings
                    undef @WordReadings;
                }

                # Set current $BooleanInWord to "FALSE";
                $BooleanInWord = "TRUE";
            }
            
            # if line is a reading line just add it to @WordReadings list
            elsif ($CG3Line =~ m/^\t\".*$/){
                if ($DebugLevel > 2) {
                    print STDERR "DL3: Current line is a reading.\n";
                    print STDERR "DL3: Line number: " . $FileLineCounter . "\n";
                }
                push(@WordReadings,$CG3Line);
            }

        } #end of foreach $CG3Line
        
        
    } #end of if $suffix eq "out"
    
} ## end of foreach $file

print STDERR $ToPrint; 
print STDERR "\n"; 

open (FOUT,">", $OutFile) || warn ("WARNING: Could not open $OutFile with write permission.\n") ;;
        print FOUT $ToPrint; 
        print FOUT "\n"; 
close (FOUT);

print STDERR "Done!\n";

###############
# SUBROUTINES #
###############

sub ProcessReadingsForPreviousWord {

    my @ReadingsToBeProcessed = @_;
    my @AllLemmaAnnotations;
    my $ClipId;
    my $TTId;
    
    # variables used while processing the different readings
    my $AnnotationRecord;
    my @AllItemsInReading;
    my ($Lemma,$POSTag);
    
    foreach my $Reading (@ReadingsToBeProcessed) {
        
        @AllItemsInReading = split(/ /,$Reading);
        
        if ($AllItemsInReading[0] =~ m/\"([^\"]+)\"/) {
            $AllItemsInReading[0] = $1;
        } 
    
    }
    
    return (@AllItemsInReading);
    #    return (@ResultingAnnotationRecords,@PendingAnnotationRecords,@MultiwordRecordCompletionInfo);
}


###--------------------------------------------------------------;
###--------------------------------------------------------------;

########################
## SUBROUTINE TO ADD TIMESTAMP TO FILE NAMES
########################

sub timestamp {
    my $t = localtime;
    return sprintf( "%04d-%02d-%02d_%02d-%02d-%02d",
    $t->year + 1900, $t->mon + 1, $t->mday,
    $t->hour, $t->min, $t->sec );
}

## SAMPLE USAGE
##print '[' . timestamp() . ']: my message'. "\n";

