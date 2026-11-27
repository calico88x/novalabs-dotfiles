
#!/bin/sh
# NovaLabs bootstrap presentation library.
# POSIX shell compatible. Source this file; do not execute directly.
#
# Presentation only:
#   - Terminal capability detection
#   - Centralized palette loading
#   - ANSI color rendering
#
# Installation and system mutation remain the responsibility of install.sh.

# Read a quoted scalar from a known theme catalog section.
# This intentionally supports only the scalar format used by our catalog.
# It is not a general-purpose TOML parser.
nl_ui_catalog_value() {
    awk -v section="$2" -v key="$3" '
        /^[[:space:]]*\[/ {
            active = ($0 == "[" section "]")
            next
        }

        active {
            line = $0

            sub(/^[[:space:]]*/, "", line)

            if (line !~ ("^" key "[[:space:]]*="))
                next

            sub(/^[^=]*=[[:space:]]*/, "", line)

            if (line !~ /^"[^"]*"[[:space:]]*$/) {
                invalid = 1
                next
            }

            sub(/^"/, "", line)
            sub(/"[[:space:]]*$/, "", line)

            value = line
            count++
        }

        END {
            if (count != 1 || invalid)
                exit 1

            print value
        }
    ' "$1"
}

# Validate a six-digit hexadecimal RGB color.
nl_ui_valid_hex() {
    case "${1:-}" in
        \#[0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F])
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

# Detect terminal capabilities without requiring external TUI utilities.
nl_ui_detect_terminal() {
    NL_UI_COLOR_MODE=plain
    NL_UI_ANIMATE=false
    NL_UI_COLUMNS=80

    if [ "${NL_UI_PLAIN:-false}" = true ] ||
       [ ! -t 1 ] ||
       [ ! -t 2 ] ||
       [ -n "${NO_COLOR:-}" ] ||
       [ "${TERM:-dumb}" = dumb ] ||
       [ -n "${CI:-}" ]
    then
        return 0
    fi

    case "${COLORTERM:-}" in
        truecolor|24bit)
            NL_UI_COLOR_MODE=truecolor
            ;;
        *)
            case "${TERM:-}" in
                *256color*)
                    NL_UI_COLOR_MODE=256
                    ;;
                *)
                    NL_UI_COLOR_MODE=ansi
                    ;;
            esac
            ;;
    esac

    if command -v tput >/dev/null 2>&1; then
        NL_UI_COLUMNS=$(tput cols 2>/dev/null) ||
            NL_UI_COLUMNS=80
    fi

    case "$NL_UI_COLUMNS" in
        ''|*[!0-9]*|0)
            NL_UI_COLUMNS=80
            ;;
    esac

    if [ "${NL_UI_NO_ANIMATION:-false}" != true ]; then
        NL_UI_ANIMATE=true
    fi

    return 0
}

# Load the authoritative presentation palette.
nl_ui_load_palette() {
    NL_UI_CATALOG="$1/.chezmoidata/theme.toml"

    [ -r "$NL_UI_CATALOG" ] || return 1
    command -v awk >/dev/null 2>&1 || return 1

    NL_UI_BRAND_1=$(nl_ui_catalog_value "$NL_UI_CATALOG" \
        theme.bootstrap.brand stop_1) || return 1

    NL_UI_BRAND_2=$(nl_ui_catalog_value "$NL_UI_CATALOG" \
        theme.bootstrap.brand stop_2) || return 1

    NL_UI_BRAND_3=$(nl_ui_catalog_value "$NL_UI_CATALOG" \
        theme.bootstrap.brand stop_3) || return 1

    NL_UI_BRAND_4=$(nl_ui_catalog_value "$NL_UI_CATALOG" \
        theme.bootstrap.brand stop_4) || return 1

    NL_UI_BRAND_5=$(nl_ui_catalog_value "$NL_UI_CATALOG" \
        theme.bootstrap.brand stop_5) || return 1

    NL_UI_BRAND_6=$(nl_ui_catalog_value "$NL_UI_CATALOG" \
        theme.bootstrap.brand stop_6) || return 1

    NL_UI_SLOGAN=$(nl_ui_catalog_value "$NL_UI_CATALOG" \
        theme.bootstrap slogan) || return 1

    NL_UI_HEADER=$(nl_ui_catalog_value "$NL_UI_CATALOG" \
        theme.hosts.any shade_1) || return 1

    NL_UI_HIGHLIGHT=$(nl_ui_catalog_value "$NL_UI_CATALOG" \
        theme.hosts.any shade_4) || return 1

    NL_UI_SUCCESS=$(nl_ui_catalog_value "$NL_UI_CATALOG" \
        theme.shared success) || return 1

    NL_UI_ERROR=$(nl_ui_catalog_value "$NL_UI_CATALOG" \
        theme.shared error) || return 1

    NL_UI_WARNING=$(nl_ui_catalog_value "$NL_UI_CATALOG" \
        theme.shared warning) || return 1

    NL_UI_FOREGROUND=$(nl_ui_catalog_value "$NL_UI_CATALOG" \
        theme.shared text_light) || return 1

    NL_UI_MUTED=$(nl_ui_catalog_value "$NL_UI_CATALOG" \
        theme.tui muted) || return 1

    for nl_ui_value in \
        "$NL_UI_BRAND_1" \
        "$NL_UI_BRAND_2" \
        "$NL_UI_BRAND_3" \
        "$NL_UI_BRAND_4" \
        "$NL_UI_BRAND_5" \
        "$NL_UI_BRAND_6" \
        "$NL_UI_HEADER" \
        "$NL_UI_HIGHLIGHT" \
        "$NL_UI_SUCCESS" \
        "$NL_UI_ERROR" \
        "$NL_UI_WARNING" \
        "$NL_UI_FOREGROUND" \
        "$NL_UI_MUTED"
    do
        nl_ui_valid_hex "$nl_ui_value" || return 1
    done

    # Restrict the early-bootstrap slogan to printable ASCII branding.
    case "$NL_UI_SLOGAN" in
        ''|*[!ABCDEFGHIJKLMNOPQRSTUVWXYZ\ ]*)
            return 1
            ;;
    esac

    return 0
}

