# Nerd Font detection, so `GAUGE_SYMBOL_SET=auto` can use real Octicon glyphs
# ( U+F407 and friends) where they'll render, and fall back to the geometric
# set (⊙ ◌ ⊕ ⊘) where they'd show up as tofu boxes.
#
# Detection is a best-effort look at installed fonts and terminal config. It
# runs ONCE and the answer is cached on disk — the prompt never pays for it.
# When in doubt it answers "no", because a wrong yes means unreadable boxes
# while a wrong no just means plainer symbols.

: ${GAUGE_FONT_CACHE:="${XDG_CACHE_HOME:-$HOME/.cache}/gauge/font"}

# Font family names that ship Nerd Font glyphs.
#
# Note the short forms: Homebrew's font casks register nameID 1 as e.g.
# "JetBrainsMono NFM" (NF = proportional, NFM = mono, NFP = propo), while the
# long "JetBrainsMono Nerd Font Mono" only exists as nameID 16. Terminals that
# match on nameID 1 need the short name, so both spellings must be recognised.
_gauge_nerdfont_pattern='(nerd[ _-]?font|nerdfont|[ _-]nf[mp]?([ _-]|$)|powerline|meslolgs|caskaydia|symbols nerd)'

_gauge_font_probe() {
  local -a hits
  local out

  # 1. Explicit opt-in / opt-out always wins.
  [[ -n ${GAUGE_HAS_NERDFONT-} ]] && { print -r -- "$GAUGE_HAS_NERDFONT"; return }

  # 2. Installed font files (strongest portable signal).
  if [[ $OSTYPE == darwin* ]]; then
    hits=( ${(f)"$(ls ~/Library/Fonts /Library/Fonts /System/Library/Fonts 2>/dev/null)"} )
    if (( ${#${(M)hits:#(#i)*nerd*}} || ${#${(M)hits:#(#i)*powerline*}} )); then
      print -r -- 1; return
    fi
  fi
  if (( $+commands[fc-list] )); then
    out=$(fc-list 2>/dev/null | tr 'A-Z' 'a-z')
    [[ $out =~ nerd || $out =~ powerline ]] && { print -r -- 1; return }
  fi

  # 3. Terminal font configuration, per emulator.
  local -a configs=(
    "${XDG_CONFIG_HOME:-$HOME/.config}/kitty/kitty.conf"
    "${XDG_CONFIG_HOME:-$HOME/.config}/alacritty/alacritty.toml"
    "${XDG_CONFIG_HOME:-$HOME/.config}/alacritty/alacritty.yml"
    "${XDG_CONFIG_HOME:-$HOME/.config}/wezterm/wezterm.lua"
    "${XDG_CONFIG_HOME:-$HOME/.config}/ghostty/config"
    "$HOME/.wezterm.lua"
    "$HOME/Library/Application Support/tabby/config.yaml"
  )
  local cfg
  for cfg in $configs; do
    [[ -r $cfg ]] || continue
    out=$(tr 'A-Z' 'a-z' < "$cfg" 2>/dev/null)
    [[ $out =~ $_gauge_nerdfont_pattern ]] && { print -r -- 1; return }
  done

  # 4. macOS terminals that keep their font in defaults(1).
  if [[ $OSTYPE == darwin* ]] && (( $+commands[defaults] )); then
    case $TERM_PROGRAM in
      iTerm.app)
        out=$(defaults read com.googlecode.iterm2 "New Bookmarks" 2>/dev/null | tr 'A-Z' 'a-z')
        [[ $out =~ $_gauge_nerdfont_pattern ]] && { print -r -- 1; return }
        ;;
      Apple_Terminal)
        out=$(defaults read com.apple.Terminal "Window Settings" 2>/dev/null | tr 'A-Z' 'a-z')
        [[ $out =~ $_gauge_nerdfont_pattern ]] && { print -r -- 1; return }
        ;;
    esac
  fi

  print -r -- 0
}

# Cached answer: 1 = Nerd Font glyphs are safe to use, 0 = fall back.
_gauge_has_nerdfont() {
  if [[ -z ${GAUGE_HAS_NERDFONT-} && -r $GAUGE_FONT_CACHE ]]; then
    GAUGE_HAS_NERDFONT=$(<"$GAUGE_FONT_CACHE")
  fi

  if [[ -z ${GAUGE_HAS_NERDFONT-} ]]; then
    GAUGE_HAS_NERDFONT=$(_gauge_font_probe)
    mkdir -p "${GAUGE_FONT_CACHE:h}" 2>/dev/null &&
      print -r -- "$GAUGE_HAS_NERDFONT" > "$GAUGE_FONT_CACHE" 2>/dev/null
  fi

  (( GAUGE_HAS_NERDFONT ))
}

# Re-run detection (call after installing a font or switching terminal fonts).
gauge-font-check() {
  local force=""
  [[ $1 == (--yes|--no) ]] && force=$1

  case $force in
    --yes|--no)
      GAUGE_HAS_NERDFONT=$([[ $force == --yes ]] && print 1 || print 0)
      mkdir -p "${GAUGE_FONT_CACHE:h}" 2>/dev/null &&
        print -r -- "$GAUGE_HAS_NERDFONT" > "$GAUGE_FONT_CACHE"
      ;;
    *)
      unset GAUGE_HAS_NERDFONT
      rm -f "$GAUGE_FONT_CACHE" 2>/dev/null
      ;;
  esac

  _gauge_has_nerdfont
  local answer=$GAUGE_HAS_NERDFONT

  print -P -- "Nerd Font detected: %B$( (( answer )) && print yes || print no )%b  (cached in $GAUGE_FONT_CACHE)"
  print -P -- "These should look like GitHub's PR icons, not boxes:"
  print -r -- "           "
  print -P -- ""
  print -P -- "If they ARE boxes: %F{cyan}gauge-font-check --no%f"
  print -P -- "If they render fine but detection said no: %F{cyan}gauge-font-check --yes%f"
  print -P -- "Then reload: %F{cyan}exec zsh%f"
}
