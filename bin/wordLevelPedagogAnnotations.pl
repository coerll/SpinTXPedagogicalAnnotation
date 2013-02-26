#!/usr/bin/perl

use strict;
use File::Basename;
use warnings;
use JSON;

use Getopt::Long;
use Time::localtime;

# ---------------------------------------;
# Reading configuration paths from the enviroment variable $SPINTX_HOME as set in ~/.profile (in unix-like OS)
my $OutputDir = $ENV{SPINTX_HOME} . "corpus/ClipTags/";

my $OutputDirWLA = $OutputDir . "wla/"; #we will dump results in the wla folder under corpus/ClipTags
my $OutputDirStats = $OutputDir . "stats/";

my $OneFileJSON = $OutputDirWLA."ClipsWLAOneFile.json" ;
my $StatsFileForRecord = $OutputDirStats . timestamp() . "_ClipsWLAOneFile" . ".json";


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

# Variables to control initial lines in files to be processed, often special lines
my (@ALLLINES); # array with all the lines in a file to be processed

# Variable where all processed contents (and result of transformation) is stored and eventually printed.
my $ToPrint = ""; # where the output string is being concatenated and printed at the end in each transcript output file
my $ToPrintAtTheEnd = ""; # where the output string is being concatenated and printed in the data summarisation output file
my $ToPrintAtTheEndIncremental = "";
my $FileLineCounter = 0;
my %FeatureCounter; #hash where pedagogical feature counts are stored
my %FeatureCounterAllFiles; #hash where pedagogical feature counts are stored
my %LemmaCounter;
my $BooleanInWord = "FALSE";
my (@WordReadings);
##my (@OneWordAnnotations,@MultiWordAnnotations,@CompletionInfo);

my %HashForJSON; #this is a silly hash used to generate data in JSON format for compatibility with DRUPAL/solr
my @JSONStringsWholeCorpus; # this is a scalar to store the JSON data at the corpus level printed in a file at the very end of the process
my @JSONStringsWholeFileArray;

# TEST

