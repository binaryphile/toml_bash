IFS=$'\n'
set -o noglob

SHPEC_PARENT=$(dirname $BASH_SOURCE)/..
source $SHPEC_PARENT/shpec/shpec-helper.bash
source $SHPEC_PARENT/lib/toml.bash

chars () {
  local -n Chars=$1
  shift

  Chars=$(printf $(printf '\\x%X' $*))
}

describe NL
  it "is newline"
    assert equal $'\n' "$NL"
  ti
end_describe

describe TAB
  it "is tab"
    assert equal $'\t' $TAB
  ti
end_describe

describe BOOLEAN
  it "contains false"
    assert equal 0 ${BOOLEAN[false]}
  ti

  it "contains true"
    assert equal 1 ${BOOLEAN[true]}
  ti
end_describe

describe WS
  it "matches space and tab"
    [[ $' \t' =~ ^${EXPRS[WS]}{2}$ ]]
    assert equal $? 0
  ti

  it "doesn't match anything else"
    chars theRest {0..8} {10..31} {33..127}
    ! [[ $theRest =~ ${EXPRS[WS]} ]]
    assert equal $? 0
  ti
end_describe

describe COMMENT
  it "matches #"
    [[ '#' =~ ^${EXPRS[COMMENT]}$ ]]
    assert equal $? 0
  ti

  it "matches # with # after"
    [[ '# #' =~ ^${EXPRS[COMMENT]}$ ]]
    assert equal $? 0
  ti

  it "matches # with text after"
    [[ '# a comment' =~ ^${EXPRS[COMMENT]}$ ]]
    assert equal $? 0
  ti

  it "doesn't match a non-# string"
    ! [[ 'a comment' =~ ^${EXPRS[COMMENT]}$ ]]
    assert equal $? 0
  ti

  it "doesn't match a # mid-string"
    ! [[ 'a # comment' =~ ^${EXPRS[COMMENT]}$ ]]
    assert equal $? 0
  ti

  it "doesn't match a hash after"
    ! [[ 'a comment #' =~ ^${EXPRS[COMMENT]}$ ]]
    assert equal $? 0
  ti
end_describe

describe BOOL
  it "matches true"
    [[ true =~ ^${EXPRS[BOOL]}$ ]]
    assert equal 0 $?
  ti

  it "matches false"
    [[ false =~ ^${EXPRS[BOOL]}$ ]]
    assert equal 0 $?
  ti

  it "doesn't match a slug"
    ! [[ slug =~ ^${EXPRS[BOOL]}$ ]]
    assert equal 0 $?
  ti
end_describe

describe DIGIT
  it "matches 0-9"
    [[ 1234567890 =~ ^$DIGIT{10}$ ]]
    assert equal 0 $?
  ti

  it "doesn't match anything else"
    chars theRest {0..47} {58..126}
    ! [[ $theRest =~ $DIGIT ]]
    assert equal $? 0
  ti
end_describe

describe HEXDIG
  it "matches the hex digits"
    [[ 1234567890abcdefABCDEF =~ ^$HEXDIG{22}$ ]]
    assert equal $? 0
  ti

  it "doesn't match anything else"
    chars theRest {0..47} {58..64} {91..96} {123..126}
    ! [[ $theRest =~ $HEXDIG ]]
    assert equal $? 0
  ti
end_describe

