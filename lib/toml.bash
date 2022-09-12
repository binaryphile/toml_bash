shopt -s expand_aliases

Ret () {
  $3 $1 $4
}

@ReturnVars () {
  local arg

  for arg; do
    alias $arg="Ret $arg"
  done
}

# AddChildren adds a node to a parent node's array of children
toml.AddChildren () {
  local parent=$1; shift
  local -n children=CHILDREN$parent
  local child

  children+=( $* )
  for child; do
    toml.SetParent $child $parent
  done
}

# Children returns a copy of a node's array of child nodes
toml.Children () {
  local -n Result=$1
  local -n Children=CHILDREN$2

  Result=( ${Children[*]:-} )
}

@ReturnVars nodeType
toml.EvalTree () {
  local nodeType

  nodeType := toml.Type $1
  toml.$nodeType $1
}

@ReturnVars child
toml.EXPRESSION () {
  local child

  child := toml.Children $1
  toml.EvalTree $child
}

@ReturnVars child
toml.KEY () {
  local child

  child := toml.Children $1
  toml.EvalTree $child
}

@ReturnVars child
toml.KEYVAL () {
  local child

  child := toml.Children $1
  toml.EvalTree $child
}

# Lex takes a line and adds the next token to the stream
toml.Lex () {
  local line=$1
  local token value

  while [[ -n $line ]]; do
    toml.Match token value $line
    case $token in
      WS ) ;;
      * )
        TERMINALS[NEXT]=$token
        VALUES[NEXT]=$value
        ;;
    esac
    line=${line#$value}
    NEXT+=1
  done
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

toml.NextId () {
  local -n Id=$1

  Id=$NEXT
  NEXT+=1
}

toml.NewNode () {
  local -n Id=$1
  local Element=$2
  local Value=${3:-}

  toml.NextId $1

  TYPES[Id]=$Element
  PARENTS[Id]=''
  declare -ag CHILDREN$Id="()"
  VALUES[Id]=$Value
}

toml.Parent () {
  local -n Parent=$1

  Parent=${PARENTS[$2]}
}

# ParseTree parses the next token by applying the rule represented by the
# supplied node.
@ReturnVars newNode nodeType token tokenType
toml.ParseTree () {
  # node is the id of the current tree element, corresponding to a rule or
  # terminal
  local node=$1

  # pos is the position in the token stream
  local -i pos=$2

  local i newNode nodeType rule token tokenType type

  token     := toml.StreamFind $pos
  tokenType := toml.Type $token
  nodeType  := toml.Type $node

  # find the corresponding rules array
  local -n rules=$nodeType

  # go through each rule as necessary
  for rule in ${rules[*]}; do
    local -a items="( $rule )"

    # go through each token in a rule
    for (( i = 0; i < ${#items[*]}; i++ )); do
      [[ ${items[i]} == $tokenType ]] && {
        toml.AddChildren $node $token

        # end if rule is done
        (( i + 1 == ${#items[*]} )) && return

        # more tokens in rule
        pos+=1
        token     := toml.StreamFind $pos
        tokenType := toml.Type $token
        continue
      }

      toml.Terminal? ${items[i]} && continue

      # the rule doesn't apply, make a new child node for the rule's element and
      # recurse
      newNode := toml.NewNode ${items[i]}
      toml.AddChildren $node $newNode
      toml.ParseTree $newNode pos+i
      return
    done
  done
  return 1
}

toml.ReadHash () {
  local -n Result=$1
  local Indent Key Line

  while read -r Line; do
    [[ -z $Line ]] && continue

    # strip indent
    Indent=${Line%%[^[:space:]]*}
    Line=${Line#$Indent}

    # find key
    Key=${Line%%:*}
    Line=${Line#$Key:}

    # strip whitespace before value
    Indent=${Line%%[^[:space:]]*}
    Line=${Line#$Indent}

    # strip trailing whitespace and find value
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
  ! IFS=$NL read -rd '' $1;:
}

toml.Set? () {
  declare -p $1 &>/dev/null
}

toml.SetParent () {
  PARENTS[$1]=$2
}

@ReturnVars child
toml.SIMPLE_KEY () {
  local child

  child := toml.Children $1
  toml.EvalTree $child
}

toml.StreamDone? () {
  local pos=$1

  (( pos + 1 >= ${#STREAM[*]} ))
}

toml.StreamAdd () {
  STREAM+=( $* )
}

toml.StreamFind () {
  local -n Token=$1
  local Pos=$2

  Token=${STREAM[$Pos]}
}

toml.Terminal? () {
  ! declare -p $1 &>/dev/null
}

@ReturnVars child
toml.TOML () {
  local child

  child := toml.Children $1
  toml.EvalTree $child
}

toml.Type () {
  local -n Type=$1

  Type=${TYPES[$2]}
}

@ReturnVars child
toml.UNQUOTED_KEY () {
  local child

  child := toml.Children $1
  toml.EvalTree $child
}

toml.Value () {
  local -n Value=$1

  Value=${VALUES[$2]}
}

# globals
# NEXT is the next node id for assignment
declare -i NEXT=0

# TERMINALS are the tokens added to the stream
TERMINALS=()

# STREAM is the array of node ids of tokens from the lexer
STREAM=()

# VALUES is the array of values associated with tokens
VALUES=()

# constants
# NL is newline
NL=$'\n'

# TAB is tab
TAB=$'\t'

# EXPRS is the hash of expressions for the lexer to recognize tokens
declare -A EXPRS=()

# BOOLEAN is a hash of "true" and "false" to numerical values
declare -A BOOLEAN=()

toml.ReadHash BOOLEAN <<'END'
  true:   1
  false:  0
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

DOT_SEP=.

toml.ReadHash EXPRS <<END
  KEYVAL_SEP:   =
  DOT_SEP:      $DOT_SEP
  WS:           [[:blank:]]+
  COMMENT:      #$NONEOL*
  BOOL:         true|false
  BASIC_STR:    $BASIC_STR
  LITERAL_STR:  $LITERAL_STR
  UNQUOTED_KEY: $UNQUOTED_KEY
  DOTTED_KEY:   $SIMPLE_KEY($DOT_SEP$SIMPLE_KEY)+
END
