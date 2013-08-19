#!/usr/bin/perl

# ---------------------------------------;
# REQUIRED LIBS
# ---------------------------------------;
use utf8;
use strict;
use File::Basename;
use warnings;
use JSON;
use Getopt::Long;
use Time::localtime;

# ---------------------------------------;
# Reading configuration paths from the enviroment variable $SPINTX_HOME as set in ~/.profile (in unix-like OS)
# ---------------------------------------;
my $OutputDir = $ENV{SPINTX_HOME} . "data/SpinTXCorpusData/";

my $OutputDirWLA = $OutputDir . "ClipWLA/"; #we will dump results in the wla folder under corpus/ClipTags
my $OutputDirStats = $OutputDir . "stats/";

my $OneFileJSON = $OutputDirWLA."TokenTagsPedagogical.json" ; #output file name for whole corpus info in JSON format
my $OneFileCSV = $OutputDirWLA."TokenTagsPedagogical.tsv" ; #output file name for whole corpus info in CSV format
my $StatsFileForRecord = $OutputDirStats . timestamp() . "_TokenTagsPedagogical" . ".tsv";
my $StatsFileVocab = $OutputDirStats . timestamp() . "_SpintxVocabMetadata" . ".tsv";


# ---------------------------------------;
# VARIABLE DEFINITION
# ---------------------------------------;


## -- To control program execution modes
# ---------------------------------------;
my %opts;
my $DebugLevel;
my $OutputFormat; #to store the format in which the output file will be printed

# -- File names, paths and contents
# ---------------------------------------;
my $CG3File; # input file name
my $OutFile; # output file name (one output file for all input files)
my ($name,$path,$suffix); # name, path and suffix of input file
my $file; # input file name including path and extention (to be opened by script)
my $Text; # input file contents

# Variable where all processed contents (and result of transformation) is stored and eventually printed.
# ---------------------------------------;
my (@ALLLINES); # array with all the lines in a file to be processed
my $ToPrint = ""; # string to store and print at the end of each transcript
my $ToPrintAtTheEnd = ""; # String to store the a final print per script that will be part of the corpus summarisation
my $ToPrintAtTheEndIncremental = ""; # String that is actually the corpus summary (the whole corpus)
my $FileLineCounter = 0; # file line counter
my %FeatureCounter; # hash where pedagogical feature counts are stored script-wise
my %FeatureCounterAllFiles; #hash where pedagogical feature counts are stored corpus-wise
my $BooleanInWord = "FALSE";
my @WordReadings;

## THIS HANDLES NON-VOCAB INFORMATION
# ---------------------------------------;
my %HashForJSON; #this hash stores the data for each particular annotation instance in JSON format in compliance with SpinTX hide/show functionalities on the web
my %HashForJSONTwoLevels; #this hash stores the same data as the previous one but if the annotation has a main and a subtype class it stores and concatenates them using a colon (e.g. Det:Demo)
my @JSONStringsWholeFileArray; # Array to store and then print the TRANSCRIPT annotations in JSON format
my @CSVStringsWholeFileArray; # Array to store and then print the TRANSCRIPT annotations in CSV format
my @JSONStringsWholeCorpus; # Array to store and then print the CORPUS annotations in JSON format
my @CSVStringsWholeCorpus; # Array to store and then print the CORPUS annotations in CSV format

## THIS HANDLES VOCAB INFORMATION
# ---------------------------------------;
my %LemmaList; #
my %LemmaTypeCounter;
my @POSFilterForVocabListGeneration = ("Adjective","Noun","Verb"); #LIST of simple POS tags used in SpinTX used to filter out the word classes included in the one-word Vocab lists (just concept words)
my @VocabList; # Array to store the list of words that will be included in the vocab list per file/script
my $VocabListSingleFileForWholeCorpusToPrint = "clip_id\tvocab_tags\n";
my @ForVocabListSingleFileForWholeCorpus;


