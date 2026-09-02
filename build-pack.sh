#!/usr/bin/env bash
# Builds the Levantine Sunset pack: 2 places x 2 depths.
#   Batroun — the coast, sun into the sea.   Beirut — the lamplit city.
set -euo pipefail
W=${W:-3840} H=${H:-2160}
DEST=${DEST:-$HOME/.config/omarchy/themes}
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT

# ---------------------------------------------------------------- palettes ---
# Batroun: ember + gold on indigo.   Beirut: clay + amber on the same indigo.
p_batroun() {
  accent="#E4744A"
  red="#E4744A"; yellow="#E8B25C"; orange="#EF8F52"; green="#A8B36A"
  cyan="#5CB6A8"; blue="#6F93E0"; magenta="#D98BA6"; brown="#6E4A3C"
  b_red="#F08A5F"; b_yellow="#F3C273"; b_green="#BAC57C"
  b_cyan="#71C9BB"; b_blue="#89A9EE"; b_magenta="#E8A0B9"
  fg="#EDE3D6"; dark_fg="#6E6478"; light_fg="#C9BFB4"; bright_fg="#FFF8EE"
  border="rgba(e4744aee) rgba(e8b25cee) 45deg"
  burn="#6A3A4E"; glow="#C25F45"; lip="#EFAE66"; emberglow="#7A3A2E"
  icons="Yaru-red"
}
p_beirut() {
  accent="#E8A63F"
  red="#D9744E"; yellow="#E8A63F"; orange="#E28A42"; green="#A3AF62"
  cyan="#88ADA2"; blue="#92A0B9"; magenta="#CD87A2"; brown="#6B4A30"
  b_red="#E88A63"; b_yellow="#F2B855"; b_green="#B5C077"
  b_cyan="#9CBFB4"; b_blue="#A5B3CA"; b_magenta="#DC9BB4"
  fg="#F0E5D3"; dark_fg="#6D6478"; light_fg="#CBBFAB"; bright_fg="#FFF8EA"
  border="rgba(e8a63fee) rgba(d9744eee) 45deg"
  burn="#7A4530"; glow="#D2833A"; lip="#F2CB86"; emberglow="#6E4520"
  icons="Yaru-yellow"
}
# ------------------------------------------------------------------ depths ---
# The ground is place-aware: Batroun leans blue (the sea), Beirut leans plum
# (lamplight on stone). Luminance is identical to the old shared base on every
# key -- only hue moves -- so the depth ladder and all contrast ratios hold.
# "Gentle" separation: the two grounds sit dE2000 4.66 apart, each ~2.3 from
# the old shared #14121A.
d_soft() {
  case $PAL in
    batroun) bg="#11131B"; dbg="#0E1018"; dkbg="#0B0D14"; lbg="#191A27"
             muted="#373649"; sel="#35314B"; sky1="#090A13"; land="#080911";;
    beirut)  bg="#171118"; dbg="#140E16"; dkbg="#110B12"; lbg="#1F1824"
             muted="#3E3446"; sel="#3E3141"; sky1="#0D0811"; land="#0C070F";;
  esac
  _m=${muted#\#}; inactive="rgba(${_m,,}aa)"
}
d_black() {
  case $PAL in
    batroun) bg="#080A0E"; dbg="#040509"; dkbg="#000000"; lbg="#10121A"
             muted="#2B2B3B"; sel="#272539"; sky1="#050510"; land="#020307";;
    beirut)  bg="#0C080C"; dbg="#060508"; dkbg="#000000"; lbg="#161017"
             muted="#322938"; sel="#2F2434"; sky1="#08050F"; land="#040307";;
  esac
  _m=${muted#\#}; inactive="rgba(${_m,,}aa)"
}

