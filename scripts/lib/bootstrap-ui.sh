
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


# Read live terminal geometry.
# Prefer the terminal device rather than environment-derived dimensions.
# Output format: columns rows.
nl_ui_terminal_geometry() (
    command -v stty >/dev/null 2>&1 ||
        exit 1

    nl_ui_size=$(stty size <&2 2>/dev/null) ||
        exit 1

    # The expected stty output is: rows columns.
    set -f
    set -- $nl_ui_size

    [ "$#" -eq 2 ] ||
        exit 1

    nl_ui_rows="$1"
    nl_ui_cols="$2"

    case "$nl_ui_cols" in
        ''|*[!0-9]*|0|0*)
            exit 1
            ;;
    esac

    case "$nl_ui_rows" in
        ''|*[!0-9]*|0|0*)
            exit 1
            ;;
    esac

    [ "${#nl_ui_cols}" -le 5 ] ||
        exit 1

    [ "${#nl_ui_rows}" -le 5 ] ||
        exit 1

    printf '%s %s\n' "$nl_ui_cols" "$nl_ui_rows"
)

# Detect whether the active locale supports UTF-8 rendering.
nl_ui_utf8_supported() (
    command -v locale >/dev/null 2>&1 ||
        exit 1

    nl_ui_charmap=$(locale charmap 2>/dev/null) ||
        exit 1

    case "$nl_ui_charmap" in
        UTF-8|UTF8|utf-8|utf8)
            exit 0
            ;;
        *)
            exit 1
            ;;
    esac
)

# Determine whether the known terminal geometry can accommodate
# the full-width animated brand frame.
nl_ui_animation_geometry_ok() {
    [ "${NL_UI_GEOMETRY_KNOWN:-false}" = true ] &&
        [ "${NL_UI_COLUMNS:-0}" -ge 68 ] &&
        [ "${NL_UI_ROWS:-0}" -ge 10 ]
}

# Detect terminal capabilities without requiring external TUI utilities.
nl_ui_detect_terminal() {
    NL_UI_COLOR_MODE=plain
    NL_UI_ANIMATE=false

    NL_UI_COLUMNS=80
    NL_UI_ROWS=0
    NL_UI_GEOMETRY_KNOWN=false

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
                xterm*|screen*|tmux*|linux|vt100|vt220|ansi|rxvt*)
                    NL_UI_COLOR_MODE=ansi
                    ;;
                *)
                    return 0
                    ;;
            esac
            ;;
    esac

    if nl_ui_geometry=$(nl_ui_terminal_geometry); then
        NL_UI_COLUMNS=${nl_ui_geometry%% *}
        NL_UI_ROWS=${nl_ui_geometry#* }
        NL_UI_GEOMETRY_KNOWN=true
    fi

    if [ "${NL_UI_NO_ANIMATION:-false}" != true ] &&
       nl_ui_animation_geometry_ok
    then
        case "$NL_UI_COLOR_MODE" in
            truecolor|256)
                NL_UI_ANIMATE=true
                ;;
        esac
    fi

    return 0
}



# Establish deterministic presentation defaults.
# Never retain partially loaded or previously initialized palette data.
nl_ui_palette_defaults() {
    NL_UI_PALETTE_READY=false

    NL_UI_BRAND_1=""
    NL_UI_BRAND_2=""
    NL_UI_BRAND_3=""
    NL_UI_BRAND_4=""
    NL_UI_BRAND_5=""
    NL_UI_BRAND_6=""

    NL_UI_HEADER=""
    NL_UI_HIGHLIGHT=""
    NL_UI_SUCCESS=""
    NL_UI_ERROR=""
    NL_UI_WARNING=""
    NL_UI_FOREGROUND=""
    NL_UI_MUTED=""

    NL_UI_SLOGAN="DECLARATIVE INFRASTRUCTURE"

    return 0
}

