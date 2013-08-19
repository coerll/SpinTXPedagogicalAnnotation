#!/bin/bash

TXTDIR="$SPINTX_HOME/data/SpinTXCorpusData/ClipTags"
CG3DIR="$SPINTX_HOME/data/SpinTXCorpusData/cg3"
OUTDIR="$SPINTX_HOME/data/SpinTXCorpusData/ClipPedagogicalTags"
## MQ: I comment this till I start working on integration of PAToS in environment using CWB Tools
## CQPDIR="$TEXTDIR/CQP"
## GRAMMARS="$SPINTX_HOME/tools/spintxPedagogicalAnntotation/grammars"
GRAMMARS="${SPINTX_HOME}tools/SpinTXPedagogicalAnnotation/grammars"

if [[ "$1" == "help" ]] || [[ "$1" == "" ]]; then
  echo " "
  echo "Script to launch any of the PAToS annotation scripts."
  echo "  USAGE: ProcessSpintx.sh OPTIONS"
  echo " "
  echo "  OPTIONS:"
  echo "    all -- Do all processes"
  echo "    tt2cg3 -- Convert TreeTagger format files to CG3 format"
  echo "    cg3 -- Apply CG3 grammar files for pedagogical annotation"
  echo "    cg3trace -- Apply CG3 grammar files for pedagogical annotation 
	    with rule trace functionalities (and exit)"
  echo "    counts -- Do the counts at the clip level"
  echo "    json -- Generate the json formatted version of the annotation files"
  echo "    help -- Print this help page"
  exit 1
fi

if [[ "$1" == "all" ]]; then
  echo "Removing older versions of cg3 files in $CG3DIR ..."
  cd "$CG3DIR"
  rm *.cg3
  echo "Removing older versions of out, pla and tsv files in $OUTDIR ..."
  cd "$OUTDIR"
  rm *.out *.pla *.tsv
fi

if [[ "$1" == "cg3" ]] || [[ "$1" == "cg3trace" ]]; then
  echo "Removing older versions of *ONLY* *.out files in $OUTDIR ..."
  cd "$OUTDIR"
  rm *.out
fi

###------------------
## CONVERSION TO CG3 FORMAT
###------------------
if [[ "$1" == "all" ]] || [[ "$1" == "tt2cg3" ]]; then
  echo "Conversion from TreeTagger format to CG3 format..."
  cd "$TXTDIR"
  ttagger2OtherFormats.pl -outformat cg3 *.txt
fi

###------------------
## ANNOTATION WITH PEDAGOGICAL INFORMATION USING VISLCG3
###------------------
if [[ "$1" == "all" ]] || [[ "$1" == "cg3" ]]; then
  echo "Tagging with vislcg3..."
  cd "$CG3DIR"

  for i in *.cg3; do
    CG3OUT=`expr "$i" : '\(.*\)\.cg3'` 
    vislcg3 -g ${GRAMMARS}/SpintxGrammar.rle -I ${i} -O ${OUTDIR}/${CG3OUT}.out
##  echo "Created file ${OUTDIR}/${CG3OUT}.out"
  done
fi

###------------------
## ANNOTATION WITH PEDAGOGICAL INFORMATION USING VISLCG3 USING ** RULE TRACE **

if [[ "$1" == "cg3trace" ]]; then
echo "Excuting vislcg3 with -t (trace) option for grammar writers..."
cd "$CG3DIR"

for i in *.cg3; do
CG3OUT=`expr "$i" : '\(.*\)\.cg3'` 
vislcg3 -t -g ${GRAMMARS}/SpintxGrammar.rle -I ${i} -O ${OUTDIR}/${CG3OUT}.out
##  echo "Created file ${OUTDIR}/${CG3OUT}.out"
done
exit 0
fi

###------------------
## CLIP LEVEL COUNTS AND JSON GENERATION FORMATS
###------------------

if [[ "$1" == "all" ]] || [[ "$1" = "counts" ]]; then
  echo "Counting/Adding up clip level information..."
  cd "$OUTDIR"
  countPedagogicalFeatures.pl -outformat nopla *.out
fi

if [[ "$1" == "all" ]] || [[ "$1" = "json" ]]; then
  echo "Generating word level annotation files in JSON format..."
  wordLevelPedagogAnnotations.pl *.out
  echo "Done!"
fi

if [[ "$1" == "all" ]] || [[ "$1" = "counts" ]]; then
  cut -f 2 ${OUTDIR}/SpintxMetadataVocab.tsv > ${OUTDIR}/JustVocabColUnigram.txt
  cut -f 6 ${OUTDIR}/SpintxPedagogicalMetadata.tsv > ${OUTDIR}/JustVocabColNgram.txt
  cut -f 1-5 ${OUTDIR}/SpintxPedagogicalMetadata.tsv > ${OUTDIR}/AllButVocab.txt
  paste -d \, ${OUTDIR}/JustVocabColNgram.txt ${OUTDIR}/JustVocabColUnigram.txt > ${OUTDIR}/JustVocabColALL.txt
  paste ${OUTDIR}/AllButVocab.txt ${OUTDIR}/JustVocabColALL.txt > ${OUTDIR}/ClipMetadataPedagogical-DRAFT.tsv
  cat ${OUTDIR}/ClipMetadataPedagogical-DRAFT.tsv | sed 's/vocab_tags,vocab_tags/vocab_tags/g' > ${OUTDIR}/ClipMetadataPedagogical-DRAFT2.tsv
  perl -pe  's/\t,/\t/g' < ${OUTDIR}/ClipMetadataPedagogical-DRAFT2.tsv > ${OUTDIR}/ClipMetadataPedagogical.tsv
fi

exit 0