# ------------------------------------------------------------- image tools ---
grad() { # out height  "hex:span"... (last stop takes no span)
  local out=$1 h=$2; shift 2
  local -a cols=() wts=(); local s
  for s in "$@"; do cols+=("${s%%:*}"); [[ $s == *:* ]] && wts+=("${s#*:}"); done
  local n=${#cols[@]} total=0 i
  for ((i=0;i<n-1;i++)); do total=$(( total + wts[i] )); done
  local -a parts=()
  for ((i=0;i<n-1;i++)); do
    local sh=$(( h * wts[i] / total )); (( sh < 2 )) && sh=2
    magick -size 16x${sh} gradient:"${cols[i]}-${cols[i+1]}" "$TMP/p$i.miff"; parts+=("$TMP/p$i.miff")
  done
  magick "${parts[@]}" -append -resize "${W}x${h}!" +repage "$out"
}
grain() { magick "$1" \( +clone -fill grey50 -colorize 100 -attenuate 1.0 +noise Gaussian -colorspace Gray \) \
  -compose overlay -define compose:args=${2:-26} -composite "$TMP/gr.png" && mv "$TMP/gr.png" "$1"; }

sky() { # out  — the shared indigo night with this palette's burn low in it
  local skyh=$(( H * 84 / 100 )) landh=$(( H - H * 84 / 100 ))
  grad "$TMP/s.png" "$skyh" "$sky1:30" "#131228:26" "#2A2140:19" "$burn:13" "$glow:8" "$lip:4" "$lip"
  magick -size "${W}x${landh}" xc:"$land" "$TMP/l.png"
  magick "$TMP/s.png" "$TMP/l.png" -append -blur 0x$(( H / 700 )) "$1"
}
ridgepts() { # baseline_frac amp_frac freq phase
  awk -v W=$W -v H=$H -v b=$1 -v a=$2 -v f=$3 -v p=$4 'BEGIN{
    n=160; for(i=0;i<=n;i++){ t=i/n; x=W*t;
      y=H*(b + a*(0.62*sin(6.2831853*f*t+p) + 0.38*sin(6.2831853*f*1.73*t+p*2.3)));
      printf "%.0f,%.0f ", x, y }
    printf "%d,%d %d,%d", W, H, 0, H }'
}
mixw() { # colorA colorB weightB(0-100) -> #rrggbb   (-depth 8 or 16-bit hex breaks the parse)
  printf '#%s' "$(magick -size 1x1 xc:"$1" \( -size 1x1 xc:"$2" \) -compose blend \
    -define compose:args=$3 -composite -depth 8 -format '%[hex:p{0,0}]' info:)"; }