# Initialize presentation state.
# Missing or invalid theme data must never block the bootstrap.
nl_ui_init() {
    nl_ui_palette_defaults
    nl_ui_detect_terminal

    if nl_ui_load_palette "$1"; then
        NL_UI_PALETTE_READY=true
    else
        nl_ui_palette_defaults

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

# Prepare the wide brand bitmap and spaced slogan.
# Call once before rendering one or more wide frames.
nl_ui_prepare_brand() {
    NL_UI_FRAME_BITMAP=$(nl_ui_bitmap NOVALABS) ||
        return 1

    NL_UI_FRAME_SLOGAN=$(
        printf '%s\n' "$NL_UI_SLOGAN" |
            awk '{
                for (i = 1; i <= length($0); i++)
                    printf "%s%s", substr($0,i,1),
                        (i == length($0) ? "" : " ")

                printf "\n"
            }'
    ) || return 1

    return 0
}

# Render the shared seven-line wide brand frame.
# Requires prepared bitmap and slogan data.
nl_ui_brand_frame() {
    printf '%s\n' "$NL_UI_FRAME_BITMAP" |
        nl_ui_gradient bitmap "${1:--1}" ||
        return 1

    printf '\n'

    printf '%s\n' "$NL_UI_FRAME_SLOGAN" |
        nl_ui_gradient text "${1:--1}"
}

# Render a slogan that wraps at the configured terminal width.
nl_ui_render_slogan() {
    printf '%s\n' "$NL_UI_SLOGAN" |
        awk -v width="${NL_UI_COLUMNS:-80}" '
            {
                line = ""

                for (i = 1; i <= NF; i++) {
                    word = $i

                    if (length(line) &&
                        length(line) + length(word) + 1 > width) {
                        print line
                        line = ""
                    }

                    while (length(word) > width) {
                        print substr(word, 1, width)
                        word = substr(word, width + 1)
                    }

                    if (length(word))
                        line = length(line) ? line " " word : word
                }

                if (length(line))
                    print line
            }
        '
}

# Render static NovaLabs branding.
nl_ui_logo() (
    printf '\n'

    if [ "${NL_UI_PALETTE_READY:-false}" != true ] ||
       [ "${NL_UI_COLOR_MODE:-plain}" = plain ]
    then
        printf 'NovaLabs\n'
        nl_ui_render_slogan
        printf '\n'
        exit 0
    fi

    if ! nl_ui_utf8_supported; then
        printf 'NovaLabs\n'
        nl_ui_render_slogan
        printf '\n'
        exit 0
    fi

    if [ "$NL_UI_COLUMNS" -ge 68 ] &&
       [ "$((${#NL_UI_SLOGAN} * 2 - 1))" -lt "$NL_UI_COLUMNS" ]
    then
        nl_ui_prepare_brand ||
            exit 1

        nl_ui_brand_frame "${1:--1}" ||
            exit 1

    elif [ "$NL_UI_COLUMNS" -ge 36 ]; then
        nl_ui_bitmap NOVA |
            nl_ui_gradient bitmap "${1:--1}"

        printf '\n'

        nl_ui_bitmap LABS |
            nl_ui_gradient bitmap "${1:--1}"

        printf '\n'

        nl_ui_render_slogan |
            nl_ui_gradient text "${1:--1}"

    else
        printf '%s\n' NOVALABS |
            nl_ui_gradient text "${1:--1}"

        nl_ui_render_slogan |
            nl_ui_gradient text "${1:--1}"
    fi

    printf '\n'
)

