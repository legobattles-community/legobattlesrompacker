#!/bin/bash
mod="$(realpath "$1")"
out="$(realpath "$2")"
work="$(mktemp -d)"


if [ -d "$mod" ]
then
manifest="$(cat "$mod"/manifest.toml)"
else
manifest="$(unzip -p "$mod" manifest.toml)"
fi

type="$(echo "$manifest" | tomlq -r .type)"





echo "$mod" "$out" "$work"  "$type" "$name"
if ! command -v uuidgen >/dev/null
then
uuidgen() { C="89ab";for ((N=0;N<16;++N));do B="$((RANDOM%256))";case "$N" in 6) printf '4%x' "$((B%16))" ;; 8) printf '%c%x' "${C:$RANDOM%${#C}:1}" "$((B%16))";; 3|5|7|9) printf '%02x-' "$B"; ;; *) printf '%02x' "$B"; ;; esac; done; printf '\n'; }
fi
reoder(){ echo "${1:6:2}${1:4:2}${1:2:2}${1:0:2}"; }
numtooff(){ echo -n "00000000$(printf '%x' "$1")" | tail -c 8 ;}
num2(){ echo -n "00000000$(printf '%x' "$1")" | tail -c 2 | tr '[:lower:]' '[:upper:]' ;}
4bb(){ echo $((0x$(reoder "$(head -c $1 "$file" | tail -c 4 | xxd -p)"))) ;}
for i in $(seq 1 $(echo "$manifest" | tomlq '.args | length'))
do
tmp="$(echo "$manifest" | tomlq -r ".args[$((i-1))]")"
# echo $i $tmp
args+=("$tmp")
done
atg="$(basename $mod | awk -F: '{print $2}')"
if [ "$atg" != "" ]
then
unset args
for i in ${atg//,/ }; do args+=("$i"); done
fi


mp01=1242 mp02=1244 mp03=1246 mp04=1248 mp05=1250 mp06=1252 mp07=1254 mp08=1256 mp09=1258 mp10=1260 mp11=1262 mp12=1264 mp13=1266 mp14=1268 mp15=1270 mp16=1272 mp17=1274 mp18=1276 mp19=1278 mp20=1280 mp21=1282 mp22=1284 mp23=1286 mp24=1288 mp25=1290 mp26=1292 mp27=1294 mp28=1296 mp29=1298 mp30=1300
name="$(echo "$manifest" | tomlq -r .name)"
version="$(echo "$manifest" | tomlq -r .version)"




spro(){
  vare(){
  eval "tmp=\"\${tw$1:-$2}\""

  eval "$1"="$(printf '%x' "$tmp")"
  }
  vari(){
  eval "tmp=\"\${tw$1:-$2}\""
  }


  vare note 72
  vare attack 127
  vare decay 127
  vare sustain 127
  vare release 125
  vari pan 0
  pan="$(printf '%x' "$(($tmp+64))")"


  echo "$note""$attack""$decay""$sustain""$release""$pan"

}
spot(){
    echo '#!/bin/bash'
    echo "num2(){ echo -n \"0000\$1\" | tail -c 4 | tr '[:lower:]' '[:upper:]' ;}"
    echo 'reoder(){ echo "${1:6:2}${1:4:2}${1:2:2}${1:0:2}"; }'
    if [ "$mode" = "add" ]
    then
    echo -e "c=\"\$(ls -1 sound_data/Files/WAVARC/WAVE_$bakt*/ | wc -l)\"\nc=\"\$((\$(ls -1 sound/Files/WAVARC/WAVE_$bakt*/ 2>/dev/null | wc -l)+c))\"\nb=\"\$(printf '%x' \$c | tr '[:lower:]' '[:upper:]' )\""
    echo -e "d=sound/Files/WAVARC/\$(basename sound_data/Files/WAVARC/WAVE_$bakt*/)/\nmkdir -p \$d\ncp -fa tmp/$fid \$d/\$b.swav"
    fi
    if [ "$mode" = "edit" ]
    then
    echo -e "b=\"\$(printf '%x' \$(($twsoundno-1)))\""
    fi
    echo -e "mkdir -p sound/Files/BANK/$bank/entrys/\necho \"\$(reoder \$(num2 \$b))\"0000\"$(spro)\" | xxd -r -p >sound/Files/BANK/$bank/entrys/$bankno"


}

sound(){
unset tw*
twork="$(echo "$manifest" | tomlq --toml-output -r .sound[$1])"
eval "$(echo "$twork" | sed 's/ = /=/g' |sed "s/.*/tw&/g")"
file="sound/$twfile"

case "$twtype" in

  sfx)
    bakt="$(echo "$twbank" | awk -F_ '{print $2}')"
    mode="$twmode"
    bank="$twbank"
    bankno="$twbankno"
    mkdir -p "$out"/scripts/
    if [ "$mode" = "add" ]
    then
    fid="$(uuidgen)"
    mkdir -p "$out"/tmp/
    cp -fa "$file" "$out""/tmp/$fid"
    fi
    spot >"$out"/scripts/"3_sound_$(uuidgen)"
    chmod +x "$out"/scripts/*
  ;;
  music)
    mkdir -p "$out""/sound/Files/STRM/"
    cp -fa "$file" "$out""/sound/Files/STRM/$twreplace.strm"

  ;;
esac





}










mkdir -p "$work"
cd "$work"
if [ -d "$mod" ]
then
cp -fat "$work" "$mod"/*
else
unzip "$mod"
fi

case "$type" in

  overlay)
    cp -fat "$out" overlay/*
    ;;

  map)
    #echo "${args[0]}"
    mkdir -p "$out/data/Maps" "$out/data/" "$out/strings/American_English/"
    
    mv map.map "$out/data/Maps/${args[0]}.map"
    if [ -d mapimages/ ]
    then
        mkdir -p "$out/data/BP"
        for i in mapimages/*; do mv $i "$out/data/$(basename "${i//@/${args[0]}}")"; done
    fi
    if [ -d detailtiles/ ]
    then
        for i in detailtiles/*
        do
          if [ -s "$i" ]
          then
            mv $i "$out/data/BP/$(basename "${i//@/${args[0]}}")"
          fi
        done
    fi
    [ -f "$out/strings/American_English/$(eval "echo \$${args[0]}")" ] && echo "$name" > "$out/strings/American_English/$(eval "echo \$${args[0]}")"

    ;;
  script)
    mkdir -p "$out/scripts"
    mv script "$out/scripts/5-script-$name"
    chmod +x "$out/scripts/5-script-$name"
#     echo "scripts/$name ${args[@]}" >> "$out/scripts/tab"

    ;;
  sound)
  soundcount="$(tomlq '.sound |length' <<<"$manifest")"
  for i in $(seq 0 $(($soundcount-1)))
  do
  sound $i
  done
  ;;
esac

rm -r "$work"

tomlq -e -r .script <<<"$manifest" >/dev/null && eval "$(echo "$manifest" | tomlq -r .script)"
