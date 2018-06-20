#!/bin/bash

if [ ! -d release ];then
	mkdir release
fi

for line in $(ls __pycache__)
do
	oldname=$line
	newname=`echo $line|awk -F "." '{print $1"."$3}'`
	echo "copy $oldname to $newname"
	cp __pycache__/$oldname release/$newname
done

mkdir -p release/dbs
mkdir -p release/conf
cp conf/global.ini release/conf
