#!/bin/bash

# Parameter validations
if [[ $# -lt 3 ]]; then
	echo "Invalid syntax. Usage:"
	echo `basename $0` "{local|internet} <version> {xz|gz}"
	exit
fi

join(){
	declare -a pieces=(${!1})
	glue=$2
	string=$(printf "${glue}%s" "${pieces[@]}")
	echo ${string:${#glue}}
	return 0
}

# Variables
temporal="kernel.tmp"
official="kernel.off"
kernel=linux-$2
filename=$kernel.tar.$3
url="https://www.kernel.org/pub/linux/kernel/v3.x"
# Create directories if necesary
mkdir -p {$temporal,$official}

# Copy/download kernel package file
if [[ $1 == "internet" ]]; then
	echo "From internet"
	if [[ -f $temporal/$filename ]]; then
		rm -f $temporal/$filename
	fi
	wget $url/$filename --output-document=$temporal/$filename
elif [[ $1 -eq "local" ]]; then
	echo "Working directory"
	if [[ ! -f $filename ]]; then
		echo "Error: File not exists."
		exit
	fi
	cp $filename $temporal/
else
	echo "Source error."
	exit
fi

# Uncompress files
if [[ ! -d $official/$kernel ]]; then
	tar -xvf $temporal/$filename -C $official
fi

# Associative array for count.
declare -A counter
: '
# Counting by file name
files=(README Kconfig Kbuild Makefile .*\\.c .*\\.h .*\\.pl .*gpio.*)
regex=$(join files[@] "\\|")
filelist=`find $official/$kernel -type f -iregex ".*/\($regex\)$"`
for file in ${files[@]}; do
	echo Counting $file files.
	counter[$file]=`echo "${filelist[*]}" | grep "$file$" | wc -l`
done

exclusions=`for file in $files; do echo -n "--ignore=$file "; done`
counter[others]=`ls -1R $exclusions | grep [^:]$ | wc -l`
counter[total]=`dc -e "[+]sa[z2!>az2!>b]sb${counter[*]}lbxp"`
# Counting architectures
counter[architectures]=`ls $official/$kernel/arch/*/ -d1 | wc -l`

# Counting by word in files content
words=(Linus kernel_start __init)
regex=$(join $words "\\|")
content=`find $official/$kernel -type f -exec cat {} \; | sed 's/\($regex\)/\1\n/g'`
for word in ${words[@]}; do
	echo Counting words: $word
	counter[$word]=`echo "${content[*]}" | grep "$word" | wc -l`
done
#counter[includes]=`find $official/$kernel/* -type f -exec cat {} \; | grep "#include\\s<linux\\/module\\.h>" | wc -l`
#'

# Sort
regex='#include <linux\/[^>]*>'
for file in `find $official/$kernel/drivers/i2c/ -type f`; do
	#echo $file
	grep "$regex" $file | sort > includes
	#start=`sed '/^#include/q' $file | wc -l`
	sed -i "/$regex/{
		R includes
		d
	}" $file # | head -n 48 | tail -n 32
	grep "@intel" $file
done
rm includes

for file in `find $official/$kernel -type f`; do
	grep "@intel" $file
done


for topic in ${!counter[@]}; do
	printf "%-15s %8s\n" $topic: ${counter[$topic]}
done