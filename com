#!/bin/bash 


rombuildbin="$(dirname "$(realpath "$0")")"
export rombuildbin

. "$rombuildbin/argsparse.sh"

#argumant parsing

argsparse_use_option output "Set the output directory" value short:o type:directory default:out/
argsparse_use_option save-file "Set the save file to creat symbolic links to in the output directory" value short:s type:file
argsparse_use_option no-pack "Disables rom packing" short:n
argsparse_use_option no-unmount "Disables umounting of working directory" short:u
argsparse_use_option jobs "Sets the maximum amount of jobs that can be run at one time" value short:j type:uint default:6
argsparse_use_option ingnore-hash "Ingnores the hashs so that it redoes work" short:i
argsparse_use_option setup "Sets up the current work directory with the rom given" value type:file

argsparse_use_option overlay "An enumerated option." value default:fuse-overlayfs
option_overlay_values=( fuse-overlayfs cp)


if [ "$#" != "0" ]
then
argsparse_parse_options "$@"
fi


if argsparse_is_option_set setup
then
. "$rombuildbin/strings" load
. "$rombuildbin/sbnk"
mkdir -p data/mods/mods
rom="$(realpath "${program_options[setup]}")"
mkdir -p basedir
cd basedir
nitro unpack -r "$rom" -o ./ -p test -d
python3 "$rombuildbin/SDATTool.py" -u data/Sound/sound_data.sdat ./sound_data
mkdir -p lang
cd lang
for i in ../data/LOC/*; do genfastlang "$i"; done
cd ..
cd sound_data/Files/BANK/
for i in *.sbnk; do gencache "$i"; done

exit
fi

if argsparse_is_option_set overlay
then
overlaytype="${program_options[overlay]}"
fi
maxjobs=6
if argsparse_is_option_set jobs
then
maxjobs="${program_options[jobs]}"
fi

basedir="$(realpath basedir)"

savefile=""
outdir=./out/

# echo "${!program_options[@]}"

if argsparse_is_option_set no-pack
then
packroms=false
else
packroms=true
fi

if argsparse_is_option_set save-file
then
savefile="$(realpath "${program_options[save-file]}")"
fi

if argsparse_is_option_set output
then
outdir="$(realpath "${program_options[output]}")"
mkdir -p "$outdir"
fi


if  [ "$overlaytype" = "fuse-overlayfs" ]
then
    if ! command -v fuse-overlayfs >/dev/null || ! [ -a /dev/fuse ]
    then
        command -v fuse-overlayfs >/dev/null || echo "[WARRING] fuse-overlayfs not found falling back to cp"
        [ -a /dev/fuse ] || echo "[WARRING] fuse not support by system falling back to cp"
        overlaytype=cp
    fi
fi





#Common functions

ckhash(){
local pwd
local ret
pwd="$PWD"
cd "$1"
ret=1
if [ -f ".hash" ] &&  [ "$(tar c * 2>/dev/null | md5sum | awk '{print $1}')" = "$(cat .hash)" ]
then
ret=0
fi
argsparse_is_option_set ingnore-hash && ret=1
cd "$pwd"
return "$ret"
}

mkhash(){
local pwd
local ret
pwd="$PWD"
cd "$1"
tar c * 2>/dev/null| md5sum | awk '{print $1}' >.hash
cd "$pwd"
}

unmount_work(){
if [ "$(echo work/*)" != "work/*" ]
then
    cd work
    umount *
    rm -r *
    cd ..
fi
}





















unmount_work


for i in data/*/*; do mkdir -p "build$i"; done



modbuild(){
        in="build$1"
    echo "$in"
    mkdir -p "$(dirname "$in")"
    echo "$1" "$(dirname "$in")"
    "$rombuildbin/mod" "$1" "$(dirname "$in")"
}

