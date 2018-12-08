#!/bin/bash

if [ ! -d release ];then
	mkdir release
fi

for pyfile in $(ls *.py)
do
python simple_compile.py $PWD"/"$pyfile
done

for line in $(ls __pycache__)
do
	oldname=$line
	newname=`echo $line|awk -F "." '{print $1"."$3}'`
	echo "copy $oldname to $newname"
	cp __pycache__/$oldname release/$newname
done

mkdir -p release/dbs
mkdir -p release/conf
mkdir -p release/doc
cp conf/global.ini release/conf
cd doc
pandoc --toc eMMC_Test_Overview.md -o ../release/doc/eMMC_Test_Overview.pdf --latex-engine=xelatex --toc-depth=4 -V mainfont="WenQuanYi Micro Hei" --smart -f markdown+tex_math_single_backslash -s --dpi=20 -V documentclass=report
pandoc --toc eMMC_TestTool_SOP.md -o ../release/doc/eMMC_TestTool_SOP.pdf --latex-engine=xelatex --toc-depth=4 -V mainfont="WenQuanYi Micro Hei" --smart -f markdown+tex_math_single_backslash -s --dpi=20 -V documentclass=report
cd ..

timestamp_str=`date +%Y%m%d%H%M%S`
tar jcf eMMC_Test_${timestamp_str}.tar.bz release/
