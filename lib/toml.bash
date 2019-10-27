toml.Lex () {
  local line=$1
  local token value

  toml.Match token value $line
  case $token in
    WS ) ;;
    * )
      TOKENS[0]=$token
      VALUES[0]=$value
      ;;
  esac
}

toml.Match () {
  local -n Token=$1 Value=$2
  local Line=$3
  local Candidate

  for Candidate in ${!EXPRS[*]}; do
    [[ $Line =~ ^(${EXPRS[$Candidate]}) ]] && {
      Token=$Candidate
      Value=${BASH_REMATCH[1]}
      case $Candidate in
        INT )
          Value=${Value//_}
          case $Value in
            0b* ) Value=$(( 2#${Value#0b} ));;
            *   ) Value=$(( ${Value//o}   ));;
          esac
          ;;
        BOOL ) Value=${BOOLEAN[$Value]};;
      esac
      return
    }
  done
}

toml.ReadHash () {
  local -n Result=$1
  local Indent Key Line

  while read -r Line; do
    [[ -z $Line ]] && continue
    Indent=${Line%%[^[:space:]]*}
    Line=${Line#$Indent}
    Key=${Line%% *}
    Line=${Line#$Key}
    Indent=${Line%%[^[:space:]]*}
    Line=${Line#$Indent}
    Indent=${Line##*[^[:space:]]}
    Result[$Key]=${Line%$Indent}
  done
}

toml.ReadHeredoc () {
  local -n Result=$1
  local Indent

  toml.Readlns $1
  Indent=${Result%%[^[:space:]]*}
  Result=${Result#$Indent}
  Result=${Result//$NL$Indent/$NL}
}

toml.Readlns () {
  IFS=$NL read -rd '' $1 ||:
}

# Globals
declare -i NEXT=0

# Constants
NL=$'\n'
TAB=$'\t'
declare -A EXPRS=()
declare -A BOOLEAN=()
TOKENS=()
VALUES=()

toml.ReadHash BOOLEAN <<'END'
  true  1
  false 0
END

toml.ReadHeredoc NONEOL <<END
  [[:print:]$TAB]
END

toml.ReadHeredoc DIGIT <<END
  [[:digit:]]
END

toml.ReadHeredoc HEXDIG <<END
  [[:xdigit:]]
END

toml.ReadHeredoc BASIC_UNESCAPED <<END
  ([^[:cntrl:]"\]|$TAB)
END

toml.ReadHeredoc ESCAPE_SEQ_CHAR <<END
  (["brnft\]|u$HEXDIG{4}|U$HEXDIG{8})
END

toml.ReadHeredoc ESCAPED <<END
  \\\\$ESCAPE_SEQ_CHAR
END

toml.ReadHeredoc BASIC_CHAR <<END
  ($BASIC_UNESCAPED|$ESCAPED)
END

toml.ReadHeredoc BASIC_STR <<END
  "$BASIC_CHAR*"
END

toml.ReadHeredoc LITERAL_CHAR <<END
  ([^[:cntrl:]']|$TAB)
END

toml.ReadHeredoc LITERAL_STR <<END
  '$LITERAL_CHAR*'
END

toml.ReadHeredoc QUOTED_KEY <<END
  ($BASIC_STR|$LITERAL_STR)
END

toml.ReadHeredoc UNQUOTED_KEY <<END
  [[:alnum:]_-]+
END

toml.ReadHeredoc SIMPLE_KEY <<END
  ($QUOTED_KEY|$UNQUOTED_KEY)
END

toml.ReadHash EXPRS <<END
  KEYVAL_SEP    =
  WS            [[:blank:]]+
  COMMENT       #$NONEOL*
  BOOL          true|false
  BASIC_STR     $BASIC_STR
  LITERAL_STR   $LITERAL_STR
  UNQUOTED_KEY  $UNQUOTED_KEY
END