my @ResultingAnnotationRecords;
my @PendingAnnotationRecords;
my @MultiwordRecordCompletionInfo;

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
print STDERR "Generating word level annotation files in JSON format...\n";

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

        $OutFile = $OutputDirWLA.$name."wla.json"; # *.wla, word level annotations file
        
        
        # reading contents of the file to be processed
        open (FILE,"$file");
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
            
            if ($CG3Line =~ m/^<[^>]>$/ & $BooleanInWord eq "FALSE"){
                if ($DebugLevel > 2) {
                    print STDERR "DL3: Current line is an SGML tag. Will be ignored.\n";
                    print STDERR "DL3: Line number: " . $FileLineCounter . "\n";
                }
                next;
            }
            elsif ($CG3Line =~ m/^<[^>]>$/ & $BooleanInWord eq "TRUE"){
                if ($DebugLevel > 2) {
                    print STDERR "DL3: Current line is an SGML tag. Will be ignored.\n";
                    print STDERR "DL3: Line number: " . $FileLineCounter . "\n";
                }

                if (scalar(@WordReadings) == 0)
                {
                    $BooleanInWord = "FALSE";
                }
                else{
                    if ($DebugLevel > 2) {
                        print STDERR "DL3: Previous one will be processed before going on.\n";
                    }
                 
                    &ProcessReadingsForPreviousWord(@WordReadings);
                    $BooleanInWord = "FALSE";
                    undef @WordReadings;
                }
                next;
            }
            elsif ($CG3Line =~ m/^\"<.*>\"$/ & $BooleanInWord eq "FALSE"){
                if ($DebugLevel > 2) {
                    print STDERR "DL3: Current line is word form.\n";
                    print STDERR "DL3: Line number: " . $FileLineCounter . "\n";
                }
                $BooleanInWord = "TRUE";
                next;
            }
            elsif ($CG3Line =~ m/^\"<.*>\"$/ & $BooleanInWord eq "TRUE"){

                if ($DebugLevel > 2) {
                    print STDERR "DL3: Current line is new word.\n";
                    print STDERR "DL3: Line number: " . $FileLineCounter . "\n";
                }

                if (scalar(@WordReadings) == 0)
                {
                    $BooleanInWord = "FALSE";
                }
                else{
                    
                    if ($DebugLevel > 2) {
                        print STDERR "DL3: Previous one will be processed before going on.\n";
                    }

                    &ProcessReadingsForPreviousWord(@WordReadings);
                    $BooleanInWord = "FALSE";
                    undef @WordReadings;
                }
                next;
            }
            elsif ($CG3Line =~ m/^\t\".*$/){
                if ($DebugLevel > 2) {
                    print STDERR "DL3: Current line is a reading.\n";
                    print STDERR "DL3: Line number: " . $FileLineCounter . "\n";
                }
                push(@WordReadings,$CG3Line);
            }

        } #end of foreach $CG3Line
        
        foreach my $a (@MultiwordRecordCompletionInfo) {
            my $TTIdTemp; 
            my $RelIdTemp;

            if ($DebugLevel > 1) {
                print STDERR "\n XXX $a";
            }            

            if ($a =~ m/^(tt-[0-9]+)_ID:([0-9]+)$/) {
                $TTIdTemp = $1; 
                $RelIdTemp = $2;
                
                if ($DebugLevel > 1) {
                    print STDERR "\n Temp ttid $TTIdTemp";
                    print STDERR "\n Temp RelId $TTIdTemp \n";
                }
            }
            
            foreach my $b (@PendingAnnotationRecords) {
                if ($b =~ m/^([^,]+),(tt-[0-9]+),R:([^0-9]*):$RelIdTemp,(.*)$/) {
                    $b = $1 . "," . $2 . "," . $TTIdTemp . "," . $3;
                    if ($DebugLevel > 1) {
                        print STDERR "\n FINISHED $b \n";
                    }
                    push(@ResultingAnnotationRecords,$b);
                }
            }
        }
        
        if ($DebugLevel > 1) {
            print STDERR "\n ONE WORD \n";
            print STDERR join("\n",@ResultingAnnotationRecords); 
            print STDERR "\n MULTI WORD \n";
            print STDERR join("\n",@PendingAnnotationRecords);
            print STDERR "\n ALONE \n";
            print STDERR join("\n",@MultiwordRecordCompletionInfo);
            print STDERR "\n";
        }
        
        my $JSONStringsWholeFile;
        my $JSONStringOneLiner;
        my @RECORDS;
        
        # the following foreach creates a hash that we later convert
        # into JSON format using PERL's json lib
        
        foreach my $record (@ResultingAnnotationRecords) {
            
            #each record in the array has the info clip, start and end token id
            @RECORDS = split(/,/,$record);
            $HashForJSON{'clip'} = $RECORDS[0];
            $HashForJSON{'start'} = $RECORDS[1];
            $HashForJSON{'end'} = $RECORDS[2];

            my $TempLabel = $RECORDS[3];
            my ($PedagogicalType, $PedagogicalTag);
            
            # the Hierarchy tag has to be split: the first level is internally called
            # type, and the second and optionally the third are called tag (and are printed 
            # together if there is second and third)
            
            if ($TempLabel =~ m/^([^:]+):(.+)$/ig){
                $PedagogicalType = $1;
                $PedagogicalTag = $2;
            }
            
            $HashForJSON{'type'} = $PedagogicalType;
            $HashForJSON{'tag'} = $PedagogicalTag;
            
            # this line encode the info in json format
            $JSONStringOneLiner = encode_json(\%HashForJSON);
            
            # this line adds all the strings in json format in one single array
            # there is one of these arrays for each clip file
            push(@JSONStringsWholeFileArray,$JSONStringOneLiner);

            # we make sure the @RECORDS array is emptied / initialized after each iteration
            undef @RECORDS;

        }

        # this prints the list of annotations for one single file in json format
        open (FOUT,">", $OutFile) || warn (" WARNING: Could not open $OutFile.\n") ;
        print FOUT "["; 
        print FOUT join(",",@JSONStringsWholeFileArray); 
        print FOUT "]"; 
        close (FOUT);
        
        foreach my $LemmaPOSPair (keys(%LemmaCounter)) {
            print STDERR $LemmaPOSPair . " : " . $LemmaCounter{$LemmaPOSPair};
            print STDERR "\n";
        }
        
        # the following line concatenates each file´s info into a larger array
        # later used to print the one-file-for-the-whole-corpus clip level annotations list
        @JSONStringsWholeCorpus = (@JSONStringsWholeCorpus,@JSONStringsWholeFileArray);
        
        # we make sure the @JSONStringsWholeFileArray array is emptied / initialized after each iteration
        undef @JSONStringsWholeFileArray;
        

    } #end of if $suffix eq "out"
    
} ## end of foreach $file

