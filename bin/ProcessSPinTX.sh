#!/bin/bash

TXTDIR="$SPINTX_HOME/corpus/ClipTags/ori"
CG3DIR="$SPINTX_HOME/corpus/ClipTags/cg3"
OUTDIR="$SPINTX_HOME/corpus/ClipTags/out"
## MQ: I comment this till I start working on integration of PAToS in environment using CWB Tools
## CQPDIR="$TEXTDIR/CQP"
GRAMMARS="$SPINTX_HOME/spintxPedagogicalAnntotation/grammars"


if [ "$1" = "all" ]; then
  echo "Conversion from TreeTagger format to CG3 format..."
  cd "$TXTDIR"
  ttagger2OtherFormats.pl -outformat cg3 *.txt
fi

echo "Tagging with vislcg3..."
cd "$CG3DIR"

for i in *.cg3; do
  CG3OUT=`expr "$i" : '\(.*\)\.cg3'` 
  vislcg3 -g ${GRAMMARS}/SpintxGrammar.rle -I ${i} -O ${OUTDIR}/${CG3OUT}.out
##  echo "Created file ${OUTDIR}/${CG3OUT}.out"
done

if [ "$1" = "all" ]; then
  echo "Counting/Adding up clip level information..."
  cd "$OUTDIR"
  countPedagogicalFeatures.pl -outformat solr *.out

  echo "Generating word level annotation files in JSON format..."
  wordLevelPedagogAnnotations.pl *.out
  echo "Done!"
fi

