#!/bin/bash
#
# may accept the following parameters
# -i DIR: input directory, will be traversed recursively, the folder structure
#         below this directory will be replicated, must not end with "/"
# -o DIR: output directory
# -t NUMBER: number of thread calling this script for multi-thraeding
# -d: dry-run, for debugging, won't create any directories / convert any files
# -v: for debugging, be extra verbose
#
# - on my raspberry I could only use avconv, not ffmpeg. 
#    choose, whatever suits you best

# The IFS takes care of spaces in file and dirnames 
# your folders may vary
IFS=$'\n'

# for debugging purposes
# will not create any folders or convert any files if "T"
testonly="F"
# be extra verbose if "T"
verbose="F"
# default thread number
thread="0"

# read options
while getopts ":i:o:t:dv" opt; do
  case "$opt" in
		i)
			echo "convert files in: $OPTARG"
			sourcebasedir="$OPTARG"
			;;
		o)
			echo "write them to: $OPTARG"
			outputbasedir="$OPTARG"
			;;
    v)
			echo "verbose"
			verbose="T"
			;;
    d)
			echo "dry-run only"
			testonly="T"
			;;
		t)
			echo "thread number"
			thread="$OPTARG"
			;;
    \?)
      echo "Invalid option: -$OPTARG" >&2
      exit 1
      ;;
    :)
      echo "Option -$OPTARG requires an argument." >&2
      exit 1
      ;;
  esac
done

# script needs a directory to keep track of unfinished conversions
confdir=~/.flacconv

# calculate the number of slashes in the source path
# so we can later cut it off so we get a relative path
slashes=$(echo "$sourcebasedir//"| grep -o "\/" | wc -l)

# kill script on ctrl-c
trap '
  trap - INT # restore default INT handler
  kill -s INT "$$"
' INT

# the name of file that is being converted is written into ~/.flacconv/current
# so if the script is interrupted the flac-file named ~./flacconv/current is
# unfinished -> on the next run delete that file

function delete_unfinished {
	echo "looking for unfinished files"

	# be verbose
	[[ -f "$confdir/current$thread" ]] &&
		[[ $verbose == 'T' ]] &&
		echo "detected unfinished file: " &&
		echo $(<"$confdir/current$thread")

	# remove unfinished file and the file holding this information
	[[ -f "$confdir/current$thread" ]] &&
		[[ $testonly == 'F' ]] &&
	  removed=$(<"$confdir/current$thread") &&
	  rm $(<"$confdir/current$thread") &&
	  rm "$confdir/current$thread" &&
		echo "removed file: $removed"
}

[[ ! -d "$confdir" ]] && [[ $verbose == 'T' ]] && echo "creating: $confdir"
[[ ! -d "$confdir" ]] && mkdir -p "$confdir"

delete_unfinished

# look for .flac/.FLAC files
for file in $(find $sourcebasedir -type f -iname '*.flac');
do
  filename="${file##*/}"
  targetname="${filename%.*}.mp3"
  sourcedir=$(dirname "$file")
  relativedir="$(echo $sourcedir | cut -d'/' -f$slashes-)"
  outputdir="$outputbasedir/$relativedir"
  outputfile="$outputdir/$targetname"
  

	[[ $verbose == 'T' ]] &&
		echo "file: $file" &&
		echo "filename: $filename" &&
		echo "targetname: $targetname" &&
		echo "sourcedir: $sourcedir" &&
		echo "relativedir: $relativedir" &&
		echo "outputdir: $outputdir" &&
		echo "outputfile: $outputfile"

	echo "$outputfile" > "$confdir/current"
  [[ ! -d "$outputdir" ]] && [[ $testonly == 'F' ]] && mkdir -p "$outputdir"

	# choose converter and quality to your liking
	[[ ! -e "$outputfile" ]] && [[ $testonly == 'F' ]] &&
		echo "converting: $relativedir/$filename to $outputfile" &&
		# ffmpeg: constant bitrate: 320 k
    #ffmpeg -loglevel info -i "$file" -codec:a libmp3lame -b:a 320k -vsync 2 "$outputfile"
		# ffmpeg: variable bitrate: compression 2 (should be quite good)
		ffmpeg -loglevel info -i "$file" -codec:a libmp3lame -qscale:a 2 -vsync 2 "$outputfile"
		# avconv: variable bitrate: compression 0 (insanely good)
    #avconv -n -nostats -loglevel info -i "$file" -codec:a libmp3lame -qscale:a 0 "$outputfile"

	# if we reach this point, the file has been converted successfully
	rm "$confdir/current"
done