# Emit an ANSI foreground color.
#
# Arguments:
#   $1: hexadecimal RGB color
#   $2: basic ANSI fallback color number
#
# The subshell prevents temporary RGB variables from leaking into
# the calling installer.
nl_ui_color() (
    [ "${NL_UI_COLOR_MODE:-plain}" != plain ] || exit 0

    nl_ui_valid_hex "${1:-}" || exit 0

    nl_ui_hex=${1#\#}

    nl_ui_r=${nl_ui_hex%????}
    nl_ui_tail=${nl_ui_hex#??}
    nl_ui_g=${nl_ui_tail%??}
    nl_ui_b=${nl_ui_hex#????}

    nl_ui_r=$((0x$nl_ui_r))
    nl_ui_g=$((0x$nl_ui_g))
    nl_ui_b=$((0x$nl_ui_b))

    case "$NL_UI_COLOR_MODE" in
        truecolor)
            printf '\033[38;2;%s;%s;%sm' \
                "$nl_ui_r" "$nl_ui_g" "$nl_ui_b"
            ;;

        256)
            # Quantize RGB channels into the ANSI 6x6x6 color cube.
            nl_ui_r=$(((nl_ui_r * 5 + 127) / 255))
            nl_ui_g=$(((nl_ui_g * 5 + 127) / 255))
            nl_ui_b=$(((nl_ui_b * 5 + 127) / 255))

            nl_ui_index=$((16 + 36 * nl_ui_r + 6 * nl_ui_g + nl_ui_b))

            printf '\033[38;5;%sm' "$nl_ui_index"
            ;;

        ansi)
            case "${2:-37}" in
                3[0-7]|9[0-7])
                    printf '\033[%sm' "${2:-37}"
                    ;;
                *)
                    printf '\033[37m'
                    ;;
            esac
            ;;
    esac
)

# Reset text attributes after colored output.
nl_ui_reset() {
    if [ "${NL_UI_COLOR_MODE:-plain}" != plain ]; then
        printf '\033[0m'
    fi

    return 0
}

# Print a colored string without interpreting its contents.
nl_ui_text() {
    nl_ui_color "$1" "$2"
    printf '%s' "$3"
    nl_ui_reset
}

# Initialize presentation state.
# Missing or invalid theme data must never block the bootstrap.
nl_ui_init() {
    NL_UI_PALETTE_READY=false

    nl_ui_detect_terminal

    if nl_ui_load_palette "$1"; then
        NL_UI_PALETTE_READY=true
    else
        NL_UI_COLOR_MODE=plain
        NL_UI_ANIMATE=false
    fi

    return 0
}