# ------------------------------------------------------------- wallpapers ----
make_walls() {
  local d=$1; mkdir -p "$d"
  # Retired wallpapers: horizon duplicated scanline's subject and brightness,
  # and ember gave up its slot to shaft. Drop them so a rebuild doesn't leave
  # six backgrounds behind. Named explicitly -- anything else in here is yours.
  rm -f "$d/1-horizon.jpg" "$d/3-ember.jpg"
  # 1 — colonnade: pointed arches cut from a dark wall, evening beyond them.
  # The same arcade as the boot mark, at wallpaper scale. Replaces the old
  # horizon, which was the same subject as scanline at the same brightness.
  # sky() still runs: ridge is drawn on top of it.
  sky "$TMP/h.png"
  local n pitch aw top spring rr rise apex cbase i cx
  n=$(( 4 + SEED % 3 ))                 # 4-6 arches, so no two themes match
  cbase=$(( H*90/100 )); top=$(( H*40/100 ))
  magick -size "${W}x$(( H*62/100 ))" gradient:"$sky1"-"$burn" "$TMP/csk.png"
  magick -size "${W}x$(( H*38/100 ))" gradient:"$glow"-"$lip" "$TMP/clo.png"
  magick "$TMP/csk.png" "$TMP/clo.png" -append -blur 0x$(( H/90 )) \
    -channel RGB -evaluate multiply 0.70 +channel "$TMP/cbehind.png"
  local -a cd=()
  pitch=$(( W / n ))
  for ((i=0;i<n;i++)); do
    aw=$(( pitch*42/100 )); cx=$(( pitch*i + pitch/2 ))
    spring=$(( top + aw/2 )); rr=$(( aw*3/2 )); rise=$(( aw*112/100 ))
    apex=$(( spring - rise ))
    cd+=( -draw "path 'M $((cx-aw)),$cbase L $((cx-aw)),$spring A $rr,$rr 0 0 1 $cx,$apex A $rr,$rr 0 0 1 $((cx+aw)),$spring L $((cx+aw)),$cbase Z'" )
  done
  # A drawn mask keeps an opaque alpha channel and -composite would use THAT
  # instead of the greyscale, putting the overlay everywhere. Strip it.
  magick -size "${W}x${H}" xc:black -fill white -stroke none "${cd[@]}" \
    -blur 0x$(( H/900 )) -alpha off -colorspace Gray "$TMP/cwall.png"
  magick -size "${W}x${H}" xc:"$dkbg" "$TMP/cbehind.png" "$TMP/cwall.png" -composite "$TMP/w1.png"
  grain "$TMP/w1.png" 24
  magick "$TMP/w1.png" -quality 88 "$d/1-colonnade.jpg"
  # 2 — ridge: the same horizon behind two rolling silhouettes.
  # SEED shifts the wave phase so the four themes get different landforms.
  local far near p1 p2; far=$(mixw "$land" "$burn" 30); near="$land"
  p1=$(awk -v s=$SEED 'BEGIN{printf "%.3f", 0.9 + s*1.77}')
  p2=$(awk -v s=$SEED 'BEGIN{printf "%.3f", 3.1 + s*2.31}')
  magick "$TMP/h.png" \
    -fill "$far"  -draw "polygon $(ridgepts 0.70 0.055 1.6 $p1)" \
    -fill "$near" -draw "polygon $(ridgepts 0.82 0.045 2.4 $p2)" "$TMP/w2.png"
  grain "$TMP/w2.png" 26; magick "$TMP/w2.png" -quality 88 "$d/2-ridge.jpg"
  # 3 — shaft: one warm beam falling through the dark, and the dust it catches.
  # Takes over ember's role as the quiet dark option, and is the only vertical
  # composition in a set that is otherwise all horizontal bands.
  local o x1 x2 x3 x4
  o=$(( (SEED - 1) * 6 ))               # slides the beam across the frame
  x1=$(( W*(30+o)/100 )); x2=$(( W*(41+o)/100 ))
  x3=$(( W*(63+o)/100 )); x4=$(( W*(48+o)/100 ))
  magick -size "${W}x${H}" xc:black -fill white -stroke none \
    -draw "polygon $x1,0 $x2,0 $x3,$H $x4,$H" -blur 0x$(( W/26 )) \
    -alpha off -colorspace Gray "$TMP/sbeam.png"
  magick -size "${W}x${H}" gradient:"$lip"-"$burn" "$TMP/sbcol.png"
  magick "$TMP/sbcol.png" "$TMP/sbeam.png" -compose multiply -composite \
    -channel RGB -evaluate multiply 0.62 +channel "$TMP/sbeam2.png"
  magick -size "${W}x${H}" xc:"$bg" "$TMP/sbeam2.png" -compose screen -composite \
    -channel RGB -evaluate multiply 0.86 +channel "$TMP/w3.png"
  grain "$TMP/w3.png" 34
  magick "$TMP/w3.png" -quality 90 "$d/3-shaft.jpg"
  # 4 — scanline: the same scene on a CRT. Its own night-heavy sky, darker than
  # horizon's, so the sun and the dimmed rows carry the frame instead of the glow.
  local skyh=$(( H*82/100 )) landh sx sy sr
  landh=$(( H - skyh ))
  grad "$TMP/nsk.png" "$skyh" "$sky1:36" "#131228:27" "#2A2140:19" "$burn:10" "$glow:5" "$lip:3" "$lip"
  magick -size "${W}x${landh}" xc:"$land" "$TMP/nld.png"
  magick "$TMP/nsk.png" "$TMP/nld.png" -append -blur 0x2 "$TMP/sc0.png"
  sx=$(( W * (50 + (SEED-1)*7) / 100 )); sy=$(( H*70/100 )); sr=$(( H*55/1000 ))
  magick "$TMP/sc0.png" -fill "$lip" -stroke none -draw "circle $sx,$sy $((sx+sr)),$sy" "$TMP/sc1.png"
  magick "$TMP/sc1.png" \( +clone -blur 0x$((H/28)) \) -compose screen -composite "$TMP/sc2.png"
  magick -size 1x3 xc:white -fill gray62 -draw "point 0,2" "$TMP/scsl.png"
  magick "$TMP/sc2.png" \( -size "${W}x${H}" tile:"$TMP/scsl.png" \) -compose multiply -composite "$TMP/sc3.png"
  magick "$TMP/sc3.png" \( -size "${W}x${H}" radial-gradient:white-gray60 -resize 150% \
    -gravity center -extent "${W}x${H}" \) -compose multiply -composite "$TMP/w4.png"
  grain "$TMP/w4.png" 14; magick "$TMP/w4.png" -quality 90 "$d/4-scanline.jpg"
}