# Render animated branding without modifying terminal modes.
# Prepare all frames before drawing the first animation frame.
nl_ui_animate_logo() (
    if [ "${NL_UI_PALETTE_READY:-false}" != true ] ||
       [ "${NL_UI_ANIMATE:-false}" != true ] ||
       ! nl_ui_animation_geometry_ok ||
       ! nl_ui_utf8_supported
    then
        nl_ui_logo
        exit $?
    fi

    case "${NL_UI_COLOR_MODE:-plain}" in
        truecolor|256)
            ;;
        *)
            nl_ui_logo
            exit $?
            ;;
    esac

    if [ "$((${#NL_UI_SLOGAN} * 2 - 1))" -ge "$NL_UI_COLUMNS" ]; then
        nl_ui_logo
        exit $?
    fi

    if ! sleep 0.01 2>/dev/null; then
        nl_ui_logo
        exit $?
    fi

    nl_ui_prepare_brand ||
        exit 1

    nl_ui_static_frame=$(nl_ui_brand_frame -1) ||
        exit 1

    # Store rendered frames in memory, separated by an ASCII
    # record separator that cannot occur in validated frame data.
    nl_ui_frame_delimiter=$(printf '\036')
    nl_ui_frames=""
    nl_ui_position=0

    while [ "$nl_ui_position" -le 100 ]; do
        nl_ui_frame=$(nl_ui_brand_frame "$nl_ui_position") ||
            exit 1

        nl_ui_frames="${nl_ui_frames}${nl_ui_frame}${nl_ui_frame_delimiter}"
        nl_ui_position=$((nl_ui_position + 5))
    done

    nl_ui_frames="${nl_ui_frames}${nl_ui_static_frame}${nl_ui_frame_delimiter}"

    nl_ui_original_geometry="$NL_UI_COLUMNS $NL_UI_ROWS"

    # Verify geometry again after frame preparation.
    if [ "$(nl_ui_terminal_geometry || true)" != "$nl_ui_original_geometry" ]; then
        nl_ui_detect_terminal
        nl_ui_logo
        exit $?
    fi

    printf '\n%s\n' "$nl_ui_static_frame" ||
        exit 1

    while [ -n "$nl_ui_frames" ]; do
        # Never issue another cursor-up operation after detecting
        # a change in terminal geometry.
        if [ "$(nl_ui_terminal_geometry || true)" != "$nl_ui_original_geometry" ]; then
            nl_ui_reset
            printf '\n'
            exit 0
        fi

        nl_ui_frame=${nl_ui_frames%%"$nl_ui_frame_delimiter"*}
        nl_ui_frames=${nl_ui_frames#*"$nl_ui_frame_delimiter"}

        # Move to the beginning of the seven-line frame.
        printf '\033[7A\r%s\n' "$nl_ui_frame" ||
            exit 1

        if [ -n "$nl_ui_frames" ]; then
            sleep 0.065 ||
                exit 1
        fi
    done

    nl_ui_reset
    printf '\n'
)

# -------------------------------------------------------------------
# System identity and semantic presentation
# -------------------------------------------------------------------

# Print a section separator appropriate to the terminal width.
nl_ui_separator() (
    nl_ui_width=${NL_UI_COLUMNS:-80}

    if [ "$nl_ui_width" -gt 63 ]; then
        nl_ui_width=63
    fi

    if [ "$nl_ui_width" -gt 1 ]; then
        nl_ui_width=$((nl_ui_width - 1))
    fi

    nl_ui_color "${NL_UI_MUTED:-}" 90

    nl_ui_i=0

    while [ "$nl_ui_i" -lt "$nl_ui_width" ]; do
        printf '%s' '-'
        nl_ui_i=$((nl_ui_i + 1))
    done

    nl_ui_reset
    printf '\n'
)

# Print a purple section heading.
nl_ui_heading() {
    printf '\n'
    nl_ui_text "${NL_UI_HEADER:-}" 35 "$1"
    printf '\n\n'
}

# Print an aligned metadata field.
#
# Arguments:
#   $1: field label
#   $2: field value
#   $3: optional presentation role (normal or highlight)
nl_ui_field() (
    nl_ui_color "${NL_UI_MUTED:-}" 90
    printf '  %-16s ' "$1"
    nl_ui_reset

    case "${3:-normal}" in
        highlight)
            nl_ui_text "${NL_UI_HIGHLIGHT:-}" 95 "$2"
            ;;
        *)
            nl_ui_text "${NL_UI_FOREGROUND:-}" 37 "$2"
            ;;
    esac

    printf '\n'
)

