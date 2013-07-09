#!/bin/bash

TXTDIR="$SPINTX_HOME/data/SpinTXCorpusData/ClipTags"
CQPDIR="$SPINTX_HOME/data/SpinTXCorpusData/ClipCQP"

echo "Compiling SPinTX in a local installation of cqp"
echo "This script assumes cqp is installed"

cd "$CQPDIR"

echo "Removing old SPinTX *.tsv files"
rm *.tsv

###------------------
echo "Conversion from TreeTagger format to CQP format..."
cd "$TXTDIR"
ttagger2OtherFormats.pl -outformat cqp *.txt

cd "$CQPDIR"
echo "Removing old SPinTX single file all-spintx.cpr"
rm all-spintx.cpr

echo "Concatenating all cpr files into one single file"
cat *.tsv > all-spintx.cpr

echo "Deleting data folder for spintxloc corpus"
rm /corpora/data/spintxloc/*.*

echo "Starting to compile in CQP"

cwb-encode -d /corpora/data/spintxloc -R /corpora/registry/spintxloc -f "$CQPDIR"/all-spintx.cpr -xsB -P lemma -P pos -P spos -P tense -P mood -P number -P person -P gender -P lang -P starttime -P endtime -P ttid -P clipid -V text:0+id -V speaker:0+type -V lang:0+code

cwb-make -M 256 -r /corpora/registry/ SPINTXLOC

