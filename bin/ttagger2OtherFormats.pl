#!/usr/bin/perl

use strict;
use File::Basename;

use Getopt::Long;

# ---------------------------------------;

# ---------------------------------------;
# -- VARIABLE DEFINITION

## -- To control program execution modes
my %opts;
my $DebugLevel;
my $OutputFormat; #to store the format in which the output file will be printed

# variables to handle file names, paths and contents
my $TTGFile; # input file name
my $CPRFile; # output file name
my ($name,$path,$suffix); # name, path and suffix of input file
my $file; # input file name including path and extention (to be opened by script)
my $Text; # input file contents
my $OutputDir = $ENV{SPINTX_HOME} . "corpus/SpinTXCorpusData/";

# Variables to control initial lines in files to be processed, often special lines
my ($FirstLine,$FirstUsefulLine);
my (@ALLLINES); # array with all the lines in a file to be processed

# Variable where all processed contents (and result of transformation) is stored and eventually printed.
my $ToPrint = ""; # where the output string is being concatenated and printed at the end in the output file

# counters
my $FileLineCounter; # counter to control which line is being processed for each file

# variables to handle line contents
my @line; #line split by tabs
my $word; #word
my $lemma; #lemma
my $POSTag; #pos
my $SimplePOSTag; #simplified/unified pos
my $punct; #puncutation
my $Speaker; #speaker
my $StartTime; #starting time in video clip
my $EndTime; #ending time in video clip
my $Lang; #language (now only useful for English fragments in Spanish interviews in SPinTX)
my $InterviewID;
my ($Tense,$Mood,$Number,$Person,$Gender); #morpho-syntactic features
my $LangForCGCohort; ## variable to store the format in which the language in which the word is will be printed for a CG-like reading (lang:LANGUAGE, e.g., lang:es and lang:en for Spanish and English)
my ($ClipId,$WordId,$TranscriptLineId); # localization indexes to be compatible with other annotating modules within SPinTX
my @ListOfAllTokenInfos; # a list I created for convenience in handling them when passed to subroutines

# ---------------------------------------;

# -- PROCESSING COMMAND LINE FLAGS
GetOptions(\%opts, "help|?", "debug=s", "outformat=s", "silent");

if ($opts{'help'}) {
    print STDERR "\nFormat conversion script for TreeTagger format SPinTX files\n";
    print STDERR "Version: 0.1 // Author: Martí Quixal (2012 - today) \n";
    print STDERR "This code is totally free and open. Share and enjoy!\n";
    print STDERR "\n";
    print STDERR "Usage: ttager2OtherFormats.pl [OPTIONS]\n";
    print STDERR "\n";
    print STDERR "Options:\n";
    print STDERR " -help,-? \t\t shows this help\n";
    print STDERR " -debug \t\t shows this help\n";
    print STDERR " -outformat \t\t specifies output format, cqp for CWB compatible tab format\n";
    print STDERR " \t\t\t and cg3 for VISLCG3 compatible format\n";
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
	print STDERR " Expected formats are cg3 or cqp.\n";
	print STDERR "\n Use -outformat=cg3 or cqp to declare it.\n";
    exit;
}

# ---------------------------------------;

# -- STARTING EXECUTION OF CONVERSION
print STDERR "Starting conversion...\n";

# generating name for output dir
# cqp stands for CQP or Corpus WorkBnech compatible, cg3 for visl-cg3 (constraing grammar)
if ($OutputFormat eq "cqp") {
    $OutputDir .= "ClipCQP/";
}
elsif ($OutputFormat eq "cg3") {
    $OutputDir .= "cg3/";
}
else {
    print STDERR "\n EXECUTION ABORTED. Unexpected ouput format. \n";
    print STDERR " Expected formats are cg3 or cqp.\n";
    exit;
}