# Print a semantic status indicator.
#
# Supported states:
#   success, failure, warning, running, skipped, info
#
# This function reports presentation state only. It does not
# execute commands or determine their success.
nl_ui_status() (
    case "$1" in
        success)
            nl_ui_symbol="✓"
            nl_ui_ascii="[OK]"
            nl_ui_status_color="${NL_UI_SUCCESS:-}"
            nl_ui_status_fallback=32
            ;;
        failure)
            nl_ui_symbol="✗"
            nl_ui_ascii="[FAIL]"
            nl_ui_status_color="${NL_UI_ERROR:-}"
            nl_ui_status_fallback=31
            ;;
        warning)
            nl_ui_symbol="!"
            nl_ui_ascii="[WARN]"
            nl_ui_status_color="${NL_UI_WARNING:-}"
            nl_ui_status_fallback=33
            ;;
        running)
            nl_ui_symbol="→"
            nl_ui_ascii="[RUN]"
            nl_ui_status_color="${NL_UI_HIGHLIGHT:-}"
            nl_ui_status_fallback=95
            ;;
        skipped)
            nl_ui_symbol="–"
            nl_ui_ascii="[SKIP]"
            nl_ui_status_color="${NL_UI_MUTED:-}"
            nl_ui_status_fallback=90
            ;;
        info)
            nl_ui_symbol="•"
            nl_ui_ascii="[INFO]"
            nl_ui_status_color="${NL_UI_HEADER:-}"
            nl_ui_status_fallback=35
            ;;
        *)
            return 1
            ;;
    esac

    printf '  '

    if [ "${NL_UI_COLOR_MODE:-plain}" = plain ]; then
        printf '%s' "$nl_ui_ascii"
    else
        nl_ui_text "$nl_ui_status_color" \
            "$nl_ui_status_fallback" "$nl_ui_symbol"
    fi

    printf ' %s\n' "$2"
)

# Normalize common CPU architecture identifiers for display.
nl_ui_architecture() {
    case "$1" in
        x86_64|amd64)
            printf '%s\n' AMD64
            ;;
        aarch64|arm64)
            printf '%s\n' ARM64
            ;;
        *)
            printf '%s\n' "$1"
            ;;
    esac
}

# Obtain the source repository revision without network access.
# Git is optional during early bootstrap.
nl_ui_revision() (
    if command -v git >/dev/null 2>&1; then
        if nl_ui_sha=$(git -C "$1" rev-parse \
            --short=7 HEAD 2>/dev/null)
        then
            printf '%s\n' "$nl_ui_sha"
            exit 0
        fi
    fi

    printf '%s\n' unknown
)

# Display system identity without initializing ChezMoi.
#
# Arguments:
#   $1: repository root
#   $2: distribution display name
#   $3: execution mode
#
# Profile information is intentionally omitted until authoritative
# enrollment data has been resolved and validated.
nl_ui_system_identity() (
    nl_ui_hostname=$(uname -n 2>/dev/null) ||
        nl_ui_hostname=unknown

    nl_ui_kernel=$(uname -s 2>/dev/null) ||
        nl_ui_kernel=unknown

    nl_ui_machine=$(uname -m 2>/dev/null) ||
        nl_ui_machine=unknown

    nl_ui_arch=$(nl_ui_architecture "$nl_ui_machine")
    nl_ui_release=$(nl_ui_revision "$1")

    case "$3" in
        preview) nl_ui_mode=PREVIEW ;;
        apply)   nl_ui_mode=APPLY ;;
        *)       nl_ui_mode="$3" ;;
    esac

    nl_ui_separator
    nl_ui_heading "SYSTEM IDENTITY"

    nl_ui_field "Hostname" "$nl_ui_hostname" highlight
    nl_ui_field "Distribution" "$2"
    nl_ui_field "Kernel" "$nl_ui_kernel"
    nl_ui_field "Architecture" "$nl_ui_arch"
    nl_ui_field "Release" "$nl_ui_release" highlight
    nl_ui_field "Mode" "$nl_ui_mode" highlight

    printf '\n'
)

# Display requested runtime versions.
# This does not claim that the runtimes are installed or verified.
nl_ui_runtime_identity() {
    nl_ui_separator
    nl_ui_heading "BOOTSTRAP RUNTIME"

    nl_ui_field "Mise target" "$1" highlight
    nl_ui_field "ChezMoi target" "$2" highlight

    printf '\n'
}


# -------------------------------------------------------------------
# Resolved host identity presentation
# -------------------------------------------------------------------

