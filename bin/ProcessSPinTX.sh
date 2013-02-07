#!/bin/bash

TXTDIR="/Users/mquixal/Documents/Feina/COERLL/ClipTags"
CG3DIR="/Users/mquixal/Documents/Feina/COERLL/ClipTags/CG3"
CQPDIR="$TEXTDIR/CQP"
GRAMMARS="/Users/mquixal/Documents/Feina/COERLL/Grammars"


if [ "$1" = "all" ]; then
  echo "Conversion from TreeTagger format to CG3 format..."
  cd "$TXTDIR"
  ttagger2OtherFormats.pl -outformat cg3 *.txt
fi

echo "Tagging with vislcg3..."
cd "$CG3DIR"

for i in *.cg3; do
  CG3OUT=`expr "$i" : '\(.*\)\.cg3'` 
  vislcg3 -g ${GRAMMARS}/SpintxGrammar.rle -I ${i} -O ${CG3OUT}.out
done

echo "Done!"