# Render a bitmap glyph as five rows of ASCII digits.
# Each glyph occupies seven terminal columns.
nl_ui_glyph() {
    case "$1" in
        N) printf '%s\n' \
            1110011 1111011 1101111 1100111 1100011 ;;
        O) printf '%s\n' \
            0111110 1100011 1100011 1100011 0111110 ;;
        V) printf '%s\n' \
            1100011 1100011 0110110 0110110 0011100 ;;
        A) printf '%s\n' \
            0111110 1100011 1111111 1100011 1100011 ;;
        L) printf '%s\n' \
            1100000 1100000 1100000 1100000 1111111 ;;
        B) printf '%s\n' \
            1111110 1100011 1111110 1100011 1111110 ;;
        S) printf '%s\n' \
            0111111 1100000 0111110 0000011 1111110 ;;
        *) return 1 ;;
    esac
}

# Construct a complete five-row bitmap from supported glyphs.
nl_ui_bitmap() (
    nl_ui_word="$1"
    nl_ui_row=1

    while [ "$nl_ui_row" -le 5 ]; do
        nl_ui_remaining="$nl_ui_word"
        nl_ui_separator=""

        while [ -n "$nl_ui_remaining" ]; do
            nl_ui_char=${nl_ui_remaining%"${nl_ui_remaining#?}"}
            nl_ui_remaining=${nl_ui_remaining#?}

            nl_ui_glyph_data=$(nl_ui_glyph "$nl_ui_char") ||
                exit 1

            nl_ui_glyph_row=$(
                printf '%s\n' "$nl_ui_glyph_data" |
                    awk -v row="$nl_ui_row" 'NR == row'
            )

            printf '%s%s' "$nl_ui_separator" "$nl_ui_glyph_row"

            nl_ui_separator="0"
        done

        printf '\n'
        nl_ui_row=$((nl_ui_row + 1))
    done
)

# Convert a bitmap or ASCII text into a horizontal brand gradient.
#
# Arguments:
#   $1: rendering mode (bitmap or text)
#   $2: optional highlight position, from 0 to 100
#
# A negative highlight position disables the animated highlight.
nl_ui_gradient() {
    awk \
        -v mode="$1" \
        -v shine="${2:--1}" \
        -v color_mode="${NL_UI_COLOR_MODE:-plain}" \
        -v palette="$NL_UI_BRAND_1 $NL_UI_BRAND_2 $NL_UI_BRAND_3 $NL_UI_BRAND_4 $NL_UI_BRAND_5 $NL_UI_BRAND_6" '
        function hexdec(s,    i,n,c) {
            s = tolower(s)
            n = 0

            for (i = 1; i <= length(s); i++) {
                c = index("0123456789abcdef", substr(s,i,1)) - 1
                n = n * 16 + c
            }

            return n
        }

        BEGIN {
            esc = sprintf("%c", 27)
            count = split(palette, stops, " ")

            for (i = 1; i <= count; i++) {
                red[i]   = hexdec(substr(stops[i],2,2))
                green[i] = hexdec(substr(stops[i],4,2))
                blue[i]  = hexdec(substr(stops[i],6,2))
            }

            basic[1] = 93
            basic[2] = 33
            basic[3] = 91
            basic[4] = 95
            basic[5] = 35
            basic[6] = 34
        }

        {
            width = length($0)

            for (x = 1; x <= width; x++) {
                char = substr($0,x,1)

                if (mode == "bitmap") {
                    if (char == "0") {
                        printf " "
                        continue
                    }

                    char = "█"
                }

                if (color_mode == "plain") {
                    printf "%s", char
                    continue
                }

                position = (width > 1) ? (x-1)/(width-1) : 0
                scaled = position * (count-1)

                left = int(scaled) + 1
                right = (left < count) ? left+1 : left
                fraction = scaled - int(scaled)

                r = red[left] + (red[right]-red[left])*fraction
                g = green[left] + (green[right]-green[left])*fraction
                b = blue[left] + (blue[right]-blue[left])*fraction

                # A moving illumination band, reserved for animation.
                if (shine >= 0) {
                    distance = position*100-shine

                    if (distance < 0)
                        distance = -distance

                    light = (1-distance/15)*0.40

                    if (light > 0) {
                        r = r+(255-r)*light
                        g = g+(255-g)*light
                        b = b+(255-b)*light
                    }
                }

                if (color_mode == "truecolor") {
                    printf "%s[38;2;%d;%d;%dm%s",
                        esc, int(r+0.5), int(g+0.5),
                        int(b+0.5), char

                } else if (color_mode == "256") {
                    index256 = 16 \
                        + 36*int(r*5/255+0.5) \
                        + 6*int(g*5/255+0.5) \
                        + int(b*5/255+0.5)

                    printf "%s[38;5;%dm%s",
                        esc, index256, char

                } else {
                    nearest = int(scaled+0.5)+1

                    printf "%s[%dm%s",
                        esc, basic[nearest], char
                }
            }

            if (color_mode != "plain")
                printf "%s[0m", esc

            printf "\n"
        }
    '
}

# Render the static NovaLabs logo and slogan.
nl_ui_logo() (
    if [ "${NL_UI_PALETTE_READY:-false}" != true ] ||
       [ "${NL_UI_COLOR_MODE:-plain}" = plain ]
    then
        printf '\nNovaLabs\n%s\n\n' \
            "${NL_UI_SLOGAN:-DECLARATIVE INFRASTRUCTURE}"
        exit 0
    fi

    printf '\n'

    if [ "$NL_UI_COLUMNS" -ge 68 ]; then
        nl_ui_bitmap NOVALABS |
            nl_ui_gradient bitmap "${1:--1}"

        printf '\n'

        printf '%s\n' "$NL_UI_SLOGAN" |
            awk '{
                for (i = 1; i <= length($0); i++)
                    printf "%s%s", substr($0,i,1),
                        (i == length($0) ? "" : " ")

                printf "\n"
            }' |
            nl_ui_gradient text "${1:--1}"

    elif [ "$NL_UI_COLUMNS" -ge 36 ]; then
        nl_ui_bitmap NOVA |
            nl_ui_gradient bitmap "${1:--1}"

        printf '\n'

        nl_ui_bitmap LABS |
            nl_ui_gradient bitmap "${1:--1}"

        printf '\n'

        printf '%s\n' "$NL_UI_SLOGAN" |
            nl_ui_gradient text "${1:--1}"

    else
        printf '%s\n' NOVALABS |
            nl_ui_gradient text "${1:--1}"

        printf '%s\n' DECLARATIVE INFRASTRUCTURE |
            nl_ui_gradient text "${1:--1}"
    fi

    printf '\n'
)


