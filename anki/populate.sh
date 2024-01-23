#!/usr/bin/env bash

rm -rf parts/
rm -rf tmp/
rm -rf deck/
mkdir -p parts/
mkdir -p tmp/
mkdir -p deck/

awk '
function shift() {
  for (i=1; i<NF; ++i) {
    $i = $(i+1)
  }
  --NF
}
function filename(fn) {
  return "parts/" IDX "." tolower(fn)
}
function create() {
  printf "" > F
}
function load() {
  D=$0
}
function append() {
  if (F) {
    print D >> F
  }
}

/^\* /     { shift(); CAT=$0;                     next }
/^\*\* /   {          IDX=$2;                     next }
/^\*\*\* / {            F=filename($2); create(); next }
{
  load()
  print "CAT=" CAT "; IDX=" IDX "; F=" F "; D=" D
  append()
}
' zp.org

for f in media question a b c answer references; do
  for F in parts/*.$f; do
    case $f in
      media)      cat $F | sed 's/^.*$/\\includegraphics{\0}/' | xargs -d '\n' | sed 's/ / \\\\ /g' > $F.0 && mv $F.0 $F;;
      references) cat $F | sed 's/^.*$/\\item \\url{\0}/'                                           > $F.0 && mv $F.0 $F;;
    esac
    case $f in
      media|answer|question) sed -i 's/^.*$/\\newcommand{\\'${f^}'}{\0}/' $F;;
      references) if [ $(cat $F | wc -l) -gt 0 ]; then ( echo '\begin{enumerate}[label={[\arabic*]}]'; cat $F; echo '\end{enumerate}' ); else cat $F; fi > $F.0 && mv $F.0 $F;;
    esac
  done
done

for i in $(sed -n 's/^\*\* \(.*\)$/\1/p' zp.org | sort -n); do
  echo $i
  (
    set -x
    for f in question answer; do
      case $f in
        answer) extra='\def\answer{yes}';;
        *)      extra='';;
      esac
      latex --halt-on-error --output-format=dvi --output-directory=tmp --jobname=$i.$f --src-specials --shell-escape $extra'\def\index{'$i'}\input{note}'
      dvips -z tmp/$i.$f.dvi -o tmp/$i.$f.ps
      ps2pdf   tmp/$i.$f.ps     deck/$i.$f.pdf
    done
  ) > tmp/$i.log 2>&1
done

for i in $(sed -n 's/^\*\* \(.*\)$/\1/p' zp.org | sort -n); do
  echo "$i,deck/$i.question.pdf,deck/$i.answer.pdf"
done > deck/deck.csv

(
  cd deck/
  ls | grep '\.\(question\|answer\)\.pdf$' | sort -t. -k1n -k2r | xargs | xargs -I{} echo pdfunite {} deck.pdf | bash
)
