#!/bin/bash

TXTDIR="$SPINTX_HOME/corpus/ClipTags/ori"
CG3DIR="$SPINTX_HOME/corpus/ClipTags/cg3"
OUTDIR="$SPINTX_HOME/corpus/ClipTags/out"
## MQ: I comment this till I start working on integration of PAToS in environment using CWB Tools
## CQPDIR="$TEXTDIR/CQP"
GRAMMARS="$SPINTX_HOME/spintxPedagogicalAnntotation/grammars"

if [[ "$1" == "help" ]] || [[ "$1" == "" ]]; then
  echo " "
  echo "Script to launch any of the PAToS annotation scripts."
  echo "  USAGE: ProcessSpintx.sh OPTIONS"
  echo " "
  echo "  OPTIONS:"
  echo "    all -- Do all processes"
  echo "    tt2cg3 -- Convert TreeTagger format files to CG3 format"
  echo "    cg3 -- Apply CG3 grammar files for pedagogical annotation"
  echo "    counts -- Do the counts at the clip level"
  echo "    json -- Generate the json formatted version of the annotation files"
  echo "    help -- Print this help page"
  exit 1
fi

if [[ "$1" == "all" ]] || [[ "$1" == "tt2cg3" ]]; then
  echo "Conversion from TreeTagger format to CG3 format..."
  cd "$TXTDIR"
  ttagger2OtherFormats.pl -outformat cg3 *.txt
fi

if [[ "$1" == "all" ]] || [[ "$1" == "cg3" ]]; then
  echo "Tagging with vislcg3..."
  cd "$CG3DIR"

  for i in *.cg3; do
    CG3OUT=`expr "$i" : '\(.*\)\.cg3'` 
    vislcg3 -g ${GRAMMARS}/SpintxGrammar.rle -I ${i} -O ${OUTDIR}/${CG3OUT}.out
##  echo "Created file ${OUTDIR}/${CG3OUT}.out"
  done
fi

if [[ "$1" == "all" ]] || [[ "$1" = "counts" ]]; then
  echo "Counting/Adding up clip level information..."
  cd "$OUTDIR"
  countPedagogicalFeatures.pl -outformat solr *.out
fi

if [[ "$1" == "all" ]] || [[ "$1" = "json" ]]; then
  echo "Generating word level annotation files in JSON format..."
  wordLevelPedagogAnnotations.pl *.out
  echo "Done!"
fi

cut -f 2 ${OUTDIR}/SpintxMetadataVocab.tsv > ${OUTDIR}/JustVocabCol.txt
paste ${OUTDIR}/SpintxPedagogicalMetadata.tsv ${OUTDIR}/JustVocabCol.txt > ${OUTDIR}/ClipMetadataPedagogical.tsv

## split -l 10000 ${CLIPSWLA}/ClipsWLAOneFile.tsv ${CLIPSWLA}/ForTokenTagsPedagogical