foreach $file (@ARGV) {
    
    #debug levels, have to be controlled later
    if ($DebugLevel > 0) {
        print STDERR "Reading new file...\n";
    }
    if ($DebugLevel > 1) {
        print STDERR "DL1: Reading input files...\n";
        print STDERR "DL2: Current file " . $file . " read.\n";
    }
    # filling/reading filename, file path and file suffix variable
    ($name,$path,$suffix) = fileparse($file, qw/txt/);
    
    # working only with files with 'txt' as extension
    if ($suffix eq 'txt') {
        
        # debug level 3
        if ($DebugLevel > 1) {
            print STDERR "DL2: File " . $file . " will be proccessed.\n";
        }

        # generating name for output file
        # CQP compatibla files will have a TSV extension because they are basically tab separated values
        if ($OutputFormat eq "cqp") {
            $CPRFile = $OutputDir.$name."tsv";
        }
        elsif ($OutputFormat eq "cg3") {
            $CPRFile = $OutputDir.$name."cg3";
        }
        else {
            print STDERR "\n EXECUTION ABORTED. Unexpected ouput format. \n";
            print STDERR " Expected formats are cg3 or cqp.\n";
            exit;
        }

        # reading contents of the file to be processed
        open (FILE,"$file");
        sysread(FILE,$Text,(-s FILE));
        close (FILE);

        # split file contents into line. each line is an annotated token
        @ALLLINES = split(/\n/,$Text);

        # checking if first line contains column names
        # this will always be so, but I add it in case it changes in the future
		$FirstLine = $ALLLINES[0];

        if ($FirstLine =~ m/^Clip ID/){
            $FirstLine = shift(@ALLLINES);
            #extract first line because it is the one with column headers (Word number, Original word, etc.)
            
            # debug level 3
            if ($DebugLevel > 2) {
                print STDERR "\nDL3: First line in array ignored " . $FirstLine . "\n";
            }
        } 
        
		$FirstUsefulLine = $ALLLINES[0]; #extract first line because it is the one with column headers (Word number, Original word, etc.)
        
        # debug level 3
            if ($DebugLevel > 2) {
                print STDERR "\nDL3: First used line will be " . $FirstUsefulLine . "\n";
            }

        
        # the file name with no extension will be the value of the attribute id in <text> SGML tag
        my $TextId = $name;
        $TextId = substr($TextId,0,-1); #just getting rid of the final dot in the final name
        
        # initializing some variables in default settings
        my $LastWordLang = "Spanish";
        my $LastWordSpeaker = "Unk";
        my $InSpeakerLoop = "FALSE";
        my $InLangLoop = "FALSE";

        # variable where the contents to be printed as the format conversion results are progressively concatenated
        # this variable is set to empty string every time a new file is read
        $ToPrint = "";
        $FileLineCounter = 0;
        
        # all files starte with a text SGML tag and an id attribute/value pair
        $ToPrint .= "<text id=\"" . $TextId ."\">\n";
        
        # this is a variable where the current line in the file currently processed will be stored
        my $FDGLine = "";
        
        foreach $FDGLine (@ALLLINES) {
            $FileLineCounter++;
            @line = split(/\t/,$FDGLine); #line split by tabs
            foreach $_ (@line){
                $_ =~ s/ /_/ig;
            } 
            $ClipId = $line[0]; #added from Jan 2013 on // on Apr 1 changed format and now not included as file name
            $WordId = $line[1]; #lemma added from Jan 2013 on
            $word = $line[2]; #word
            $lemma = $line[5]; #lemma
            $POSTag = $line[3]; #pos
            $SimplePOSTag = $line[4]; #puncutation
            #$punct = $line[6]; #puncutation #As of March 5 punctuation is no longer a property of the token but a token in itself
            $Speaker = $line[6]; #speaker
            $StartTime = $line[7]; #starting time in video clip
            $EndTime = $line[8]; #ending time in video clip
            $TranscriptLineId = $line[9]; #Line Id added from Jan 2013 on
            $TranscriptLineId = "SRTLine" . $TranscriptLineId;
            $Lang = $line[10]; #language (now only useful for English fragments in Spanish interviews in SPinTX)
            $InterviewID = $line[11]; #as of March 5 interview ID is added as a token property
            $Tense = $line[12]; #tense for verbs
            $Mood = $line[13]; #mood for verbs
            $Number = $line[14]; #number
            $Person = $line[15]; #person
            $Gender = $line[16]; #gender
            
            if ($lemma eq "<unknown>") {
                $lemma = "UNK";
            }

            # March 5: punctuation is now a token in itself
#            if ($punct eq "" || $punct eq"_") {
#                $punct = "BL"
#            } #default punctuation value
#            else
#            {
#                $punct =~ s/^_//ig;
#                $punct =~ s/_$//ig;
#            }
            if ($Speaker eq ">>i") {
                $Speaker = "int";
            }
            elsif ($Speaker eq ">>s") {
                $Speaker = "subj";
            }
            else {
                $Speaker = $LastWordSpeaker;

                # debug level 1
                unless ($opts{'silent'}) {
                    print STDERR "\n WARNING: Line " . $FileLineCounter . " in " . $file . " does not have a speaker assigned.\n" ;
                    print STDERR "   This token will be assigned the same speaker as the previous word.\n";
                }
            }

            if ($Lang eq "Spanish") {$Lang = "es"}
            elsif ($Lang eq "English") {
                $Lang = "en";
            }
            else {
                # debug level 1
                unless ($opts{'silent'}) {
                    print STDERR "\n WARNING: Line " . $FileLineCounter . " in " . $file . " does not have a language assigned.\n";
                    print STDERR "   This token will be assigned the same language as the previous word.\n";   
                    $Lang = $LastWordLang;
                    if ($Lang eq "") {$Lang == "es"}
                }
            }
            
            if ($Tense eq "") {$Tense = "NA"} #default punctuation value
            if ($Mood eq "") {$Mood = "NA"} #default punctuation value
            if ($Number eq "") {$Number = "NA"} #default punctuation value
            if ($Person eq "") {$Person = "NA"} #default punctuation value
            if ($Gender eq "") {$Gender = "NA"} #default punctuation value
            $LangForCGCohort = "lang:".$Lang;
            # for convenience (in calling some subroutines later
            # we put all token level infos in list but in my preferred order
            @ListOfAllTokenInfos = ($word, $lemma, $POSTag, $SimplePOSTag, $punct, $Tense, $Mood, $Number, $Person, $Gender, $LangForCGCohort, $StartTime, $EndTime, $WordId, $ClipId);
            # removed on Apr 1 2013
            
            #debug line
            if ($DebugLevel > 4) {
                print STDERR " Line: " . $FDGLine . "\n";
                print STDERR " Yields: " . join("|",@ListOfAllTokenInfos) . "\n";
                
            }
            
            # we handle the first line
            if ($FileLineCounter == 1) {
                # we will open a speaker area with the current value in the $Speaker variable
                # we print all values in tab format
                # we will open a lang area if word is in English, but not if it is in Spanish
                if ($Lang eq "es") {
                    $ToPrint .= "<speaker type=\"". $Speaker . "\">\n";
                    
                    # Call sub PrintTokenLevelInformation (returns string for printout)
                    # Requires an $OutputFormat and a @ListOfElements
                    # $ToPrint .= &PrintTokenLevelInformation($OutputFormat, $word, $lemma, $POSTag, $punct, $StartTime, $EndTime, $Tense, $Mood, $Number, $Person, $Gender, $Lang);
                    $ToPrint .= &PrintTokenLevelInformation($OutputFormat,@ListOfAllTokenInfos);
                }
                elsif ($Lang eq "en") {
                    $ToPrint .= "<speaker type=\"". $Speaker . "\">\n";
                    $ToPrint .= "<lang code=\"". $Lang . "\">\n";
                    $ToPrint .= &PrintTokenLevelInformation($OutputFormat,@ListOfAllTokenInfos);
                    # we start a lang loop
                    $InLangLoop = "TRUE";
                }
                # we set to TRUE the boolean for a Speaker loop
                # this might not be really true if the last else applies, but I don't think this is a problem now
                $InSpeakerLoop = "TRUE";
            }
            # case: not first line & speaker is the same as previous line, , & NOT in a lang loop
            elsif ($LastWordSpeaker eq $Speaker && $InLangLoop eq "FALSE") {
                # the speaker IS the same as in the preivous word and lang loop is not open
                
                #if the current word is in Spanish
                if ($Lang eq "es"){
                    $ToPrint .= &PrintTokenLevelInformation($OutputFormat,@ListOfAllTokenInfos);
#                    $ToPrint .= $word."\t".$lemma."\t".$POSTag . "\t".$punct . "\t" . $StartTime.  "\t" . $EndTime . "\t".$Tense . "\t".$Mood . "\t".$Number . "\t".$Person . "\t".$Gender . "\t".$Lang ."\n";
                }
                elsif ($Lang eq "en"){
                    $ToPrint .= "<lang code=\"". $Lang . "\">\n";
                    $ToPrint .= &PrintTokenLevelInformation($OutputFormat,@ListOfAllTokenInfos);
#                   $ToPrint .= $word."\t".$lemma."\t".$POSTag . "\t".$punct . "\t" . $StartTime.  "\t" . $EndTime . "\t".$Tense . "\t".$Mood . "\t".$Number . "\t".$Person . "\t".$Gender . "\t".$Lang ."\n";
                    $InLangLoop = "TRUE";
                }
            }

            elsif ($LastWordSpeaker eq $Speaker && $InLangLoop eq "TRUE") {
                # the speaker IS the same as in the preivous word and lang loop is not open
                
                #if the current word is in Spanish, then we need to close the tag
                if ($Lang eq "es"){
                    $ToPrint .= "</lang>\n";
                    $ToPrint .= &PrintTokenLevelInformation($OutputFormat,@ListOfAllTokenInfos);
#                   $ToPrint .= $word."\t".$lemma."\t".$POSTag . "\t".$punct . "\t" . $StartTime.  "\t" . $EndTime . "\t".$Tense . "\t".$Mood . "\t".$Number . "\t".$Person . "\t".$Gender . "\t".$Lang ."\n";
                    # and we close the lang loop, set boolean to false
                    $InLangLoop = "FALSE";
                }
                #if the current word is in English, we print and keep on processing
                elsif ($Lang eq "en"){
                    $ToPrint .= &PrintTokenLevelInformation($OutputFormat,@ListOfAllTokenInfos);
#                   $ToPrint .= $word."\t".$lemma."\t".$POSTag . "\t".$punct . "\t" . $StartTime.  "\t" . $EndTime . "\t".$Tense . "\t".$Mood . "\t".$Number . "\t".$Person . "\t".$Gender . "\t".$Lang ."\n";
                }
            }

            # case: not first line & speaker CHANGES, & NOT in a lang loop
            elsif ($LastWordSpeaker ne $Speaker  && $InLangLoop eq "FALSE") {
                # the speaker is NOT the same as in the preivous word
                # we first close the open speaker look and open a new one, and keep on processing
                $ToPrint .= "</speaker>\n";
                $ToPrint .= "<speaker type=\"". $Speaker . "\">\n";
                $ToPrint .= &PrintTokenLevelInformation($OutputFormat,@ListOfAllTokenInfos);
#                $ToPrint .= $word."\t".$lemma."\t".$POSTag . "\t".$punct . "\t" . $StartTime.  "\t" . $EndTime . "\t".$Tense . "\t".$Mood . "\t".$Number . "\t".$Person . "\t".$Gender . "\t".$Lang ."\n";
            }
            
            # case: not first line & speaker CHANGES, & WE ARE in a lang loop
            elsif ($LastWordSpeaker ne $Speaker  && $InLangLoop eq "TRUE") {
                # the speaker is NOT the same as in the preivous word
                # we first close the open speaker look and open a new one, and keep on processing
                $ToPrint .= "</lang>\n";
                $ToPrint .= "</speaker>\n";
                $ToPrint .= "<speaker type=\"". $Speaker . "\">\n";
                $ToPrint .= &PrintTokenLevelInformation($OutputFormat,@ListOfAllTokenInfos);
#                $ToPrint .= $word."\t".$lemma."\t".$POSTag . "\t".$punct . "\t" . $StartTime.  "\t" . $EndTime . "\t".$Tense . "\t".$Mood . "\t".$Number . "\t".$Person . "\t".$Gender . "\t".$Lang ."\n";

                # and we close the lang loop, set boolean to false
                $InLangLoop = "FALSE";
            }
            
            else { 
                print STDERR " *** PROCESSING STOPPED!\n";
                print STDERR " I stopped processing in line " . $FileLineCounter . " in file " . $file . " because my code writer did not foresee this case.\n";
                last;
            }
            # we assign the values of $Speaker and $Lang as the values for the last word processed
            $LastWordSpeaker = $Speaker;
            $LastWordLang = $Lang;
            
        } #end of foreach line in file to be processed
        # we assume all texts end with a speaker turn and a text tag
        if ($InLangLoop eq "TRUE") {
            $ToPrint .= "</lang>\n";
        }
        $ToPrint .= "</speaker>\n";
        $ToPrint .= "</text>\n";
        
    } #end of if file ends with 'txt' extension
    # here is where each file has to be printed out
    #print STDOUT $ToPrint . "\n";
    open(FOUT,">$CPRFile") || die " Could not open file $CPRFile\n Output dir is $OutputDir\n Execution aborted.\n";
    print FOUT $ToPrint;
    close(FOUT);

    if ($DebugLevel > 1) {
        print STDERR "DL2: File " . $CPRFile . " was generated.\n";
    }

    $ToPrint = '';

    
} #end of foreach file in input array to be processed

  print STDERR "\nDone!\n";