# Render a four-color host palette.
#
# Arguments:
#   $1-$4: authoritative host palette shades
#
# Invalid palette data is omitted rather than interrupting bootstrap.
nl_ui_host_palette() (
    for nl_ui_shade in "$1" "$2" "$3" "$4"; do
        nl_ui_valid_hex "$nl_ui_shade" || exit 0
    done

    nl_ui_color "${NL_UI_MUTED:-}" 90
    printf '  %-16s ' "Host palette"
    nl_ui_reset

    if [ "${NL_UI_COLOR_MODE:-plain}" = plain ]; then
        printf '%s %s %s %s\n' "$1" "$2" "$3" "$4"
        exit 0
    fi

    for nl_ui_shade in "$1" "$2" "$3" "$4"; do
        nl_ui_text "$nl_ui_shade" 35 "████"
    done

    printf '\n'
)

# Display resolved host profile information.
#
# Arguments:
#   $1: enrolled profile identifier
#   $2: profile display name
#   $3: theme family
#   $4: palette shade_1
#   $5: palette shade_2
#   $6: palette shade_3
#   $7: palette shade_4
#
# The caller is responsible for resolving and validating the profile.
# This function does not infer enrollment from the hostname.
nl_ui_host_identity() {
    nl_ui_separator
    nl_ui_heading "HOST PROFILE"

    nl_ui_field "Profile" "$1" highlight
    nl_ui_field "Identity" "$2"
    nl_ui_field "Theme family" "$3"

    if nl_ui_valid_hex "$7"; then
        nl_ui_color "${NL_UI_MUTED:-}" 90
        printf '  %-16s ' "Host accent"
        nl_ui_reset

        nl_ui_text "$7" 35 "$7"
        printf '\n'
    fi

    nl_ui_host_palette "$4" "$5" "$6" "$7"

    printf '\n'
}


# -------------------------------------------------------------------
# Bootstrap stage tracking and execution summaries
# -------------------------------------------------------------------

# Obtain a wall-clock timestamp in whole seconds.
# Timing failures must not prevent bootstrap execution.
nl_ui_now() (
    nl_ui_timestamp=$(date +%s 2>/dev/null) ||
        nl_ui_timestamp=0

    case "$nl_ui_timestamp" in
        ''|*[!0-9]*)
            nl_ui_timestamp=0
            ;;
    esac

    printf '%s\n' "$nl_ui_timestamp"
)

# Calculate elapsed seconds.
# Guard against unavailable timestamps and backward clock changes.
nl_ui_elapsed() {
    if [ "$1" -gt 0 ] &&
       [ "$2" -ge "$1" ]
    then
        printf '%s\n' "$(($2 - $1))"
    else
        printf '%s\n' 0
    fi
}

# Initialize execution tracking.
#
# $1: total number of planned stages.
nl_ui_tracker_init() {
    case "$1" in
        ''|*[!0-9]*|0|0*)
            return 1
            ;;
    esac

    NL_UI_STAGE_TOTAL="$1"
    NL_UI_STAGE_NUMBER=0
    NL_UI_STAGE_COMPLETED=0
    NL_UI_STAGE_SKIPPED=0
    NL_UI_STAGE_FAILED=0
    NL_UI_STAGE_ACTIVE=false
    NL_UI_STAGE_NAME=""
    NL_UI_STAGE_STARTED=0
    NL_UI_TRACKER_STARTED=$(nl_ui_now)

    return 0
}

# Begin a new execution stage.
#
# This function only reports that a stage has started.
# It does not execute or wrap the underlying command.
nl_ui_stage_begin() {
    [ "$NL_UI_STAGE_ACTIVE" = false ] ||
        return 1

    [ "$NL_UI_STAGE_NUMBER" -lt "$NL_UI_STAGE_TOTAL" ] ||
        return 1

    [ "$NL_UI_STAGE_FAILED" -eq 0 ] ||
        return 1

    NL_UI_STAGE_NUMBER=$((NL_UI_STAGE_NUMBER + 1))
    NL_UI_STAGE_NAME="$1"
    NL_UI_STAGE_ACTIVE=true
    NL_UI_STAGE_STARTED=$(nl_ui_now)

    printf '\n'

    nl_ui_color "${NL_UI_HEADER:-}" 35

    printf '[%02d/%02d] %s\n' \
        "$NL_UI_STAGE_NUMBER" \
        "$NL_UI_STAGE_TOTAL" \
        "$NL_UI_STAGE_NAME"

    nl_ui_reset

    return 0
}

