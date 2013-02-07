PAToS -- Pedagogical Annotation Tools for Spanish
=================================================

PAToS is an set of Natural Language Processing and PERL scripts developed for the pedagogical
annotation of Spanish texts. PAToS assumes as input a file (or files) annotated with lemma and
POS tags including a series of informations such as language (for texts written including words
in languages other than Spanish), morphosyntactic features and starting and ending times for
transcripts of audiovisual documents (since it is originally designed for the annotation of 
interview transcripts obtained through the SPinTX project).

The PAToS package provides with the following functionalities:

- PERL scripts for format conversions between other SPinTX-related tools and VISL-CG3 
and Corpus WorkBench Tools
- VISL-CG3 grammars that annotate (or post-edit) Spanish texts assuming they have been
tokenized, lemmatized and POS-tagged with TreeTagger (and usuing the SPinTX POS tagging tools)
- PERL scripts for the generation of file (document) level breakdowns, and word level 
visualization files using the internal SPinTX token ids
- PERL scripts to generate the linguistic specifications included in the VISL-CG3 file (if 
following the established documentation format)

Installation
------------

See INSTALL for installation instructions

Further Documentation
---------------------

See 'docs/EXTENDING' on how to extend the VISL-CG3 grammars for the annotation of new linguistic 
or pedagogical phenomena.