### ---------------------------------;
### SUBROUTINES
### ---------------------------------;


sub PrintTokenLevelInformation{
    
    my ($OutputFormat) = shift(@_);
    my (@ListOfTokenInfos) = (@_);
    my $TokenLevelString = "";
    my ($Word, $Lemma, $PoSTag, $SimplePoSTag);

    
    $Word = shift(@ListOfTokenInfos);
    $Lemma = shift(@ListOfTokenInfos);
    $PoSTag = shift(@ListOfTokenInfos);
    $SimplePoSTag = shift(@ListOfTokenInfos);

    #format generation if outformat is CQP
    if ($OutputFormat eq "cqp") {

        $TokenLevelString .= $Word . "\t" .$Lemma . "\t" .$PoSTag . "\t" .$SimplePoSTag;
        $TokenLevelString .= join ("\t",@ListOfTokenInfos);
        $TokenLevelString .= "\n";
        
    }

    #format generation if outformat is CG3
    elsif ($OutputFormat eq "cg3") {

        if ($SimplePoSTag eq "Punctuation") {
            
            # Adding the dollar symbol, $, to all punctuation sign that will be delimiters in CG 
            # DELIMITERS = "<$.>" "<$?>" "<$!>" "<$:>" "<$\;>" ;
            if ($Word eq "." | $Word eq "?" | $Word eq "!" | $Word eq "¿" | $Word eq "¡" | $Word eq ":" | $Word eq ";") {
                $TokenLevelString .= "\"<\$" . $Word. ">\"\n";
                $TokenLevelString .= "\t\"" . $Lemma. "\""; # Punct Clause\n";
            }
            else {
                $TokenLevelString = "\"<". $Word. ">\"". "\n";
                $TokenLevelString .= "\t\"". $Lemma. "\"";
            }
            $TokenLevelString .= " ". $SimplePoSTag . " ". $PoSTag;
        
        }
        else {
            $TokenLevelString = "\"<". $Word. ">\"". "\n";
            $TokenLevelString .= "\t\"". $Lemma. "\"";
            $TokenLevelString .= " ". $SimplePoSTag . " ". $PoSTag;
        }

        foreach my $item (@ListOfTokenInfos) {
            unless ($item eq "NA"){$TokenLevelString .= " ". $item	};
        }

        $TokenLevelString .= "\n";
        

    }
    
    return $TokenLevelString;
    
}