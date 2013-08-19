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
my $OutFile; # human readable output file name that summarises the annotations for EACG SINGLE FILE, ONLY internal/personal use
my ($name,$path,$suffix); # name, path and suffix of input file
my $file; # input file name including path and extention (to be opened by script)
my $Text; # text of the input
my $OutputDir;

# Variables to control initial lines in files to be processed, often special lines
my (@ALLLINES); # array with all the lines in a file to be processed
my $FileLineCounter = 0; # to count lines read and be able to give line-specific process/error messages
my %FeatureCounter; # hash where pedagogical feature counts are stored
my %FeatureCounterAllFiles; # hash where pedagogical feature counts are stored

# Variable where all processed contents (and result of transformation) is stored and eventually printed.
my $ToPrint = ""; # string that will be printed in *.pla files as output
my $ToPrintAtTheEnd = ""; # file-level string to be printed in SpintxPedagogicalMetadata.tsv
my $ToPrintAtTheEndIncremental = ""; # incremental string that will be corpus-level SpintxPedagogicalMetadata.tsv ((part of ClipMetadataPedagogical.tsv)

# ---------------------------------------;
# STARTING WITH READING OPTIONS
# ---------------------------------------;


GetOptions(\%opts, "help|?", "debug=s", "outformat=s", "silent");

if ($opts{'help'}) {
    print STDERR "\nPedagogical feature counting for CG3 annotated files for SpinTX\n";
    print STDERR "Version: 0.1 // Author: Martí Quixal (2012 - today) \n";
    print STDERR "This code is totally free and open. Share and enjoy!\n";
    print STDERR "\n";
    print STDERR "Usage: countPedagogicalFeatures.pl [OPTIONS]\n";
    print STDERR "\t This program takes *.out files as input.";
    print STDERR "\t *out files in the directory ClipPedagagical.";
    print STDERR "\  As output it generates *pla files and the ClipMetadataPedagogical.tsv table.";
    print STDERR "\n";
    print STDERR "Options:\n";
    print STDERR " -help,-? \t\t shows this help\n";
    print STDERR " -debug \t\t shows this help\n";
    print STDERR " -outformat \t\t specifies output format, pla for SPinTX/drupal compatible format\n";
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
    unless ($opts{'silent'}) {
        print STDERR "\n WARNING. No output given. Default format, *.pla, will be used.\n";
        print STDERR "\n  Execute countePedagogicalFeatures.pl -help for more information.\n";
        $OutputFormat = "pla";
    }
}

# ---------------------------------------;

# -- STARTING EXECUTION OF CONVERSION
print STDERR "Starting counting...\n" unless ($opts{'silent'});

foreach $file (@ARGV) {
    
    #debug levels, have to be controlled later
    if ($DebugLevel > 0) {
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
            print STDERR "\nDL2: File " . $file . " will be proccessed.";
        }
        # GENERATING *.pla format
        # generating name for output file
        if ($OutputFormat eq "pla") {
            $OutputDir = "";
            $OutFile = $path.$OutputDir.$name."pla";
        }
        # NOT generating *.pla format
        elsif ($OutputFormat eq "nopla") {
            if ($DebugLevel > 1){
                print STDERR "\n DL2: Format *pla will not be generated.";
            }
        }
        # NOT generating *.pla format (DEFAULT)
        else {
            print STDERR "\n No ouput format specified. \n";
            print STDERR " The only output format will be *.out, CG format.\n";
            print STDERR "\n Use -outformat=pla to obtain PLA files, a Pedagogical List of Annotations at the file levels in human readable format.\n";
        }
        
        
        # reading contents of the file to be processed
        open (FILE,"$file");
        sysread(FILE,$Text,(-s FILE));
        close (FILE);
        
        # split file contents into line. each line is an annotated token
        @ALLLINES = split(/\n/,$Text);

        $FileLineCounter = 0; #every time we start we set it to zero
        my $WordForm; #the word itself
        my $Lemma; #the lemma of the word
        my $LemmaAnnotations; #all the information associated to a lemma (in turn associated to a word)
        my @AllLemmaAnnotations; #the annotations in list form (as opposed to string)
        my @AllPedagogicalFeaturesInAReading; #list of the pedagogical annotations (filtering out other type of annotations)
        
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

                        #@ or R are the prefixes used by VISLCG3 SpinTX grammar to indicade pedaogical annotations
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
                            
                        } #end of if $Annotation has @ or R (starting prefix of all pedaogical annotations)
                    }
                } #end of if that checks if string $LemmaAnnotations has any "@" or "R:"
                
                # all lines that have no annotation are simply ignored
                else{
                    if ($DebugLevel > 2) {
                        print STDERR "\n DL3: Line " . $FileLineCounter . "for lemma " . $Lemma . " has no pedagogical features." ;
                        print STDERR "\n Contents: " . $CG3Line ;
                    }
                }

            }
        } #end of foreach that iterates through all lines in each file
        
        
        #this line sends the file name and the %FeatureCounter hash to a subroutine
        #that prepares all the annotations to be printed file wise
        ($ToPrint,$ToPrintAtTheEnd) = &PrintDataForFile($file,%FeatureCounter);
        # $ToPrint: used to store the string that will be printed in *.pla files as output
        # $ToPrintAtTheEnd: used to store the string that will be printed in the table SpintxPedagogicalMetadata.tsv
        # which contains part of the information that will be finally added up to ClipMetadataPedagogical.tsv
        
        $ToPrintAtTheEndIncremental .= $ToPrintAtTheEnd;

        if ($OutputFormat eq "pla") {
            open (FOUT,">$OutFile");
            print FOUT $ToPrint;
            close (FOUT);
        }
        
        undef (%FeatureCounter);
    }
} #end of foreach $file (@ARGV), foreach that iterates through all the input files