# Print the elapsed time of the active stage.
nl_ui_stage_duration() (
    nl_ui_finished=$(nl_ui_now)

    nl_ui_duration=$(nl_ui_elapsed \
        "$NL_UI_STAGE_STARTED" \
        "$nl_ui_finished")

    nl_ui_text "${NL_UI_MUTED:-}" 90 \
        "    Elapsed: ${nl_ui_duration}s"

    printf '\n'
)

# Record a successfully completed stage.
nl_ui_stage_pass() {
    [ "$NL_UI_STAGE_ACTIVE" = true ] ||
        return 1

    NL_UI_STAGE_COMPLETED=$((NL_UI_STAGE_COMPLETED + 1))
    NL_UI_STAGE_ACTIVE=false

    nl_ui_status success "$1"
    nl_ui_stage_duration

    return 0
}

# Record an intentionally skipped stage.
nl_ui_stage_skip() {
    [ "$NL_UI_STAGE_ACTIVE" = true ] ||
        return 1

    NL_UI_STAGE_SKIPPED=$((NL_UI_STAGE_SKIPPED + 1))
    NL_UI_STAGE_ACTIVE=false

    nl_ui_status skipped "$1"
    nl_ui_stage_duration

    return 0
}

# Record a failed stage.
#
# Arguments:
#   $1: actual nonzero exit status
#   $2: failure description
#
# Reporting a failure must not replace the original command's
# exit status. The caller retains responsibility for exiting.
nl_ui_stage_fail() {
    [ "$NL_UI_STAGE_ACTIVE" = true ] ||
        return 1

    case "$1" in
        ''|*[!0-9]*|0|0*)
            return 1
            ;;
    esac

    NL_UI_STAGE_FAILED=$((NL_UI_STAGE_FAILED + 1))
    NL_UI_STAGE_ACTIVE=false

    nl_ui_status failure "$2 (exit status: $1)"
    nl_ui_stage_duration

    return 0
}

# Print the final execution summary.
#
# $1: actual bootstrap exit status.
#
# A successful summary requires every planned stage to have
# been explicitly completed or skipped.
nl_ui_summary() (
    nl_ui_exit_status="$1"

    nl_ui_processed=$((NL_UI_STAGE_COMPLETED \
        + NL_UI_STAGE_SKIPPED \
        + NL_UI_STAGE_FAILED))

    nl_ui_finished=$(nl_ui_now)

    nl_ui_total_duration=$(nl_ui_elapsed \
        "$NL_UI_TRACKER_STARTED" \
        "$nl_ui_finished")

    printf '\n'
    nl_ui_separator

    if [ "$nl_ui_exit_status" -ne 0 ] ||
       [ "$NL_UI_STAGE_FAILED" -ne 0 ]
    then
        nl_ui_heading "BOOTSTRAP FAILED"

        nl_ui_status failure \
            "Bootstrap did not complete successfully."

    elif [ "$nl_ui_processed" -eq "$NL_UI_STAGE_TOTAL" ] &&
         [ "$NL_UI_STAGE_ACTIVE" = false ]
    then
        nl_ui_heading "BOOTSTRAP COMPLETE"

        nl_ui_status success \
            "NovaLabs bootstrap completed successfully."

    else
        nl_ui_heading "BOOTSTRAP INCOMPLETE"

        nl_ui_status warning \
            "Not all planned stages were completed."
    fi

    printf '\n'

    nl_ui_field "Stages processed" \
        "$nl_ui_processed/$NL_UI_STAGE_TOTAL" highlight

    nl_ui_field "Completed" "$NL_UI_STAGE_COMPLETED"
    nl_ui_field "Skipped" "$NL_UI_STAGE_SKIPPED"
    nl_ui_field "Failed" "$NL_UI_STAGE_FAILED"

    nl_ui_field "Elapsed time" \
        "${nl_ui_total_duration}s" highlight

    nl_ui_field "Exit status" "$nl_ui_exit_status" highlight

    printf '\n'

    nl_ui_separator
    nl_ui_reset
)
