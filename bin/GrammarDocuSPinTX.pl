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
my $RuleFile; # input file name
my $OutFile; # output file name (one output file for all input files)
my ($name,$path,$suffix); # name, path and suffix of input file
my $file; # input file name including path and extention (to be opened by script)
my $Text; # input file contents
my $OutputDir;

# Variables to control initial lines in files to be processed, often special lines
my (@ALLLINES); # array with all the lines in a file to be processed
my $FileLineCounter;

# Variable where all processed contents (and result of transformation) is stored and eventually printed.
my $ToPrint = ""; # where the output string is being concatenated and printed at the end in the output file


# ---------------------------------------;
# STARTING WITH READING OPTIONS
# ---------------------------------------;


GetOptions(\%opts, "help|?", "debug=s", "outformat=s");

if ($opts{'help'}) {
    print STDERR "\nAutomatic generation of documentation for the CG3 SPinTX grammar\n";
    print STDERR "Version: 0.1 // Author: Martí Quixal (2012 - today) \n";
    print STDERR "This code is totally free and open. Share and enjoy!\n";
    print STDERR "\n";
    print STDERR "Usage: GrammarDocuSPinTX.pl [OPTIONS]\n";
    print STDERR "\n";
    print STDERR "Options:\n";
    print STDERR " -help,-? \t\t shows this help\n";
    print STDERR " -debug \t\t shows this help\n";
    print STDERR " -outformat \t\t specifies output format, currently only pdf suported\n";
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
	print STDERR " Expected format is pdf.\n";
	print STDERR "\n Use -outformat pdf to declare it.\n";
    exit;
}

# ---------------------------------------;

print STDERR "Starting generation of documentation...\n";

$ToPrint = "\\documentclass[11pt]{report}\n\n";

$ToPrint .= "%to add links but not color
\\usepackage{hyperref}
%%Non-ASCII characters
\\usepackage[utf8]{inputenc}

%LANGUAGES
\\usepackage[english]{babel}

% Add draft watermark
\\usepackage{draftwatermark}
\\SetWatermarkScale{3}

%To add frames to verbatim environment
\\usepackage{fancyvrb}

\\topmargin=-1in    % Make letterhead start about 1 inch from top of page
\\textheight=9in  % text height can be bigger for a longer letter
\\oddsidemargin=0pt % leftmargin is 1 inch
\\textwidth=6.5in   % textwidth of 6.5in leaves 1 inch for right margin
%%\\usepackage[hyphens]{url}

%Bib style
\\usepackage{natbib}
\\bibpunct[: ]{(}{)}{;}{a}{,}{,}
";

$ToPrint .= "\\begin{document}
\\title{Especificaciones para la anotación de SPinTX\\\\ con información lingüística para fines pedagógicos}
\\author{Martí Quixal}
\\date{Diciembre 2012 -- hoy}
\\maketitle
\\tableofcontents

";
    
foreach $file (@ARGV) {
    
    #debug levels, have to be controlled later
    if ($DebugLevel == 1) {
        print STDERR "DL1: Reading new file...\n";
    }
    if ($DebugLevel > 1) {
        print STDERR "DL2: Current file " . $file . " read.\n";
    }
    # filling/reading filename, file path and file suffix variable
    ($name,$path,$suffix) = fileparse($file, qw/rle/);
    
    # working only with files with 'txt' as extension
    if ($suffix eq "rle") {
        
        # debug level 3
        if ($DebugLevel > 1) {
            print STDERR "DL2: File " . $file . " will be proccessed.\n";
        }
        # generating name for output file, cpr stands for compressed
        if ($OutputFormat eq "pdf") {
            $OutputDir = "";
            $OutFile = $path.$OutputDir.$name."tex";
        }
        else {
            print STDERR "\n EXECUTION ABORTED. Unexpected ouput format. \n";
            print STDERR " Currently only pdf is supported as an output format.\n";
            exit;
        }
        
        # reading contents of the file to be processed
        open (FILE,"$file");
        sysread(FILE,$Text,(-s FILE));
        close (FILE);
        
        # split file contents into line. each line is an annotated token
        @ALLLINES = split(/\n/,$Text);
        
        $FileLineCounter = 0;
        
        foreach my $GrammarFileLine (@ALLLINES) {
            $FileLineCounter++;
            if ($GrammarFileLine =~ m/^\#LATEX(.+)$/) {
                #                $ToPrint .= $1 ."\n";
                my $ToBeProcessed = $1;
                $ToPrint .= &ProcessLineContents($ToBeProcessed);
            }
            elsif ($GrammarFileLine =~ m/^(ADD|ADDRELATIONS|ADDRELATION|REPLACE) (.+)$/) {
                $ToPrint .= &ProcessRuleContents($GrammarFileLine);
            }

            else {
                if ($DebugLevel > 1) {
                    print STDERR "\n DL2: Line " . $FileLineCounter . " ignored.";
                }
                if ($DebugLevel > 2) {
                    print STDERR "\n DL3: Line contents: " . $GrammarFileLine;
                }
            }
        } #end of foreach that iterates through grammar file lines

    } #end of if that checks that file extension is rle

} #end of foreach that iterates list of files in @ARGV

$ToPrint .= "\\end{document}";

open (FOUT,">$OutFile");
print FOUT $ToPrint;
close (FOUT);

system ("pdflatex $OutFile");
system ("pdflatex $OutFile");
system ("pdflatex $OutFile");

print STDERR "\n\nOutput file is: ". $OutFile . "\n";
print STDERR "And the corresponding PDF file.\n";

##-------------------
## SUB ROUTINES
##-------------------

sub ProcessLineContents{

    my $Line = shift (@_);
    my $ResultLine;
    
    if ($DebugLevel > 1) {
        print STDERR "DL2: In subroutine to process line contents (ProcessLineContents)\n";
        print STDERR "DL2: Value of \$Line is : " . $Line ."\n";
    }

    if ($Line =~ m/^DOCU (.+)$/) {
        $ResultLine = $1 . "\n\n";
    }
    elsif ($Line =~ m/\\(part|chapter|section|subsection|subsubsection|paragraph|subparagraph){ (.+)$/) {
        $ResultLine = $Line . "\n\n";
    }
    elsif ($Line =~ m/^REM (.+)$/) {
        $ResultLine = "OBSERVACIÓN: " . $1 . "\n\n";
    }
    elsif ($Line =~ m/^ T: (.+)$/) {
        $ResultLine = "\\begin{itemize}\n";
        $ResultLine .= "\\item ETIQ.: " . $Line . "\n";
    }
    elsif ($Line =~ m/^ E: (.+)$/) {
        $ResultLine = "\\item EJEM.: " . $Line . "\n";
    }
    elsif ($Line =~ m/^ D: (.+)$/) {
        $ResultLine = "\\item DESC.: " . $Line . "\n";
        $ResultLine .= "\\end{itemize}\n\n";
    }
    else{
        $ResultLine = $Line . "\n";
    }
    return $ResultLine;
}

sub ProcessRuleContents{
        
    my $Line = shift (@_);
    my $ResultLine;

    if ($DebugLevel > 1) {
        print STDERR "DL2: In subroutine to process rule contents (ProcessRuleContents)\n";
        print STDERR "DL2: Value of \$Line is : " . $Line ."\n";
    }
    
    $ResultLine = "\\paragraph*{Rule}\n";
    $ResultLine .= "\\fbox{\n";
    $ResultLine .= "\\parbox{.9\\linewidth}{";
    $ResultLine .= "\\texttt{";
    $ResultLine .= $Line . "}}\n";
    $ResultLine .= "}\n";
    

    return $ResultLine;

}