# ---------------------------------------;
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
print STDERR " First: removing old files...\n";
system ("rm $OutputDirWLA/*.json");
system ("rm $OutputDirWLA/*.tsv");



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
        my $CSVStringOneLiner;
        my $JSONStringOneLinerTwoLevels;
        my $CSVStringOneLinerTwoLevels;
        my @RECORDS;
        
        # the following foreach creates a hash that we later convert
        # into JSON format using PERL's json lib
        
        foreach my $record (@ResultingAnnotationRecords) {
            
            #each record in the array has the info clip, start and end token id
            @RECORDS = split(/,/,$record);
            $HashForJSON{'clip'} = $RECORDS[0];
            $HashForJSON{'start'} = $RECORDS[1];
            $HashForJSON{'end'} = $RECORDS[2];

            $HashForJSONTwoLevels{'clip'} = $RECORDS[0];
            $HashForJSONTwoLevels{'start'} = $RECORDS[1];
            $HashForJSONTwoLevels{'end'} = $RECORDS[2];

            my $TempLabel = $RECORDS[3];
            my ($PedagogicalType, $PedagogicalTag, $PedagogicalTagLeft, $PedagogicalTagRight);
            
            # the Hierarchy tag has to be split: the first level is internally called
            # type, and the second and optionally the third are called tag (and are printed 
            # together if there is second and third)
            
            if ($TempLabel =~ m/^([^:]+):(.+)$/ig){
                $PedagogicalType = $1;
                $PedagogicalTag = $2;
            }

            if ($PedagogicalTag =~ m/^([^:]+):(.+)$/ig){
                $PedagogicalTagLeft = $1;
                $PedagogicalTagRight = $2;
            }
            else{
                $PedagogicalTagLeft = $PedagogicalTag;
                $PedagogicalTagRight = "";
            }
            
            $HashForJSON{'type'} = $PedagogicalType;
            $HashForJSON{'tag'} = $PedagogicalTagLeft;
            

            $HashForJSONTwoLevels{'type'} = $PedagogicalType;
            
            if ($PedagogicalTagRight eq "") {
                $HashForJSONTwoLevels{'tag'} = $PedagogicalTagLeft;
            }
            else{
                $HashForJSONTwoLevels{'tag'} = $PedagogicalTagLeft . ":" . $PedagogicalTagRight;
            }

            # this line encode the info in json format
            $JSONStringOneLiner = encode_json(\%HashForJSON);
            $JSONStringOneLinerTwoLevels = encode_json(\%HashForJSONTwoLevels);


            # this line encode the info in CSV format
            # $CSVStringOneLiner = join ("\t",@RECORDS);
            # clip_id \t tag \t tag_type \t tt-start \t tt-end

            $CSVStringOneLiner = $RECORDS[0] . "\t" . $PedagogicalTagLeft . "\t" . $PedagogicalType . "\t" . $RECORDS[1] . "\t" . $RECORDS[2];

            if ($PedagogicalTagRight eq "") {
                $CSVStringOneLinerTwoLevels = $RECORDS[0] . "\t" . $PedagogicalTagLeft . "\t" . $PedagogicalType . "\t" . $RECORDS[1] . "\t" . $RECORDS[2];
            }
            else{
                $CSVStringOneLinerTwoLevels = $RECORDS[0] . "\t" . $PedagogicalTagLeft . ":" . $PedagogicalTagRight . "\t" . $PedagogicalType . "\t" . $RECORDS[1] . "\t" . $RECORDS[2];
            }


            # this line adds all the strings in json format in one single array
            # there is one of these arrays for each clip file

            if ($PedagogicalTagRight eq "") {
                push(@JSONStringsWholeFileArray,$JSONStringOneLiner);
                push(@CSVStringsWholeFileArray,$CSVStringOneLiner);
            }
            else{
                push(@JSONStringsWholeFileArray,$JSONStringOneLiner);
                push(@CSVStringsWholeFileArray,$CSVStringOneLiner);
                push(@JSONStringsWholeFileArray,$JSONStringOneLinerTwoLevels);
                push(@CSVStringsWholeFileArray,$CSVStringOneLinerTwoLevels);
            }

            
            # we make sure the @RECORDS array is emptied / initialized after each iteration
            undef @RECORDS;

        }

        my $LemmaPOSPair;

        # FITA: alerta, que ara mateix no estic tenint en compte el TTID, ni el clip ID i serà important!!!
        #        foreach $LemmaPOSPair (sort {$LemmaList{$b} <=> $LemmaList{$a}} keys(%LemmaList)) {
        foreach $LemmaPOSPair (keys(%LemmaList)) {
            
            ($LemmaInPair,$POSInPair,$TTIDInPair,$ClipIDInPair) = split(/\|/,$LemmaPOSPair);
            
#            print STDERR $LemmaPOSPair . " : " . $LemmaList{$LemmaPOSPair};
#            print STDERR "\n";
#            print STDERR $LemmaInPair. " " .$POSInPair;
#            print STDERR "\n";

            
            foreach my $FilterTag (@POSFilterForVocabListGeneration) {
                if ($POSInPair eq $FilterTag) {
                    
                    #if ($LemmaInPair eq 'ser') { print STDERR "in stop word list\n"};
#                    print STDERR $LemmaPOSPair . " : " . $LemmaList{$LemmaPOSPair};
#                    print STDERR "\n";
                    push (@VocabList,$LemmaPOSPair);
                    $LemmaTypeCounter{$LemmaInPair."|".$POSInPair}++;
                  
                }
            }
        }# end of foreach $LemmaPOSPair (keys(%LemmaList)) {
        
        if ($DebugLevel > 3){
            print STDERR "ALL LEMMAS TO BE PRINTED";
            print STDERR join(",",@VocabList);
            print STDERR "\n";
        }
        foreach $_ (@VocabList){

            #each record in the array has the info clip, start and end token id
            #initially I used a json encoder for perl, but I did not manage that
            #it respected utf-8 characters so I implemented this maually
            
            @RECORDS = split(/\|/,$_);
            
            my $JSONClip = "\"clip\":". "\"" . $RECORDS[3] . "\",";
            my $JSONStart = "\"start\":". "\"" . $RECORDS[2] . "\"";
            my $JSONEnd = "\"end\":". "\"" . $RECORDS[2] . "\",";
            my $JSONType = "\"type\":". "\"Vocab\",";
            my $JSONTag = "\"tag\":". "\"" . $RECORDS[1].":".$RECORDS[0] . "\","; #order is tag:lemma, e.g., Noun:plato

            if ($JSONTag =~ m/.*UNK\:[Adjective|Noun|Verb].*/){
                next;
            }
            else{
                
                if ($DebugLevel > 3) {
                    print STDERR "clip " . $RECORDS[3];
                    print STDERR "\n";
                    print STDERR "start " . $RECORDS[2];
                    print STDERR "\n";
                    print STDERR "end " . $RECORDS[2];
                    print STDERR "\n";
                    print STDERR "tag " . "Vocab";
                    print STDERR "\n";
                    print STDERR "type " . $RECORDS[0].":".$RECORDS[1];
                    print STDERR "\n";
                }
                
                $JSONStringOneLiner = "{" . $JSONClip . $JSONTag . $JSONType . $JSONEnd . $JSONStart ."}" ;
                
                # clip_id \t tag \t tag_type \t tt-start \t tt-end
                
                $CSVStringOneLiner = $RECORDS[3] . "\t" . $RECORDS[1] . ":" . $RECORDS[0] . "\t" . "Vocab" . "\t" . $RECORDS[2] . "\t" . $RECORDS[2];

#                $CSVStringOneLiner = $RECORDS[3] . "\t" . $RECORDS[2] . "\t" . $RECORDS[2] . "\tVocab:" . $RECORDS[1] . ":" .$RECORDS[0]; 
                
                # this line adds all the strings in json format in one single array
                # there is one of these arrays for each clip file

            }
 
            push(@JSONStringsWholeFileArray,$JSONStringOneLiner);
            push(@CSVStringsWholeFileArray,$CSVStringOneLiner);
            
            # we make sure the @RECORDS array is emptied / initialized after each iteration
            undef @RECORDS;

        }
        
        if ($DebugLevel > 2) {
            print STDERR "ALL LEMMA COUNTS TO BE PRINTED";
        }

        #Using file name to add clip id to clip level summary of vocab info
        # kind of dirty... I know, I apologize and hope to do it better in the future
        $name =~ s/\.$//;
        
        if ($DebugLevel > 2) {
            print STDERR " List of vocab items for Clip ID: " . $name . "\n" ;
        }
        
        #we add the clip id as the starting item of the row
        # for this clip in vocab info summary file
        
        $VocabListSingleFileForWholeCorpusToPrint .= $name . "\t";

        foreach $_ (sort {$LemmaTypeCounter{$b} <=> $LemmaTypeCounter{$a}} keys(%LemmaTypeCounter)) {
            
            #we exclude vocabulary that only occurs once
            unless ($LemmaTypeCounter{$_} == 1) {

                #we exclude vocabulary in a stop word list
                #now we exclude words marked as UNK by TreeTagger
                if ($_ eq "UNK|Adjective" || $_ eq "UNK|Noun" || $_ eq "UNK|Verb"){
                    next;
                }

                #we append the remainding vocab items and prepare them for
                # the one file vocab info summary
                else{
                    
                    # some dirty splitting and concat operations to
                    #obtain the output of lemma-tag pair infos in the wished format
                    my @LemmaTagPairParts = split (/\|/,$_);
                    my $NewLemmaTagPairParts = $LemmaTagPairParts[1].":".$LemmaTagPairParts[0];
                    
                    push(@ForVocabListSingleFileForWholeCorpus,$NewLemmaTagPairParts);
                    
                    if ($DebugLevel > 2) {
                        print STDERR $_ . " : " . $LemmaTypeCounter{$_} ;
                        print STDERR "\n";
                    }
                }
            }
        }
        
        $VocabListSingleFileForWholeCorpusToPrint .= join(",",@ForVocabListSingleFileForWholeCorpus);
        $VocabListSingleFileForWholeCorpusToPrint .= "\n";

        # this prints the list of annotations for one single file in json format
        open (FOUT,">", $OutFile) || warn (" WARNING: Could not open $OutFile.\n") ;
        print FOUT "["; 
        print FOUT join(",",@JSONStringsWholeFileArray); 
        print FOUT "]"; 
        close (FOUT);
        
        # the following line concatenates each file´s info into a larger array
        # later used to print the one-file-for-the-whole-corpus clip level annotations list
        @JSONStringsWholeCorpus = (@JSONStringsWholeCorpus,@JSONStringsWholeFileArray);
        
        @CSVStringsWholeCorpus = (@CSVStringsWholeCorpus,@CSVStringsWholeFileArray);
        
    } #end of if $suffix eq "out"
    
    # we make sure the @JSONStringsWholeFileArray array is emptied / initialized after each iteration
    undef @JSONStringsWholeFileArray;
    undef @CSVStringsWholeFileArray;
    undef %LemmaTypeCounter;
    undef %LemmaList;
    undef @VocabList;
    undef @ForVocabListSingleFileForWholeCorpus;
    
} ## end of foreach $file

