#!/bin/bash
#
# may accept the following parameters
# -i DIR: input directory, will be traversed recursively, the folder structure
#         below this directory will be replicated, must not end with "/"
# -o DIR: output directory
# -t NUMBER: number of thread calling this script for multi-thraeding
# -e ENCODER: either ffmpeg or avconv, default: ffmpeg
# -d: dry-run, for debugging, won't create any directories / convert any files
# -v: for debugging, be extra verbose

# the IFS takes care of spaces in file and dirnames
IFS=$'\n'

# for debugging purposes
# will not create any folders or convert any files if "T"
testonly="F"
# be extra verbose if "T"
verbose="F"
# default thread number
thread="0"
# default encoder
encoder="ffmpeg"

# read options
while getopts ":i:o:t:e:dv" opt; do
  case "$opt" in
    i)
      echo "convert files in: $OPTARG"
      sourcebasedir="$OPTARG"
      ;;
    o)
      echo "write them to: $OPTARG"
      outputbasedir="$OPTARG"
      ;;
    e)
      echo "encoder: $OPTARG"
      encoder="$OPTARG"
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

  if [[ -f "$confdir/current$thread" ]]; then
    # be verbose
    [[ $verbose == 'T' ]] &&
      echo "detected unfinished file: "$(<"$confdir/current$thread")

    # remove unfinished file and the file holding this information
    if [[ $testonly == 'F' ]]; then
      removed=$(<"$confdir/current$thread")
      rm $(<"$confdir/current$thread")
      rm "$confdir/current$thread"
      echo "removed file: $removed"
    fi
  fi
}

if [[ ! -d "$confdir" ]]; then
  [[ $verbose == 'T' ]] && echo "creating: $confdir"
  mkdir -p "$confdir"
fi

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
  

  if [[ $verbose == 'T' ]]; then
    echo "file: $file"
    echo "filename: $filename"
    echo "targetname: $targetname"
    echo "sourcedir: $sourcedir"
    echo "relativedir: $relativedir"
    echo "outputdir: $outputdir"
    echo "outputfile: $outputfile"
  fi

  echo "$outputfile" > "$confdir/current$thread"

  if [[ $testonly == 'F' ]]; then 
    [[ ! -d "$outputdir" ]] && mkdir -p "$outputdir"

    # choose converter and quality to your liking
    if [[ ! -e "$outputfile" ]]; then
      echo "converting: $relativedir/$filename to $outputfile"

      #ffmpeg -loglevel info -i "$file" -codec:a libmp3lame -b:a 320k -vsync 2 "$outputfile"
      $encoder -nostats -n -loglevel info -i "$file" -codec:a libmp3lame -qscale:a 2 -vsync 2 "$outputfile"
    fi

    # if we reach this point, the file has been converted successfully
    rm "$confdir/current$thread"
  fi
done