##--------------------------------------------------;
## START: I used to use this to have a quick overview of the amount of annotations 'happening'
##--------------------------------------------------;
#print STDOUT "GlobalStats";
#foreach my $key (sort (keys(%FeatureCounterAllFiles))){
#    print STDOUT "\t" . $key . " | " . $FeatureCounterAllFiles{$key};
#}
#print STDOUT "\n";
##--------------------------------------------------;
## END COMMENT
##--------------------------------------------------;

open (FOUT,">SpintxPedagogicalMetadata.tsv") || warn ("\n WARNING: SpintxPedagogicalMetadata.tsv could not be opened.\n  Check writing permissions.\n");
print FOUT "clip_id\tgram_tags\tprag_tags\tfunc_tags\therit_tags\tvocab_tags\n";
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

    my (@TempSortedArray,@GramTagsForOneFileInfo,@PragTagsForOneFileInfo,@HeritTagsForOneFileInfo,
    @VocabTagsForOneFileInfo,@FuncTagsForOneFileInfo);
    my $MainCategory = "";
    @TempSortedArray = sort keys(%HashWithCounts);
    
    foreach my $t (@TempSortedArray) {
        if ($t eq "\@Gram" | $t eq "R:Gram") {
            $MainCategory = "Gram";
            next;
        }
        elsif ($t =~ m/^(@|R:)Gram:(.*)$/ & $MainCategory eq "Gram") {
            push(@GramTagsForOneFileInfo,$2);
        }
        elsif ($t eq "\@Prag" | $t eq "R:Prag") {
            $MainCategory = "Prag";
            next;
        }
        elsif ($t =~ m/^(@|R:)Prag:(.*)$/ & $MainCategory eq "Prag") {
            $MainCategory = "Prag";
            push(@PragTagsForOneFileInfo,$2);
        } 
        #--- Func
        elsif ($t eq "\@Func" | $t eq "R:Func") {
            $MainCategory = "Func";
            next;
        }
        elsif ($t =~ m/^(@|R:)Func:(.*)$/ & $MainCategory eq "Func") {
            $MainCategory = "Func";
            push(@FuncTagsForOneFileInfo,$2);
        }
        #--- Herit
        elsif ($t eq "\@Herit" | $t eq "R:Herit") {
            $MainCategory = "Herit";
            next;
        }
        elsif ($t =~ m/^(@|R:)Herit:(.*)$/ & $MainCategory eq "Herit") {
            $MainCategory = "Herit";
            push(@HeritTagsForOneFileInfo,$2);
        }
        #--- Vocab
        elsif ($t eq "\@Vocab" | $t eq "R:Vocab") {
            $MainCategory = "Vocab";
            next;
        }
        elsif ($t =~ m/^(@|R:)Vocab:(.*)$/ & $MainCategory eq "Vocab") {
            $MainCategory = "Vocab";
            push(@VocabTagsForOneFileInfo,$2);
        }
    }

    $PrintToReturnForOneFileInfo .= join (",",@GramTagsForOneFileInfo) . "\t" . join (",",@PragTagsForOneFileInfo) . "\t" . join (",",@FuncTagsForOneFileInfo) . "\t" . join (",",@HeritTagsForOneFileInfo). "\t" . join (",",@VocabTagsForOneFileInfo);
        
    $PrintToReturn .= "\n";
    $PrintToReturnForOneFileInfo .= "\n";
    
    return ($PrintToReturn,$PrintToReturnForOneFileInfo);
}