# Render the full-width logo without leading or trailing blank lines.
# Used by the animation engine to maintain a fixed frame height.
nl_ui_brand_frame() {
    nl_ui_bitmap NOVALABS |
        nl_ui_gradient bitmap "${1:--1}"

    printf '\n'

    printf '%s\n' "$NL_UI_SLOGAN" |
        awk '{
            for (i = 1; i <= length($0); i++)
                printf "%s%s", substr($0,i,1),
                    (i == length($0) ? "" : " ")

            printf "\n"
        }' |
        nl_ui_gradient text "${1:--1}"
}

# Render the animated NovaLabs startup sequence.
#
# The animation:
#   - Uses a fixed seven-row display region.
#   - Leaves the terminal scrollback intact.
#   - Does not hide the cursor or change terminal modes.
#   - Does not register traps or launch background processes.
#   - Falls back to static branding when animation is unsuitable.
nl_ui_animate_logo() (
    if [ "${NL_UI_PALETTE_READY:-false}" != true ] ||
       [ "${NL_UI_ANIMATE:-false}" != true ] ||
       [ "${NL_UI_COLUMNS:-80}" -lt 68 ]
    then
        nl_ui_logo
        exit 0
    fi

    case "${NL_UI_COLOR_MODE:-plain}" in
        truecolor|256)
            ;;
        *)
            nl_ui_logo
            exit 0
            ;;
    esac

    # Fractional sleep is optional for the presentation layer.
    if ! sleep 0.01 2>/dev/null; then
        nl_ui_logo
        exit 0
    fi

    # Construct the bitmap only once for the complete animation.
    nl_ui_logo_bitmap=$(nl_ui_bitmap NOVALABS) ||
        exit 1

    nl_ui_logo_slogan=$(
        printf '%s\n' "$NL_UI_SLOGAN" |
            awk '{
                for (i = 1; i <= length($0); i++)
                    printf "%s%s", substr($0,i,1),
                        (i == length($0) ? "" : " ")

                printf "\n"
            }'
    )

    nl_ui_animation_frame() {
        printf '%s\n' "$nl_ui_logo_bitmap" |
            nl_ui_gradient bitmap "$1"

        printf '\n'

        printf '%s\n' "$nl_ui_logo_slogan" |
            nl_ui_gradient text "$1"
    }

    printf '\n'

    # Display the initial, unmodified gradient.
    nl_ui_animation_frame -1

    # Move the illumination band across the existing logo.
    nl_ui_position=0

    while [ "$nl_ui_position" -le 100 ]; do
        printf '\033[7A'

        nl_ui_animation_frame "$nl_ui_position"

        sleep 0.065

        nl_ui_position=$((nl_ui_position + 5))
    done

    # Restore the exact static brand palette.
    printf '\033[7A'
    nl_ui_animation_frame -1

    nl_ui_reset
    printf '\n'
)