declare -a topacker
for i in data/*
do
# echo "$i"
    fset=""
    for o in "$i"/*
    do

        needwork=0
        if ! ckhash "$o"
        then
            if [ "$(ls "$o")" != "" ]
            then

            [ "$(ls "build$o"/)" != "" ] && rm -r "build$o"/*
            for p in "$o"/*.lbz
            do

                modbuild "$p" &
                [ "$(jobs -rp | wc -l)" -ge $maxjobs ] && wait
            done
            fi

        needwork=1
        mkhash "$o"
        fi
        if [ "$fset" = "" ]
        then
        fset="$needwork $o"
        else
        fset="$fset
$needwork $o"
        fi
    done
    topacker+=("$fset")
#     echo -n "$needwork" | wc -l
done
# echo "${topacker[@]}"

# exit






wait


# exit



mkdir -p "$outdir" builddata/mods

#removes roms in the output directory if packroms is true



packer(){
    echo "[PACKING START]" $name

    upper="$(mktemp -d)"
    workdir="$(mktemp -d)"
    echo "$upper"




    if [ "$overlaytype" = "fuse-overlayfs" ]
    then

        unset stacktmp
        for count in $(seq 0 $((${#overlaystack[@]}-1)))
        do
            stacktmp="${overlaystack[$count]}":"$stacktmp"
        done
	    fuse-overlayfs -o lowerdir="${stacktmp::-1}",upperdir="$upper",workdir="$workdir" "$dir"
    else
        for count in $(seq 0 $((${#overlaystack[@]}-1)))
        do
            [ "$(echo "${overlaystack[$count]}"/*)" != "${overlaystack[$count]}""/*" ] && cp -fat "$dir" "${overlaystack[$count]}"/*
        done
    fi


    bash -c "cd \"$dir\"; [ -d scripts/ ] && for i in scripts/* ; do eval \"\$i\" ;done"
    bash -c "cd \"$dir\"; $rombuildbin/strings"
    bash -c "cd \"$dir\"; $rombuildbin/sound"


    if [ "$packroms" != "false" ]
    then
        nitro pack -c -p "$dir/test.xml" -r "$outdir/$name.nds"
        [ -f "$savefile" ] && ln -s "$savefile" "$outdir/$name.sav"
    fi


    echo "[PACKING DONE]" $name

}












subpacker(){
# echo "$@"




if [ "$1" != "0" ]
then
    for q in $(seq 1 "$(echo  "${topacker[$1]}" | wc -l)")
    do
        [ "$(echo -n "${topacker[$1]}" | head -n $q | tail -1 | awk '{print $2}')" = "" ] && continue
        flag[$1]="$(echo -n "${topacker[$1]}" | head -n $q | tail -1 | awk '{print $1}' )"
        subpacker $(($1-1))  "$@" "build$(echo -n "${topacker[$1]}" | head -n $q | tail -1 | awk '{print $2}' )"

    done
else
    for q in $(seq 1 "$(echo  "${topacker[$1]}" | wc -l)")
    do
        flag[$1]="$(echo -n "${topacker[$1]}" | head -n $q | tail -1 | awk '{print $1}' )"
        [ "$(for y in "${flag[@]}" ;do [ "$y" = 1 ] && echo filler ;done)" = "" ] && continue
        overlaystack=( "$basedir" )
#                 echo
# echo "${flag[@]}"

        name=""
        k=0
        for t in "$@"
        do
            k=$((k+1))
            [ $k -le $((depth+1)) ] && continue
            overlaystack+=("$t")
            if [ "$name" = "" ]
            then
                name="$(echo "$t" | awk -F/ '{print $NF}')"
            else
                name+=_"$(echo "$t" | awk -F/ '{print $NF}')"
            fi

        done

        overlaystack+=( "build$(echo -n "${topacker[$1]}" | head -n $q | tail -1 | awk '{print $2}' )")
        name="${name:-"Modified$q"}"
        dir="work/""$name"
        echo "$dir"
        mkdir -p "$dir"
        echo name "$name"
#         echo "${overlaystack[@]}"
        packer &
        [ "$(jobs -rp | wc -l)" -ge $maxjobs ] && wait

    done

fi



}




name=""


depth="$((${#topacker[@]}-1))"
declare -a flag

# echo "${topacker[@]}"
subpacker "$((${#topacker[@]}-1))"

wait













if ! argsparse_is_option_set no-unmount
then
    unmount_work
fi