open (FOUT,">", $OneFileJSON) || warn (" WARNING: Could not open $OneFileJSON with write permission.\n") ;;
        print FOUT "["; 
        print FOUT join(",",@JSONStringsWholeCorpus); 
        print FOUT "]"; 
close (FOUT);

system ("cp -v $OneFileJSON $StatsFileForRecord");

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
        
        if ($DebugLevel > 2) {
            print STDERR join("|",@AllItemsInReading);
            print STDERR "\n";
        }
        $Lemma = $AllItemsInReading[0];
        $POSTag = $AllItemsInReading[1];
        
        $Lemma =~ s/\"(.+)\"/$1/ig;

        if ($DebugLevel > 2) {
            print STDERR "Lemma: " . $Lemma . "\n";
            print STDERR "POSTag: " . $POSTag . "\n";
        }
        
        $LemmaCounter{$Lemma."|".$POSTag}++;
        
        if ($Reading =~ m/(@|R|ID:)/) {
            
            @AllLemmaAnnotations = split(/ /,$Reading);
            
            # this foreach is used to identify the tokentag id (ttid) and the clip id 
            # for the relevant annotation line
            foreach my $Annotation (@AllLemmaAnnotations) {
                if ($Annotation =~ m/^tt-[0-9]+$/) {
                    $TTId = $Annotation;
                }
                elsif ($Annotation =~ m/^[A-Z]{2}[0-9]{3}_[0-9]{4}_.*$/) {
                    $ClipId = $Annotation;
                }
            }            

            # this foreach process the information of the pedagogical/metlinguistic tag
            # if it is a @-tag it stores it in the array @ResultingAnnotationRecords, which
            # does not require further processing. If it is an R-tag it stores in @PendingAnnotationRecords
            # and if it is an ID-tag it stores it in @MultiwordRecordCompletionInfo.
            # the two latter arrays are processed in the main routine so that
            # the starting and ending ttid is correctly stated in the resulting list.
            
            foreach my $Annotation (@AllLemmaAnnotations) {
                
                #if it has an @-symbol at the beginning it is a pedagogical feature annotation                    
                if ($Annotation =~ m/^@(.*)$/) {
                    #one word annotation
                    if ($DebugLevel > 2) {
                        print STDERR "In 1-word annotation: " . $Annotation . "\n";
                    }
                    $AnnotationRecord = join(",",$ClipId,$TTId,$TTId,$1);
                    push(@ResultingAnnotationRecords,$AnnotationRecord);
                }
                elsif  ($Annotation =~ m/^R:([^0-9]*):[0-9]+$/) {
                    #first word in multi word annotation
                    if ($DebugLevel > 2) {
                        print STDERR "In n-word annotation: " . $Annotation . "\n";
                    }
                    $AnnotationRecord = join(",",$ClipId,$TTId,$Annotation,$1);
                    push(@PendingAnnotationRecords,$AnnotationRecord);
                }
                elsif  ($Annotation =~ m/^ID:.*$/) {
                    #last word in multi word annotation
                    $AnnotationRecord = join("_",$TTId,$Annotation);
                    push(@MultiwordRecordCompletionInfo,$AnnotationRecord);
                }
                else { next; }
            }
        } #end of if $reading has @, R or ID
        else { next; }
        
    }# end of foreach $reading

    if ($DebugLevel > 4) {
        print STDERR "\n SUB ONE WORD \n";
        print STDERR join("\t",@ResultingAnnotationRecords); 
        print STDERR "\n SUB MULTI WORD \n";
        print STDERR join("\t",@PendingAnnotationRecords);
        print STDERR "\n SUB ALONE \n";
        print STDERR join("\t",@MultiwordRecordCompletionInfo);
        print STDERR "\n";
    }

    
    return (@ResultingAnnotationRecords,@PendingAnnotationRecords,@MultiwordRecordCompletionInfo);
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



