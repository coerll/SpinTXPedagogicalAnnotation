#!/usr/bin/perl

use strict;
use File::Basename;
use warnings;
use JSON;

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
my $BooleanInWord = "FALSE";
my (@WordReadings);
##my (@OneWordAnnotations,@MultiWordAnnotations,@CompletionInfo);

my %HashForJSON; #this is a silly hash used to generate data in JSON format for compatibility with DRUPAL/solr
my $JSONStringsWholeCorpus; # this is a scalar to store the JSON data at the corpus level printed in a file at the very end of the process

# TEST

my @ResultingAnnotationRecords;
my @PendingAnnotationRecords;
my @MultiwordRecordCompletionInfo;

# ---------------------------------------;
# STARTING WITH READING OPTIONS
# ---------------------------------------;


GetOptions(\%opts, "help|?", "debug=s", "outformat=s", "silent");

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

#if ($opts{'outformat'}) {
#	$OutputFormat = $opts{'outformat'};
#}
#else {
#	print STDERR "\n EXECUTION ABORTED. An ouput format is required. \n";
#	print STDERR " Expected format is solr.\n";
#	print STDERR "\n Use -outformat=solr to declare it.\n";
#    exit;
#}

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

        $OutputDir = "";
        $OutFile = $path.$OutputDir.$name."wla.json"; # *.wla, word level annotations file
        
        
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
        
        # FITA: this needs to be generated as a hash
        # and then converted into json
        
        foreach my $record (@ResultingAnnotationRecords) {
            @RECORDS = split(/,/,$record);
            $HashForJSON{'clip'} = $RECORDS[0];
            $HashForJSON{'start'} = $RECORDS[1];
            $HashForJSON{'end'} = $RECORDS[2];

            my $ TempLabel = $RECORDS[3];
            my ($PedagogicalType, $PedagogicalTag);
            
            if ($TempLabel =~ m/^([^:]+):(.+)$/ig){
                $PedagogicalType = $1;
                $PedagogicalTag = $2;
            }
            
            $HashForJSON{'type'} = $PedagogicalType;
            $HashForJSON{'tag'} = $PedagogicalTag;
            
            $JSONStringOneLiner = encode_json(\%HashForJSON);
            $JSONStringsWholeFile .= $JSONStringOneLiner ."\n"; 

            undef @RECORDS;

        }


        open (FOUT,">$OutFile");
#        my @s = sort {$a cmp $b} @ResultingAnnotationRecords;
#        $json_string = join("\n",@s);
        #        print FOUT $json_string . "\n"; 
        print FOUT $JSONStringsWholeFile; 
        close (FOUT);
        
        $JSONStringsWholeCorpus .= $JSONStringsWholeFile;
        

    } #end of if $suffix eq "out"
    
} ## end of foreach $file

open (FOUT,">ClipsWLAOneFile.json");
#        my @s = sort {$a cmp $b} @ResultingAnnotationRecords;
#        $json_string = join("\n",@s);
#        print FOUT $json_string . "\n"; 
print FOUT $JSONStringsWholeCorpus; 
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
#    my @ResultingAnnotationRecords;
#    my @PendingAnnotationRecords;
#    my @MultiwordRecordCompletionInfo;
    
    foreach my $Reading (@ReadingsToBeProcessed) {
        if ($Reading =~ m/(@|R|ID:)/) {
            
            @AllLemmaAnnotations = split(/ /,$Reading);
            foreach my $Annotation (@AllLemmaAnnotations) {
                if ($Annotation =~ m/^tt-[0-9]+$/) {
                    $TTId = $Annotation;
                }
                elsif ($Annotation =~ m/^[A-Z]{2}[0-9]{3}_[0-9]{4}_.*$/) {
                    $ClipId = $Annotation;
                    # FITA Seria		 millor treure-ho del nom del fitxer... però no n'estic segur
                }
            }            

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
                    # TODO/REM: this is now a next but should be more sophisticated
                    # it should allow for further search in here but avoid storing ID:XX by using a boolean or something similar

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