open (FOUT,">", $OneFileJSON) || warn (" WARNING: Could not open $OneFileJSON with write permission.\n") ;;
        print FOUT "["; 
        print FOUT join(",",@JSONStringsWholeCorpus); 
        print FOUT "]"; 
close (FOUT);

open (FOUT3,">", $OneFileCSV) || warn (" WARNING: Could not open $OneFileCSV with write permission.\n") ; 
print FOUT3 "clip_id"."\t"."tag"."\t"."tag_type"."\t"."tt_start"."\t"."tt_end"; 
print FOUT3 "\n";
print FOUT3 join("\n",@CSVStringsWholeCorpus); 
print FOUT3 "\n";
close (FOUT3);

open (FOUT2,">", "SpintxMetadataVocab.tsv") || warn (" WARNING: Could not open SpintxMetadataVocab.tsv with write permission.\n") ;
print FOUT2 $VocabListSingleFileForWholeCorpusToPrint; 
close (FOUT2);

#system ("cp -v $OneFileJSON $StatsFileForRecord");
system ("cp -v $OneFileCSV $StatsFileForRecord");
system ("cp -v SpintxMetadataVocab.tsv $StatsFileVocab");

print STDERR "Done!\n";


###############
# SUBROUTINES #
###############

sub ProcessReadingsForPreviousWord {

    my @ReadingsToBeProcessed = @_;
    my @AllLemmaAnnotations;
    my $ClipId;
    my $TTId;
    my $IDToRemoveFromVocabListFromUnigrams = "EMPTY";
    
    # variables used while processing the different readings
    my $AnnotationRecord;
    my @AllItemsInReading;
    my ($Lemma,$POSTag);
    
    foreach my $Reading (@ReadingsToBeProcessed) {
        
        @AllItemsInReading = split(/ /,$Reading);
        
        if ($DebugLevel > 2) {
            print STDERR "ALL ELEMENTS IN COHORT";
            print STDERR join("|",@AllItemsInReading);
            print STDERR "\n";
        }
        $Lemma = $AllItemsInReading[0];
        $Lemma =~ s/^\t(.+)/$1/;
        $POSTag = $AllItemsInReading[1];

        # this foreach is used to identify the tokentag id (ttid) and the clip id 
        # for the relevant annotation line
        foreach my $Annotation (@AllItemsInReading) {
            if ($Annotation =~ m/^tt-[0-9]+$/) {
                $TTId = $Annotation;
            }
            elsif ($Annotation =~ m/^[A-Z]{2}[0-9]{3}_[0-9]{4}_.*$/) {
                $ClipId = $Annotation;
            }
        }            
        
        $Lemma =~ s/\"(.+)\"/$1/ig;

        if ($DebugLevel > 2) {
            print STDERR "Lemma: " . $Lemma . "\n";
            print STDERR "POSTag: " . $POSTag . "\n";
            print STDERR "ttID: " . $TTId . "\n";
            print STDERR "clipID: " . $ClipId . "\n";
        }
        
        #This filter is to exclude punctuation from the list of unigram lemmas that will be part of the vocabulary tab in the transcript
        if ($POSTag eq "Punctuation") {
            if ($DebugLevel > 2) {
                print STDERR "punct token, reading ignored\n";
                print STDERR $Reading;
                print STDERR "\n";
            }
        }
        elsif ($Reading =~ m/R\:Vocab/) {
            if ($DebugLevel > 2) {
                print STDERR "bigram vocab token, reading ignored\n";
                print STDERR $Reading;
                print STDERR "\n";
            }
            $IDToRemoveFromVocabListFromUnigrams = $Reading;
            #            $IDToRemoveFromVocabListFromUnigrams =~ s/([0-9]+)/$1/ig;
            if ($Reading =~ m/R:[^0-9]*\:([0-9]+)/) {
                $IDToRemoveFromVocabListFromUnigrams = $1;
            }
            $IDToRemoveFromVocabListFromUnigrams = "ID:".$IDToRemoveFromVocabListFromUnigrams;
            if ($DebugLevel > 2) {
                print STDERR "ID to be removed from one-word vocab list\n";
                print STDERR $IDToRemoveFromVocabListFromUnigrams;
                print STDERR "\n";
            }
            # TO DO: recollir el ID number de la relació del token exclòs i usar-lo per excloure també l'altre token (només funcionarà per bigrames no per tri-grames i superiors)
        }
        else {
            if ($Reading =~ m/$IDToRemoveFromVocabListFromUnigrams/) {
                if ($DebugLevel > 2) {
                    print STDERR "token excluded in vocab list because it belongs to bi- or plusgram vocab token\n";
                    print STDERR $Reading;
                    print STDERR "\n";
                }
                $IDToRemoveFromVocabListFromUnigrams = "EMPTY";
            }
            else {
                if ($DebugLevel > 2) {
                    print STDERR "token included in vocab list\n";
                    print STDERR $Reading;
                    print STDERR "\n";
                }
                $LemmaList{$Lemma."|".$POSTag."|".$TTId."|".$ClipId}++;
            }

            
        }
        
        if ($Reading =~ m/(@|R|ID:)/) {
            
            @AllLemmaAnnotations = split(/ /,$Reading);

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

    #print STDERR @ResultingAnnotationRecords."\n"."\n".@PendingAnnotationRecords."\n"."\n".@MultiwordRecordCompletionInfo;
    
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



########################
## SUBROUTINE TO ORDER HASH VALUES IN DESCENDING ORDER
########################

#sub hashValueDescendingNum {
#    $grades{$b} <=> $grades{$a};
#}