# ---- unlock.png: the Plymouth boot logo. 800x188 to match every stock theme.
# omarchy-plymouth-set takes one static PNG plus two hex colours -- there is no
# animation slot, so this is a still mark: a sun half-risen on the horizon.
unlock_mark() { # outfile — the OMARCHY wordmark beneath a pointed arcade
  local out=$1 W2=800 H2=188 CX=400 base=116 sc=74
  local -a args=(); local i=0 spec x w top spring rr rise apex col
  # Every stock theme's unlock.png is the OMARCHY wordmark recoloured, so the
  # name belongs here. The arcade carries the theme; the wordmark stays quiet
  # underneath it, lowercase and widely tracked.
  #
  # Built on OPAQUE black: alpha comes from luminance at the end, so a filled
  # silhouette would vanish. Outlines catching light are the only thing that works.
  for spec in "-290 42 92" "-174 48 104" "-58 54 116" "58 54 116" "174 48 104" "290 42 92"; do
    set -- $spec
    x=$(( CX + $1 )); w=$(( $2 * sc / 100 )); top=$(( base - $3 * sc / 100 ))
    spring=$(( top + w ))
    # radius 1.5x the half-span makes the arcs meet at a point rather than
    # closing into a Roman semicircle
    rr=$(( w * 3 / 2 )); rise=$(( w * 112 / 100 )); apex=$(( spring - rise ))
    case $i in 0|5) col="$burn";; 1|4) col="$glow";; *) col="$lip";; esac
    args+=( -stroke "$col" -strokewidth 2 -draw "path 'M $((x-w)),$base L $((x-w)),$spring A $rr,$rr 0 0 1 $x,$apex A $rr,$rr 0 0 1 $((x+w)),$spring L $((x+w)),$base'" )
    i=$(( i + 1 ))
  done
  magick -size ${W2}x${H2} xc:black -fill none "${args[@]}" \
    -stroke "$accent" -strokewidth 2 -draw "line 96,$base 704,$base" \
    -stroke none -fill "$lip" -font Adwaita-Sans -pointsize 30 -kerning 13 \
    -gravity north -annotate +6+136 "omarchy" "$TMP/am0.png"
  magick "$TMP/am0.png" \( +clone -blur 0x9 \) -compose screen -composite \
    \( +clone -blur 0x22 \) -compose screen -composite "$TMP/am1.png"
  magick "$TMP/am1.png" \( +clone -colorspace Gray \) \
    -alpha off -compose CopyOpacity -composite "$out"
}

# ------------------------------------------------------------ colors.toml ----
make_colors() {
  cat > "$1" <<TOML
# $2 — from the Levantine Sunset collection.
# $3 on a $4 base.
mode = "dark"

accent = "$accent"
selection = "$sel"
muted = "$muted"

background = "$bg"
dark_background = "$dbg"
darker_background = "$dkbg"
lighter_background = "$lbg"

foreground = "$fg"
dark_foreground = "$dark_fg"
light_foreground = "$light_fg"
bright_foreground = "$bright_fg"

hyprland_active_border = "$border"
hyprland_inactive_border = "$inactive"

red = "$red"
yellow = "$yellow"
orange = "$orange"
green = "$green"
cyan = "$cyan"
blue = "$blue"
magenta = "$magenta"
brown = "$brown"

bright_red = "$b_red"
bright_yellow = "$b_yellow"
bright_green = "$b_green"
bright_cyan = "$b_cyan"
bright_blue = "$b_blue"
bright_magenta = "$b_magenta"
TOML
}

