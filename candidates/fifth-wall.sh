#!/usr/bin/env bash
set -euo pipefail
W=${W:-1920} H=${H:-1080}
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
bg="#171118"; dkbg="#110B12"
sky1="#0D0811"; land="#0C070F"
burn="#7A4530"; glow="#D2833A"; lip="#F2CB86"; emberglow="#6E4520"

grain() { magick "$1" \( +clone -fill grey50 -colorize 100 -attenuate 1.0 +noise Gaussian -colorspace Gray \) \
  -compose overlay -define compose:args=${2:-26} -composite "$TMP/gr.png" && mv "$TMP/gr.png" "$1"; }
lum() { magick "$1" -depth 8 -format '%[fx:int((mean.r*0.299+mean.g*0.587+mean.b*0.114)*255)]' info:; }

# ---------------------------------------------------------- A · mashrabiya ---
# A pierced screen: eight-point stars cut from a dark panel, warm light behind,
# strongest low and centre. Echoes the pointed arcade on the boot mark.
mashrabiya() {
  local T=150 c=75 R=52 rr=30 pts="" i rad
  for ((i=0;i<16;i++)); do
    rad=$(( i%2==0 ? R : rr ))
    pts+=$(awk -v i=$i -v c=$c -v rad=$rad 'BEGIN{
      a=3.14159265*i/8 - 3.14159265/2; printf "%.1f,%.1f ", c+rad*cos(a), c+rad*sin(a)}')
  done
  magick -size ${T}x${T} xc:black -fill white -stroke none -draw "polygon $pts" \
    -fill none -stroke white -strokewidth 2 -draw "rectangle 0,0 149,149" "$TMP/tile.png"
  magick -size "${W}x${H}" tile:"$TMP/tile.png" -blur 0x1.4 -alpha off -colorspace Gray "$TMP/mask.png"
  local gw=$(( W*20/10 ))
  magick -size "${gw}x${gw}" radial-gradient:"$lip"-"$sky1" \
    -gravity south -crop "${gw}x$(( gw*36/100 ))+0+0" +repage \
    -resize "${W}x${H}!" -channel RGB -evaluate multiply 0.30 +channel "$TMP/back.png"
  magick -size "${W}x${H}" xc:"$dkbg" "$TMP/back.png" "$TMP/mask.png" -composite "$TMP/a.png"
  grain "$TMP/a.png" 22
  magick "$TMP/a.png" -quality 90 a-mashrabiya.jpg
}

# ------------------------------------------------------------ B · colonnade ---
# From inside the arcade at dusk: pointed arches in silhouette, evening beyond.
colonnade() {
  local base=$(( H*90/100 )) i x w top spring rr rise apex
  magick -size "${W}x$(( H*62/100 ))" gradient:"$sky1"-"$burn" "$TMP/sk.png"
  magick -size "${W}x$(( H*38/100 ))" gradient:"$glow"-"$lip" "$TMP/lo.png"
  magick "$TMP/sk.png" "$TMP/lo.png" -append -blur 0x6 \
    -channel RGB -evaluate multiply 0.56 +channel "$TMP/behind.png"
  local -a d=()
  for i in 0 1 2 3 4; do
    w=$(( W*82/1000 )); x=$(( W*(11 + i*195/10)/100 ))
    top=$(( H*54/100 )); spring=$(( top + w/2 ))
    rr=$(( w*3/2 )); rise=$(( w*112/100 )); apex=$(( spring - rise ))
    d+=( -draw "path 'M $((x-w)),$base L $((x-w)),$spring A $rr,$rr 0 0 1 $x,$apex A $rr,$rr 0 0 1 $((x+w)),$spring L $((x+w)),$base Z'" )
  done
  magick -size "${W}x${H}" xc:black -fill white -stroke none "${d[@]}" -blur 0x1 -alpha off -colorspace Gray "$TMP/wall.png"
  magick -size "${W}x${H}" xc:"$dkbg" "$TMP/behind.png" "$TMP/wall.png" -composite "$TMP/b.png"
  grain "$TMP/b.png" 24
  magick "$TMP/b.png" -quality 90 b-colonnade.jpg
}

# -------------------------------------------------------------- C · plaster ---
# No subject at all: a warm wall, mottled and weathered, very low contrast.
plaster() {
  magick -size "${W}x${H}" plasma:fractal -colorspace Gray -blur 0x14 -normalize \
    -sigmoidal-contrast 2,50% "$TMP/n.png"
  magick -size 1x256 gradient:"$dkbg"-"$emberglow" -rotate 90 "$TMP/ramp.png"
  magick "$TMP/n.png" "$TMP/ramp.png" -clut \
    -channel RGB -evaluate multiply 0.34 +channel "$TMP/c.png"
  grain "$TMP/c.png" 32
  magick "$TMP/c.png" -quality 90 c-plaster.jpg
}

# ---------------------------------------------------------------- D · shaft ---
# Vertical light where everything else in the set is horizontal: one warm beam
# falling through the dark, and the dust it catches.
shaft() {
  local x1=$(( W*30/100 )) x2=$(( W*41/100 )) x3=$(( W*63/100 )) x4=$(( W*48/100 ))
  magick -size "${W}x${H}" xc:black \
    -fill white -stroke none -draw "polygon $x1,0 $x2,0 $x3,$H $x4,$H" \
    -blur 0x$(( W/26 )) "$TMP/beam.png"
  magick -size "${W}x${H}" gradient:"$lip"-"$burn" "$TMP/beamcol.png"
  magick "$TMP/beamcol.png" "$TMP/beam.png" -compose multiply -composite \
    -channel RGB -evaluate multiply 0.90 +channel "$TMP/beam2.png"
  magick -size "${W}x${H}" xc:"$bg" "$TMP/beam2.png" -compose screen -composite \
    -channel RGB -evaluate multiply 1.0 +channel "$TMP/d.png"
  grain "$TMP/d.png" 36
  magick "$TMP/d.png" -quality 90 d-shaft.jpg
}

mashrabiya; colonnade; plaster; shaft
for f in a-mashrabiya.jpg b-colonnade.jpg c-plaster.jpg d-shaft.jpg; do
  printf '%-18s lum %s\n' "$f" "$(lum "$f")"
done