describe BASIC_UNESCAPED
  it "matches all the characters except \\ and \""
    chars everything 9 32 33 {35..91} {93..126}
    [[ $everything =~ ^$BASIC_UNESCAPED{94}$ ]]
    assert equal $? 0
  ti

  it "doesn't match \\"
    ! [[ \\ =~ $BASIC_UNESCAPED ]]
    assert equal $? 0
  ti

  it "doesn't match \""
    ! [[ \" =~ $BASIC_UNESCAPED ]]
    assert equal $? 0
  ti
end_describe

describe ESCAPE_SEQ_CHAR
  it "matches \"\\brnft"
    [[ '\"brnft' =~ ^$ESCAPE_SEQ_CHAR{7}$ ]]
    assert equal $? 0
  ti

  it "matches a 2-byte codepoint"
    [[ uABCD =~ ^$ESCAPE_SEQ_CHAR$ ]]
    assert equal $? 0
  ti

  it "matches a 4-byte codepoint"
    [[ UABCDEFAB =~ ^$ESCAPE_SEQ_CHAR$ ]]
    assert equal $? 0
  ti

  it "doesn't match anything else"
    chars theRest {0..33} {35..91} {93..97} {99..101} {103..109} {111..113} 115 {117..126}
    ! [[ $theRest =~ $ESCAPE_SEQ_CHAR ]]
    assert equal $? 0
  ti

  it "doesn't match a 1.5-byte codepoint"
    ! [[ uABC =~ ^$ESCAPE_SEQ_CHAR$ ]]
    assert equal $? 0
  ti

  it "doesn't match a 2.5-byte codepoint"
    ! [[ uABCDE =~ ^$ESCAPE_SEQ_CHAR$ ]]
    assert equal $? 0
  ti

  it "doesn't match a 3.5-byte codepoint"
    ! [[ UABCDEFA =~ ^$ESCAPE_SEQ_CHAR$ ]]
    assert equal $? 0
  ti

  it "doesn't match a 4.5-byte codepoint"
    ! [[ UABCDEFABA =~ ^$ESCAPE_SEQ_CHAR$ ]]
    assert equal $? 0
  ti
end_describe

describe ESCAPED
  it "matches a backslashed escape"
    [[ '\b' =~ ^$ESCAPED$ ]]
    assert equal $? 0
  ti
end_describe

describe BASIC_CHAR
  it "matches a basic unescaped"
    [[ a =~ ^$BASIC_CHAR$ ]]
    assert equal $? 0
  ti

  it "matches an escaped"
    [[ '\b' =~ ^$BASIC_CHAR$ ]]
    assert equal $? 0
  ti
end_describe

describe BASIC_STR
  it "matches an empty string"
    [[ '""' =~ ^${EXPRS[BASIC_STR]}$ ]]
    assert equal $? 0
  ti

  it "matches a string"
    [[ '"a"' =~ ^${EXPRS[BASIC_STR]}$ ]]
    assert equal $? 0
  ti

  it "matches a string with multiple characters"
    [[ '"abc"' =~ ^${EXPRS[BASIC_STR]}$ ]]
    assert equal $? 0
  ti

  it "doesn't match a string without quotes"
    ! [[ abc =~ ^${EXPRS[BASIC_STR]}$ ]]
    assert equal $? 0
  ti
end_describe

describe LITERAL_CHAR
  it "matches all the characters except '"
    chars everything 9 {32..38} {40..126}
    [[ $everything =~ ^$LITERAL_CHAR{95}$ ]]
    assert equal $? 0
  ti

  it "doesn't match '"
    ! [[ "'" =~ ^$LITERAL_CHAR$ ]]
    assert equal $? 0
  ti
end_describe

describe LITERAL_STR
  it "matches an empty string"
    [[ "''" =~ ^$LITERAL_STR$ ]]
    assert equal $? 0
  ti

  it "matches a string"
    [[ "'a'" =~ ^$LITERAL_STR$ ]]
    assert equal $? 0
  ti

  it "matches a string with multiple characters"
    [[ "'abc'" =~ ^$LITERAL_STR$ ]]
    assert equal $? 0
  ti

  it "doesn't match a string without quotes"
    ! [[ abc =~ ^$LITERAL_STR$ ]]
    assert equal $? 0
  ti
end_describe

describe QUOTED_KEY
  it "matches basic string"
    [[ '"abc"' =~ ^$QUOTED_KEY$ ]]
    assert equal $? 0
  ti

  it "matches a literal string"
    [[ "'abc'" =~ ^$QUOTED_KEY$ ]]
    assert equal $? 0
  ti

  it "doesn't match a string without quotes"
    ! [[ abc =~ ^$QUOTED_KEY$ ]]
    assert equal $? 0
  ti
end_describe

describe UNQUOTED_KEY
  it "matches at least one alphanumeric, hyphen and underscore"
    chars key 45 {48..57} {65..90} 95 {97..122}
    [[ $key =~ ^${EXPRS[UNQUOTED_KEY]}$ ]]
    assert equal $? 0
  ti

  it "doesn't match everything else"
    chars theRest {0..44} 46 47 {58..64} {91..94} 96 {123..126}
    ! [[ $theRest =~ ${EXPRS[UNQUOTED_KEY]} ]]
    assert equal $? 0
  ti

  it "doesn't match an empty string"
    ! [[ '' =~ ^${EXPRS[UNQUOTED_KEY]}$ ]]
    assert equal $? 0
  ti
end_describe

describe toml.Match
  it "matches space whitespace"
    toml.Match token value ' a'
    assert equal WS $token
  ti

  it "returns space whitespace"
    toml.Match token value ' a'
    assert equal $value ' '
  ti

  it "matches tab whitespace"
    toml.Match token value $'\ta'
    assert equal $token WS
  ti

  it "returns tab whitespace"
    toml.Match token value $'\ta'
    assert equal $value $TAB
  ti

  it "matches multiple whitespace"
    toml.Match token value $' \ta'
    assert equal $token WS
  ti

  it "returns multiple whitespace"
    toml.Match token value $' \ta'
    assert equal $value " $TAB"
  ti

  it "matches a comment"
    toml.Match token value '#'
    assert equal $token COMMENT
  ti

  it "returns a comment"
    toml.Match token value '#'
    assert equal $value '#'
  ti

  it "matches a comment with trailing text"
    toml.Match token value '# a comment'
    assert equal $token COMMENT
  ti

  it "returns a comment with trailing text"
    toml.Match token value '# a comment'
    assert equal $value '# a comment'
  ti

  it "matches a comment with a tab"
    toml.Match token value $'#\ta comment'
    assert equal $token COMMENT
  ti

  it "returns a comment with a tab"
    toml.Match token value $'#\ta comment'
    assert equal $value $'#\ta comment'
  ti

  it "matches an empty basic string"
    toml.Match token value '""#'
    assert equal $token BASIC_STR
  ti

  it "returns an empty basic string"
    toml.Match token value '""#'
    assert equal $value '""'
  ti

  it "matches a basic string with a value"
    toml.Match token value '"a"#'
    assert equal $token BASIC_STR
  ti

  it "returns a basic string with a value"
    toml.Match token value '"a"#'
    assert equal $value '"a"'
  ti

  it "matches a basic string with punctuation"
    toml.Match token value '"["#'
    assert equal $token BASIC_STR
  ti

  it "returns a basic string with punctuation"
    toml.Match token value '"["#'
    assert equal $value '"["'
  ti

  it "matches a basic string with characters"
    toml.Match token value '"[a"#'
    assert equal $token BASIC_STR
  ti

  it "returns a basic string with characters"
    toml.Match token value '"[a"#'
    assert equal $value '"[a"'
  ti

  it "matches a basic string with space"
    toml.Match token value '" "#'
    assert equal $token BASIC_STR
  ti

  it "returns a basic string with space"
    toml.Match token value '" "#'
    assert equal $value '" "'
  ti

  it "matches a basic string with tab"
    toml.Match token value $'"\t"#'
    assert equal $token BASIC_STR
  ti

  it "returns a basic string with tab"
    toml.Match token value $'"\t"#'
    assert equal $value $'"\t"'
  ti

  it "matches a basic string with an escape"
    toml.Match token value '"\b"#'
    assert equal $token BASIC_STR
  ti

  it "returns a basic string with an escape"
    toml.Match token value '"\b"#'
    assert equal $value '"\b"'
  ti

  it "matches a basic string with an escaped backslash"
    toml.Match token value '"\\"#'
    assert equal $token BASIC_STR
  ti

  it "matches a basic string with an escaped backslash"
    toml.Match token value '"\\"#'
    assert equal $value '"\\"'
  ti

  it "matches a basic string with uXXXX"
    toml.Match token value '"\uABCD"#'
    assert equal $token BASIC_STR
  ti

  it "returns a basic string with uXXXX"
    toml.Match token value '"\uABCD"#'
    assert equal $value '"\uABCD"'
  ti

  it "matches a basic string with UXXXXXXXX"
    toml.Match token value '"\UABCDEFAB"#'
    assert equal $token BASIC_STR
  ti

  it "returns a basic string with UXXXXXXXX"
    toml.Match token value '"\UABCDEFAB"#'
    assert equal $value '"\UABCDEFAB"'
  ti

  it "matches an empty literal string"
    toml.Match token value "''#"
    assert equal $token LITERAL_STR
  ti

  it "returns an empty literal string"
    toml.Match token value "''#"
    assert equal $value "''"
  ti

  it "matches a literal string with a value"
    toml.Match token value "'a'#"
    assert equal $token LITERAL_STR
  ti

  it "returns a literal string with a value"
    toml.Match token value "'a'#"
    assert equal $value "'a'"
  ti

  it "matches a literal string with punctuation"
    toml.Match token value "'['#"
    assert equal $token LITERAL_STR
  ti

  it "returns a literal string with punctuation"
    toml.Match token value "'['#"
    assert equal $value "'['"
  ti

  it "matches a literal string with characters"
    toml.Match token value "'[a'#"
    assert equal $token LITERAL_STR
  ti

  it "returns a literal string with characters"
    toml.Match token value "'[a'#"
    assert equal $value "'[a'"
  ti

  it "matches a literal string with space"
    toml.Match token value "' '#"
    assert equal $token LITERAL_STR
  ti

  it "returns a literal string with space"
    toml.Match token value "' '#"
    assert equal $value "' '"
  ti

  it "matches a literal string with tab"
    toml.Match token value "'$TAB'#"
    assert equal $token LITERAL_STR
  ti

  it "returns a literal string with tab"
    toml.Match token value "'$TAB'#"
    assert equal $value "'$TAB'"
  ti

#   it "matches an unsigned int"
#     toml.Match token value '0#'
#     assert equal INT $token
#   ti
#
#   it "returns an unsigned int"
#     toml.Match token value '0#'
#     assert equal 0 $value
#   ti
#
#   it "matches a double-digit unsigned int"
#     toml.Match token value '10#'
#     assert equal INT $token
#   ti
#
#   it "returns a double-digit unsigned int"
#     toml.Match token value '10#'
#     assert equal 10 $value
#   ti
#
#   it "matches an unsigned int with underscore"
#     toml.Match token value '1_0#'
#     assert equal INT $token
#   ti
#
#   it "returns an unsigned int with underscore"
#     toml.Match token value '1_0#'
#     assert equal 10 $value
#   ti
#
#   it "matches a signed positive int"
#     toml.Match token value '+1#'
#     assert equal INT $token
#   ti
#
#   it "returns a signed positive int"
#     toml.Match token value '+1#'
#     assert equal 1 $value
#   ti
#
#   it "matches a negative int"
#     toml.Match token value '-1#'
#     assert equal INT $token
#   ti
#
#   it "returns a negative int"
#     toml.Match token value '-1#'
#     assert equal -1 $value
#   ti
#
#   it "matches a hex int"
#     toml.Match token value '0x0100#'
#     assert equal INT $token
#   ti
#
#   it "returns a hex int"
#     toml.Match token value '0x0100#'
#     assert equal 256 $value
#   ti
#
#   it "matches a hex int with an underscore"
#     toml.Match token value '0x01_00#'
#     assert equal INT $token
#   ti
#
#   it "returns a hex int with an underscore"
#     toml.Match token value '0x01_00#'
#     assert equal 256 $value
#   ti
#
#   it "matches an octal int"
#     toml.Match token value '0o10#'
#     assert equal INT $token
#   ti
#
#   it "returns an octal int"
#     toml.Match token value '0o10#'
#     assert equal 8 $value
#   ti
#
#   it "matches an octal int with an underscore"
#     toml.Match token value '0o001_000#'
#     assert equal INT $token
#   ti
#
#   it "returns an octal int with an underscore"
#     toml.Match token value '0o001_000#'
#     assert equal 512 $value
#   ti
#
#   it "matches a binary int"
#     toml.Match token value '0b10#'
#     assert equal INT $token
#   ti
#
#   it "returns a binary int"
#     toml.Match token value '0b10#'
#     assert equal 2 $value
#   ti
#
#   it "matches a binary int with an underscore"
#     toml.Match token value '0b1_0#'
#     assert equal INT $token
#   ti
#
#   it "returns a binary int with an underscore"
#     toml.Match token value '0b1_0#'
#     assert equal 2 $value
#   ti

  it "matches a boolean true"
    toml.Match token value 'true#'
    assert equal $token BOOL
  ti

  it "returns a boolean true"
    toml.Match token value 'true#'
    assert equal $value 1
  ti

  it "matches a boolean false"
    toml.Match token value 'false#'
    assert equal $token BOOL
  ti

  it "returns a boolean false"
    toml.Match token value 'false#'
    assert equal $value 0
  ti

  it "matches an unquoted key"
    toml.Match token value key=
    assert equal $token UNQUOTED_KEY
  ti

  it "returns an unquoted key"
    toml.Match token value key=
    assert equal $value key
  ti

  it "matches an underscored unquoted key"
    toml.Match token value unquoted_key=
    assert equal $token UNQUOTED_KEY
  ti

  it "returns an underscored unquoted key"
    toml.Match token value unquoted_key=
    assert equal $value unquoted_key
  ti

  it "matches a hyphenated unquoted key"
    toml.Match token value unquoted-key=
    assert equal $token UNQUOTED_KEY
  ti

  it "returns a hyphenated unquoted key"
    toml.Match token value unquoted-key=
    assert equal $value unquoted-key
  ti

  it "matches a numerical bare key"
    toml.Match token value 1234=
    assert equal $token UNQUOTED_KEY
  ti

  it "returns a numerical bare key"
    toml.Match token value 1234=
    assert equal $value 1234
  ti

#   it "matches a dotted quoted key"
#     toml.Match token value '"127.0.0.1"'
#     assert equal BASIC_STR $token
#   ti
#
#   it "matches the quoted key value"
#     toml.Match token value '"127.0.0.1"'
#     assert equal '"127.0.0.1"' $value
#   ti
#
#   it "matches a spaced quoted key"
#     toml.Match token value '"character encoding"'
#     assert equal BASIC_STR $token
#   ti
#
#   it "matches a unicode quoted key"
#     toml.Match token value '"ʎǝʞ"'
#     assert equal BASIC_STR $token
#   ti
#
#   it "matches a single-quoted key"
#     toml.Match token value "'key2'"
#     assert equal LITERAL_STR $token
#   ti
#
#   it "matches a quotes key"
#     toml.Match token value "'quoted \"value\"'"
#     assert equal LITERAL_STR $token
#   ti
#
#   it "matches a quotes key"
#     toml.Match token value "'quoted \"value\"'"
#     assert equal LITERAL_STR $token
#   ti
#
#   it "matches a multiline basic start"
#     toml.Match token value '"""'
#     assert equal MULTI_BASIC_START $token
#   ti
end_describe

describe toml.Lex
  it "calls lexes the first element of a line"
    toml.Lex key
    assert equal ${TOKENS[0]} UNQUOTED_KEY
  ti
end_describe

# describe toml.parse
#   alias setup='declare -A actual=()'
#
#   it "parses an empty string"
#     toml.parse actual ""
#     assert equal 0 ${#actual[*]}
#   ti
#
#   it "parses a key/string pair"
#     toml.parse actual ""
#     ! declare -p actual &>/dev/null
#     assert equal 0 $?
#   ti
# end_describe