# ---------------------------------------------------------------- preview ----
make_preview() { # dir title
  local d=$1 sw=$(( 1200 / 8 ))
  magick "$d/1-colonnade.jpg" -resize 1200x -gravity north -crop 1200x620+0+0 +repage "$TMP/pv.png"
  local strip=()
  for c in "$accent" "$red" "$yellow" "$green" "$cyan" "$blue" "$magenta" "$fg"; do
    magick -size ${sw}x80 xc:"$c" "$TMP/sw_${#strip[@]}.png"; strip+=("$TMP/sw_${#strip[@]}.png")
  done
  magick "${strip[@]}" +append "$TMP/ramp.png"
  magick "$TMP/pv.png" "$TMP/ramp.png" -append -quality 92 "$d/preview.png"
}

# ------------------------------------------------------------------ build ----
SEED=0
for PAL in batroun beirut; do
  for DEPTH in soft black; do
    p_$PAL; d_$DEPTH
    if [[ $DEPTH == soft ]]; then slug="$PAL"; else slug="$PAL-noir"; fi
    dir="$DEST/$slug"; mkdir -p "$dir/backgrounds"
    case "$PAL/$DEPTH" in
      batroun/soft)  disp="Batroun";      acc="ember and gold"; bse="soft indigo";;
      batroun/black) disp="Batroun Noir"; acc="ember and gold"; bse="near-black indigo";;
      beirut/soft)   disp="Beirut";       acc="clay and amber"; bse="soft indigo";;
      beirut/black)  disp="Beirut Noir";  acc="clay and amber"; bse="near-black indigo";;
    esac
    echo ">> $disp  ($slug)  [seed $SEED]"
    make_colors "$dir/colors.toml" "$disp" "$acc" "$bse"
    # omarchy-theme-set-gnome reads this and sets gsettings icon-theme;
    # without it every theme falls back to Yaru-blue.
    printf '%s\n' "$icons" > "$dir/icons.theme"
    [[ ${ASSETS_ONLY:-0} == 1 ]] || make_walls "$dir/backgrounds"
    unlock_mark "$dir/unlock.png"
    # Generated with Omarchy's own tool so it matches the stock convention
    # exactly; same bg/text keys omarchy-plymouth-set-by-theme reads.
    # omarchy-plymouth-preview writes the file and then blocks on `imv` to
    # display it — it is an interactive tool. Shadow imv with a no-op so it
    # returns immediately in a batch build.
    mkdir -p "$TMP/shim"
    printf '#!/bin/sh\nexit 0\n' > "$TMP/shim/imv"; chmod +x "$TMP/shim/imv"
    PATH="$TMP/shim:$PATH" omarchy-plymouth-preview "$bg" "$fg" \
      "$dir/unlock.png" "$dir/preview-unlock.png" >/dev/null 2>&1 || \
      echo "     (plymouth preview unavailable — preview-unlock.png skipped)"
    # The shipped preview.png is a real 1800x1012 desktop screenshot, not a
    # generated crop -- a rebuild must not clobber it. make_preview only fills
    # in when there is nothing there, or when explicitly asked.
    if [[ ${GEN_PREVIEW:-0} == 1 || ! -f "$dir/preview.png" ]]; then
      make_preview "$dir/backgrounds"
      mv "$dir/backgrounds/preview.png" "$dir/preview.png"
    fi
    SEED=$(( SEED + 1 ))
  done
done

# The theme picker caches previews in two layers and invalidates BOTH on
# directory mtimes alone -- omarchy-theme-switcher's symlink cache and
# omarchy-menu-images' rows/thumbnail cache. Overwriting preview.png in place
# never changes a directory's mtime, so the picker keeps serving the thumbnail
# it built the first time it saw the theme. Drop the caches; they rebuild on
# next open, and --lazy-thumbnails shows the full image meanwhile.
cache=${XDG_CACHE_HOME:-$HOME/.cache}/omarchy
rm -rf "$cache/theme-selector" "$cache/image-selector"

echo "done."
