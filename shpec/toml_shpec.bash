IFS=$'\n'
set -o noglob

SHPEC_PARENT=$(dirname $BASH_SOURCE)/..
source $SHPEC_PARENT/shpec/shpec-helper.bash
source $SHPEC_PARENT/lib/toml.bash

STREAM_START=0

chars () {
  local -n Chars=$1
  shift

  Chars=$(printf $(printf '\\x%X' $*))
}

describe "toml.ParseTree single rule"
  alias setup='
    children=()
    TOML=( EXPRESSION )
    toml.NewNode root TOML
    toml.NewNode token EXPRESSION'

  it "sets the terminal as the only child of the root"
    toml.StreamAdd $token
    toml.ParseTree $root $STREAM_START
    toml.Children children $root
    assert equal "${children[*]}" 1
  ti

  it "sets the parent of the terminal"
    toml.StreamAdd $token
    toml.ParseTree $root $STREAM_START
    toml.Parent parent $token
    assert equal $parent 0
  ti

  it "has no children for the terminal"
    toml.StreamAdd $token
    toml.ParseTree $root $STREAM_START
    toml.Children children $token
    assert equal ${#children[*]} 0
  ti

  it "errors on a non-match"
    toml.NewNode other OTHER
    toml.StreamAdd $other
    ! toml.ParseTree $root $STREAM_START
    assert equal $? 0
  ti
end_describe

describe "toml.ParseTree two rules"
  alias setup='
    children=()
    TOML=( EXPRESSION )
    EXPRESSION=( NUMBER )
    toml.NewNode root TOML
    toml.NewNode token NUMBER'

  it "sets the intermediate as the only child of the root"
    toml.StreamAdd $token
    toml.ParseTree $root $STREAM_START
    toml.Children children $root
    assert equal "${children[*]}" 2
  ti

  it "sets the parent of the intermediate"
    toml.StreamAdd $token
    toml.ParseTree $root $STREAM_START
    toml.Parent parent 2
    assert equal $parent 0
  ti

  it "sets the terminal as the only child of the intermediate"
    toml.StreamAdd $token
    toml.ParseTree $root $STREAM_START
    toml.Children children 2
    assert equal "${children[*]}" 1
  ti

  it "sets the parent of the terminal"
    toml.StreamAdd $token
    toml.ParseTree $root $STREAM_START
    toml.Parent parent $token
    assert equal $parent 2
  ti

  it "errors on a non-match"
    toml.NewNode other OTHER
    toml.StreamAdd $other
    ! toml.ParseTree $root $STREAM_START
    assert equal $? 0
  ti
end_describe

describe "toml.ParseTree binary rule"
  it "has two children of the root"
    TOML=( "SIGN NUMBER" )
    toml.NewNode sign SIGN
    toml.NewNode number NUMBER
    toml.NewNode root TOML
    toml.StreamAdd $sign $number

    toml.ParseTree $root $STREAM_START
    toml.Children children $root

    expecteds=( 2 3 )
    assert equal "${children[*]}" "${expecteds[*]}"
  ti
end_describe

describe "toml.ParseTree ternary rule"
  it "has three children of the root"
    TOML=( "KEY SEP VAL" )
    toml.NewNode key KEY
    toml.NewNode sep SEP
    toml.NewNode val VAL
    toml.NewNode root TOML
    toml.StreamAdd $key $sep $val

    toml.ParseTree $root $STREAM_START
    toml.Children children $root

    expecteds=( 2 3 4 )
    assert equal "${children[*]}" "${expecteds[*]}"
  ti
end_describe

describe "toml.ParseTree simple alternatives"
  alias setup='
    TOML=( FIRST SECOND )
    toml.NewNode first FIRST
    toml.NewNode second SECOND
    toml.NewNode root TOML'

  it "chooses the first rule"
    toml.StreamAdd $first
    toml.ParseTree $root $STREAM_START
    toml.Children children $root

    assert equal "${children[*]}" 0
  ti

  it "chooses the second rule"
    toml.StreamAdd $second
    toml.ParseTree $root $STREAM_START
    toml.Children children $root

    assert equal "${children[*]}" 1
  ti
end_describe

describe "toml.ParseTree multipart alternatives"
  alias setup='
    TOML=( "FIRST SECOND" "FIRST THIRD" )
    toml.NewNode first FIRST
    toml.NewNode second SECOND
    toml.NewNode third THIRD
    toml.NewNode root TOML'

  it "backtracks on a partial match"
    toml.StreamAdd $first $third
    toml.ParseTree $root $STREAM_START
    toml.Children children $root

    expecteds=( 0 2 )
    assert equal "${children[*]}" "${expecteds[*]}"
  ti
end_describe

describe "toml.EvalTree simple key value"
  alias setup='
    toml.NewNode root       TOML
    toml.NewNode expr       EXPRESSION
    toml.NewNode keyval     KEYVAL
    toml.NewNode key        KEY
    toml.NewNode simpkey    SIMPLE_KEY
    toml.NewNode unqkey     UNQUOTED_KEY sample
    toml.NewNode kvsep      KEYVAL_SEP
    toml.NewNode val        VAL
    toml.NewNode int        INTEGER
    toml.NewNode dint       DEC_INT
    toml.NewNode udint      UNSIGNED_DEC_INT 1
    toml.AddChildren        $root $expr
    toml.AddChildren        $expr $keyval
    toml.AddChildren        $keyval $key $kvsep $val
    toml.AddChildren        $key $simpkey
    toml.AddChildren        $simpkey $unqkey
    toml.AddChildren        $val $int
    toml.AddChildren        $int $dint
    toml.AddChildren        $dint $udint'

    it "generates the variable"
      toml.EvalTree $root
      assert equal $sample 1
    ti
end_describe

# describe toml.parse
#   it "parses an empty string"
#     toml.parse ''
#     assert equal "${AST[0]}" TOML
#   ti
#
#   it "parses a key-value pair at the top-level"
#     toml.parse 'key = "value"'
#     assert equal "${AST[0]}" TOML
#   ti
#
#   it "parses the children at the top level"
#     toml.parse 'key = "value"'
#     assert equal "${CHILDREN0[0]}" 1
#   ti
#
#   it "parses a key-value pair at the expression level"
#     toml.parse 'key = "value"'
#     assert equal "${AST[1]}" EXPRESSION
#   ti
#
#   it "parses the children at the keyval level"
#     toml.parse 'key = "value"'
#     assert equal "${CHILDREN1[0]}" 2
#   ti
#
#   it "parses a key-value pair at the keyval level"
#     toml.parse 'key = "value"'
#     assert equal "${AST[2]}" KEYVAL
#   ti
#
#   it "parses the children at the key level"
#     toml.parse 'key = "value"'
#     expecteds=( 3 4 5 )
#     assert equal "${CHILDREN2[*]}" "${expecteds[*]}"
#   ti
#
#   it "parses a key at the key level"
#     toml.parse 'key = "value"'
#     assert equal "${AST[3]}" KEYVAL
#   ti
#
#   it "parses a keyval-sep at the key level"
#     toml.parse 'key = "value"'
#     assert equal "${AST[4]}" KEYVAL_SEP
#   ti
#
#   it "parses a val at the key level"
#     toml.parse 'key = "value"'
#     assert equal "${AST[5]}" VAL
#   ti
#
#   it "parses the children at the val level"
#     toml.parse 'key = "value"'
#     assert equal "${CHILDREN3[0]}" 6
#   ti
#
#   it "parses a val at the val level"
#     toml.parse 'key = "value"'
#     assert equal "${AST[6]}" STRING
#   ti
# end_describe

# describe NL
#   it "is newline"
#     assert equal $'\n' "$NL"
#   ti
# end_describe
#
# describe TAB
#   it "is tab"
#     assert equal $'\t' $TAB
#   ti
# end_describe
#
# describe BOOLEAN
#   it "contains false"
#     assert equal 0 ${BOOLEAN[false]}
#   ti
#
#   it "contains true"
#     assert equal 1 ${BOOLEAN[true]}
#   ti
# end_describe
#
# describe WS
#   it "matches space and tab"
#     [[ $' \t' =~ ^${EXPRS[WS]}{2}$ ]]
#     assert equal $? 0
#   ti
#
#   it "doesn't match anything else"
#     chars theRest {0..8} {10..31} {33..127}
#     ! [[ $theRest =~ ${EXPRS[WS]} ]]
#     assert equal $? 0
#   ti
# end_describe
#
# describe COMMENT
#   it "matches #"
#     [[ '#' =~ ^${EXPRS[COMMENT]}$ ]]
#     assert equal $? 0
#   ti
#
#   it "matches # with # after"
#     [[ '# #' =~ ^${EXPRS[COMMENT]}$ ]]
#     assert equal $? 0
#   ti
#
#   it "matches # with text after"
#     [[ '# a comment' =~ ^${EXPRS[COMMENT]}$ ]]
#     assert equal $? 0
#   ti
#
#   it "doesn't match a non-# string"
#     ! [[ 'a comment' =~ ^${EXPRS[COMMENT]}$ ]]
#     assert equal $? 0
#   ti
#
#   it "doesn't match a # mid-string"
#     ! [[ 'a # comment' =~ ^${EXPRS[COMMENT]}$ ]]
#     assert equal $? 0
#   ti
#
#   it "doesn't match a hash after"
#     ! [[ 'a comment #' =~ ^${EXPRS[COMMENT]}$ ]]
#     assert equal $? 0
#   ti
# end_describe
#
# describe BOOL
#   it "matches true"
#     [[ true =~ ^${EXPRS[BOOL]}$ ]]
#     assert equal 0 $?
#   ti
#
#   it "matches false"
#     [[ false =~ ^${EXPRS[BOOL]}$ ]]
#     assert equal 0 $?
#   ti
#
#   it "doesn't match a slug"
#     ! [[ slug =~ ^${EXPRS[BOOL]}$ ]]
#     assert equal 0 $?
#   ti
# end_describe
#
# describe DIGIT
#   it "matches 0-9"
#     [[ 1234567890 =~ ^$DIGIT{10}$ ]]
#     assert equal 0 $?
#   ti
#
#   it "doesn't match anything else"
#     chars theRest {0..47} {58..126}
#     ! [[ $theRest =~ $DIGIT ]]
#     assert equal $? 0
#   ti
# end_describe
#
# describe HEXDIG
#   it "matches the hex digits"
#     [[ 1234567890abcdefABCDEF =~ ^$HEXDIG{22}$ ]]
#     assert equal $? 0
#   ti
#
#   it "doesn't match anything else"
#     chars theRest {0..47} {58..64} {91..96} {123..126}
#     ! [[ $theRest =~ $HEXDIG ]]
#     assert equal $? 0
#   ti
# end_describe
#
# describe BASIC_UNESCAPED
#   it "matches all the characters except \\ and \""
#     chars everything 9 32 33 {35..91} {93..126}
#     [[ $everything =~ ^$BASIC_UNESCAPED{94}$ ]]
#     assert equal $? 0
#   ti
#
#   it "doesn't match \\"
#     ! [[ \\ =~ $BASIC_UNESCAPED ]]
#     assert equal $? 0
#   ti
#
#   it "doesn't match \""
#     ! [[ \" =~ $BASIC_UNESCAPED ]]
#     assert equal $? 0
#   ti
# end_describe
#
# describe ESCAPE_SEQ_CHAR
#   it "matches \"\\brnft"
#     [[ '\"brnft' =~ ^$ESCAPE_SEQ_CHAR{7}$ ]]
#     assert equal $? 0
#   ti
#
#   it "matches a 2-byte codepoint"
#     [[ uABCD =~ ^$ESCAPE_SEQ_CHAR$ ]]
#     assert equal $? 0
#   ti
#
#   it "matches a 4-byte codepoint"
#     [[ UABCDEFAB =~ ^$ESCAPE_SEQ_CHAR$ ]]
#     assert equal $? 0
#   ti
#
#   it "doesn't match anything else"
#     chars theRest {0..33} {35..91} {93..97} {99..101} {103..109} {111..113} 115 {117..126}
#     ! [[ $theRest =~ $ESCAPE_SEQ_CHAR ]]
#     assert equal $? 0
#   ti
#
#   it "doesn't match a 1.5-byte codepoint"
#     ! [[ uABC =~ ^$ESCAPE_SEQ_CHAR$ ]]
#     assert equal $? 0
#   ti
#
#   it "doesn't match a 2.5-byte codepoint"
#     ! [[ uABCDE =~ ^$ESCAPE_SEQ_CHAR$ ]]
#     assert equal $? 0
#   ti
#
#   it "doesn't match a 3.5-byte codepoint"
#     ! [[ UABCDEFA =~ ^$ESCAPE_SEQ_CHAR$ ]]
#     assert equal $? 0
#   ti
#
#   it "doesn't match a 4.5-byte codepoint"
#     ! [[ UABCDEFABA =~ ^$ESCAPE_SEQ_CHAR$ ]]
#     assert equal $? 0
#   ti
# end_describe
#
# describe ESCAPED
#   it "matches a backslashed escape"
#     [[ '\b' =~ ^$ESCAPED$ ]]
#     assert equal $? 0
#   ti
# end_describe
#
# describe BASIC_CHAR
#   it "matches a basic unescaped"
#     [[ a =~ ^$BASIC_CHAR$ ]]
#     assert equal $? 0
#   ti
#
#   it "matches an escaped"
#     [[ '\b' =~ ^$BASIC_CHAR$ ]]
#     assert equal $? 0
#   ti
# end_describe
#
# describe BASIC_STR
#   it "matches an empty string"
#     [[ '""' =~ ^${EXPRS[BASIC_STR]}$ ]]
#     assert equal $? 0
#   ti
#
#   it "matches a string"
#     [[ '"a"' =~ ^${EXPRS[BASIC_STR]}$ ]]
#     assert equal $? 0
#   ti
#
#   it "matches a string with multiple characters"
#     [[ '"abc"' =~ ^${EXPRS[BASIC_STR]}$ ]]
#     assert equal $? 0
#   ti
#
#   it "doesn't match a string without quotes"
#     ! [[ abc =~ ^${EXPRS[BASIC_STR]}$ ]]
#     assert equal $? 0
#   ti
# end_describe
#
# describe LITERAL_CHAR
#   it "matches all the characters except '"
#     chars everything 9 {32..38} {40..126}
#     [[ $everything =~ ^$LITERAL_CHAR{95}$ ]]
#     assert equal $? 0
#   ti
#
#   it "doesn't match '"
#     ! [[ "'" =~ ^$LITERAL_CHAR$ ]]
#     assert equal $? 0
#   ti
# end_describe
#
# describe LITERAL_STR
#   it "matches an empty string"
#     [[ "''" =~ ^$LITERAL_STR$ ]]
#     assert equal $? 0
#   ti
#
#   it "matches a string"
#     [[ "'a'" =~ ^$LITERAL_STR$ ]]
#     assert equal $? 0
#   ti
#
#   it "matches a string with multiple characters"
#     [[ "'abc'" =~ ^$LITERAL_STR$ ]]
#     assert equal $? 0
#   ti
#
#   it "doesn't match a string without quotes"
#     ! [[ abc =~ ^$LITERAL_STR$ ]]
#     assert equal $? 0
#   ti
# end_describe
#
# describe QUOTED_KEY
#   it "matches basic string"
#     [[ '"abc"' =~ ^$QUOTED_KEY$ ]]
#     assert equal $? 0
#   ti
#
#   it "matches a literal string"
#     [[ "'abc'" =~ ^$QUOTED_KEY$ ]]
#     assert equal $? 0
#   ti
#
#   it "doesn't match a string without quotes"
#     ! [[ abc =~ ^$QUOTED_KEY$ ]]
#     assert equal $? 0
#   ti
# end_describe
#
# describe UNQUOTED_KEY
#   it "matches at least one alphanumeric, hyphen and underscore"
#     chars key 45 {48..57} {65..90} 95 {97..122}
#     [[ $key =~ ^${EXPRS[UNQUOTED_KEY]}$ ]]
#     assert equal $? 0
#   ti
#
#   it "doesn't match everything else"
#     chars theRest {0..44} 46 47 {58..64} {91..94} 96 {123..126}
#     ! [[ $theRest =~ ${EXPRS[UNQUOTED_KEY]} ]]
#     assert equal $? 0
#   ti
#
#   it "doesn't match an empty string"
#     ! [[ '' =~ ^${EXPRS[UNQUOTED_KEY]}$ ]]
#     assert equal $? 0
#   ti
# end_describe
#
# describe toml.Match
#   it "matches space whitespace"
#     toml.Match token value ' a'
#     assert equal WS $token
#   ti
#
#   it "returns space whitespace"
#     toml.Match token value ' a'
#     assert equal $value ' '
#   ti
#
#   it "matches tab whitespace"
#     toml.Match token value $'\ta'
#     assert equal $token WS
#   ti
#
#   it "returns tab whitespace"
#     toml.Match token value $'\ta'
#     assert equal $value $TAB
#   ti
#
#   it "matches multiple whitespace"
#     toml.Match token value $' \ta'
#     assert equal $token WS
#   ti
#
#   it "returns multiple whitespace"
#     toml.Match token value $' \ta'
#     assert equal $value " $TAB"
#   ti
#
#   it "matches a comment"
#     toml.Match token value '#'
#     assert equal $token COMMENT
#   ti
#
#   it "returns a comment"
#     toml.Match token value '#'
#     assert equal $value '#'
#   ti
#
#   it "matches a comment with trailing text"
#     toml.Match token value '# a comment'
#     assert equal $token COMMENT
#   ti
#
#   it "returns a comment with trailing text"
#     toml.Match token value '# a comment'
#     assert equal $value '# a comment'
#   ti
#
#   it "matches a comment with a tab"
#     toml.Match token value $'#\ta comment'
#     assert equal $token COMMENT
#   ti
#
#   it "returns a comment with a tab"
#     toml.Match token value $'#\ta comment'
#     assert equal $value $'#\ta comment'
#   ti
#
#   it "matches an empty basic string"
#     toml.Match token value '""#'
#     assert equal $token BASIC_STR
#   ti
#
#   it "returns an empty basic string"
#     toml.Match token value '""#'
#     assert equal $value '""'
#   ti
#
#   it "matches a basic string with a value"
#     toml.Match token value '"a"#'
#     assert equal $token BASIC_STR
#   ti
#
#   it "returns a basic string with a value"
#     toml.Match token value '"a"#'
#     assert equal $value '"a"'
#   ti
#
#   it "matches a basic string with punctuation"
#     toml.Match token value '"["#'
#     assert equal $token BASIC_STR
#   ti
#
#   it "returns a basic string with punctuation"
#     toml.Match token value '"["#'
#     assert equal $value '"["'
#   ti
#
#   it "matches a basic string with characters"
#     toml.Match token value '"[a"#'
#     assert equal $token BASIC_STR
#   ti
#
#   it "returns a basic string with characters"
#     toml.Match token value '"[a"#'
#     assert equal $value '"[a"'
#   ti
#
#   it "matches a basic string with space"
#     toml.Match token value '" "#'
#     assert equal $token BASIC_STR
#   ti
#
#   it "returns a basic string with space"
#     toml.Match token value '" "#'
#     assert equal $value '" "'
#   ti
#
#   it "matches a basic string with tab"
#     toml.Match token value $'"\t"#'
#     assert equal $token BASIC_STR
#   ti
#
#   it "returns a basic string with tab"
#     toml.Match token value $'"\t"#'
#     assert equal $value $'"\t"'
#   ti
#
#   it "matches a basic string with an escape"
#     toml.Match token value '"\b"#'
#     assert equal $token BASIC_STR
#   ti
#
#   it "returns a basic string with an escape"
#     toml.Match token value '"\b"#'
#     assert equal $value '"\b"'
#   ti
#
#   it "matches a basic string with an escaped backslash"
#     toml.Match token value '"\\"#'
#     assert equal $token BASIC_STR
#   ti
#
#   it "matches a basic string with an escaped backslash"
#     toml.Match token value '"\\"#'
#     assert equal $value '"\\"'
#   ti
#
#   it "matches a basic string with uXXXX"
#     toml.Match token value '"\uABCD"#'
#     assert equal $token BASIC_STR
#   ti
#
#   it "returns a basic string with uXXXX"
#     toml.Match token value '"\uABCD"#'
#     assert equal $value '"\uABCD"'
#   ti
#
#   it "matches a basic string with UXXXXXXXX"
#     toml.Match token value '"\UABCDEFAB"#'
#     assert equal $token BASIC_STR
#   ti
#
#   it "returns a basic string with UXXXXXXXX"
#     toml.Match token value '"\UABCDEFAB"#'
#     assert equal $value '"\UABCDEFAB"'
#   ti
#
#   it "matches an empty literal string"
#     toml.Match token value "''#"
#     assert equal $token LITERAL_STR
#   ti
#
#   it "returns an empty literal string"
#     toml.Match token value "''#"
#     assert equal $value "''"
#   ti
#
#   it "matches a literal string with a value"
#     toml.Match token value "'a'#"
#     assert equal $token LITERAL_STR
#   ti
#
#   it "returns a literal string with a value"
#     toml.Match token value "'a'#"
#     assert equal $value "'a'"
#   ti
#
#   it "matches a literal string with punctuation"
#     toml.Match token value "'['#"
#     assert equal $token LITERAL_STR
#   ti
#
#   it "returns a literal string with punctuation"
#     toml.Match token value "'['#"
#     assert equal $value "'['"
#   ti
#
#   it "matches a literal string with characters"
#     toml.Match token value "'[a'#"
#     assert equal $token LITERAL_STR
#   ti
#
#   it "returns a literal string with characters"
#     toml.Match token value "'[a'#"
#     assert equal $value "'[a'"
#   ti
#
#   it "matches a literal string with space"
#     toml.Match token value "' '#"
#     assert equal $token LITERAL_STR
#   ti
#
#   it "returns a literal string with space"
#     toml.Match token value "' '#"
#     assert equal $value "' '"
#   ti
#
#   it "matches a literal string with tab"
#     toml.Match token value "'$TAB'#"
#     assert equal $token LITERAL_STR
#   ti
#
#   it "returns a literal string with tab"
#     toml.Match token value "'$TAB'#"
#     assert equal $value "'$TAB'"
#   ti
#
# #   it "matches an unsigned int"
# #     toml.Match token value '0#'
# #     assert equal INT $token
# #   ti
# #
# #   it "returns an unsigned int"
# #     toml.Match token value '0#'
# #     assert equal 0 $value
# #   ti
# #
# #   it "matches a double-digit unsigned int"
# #     toml.Match token value '10#'
# #     assert equal INT $token
# #   ti
# #
# #   it "returns a double-digit unsigned int"
# #     toml.Match token value '10#'
# #     assert equal 10 $value
# #   ti
# #
# #   it "matches an unsigned int with underscore"
# #     toml.Match token value '1_0#'
# #     assert equal INT $token
# #   ti
# #
# #   it "returns an unsigned int with underscore"
# #     toml.Match token value '1_0#'
# #     assert equal 10 $value
# #   ti
# #
# #   it "matches a signed positive int"
# #     toml.Match token value '+1#'
# #     assert equal INT $token
# #   ti
# #
# #   it "returns a signed positive int"
# #     toml.Match token value '+1#'
# #     assert equal 1 $value
# #   ti
# #
# #   it "matches a negative int"
# #     toml.Match token value '-1#'
# #     assert equal INT $token
# #   ti
# #
# #   it "returns a negative int"
# #     toml.Match token value '-1#'
# #     assert equal -1 $value
# #   ti
# #
# #   it "matches a hex int"
# #     toml.Match token value '0x0100#'
# #     assert equal INT $token
# #   ti
# #
# #   it "returns a hex int"
# #     toml.Match token value '0x0100#'
# #     assert equal 256 $value
# #   ti
# #
# #   it "matches a hex int with an underscore"
# #     toml.Match token value '0x01_00#'
# #     assert equal INT $token
# #   ti
# #
# #   it "returns a hex int with an underscore"
# #     toml.Match token value '0x01_00#'
# #     assert equal 256 $value
# #   ti
# #
# #   it "matches an octal int"
# #     toml.Match token value '0o10#'
# #     assert equal INT $token
# #   ti
# #
# #   it "returns an octal int"
# #     toml.Match token value '0o10#'
# #     assert equal 8 $value
# #   ti
# #
# #   it "matches an octal int with an underscore"
# #     toml.Match token value '0o001_000#'
# #     assert equal INT $token
# #   ti
# #
# #   it "returns an octal int with an underscore"
# #     toml.Match token value '0o001_000#'
# #     assert equal 512 $value
# #   ti
# #
# #   it "matches a binary int"
# #     toml.Match token value '0b10#'
# #     assert equal INT $token
# #   ti
# #
# #   it "returns a binary int"
# #     toml.Match token value '0b10#'
# #     assert equal 2 $value
# #   ti
# #
# #   it "matches a binary int with an underscore"
# #     toml.Match token value '0b1_0#'
# #     assert equal INT $token
# #   ti
# #
# #   it "returns a binary int with an underscore"
# #     toml.Match token value '0b1_0#'
# #     assert equal 2 $value
# #   ti
#
#   it "matches a boolean true"
#     toml.Match token value 'true#'
#     assert equal $token BOOL
#   ti
#
#   it "returns a boolean true"
#     toml.Match token value 'true#'
#     assert equal $value 1
#   ti
#
#   it "matches a boolean false"
#     toml.Match token value 'false#'
#     assert equal $token BOOL
#   ti
#
#   it "returns a boolean false"
#     toml.Match token value 'false#'
#     assert equal $value 0
#   ti
#
#   it "matches an unquoted key"
#     toml.Match token value key=
#     assert equal $token UNQUOTED_KEY
#   ti
#
#   it "returns an unquoted key"
#     toml.Match token value key=
#     assert equal $value key
#   ti
#
#   it "matches an underscored unquoted key"
#     toml.Match token value unquoted_key=
#     assert equal $token UNQUOTED_KEY
#   ti
#
#   it "returns an underscored unquoted key"
#     toml.Match token value unquoted_key=
#     assert equal $value unquoted_key
#   ti
#
#   it "matches a hyphenated unquoted key"
#     toml.Match token value unquoted-key=
#     assert equal $token UNQUOTED_KEY
#   ti
#
#   it "returns a hyphenated unquoted key"
#     toml.Match token value unquoted-key=
#     assert equal $value unquoted-key
#   ti
#
#   it "matches a numerical bare key"
#     toml.Match token value 1234=
#     assert equal $token UNQUOTED_KEY
#   ti
#
#   it "returns a numerical bare key"
#     toml.Match token value 1234=
#     assert equal $value 1234
#   ti
#
# #   it "matches a dotted quoted key"
# #     toml.Match token value '"127.0.0.1"'
# #     assert equal BASIC_STR $token
# #   ti
# #
# #   it "matches the quoted key value"
# #     toml.Match token value '"127.0.0.1"'
# #     assert equal '"127.0.0.1"' $value
# #   ti
# #
# #   it "matches a spaced quoted key"
# #     toml.Match token value '"character encoding"'
# #     assert equal BASIC_STR $token
# #   ti
# #
# #   it "matches a unicode quoted key"
# #     toml.Match token value '"??????"'
# #     assert equal BASIC_STR $token
# #   ti
# #
# #   it "matches a single-quoted key"
# #     toml.Match token value "'key2'"
# #     assert equal LITERAL_STR $token
# #   ti
# #
# #   it "matches a quotes key"
# #     toml.Match token value "'quoted \"value\"'"
# #     assert equal LITERAL_STR $token
# #   ti
# #
# #   it "matches a quotes key"
# #     toml.Match token value "'quoted \"value\"'"
# #     assert equal LITERAL_STR $token
# #   ti
# #
# #   it "matches a multiline basic start"
# #     toml.Match token value '"""'
# #     assert equal MULTI_BASIC_START $token
# #   ti
# end_describe
#
# describe toml.Lex
#   it "lexes the first token of a line"
#     toml.Lex key
#     assert equal ${TERMINALS[0]} UNQUOTED_KEY
#   ti
#
#   it "lexes the first value of a line"
#     toml.Lex key
#     assert equal ${VALUES[0]} key
#   ti
#
#   it "removes preceding whitespace"
#     toml.Lex ' key'
#     assert unequal "${TERMINALS[0]:-}" WS
#   ti
#
#   it "lexes two tokens with ws"
#     toml.Lex 'key ='
#     expecteds=( UNQUOTED_KEY KEYVAL_SEP )
#     assert equal "${TERMINALS[*]}" "${expecteds[*]}"
#   ti
# end_describe
