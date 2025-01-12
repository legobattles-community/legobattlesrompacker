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
argsparse_use_option update "Updates rombuilder"

argsparse_use_option overlay "Sets the methoid to combind the mods" short:f value default:fuse-overlayfs
option_overlay_values=( fuse-overlayfs cp overlayfs)


if [ "$#" != "0" ]
then
argsparse_parse_options "$@"
fi

overlaytype=fuse-overlayfs
if argsparse_is_option_set update
then
cd "$rombuildbin"
git stash
git pull origin main
chmod +x "$rombuildbin"/*

exit
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

temp="$(mktemp -d)"
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
    if ! command -v fuse-overlayfs >/dev/null || ! [ -w /dev/fuse ]
    then
        command -v fuse-overlayfs >/dev/null || echo "[WARRING] fuse-overlayfs not found falling back to cp"
        if [ ! -w /dev/fuse ]; then
            echo -e '[WARRING] /dev/fuse is not accessible falling back to cp. Change it with \nsudo chmod 0666 /dev/fuse'
        fi

        overlaytype=cp
    fi
fi

if ! [ -d "$basedir" ]
then
echo "[ERROR] basedir does not esist make it with --setup"
exit

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
if ! [ "$overlaytype" = "overlayfs" ]
then
if [ "$(echo "$temp"/*)" != "$temp/*" ]
then
    rm -r "$temp"
fi
if [ "$(echo work/*)" != "work/*" ]
then
    cd work
    for i in *
    do
    if mountpoint -q -- "$i"
    then
    umount "$i" || sudo umount "$i"
    fi
    rm -r "$i"
    done
    cd ..
fi
else
if [ "$(echo "$temp"/*)" != "$temp/*" ]
then
    sudo rm -r "$temp"
fi
if [ "$(echo work/*)" != "work/*" ]
then
    cd work
    for i in *
    do
    if mountpoint -q -- "$i"
    then
    sudo umount "$i"
    fi
    sudo rm -r "$i"
    done
    cd ..
fi
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
                while [ "$(jobs -rp | wc -l)" -ge $maxjobs ] ; do :  ;done
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

    mkdir -p "$temp"/"$name"/upper "$temp"/"$name"/workdir
    upper="$temp/"$name"/upper"
    workdir="$temp/"$name"/workdir"
    echo "$upper"




    if [ "$overlaytype" = "fuse-overlayfs" ]
    then

        unset stacktmp
        for count in $(seq 0 $((${#overlaystack[@]}-1)))
        do
            stacktmp="${overlaystack[$count]}":"$stacktmp"
        done
	    fuse-overlayfs -o lowerdir="${stacktmp::-1}",upperdir="$upper",workdir="$workdir" "$dir"
    fi
    if [ "$overlaytype" = "overlayfs" ]
    then

        unset stacktmp
        for count in $(seq 0 $((${#overlaystack[@]}-1)))
        do
            stacktmp="${overlaystack[$count]}":"$stacktmp"
        done
	    sudo mount -t overlay overlay -olowerdir="${stacktmp::-1}",upperdir="$upper",workdir="$workdir" "$dir"
    fi
    if [ "$overlaytype" = "cp" ]
    then
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
        nitro pack -c -p "$dir/test."* -r "$outdir/$name.nds"
        [ -a "$savefile" ] && ln -s "$savefile" "$outdir/$name.sav"
    fi

    if [ "$overlaytype" = "overlayfs" ]
    then

	    sudo umount "$dir"
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
            if [ "$(ls -1 "$(dirname "$t")" | wc -l)" -gt 1 ]
            then
                if [ "$name" = "" ]
                then
                    name="$(echo "$t" | awk -F/ '{print $NF}')"
                else
                    name+=_"$(echo "$t" | awk -F/ '{print $NF}')"
                fi
            fi

        done

        overlaystack+=( "build$(echo -n "${topacker[$1]}" | head -n $q | tail -1 | awk '{print $2}' )")
        t="build$(echo -n "${topacker[$1]}" | head -n $q | tail -1 | awk '{print $2}' )"
        if [ "$(ls -1 "$(dirname "$t")" | wc -l)" -gt 1 ]
        then
            if [ "$name" = "" ]
            then
                name="$(echo "$t" | awk -F/ '{print $NF}')"
            else
                name+=_"$(echo "$t" | awk -F/ '{print $NF}')"
            fi
        fi
        name="${name:-"Modified$q"}"
        dir="work/""$name"
        echo "$dir"
        mkdir -p "$dir"
#         echo name "$name"
#         echo "${overlaystack[@]}"
        packer &
        while [ "$(jobs -rp | wc -l)" -ge $maxjobs ] ; do : ;done

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
