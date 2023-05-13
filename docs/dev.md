## State diagram

```mermaid
TopLevel --"whitespace:" --> TopLevel
TopLevel --"#: set after_comment_state = TopLevel" --> Comment
TopLevel --"double quote: set after_string_state = ValueBegin" --> BasicStringMaybeCharOrClosingQuoteOrLeadingQuote2
TopLevel --"single quote: set after_string_state = ValueBegin" --> LiteralStringMaybeCharOrClosingQuoteOrLeadingQuote2
TopLevel --"ALPHA | DIGIT | - | _: set after_key_state = ValueBegin" --> UnquotedKey
// TODO: tables

UnquotedKey --"unquoted-key-char:" --> UnquotedKey
UnquotedKey --"dot: emit UnquotedKey, emit DottedKeySeparator" --> SimpleKey
UnquotedKey --"keyval separator: if after_key_state is ValueBegin, then emit UnquotedKey and unset after_key_state. Otherwise error out." --> ValueBegin

BasicStringMaybeCharOrClosingQuoteOrLeadingQuote2 --"double quote:" --> BasicStringMaybeClosingQuoteOrLeadingQuote3
BasicStringMaybeClosingQuoteOrLeadingQuote3 --"double quote: set string_kind = multiline_basic" --> StringMaybeCharOrLeadingNewline
StringMaybeCharOrLeadingNewline --"\n: account for size diff" --> String
StringMaybeCharOrLeadingNewline --"\r: account for size diff" --> StringNewline
StringMaybeCharOrLeadingNewline --"ascii w/o control codes & special chars (0x20 | 0x09 | 0x21 | 0x23 - 0x5b | 0x5d - 0x9e):" --> String
StringMaybeCharOrLeadingNewline --"leading byte of 2-byte UTF-8 sequence (0xC2-0xDF): set after_utf8_state = String" --> StringUtf8Byte2Of2
StringMaybeCharOrLeadingNewline --"leading byte of 3-byte UTF-8 sequence (0xE0, 0xE1-0xEC, 0xED, 0xEE-0xEF): set after_utf8_state = String, set leading_utf8_byte" --> StringUtf8Byte2Of3
StringMaybeCharOrLeadingNewline --"leading byte of 4-byte UTF-8 sequence (0xF0, 0xF1-0xF3, 0xF4): set after_utf8_state = String, set leading_utf8_byte" --> StringUtf8Byte2Of4
BasicStringMaybeCharOrClosingQuoteOrLeadingQuote2 --"ascii w/o control codes & special chars (0x20 | 0x09 | 0x21 | 0x23 - 0x5b | 0x5d - 0x9e): set string_kind = basic" --> String
BasicStringMaybeCharOrClosingQuoteOrLeadingQuote2 --"leading byte of 2-byte UTF-8 sequence (0xC2-0xDF): set string_kind = basic, set after_utf8_state = String" --> StringUtf8Byte2Of2
BasicStringMaybeCharOrClosingQuoteOrLeadingQuote2 --"leading byte of 3-byte UTF-8 sequence (0xE0, 0xE1-0xEC, 0xED, 0xEE-0xEF): set string_kind = basic, set after_utf8_state = String, set leading_utf8_byte" --> StringUtf8Byte2Of3
BasicStringMaybeCharOrClosingQuoteOrLeadingQuote2 --"leading byte of 4-byte UTF-8 sequence (0xF0, 0xF1-0xF3, 0xF4): set string_kind = basic, set after_utf8_state = String, set leading_utf8_byte" --> StringUtf8Byte2Of4
String --"ascii w/o control codes & special chars (0x20 | 0x09 | 0x21 | 0x23 - 0x5b | 0x5d - 0x7e):" --> String
String --"\n and string_kind = multiline_basic:" --> String
String --"\r and string_kind = multiline_basic:" --> StringNewline
StringNewline --"\n:" --> String
String --"leading byte of 2-byte UTF-8 sequence (0xC2-0xDF): set after_utf8_state = String" --> StringUtf8Byte2Of2
String --"leading byte of 3-byte UTF-8 sequence (0xE0, 0xE1-0xEC, 0xED, 0xEE-0xEF): set after_utf8_state = String, set leading_utf8_byte" --> StringUtf8Byte2Of3
String --"leading byte of 4-byte UTF-8 sequence (0xF0, 0xF1-0xF3, 0xF4): set after_utf8_state = String, set leading_utf8_byte" --> StringUtf8Byte2Of4
String --"double quote and string_kind = basic: unset after_string_state; if after_string_state is ValueBegin, emit String w/ is_key=true. Else TODO" --> $after_string_state
String --"double quote and string_kind = multiline_basic:" --> BasicStringMaybeQuote2OrChar
BasicStringMaybeQuote2OrChar --"double quote:" BasicStringMaybeQuote3OrChar
BasicStringMaybeQuote2OrChar --"ascii w/o control codes & special chars PLUS \n (0x20 | 0x09 | 0x21 | 0x23 - 0x5b | 0x5d - 0x7e | \n:" --> String
BasicStringMaybeQuote2OrChar --"\r:" --> StringNewline
BasicStringMaybeQuote3OrChar --"double quote:" BasicStringMaybeQuote4OrEnd
-- char
BasicStringMaybeQuote4OrEnd --"double quote:" BasicStringMaybeQuote5OrEnd
BasicStringMaybeQuote4OrEnd --"(anything else): unset after_string_state; if after_string_state is ValueBegin, emit String w/ is_key=true. Else TODO. REPAT THE SAME CHAR" --> $after_string_state
BasicStringMaybeQuote5OrEnd --"double quote: unset after_string_state; if after_string_state is ValueBegin, emit String w/ is_key=true." --> $after_string_state
BasicStringMaybeQuote5OrEnd --"(anything else): unset after_string_state; if after_string_state is ValueBegin, emit String w/ is_key=true. Else TODO. REPAT THE SAME CHAR" --> $after_string_state

XXX: TODO
LiteralStringMaybeCharOrClosingQuoteOrLeadingQuote2 --"ascii w/o control codes and single quote & with horizontal tab (0x09 | 0x20-0x26 | 0x28-0x7e | 
; literal-char = %x09 / %x20-26 /           %x28-7E / non-ascii
; rrbasic-char = %x09 / %x20-21 / %x23-5B / %x5D-7E / non-ascii
;                tab    \n     \r               "                '                \
; uni-char     = %x09 / %x0A / %x0D / %x20-21 / %x22 / %x23-26 / %x27 / %x28-5B / %x5C / %x5D-7E / non-ascii
;   basic        Y      N      N      Y         N      Y         Y      Y         Y[1]    Y        Y
;   literal      Y      N      N      Y         Y      Y         N      Y         Y       Y        Y
;   ml-basic     Y      Y[2]   Y[3]   Y         Y[4]   Y         Y      Y         Y[5]    Y        Y
;   ml-literal   Y      Y[6]   Y[7]   Y         Y      Y         Y[8]   Y         Y       Y        Y
;
;   algo         Y      Y      Y      Y         Y      Y         Y      Y         Y       Y        Y
;
;   FOOTNOTES
;   [1] reverse solidus starts an escape sequence
;   [2] if \n is the first after leading triple quote, it must be trimmed. It also may be an escaped newline.
;   [3] \r must be part of CRLF, otherwise it's illegal. If it comes first after leading triple quote, it must be trimmed along with \n. It also may be an escaped newline.
;   [4] up to 2 double quotes allowed
;   [5] reverse solidus starts an escape sequence
;   [6] if \n is the first after leading triple quote, it must be trimmed. It also may be an escaped newline.
;   [7] \r must be part of CRLF, otherwise it's illegal. If it comes first after leading triple quote, it must be trimmed along with \n. It also may be an escaped newline.
;   [8] up to 2 single quotes allowed
;   so how it should work:
;   1) %x09 / %x20-21 / %x23-26 / %x28-5B / %x5D-7E / non-ascii: the same for all (either String->String or String->Utf8Byte2OfX)
;   2) %x5C: if literal, then just String->String, otherwise start escape sequence
;   3) %x0A, %x0D: if multiline, go to newline mode. Otherwise illegal
;   4) %x22 (double quote): if literal, just String->String, if basic, then close string, if ml basic, then go into quote state
;   5) %x27 (single quote): if basic, just String->String, if literal, then close string, if ml literal, then go into quote state

String --"reverse solidus: set after_escape_state = String" --> EscapeMaybeSpecialOr2HexOr4HexOr8HexOrWhitespace
EscapeMaybeSpecialOr2HexOr4HexOr8HexOrWhitespace --"double quote: unset after_escape_state" --> $after_escape_state
EscapeMaybeSpecialOr2HexOr4HexOr8HexOrWhitespace --"reverse solidus: unset after_escape_state" --> $after_escape_state
EscapeMaybeSpecialOr2HexOr4HexOr8HexOrWhitespace --"backspace: unset after_escape_state" --> $after_escape_state
EscapeMaybeSpecialOr2HexOr4HexOr8HexOrWhitespace --"e: unset after_escape_state" --> $after_escape_state
EscapeMaybeSpecialOr2HexOr4HexOr8HexOrWhitespace --"f: unset after_escape_state" --> $after_escape_state
EscapeMaybeSpecialOr2HexOr4HexOr8HexOrWhitespace --"n: unset after_escape_state" --> $after_escape_state
EscapeMaybeSpecialOr2HexOr4HexOr8HexOrWhitespace --"r: unset after_escape_state" --> $after_escape_state
EscapeMaybeSpecialOr2HexOr4HexOr8HexOrWhitespace --"t: unset after_escape_state" --> $after_escape_state
EscapeMaybeSpecialOr2HexOr4HexOr8HexOrWhitespace --"t: unset after_escape_state" --> $after_escape_state
EscapeMaybeSpecialOr2HexOr4HexOr8HexOrWhitespace --"x:" --> EscapeHexDigit1Of2
EscapeHexDigit1Of2 --"0-9,A-F:" --> EscapeHexDigit2Of2
EscapeHexDigit2Of2 --"0-9,A-F: unset after_escape_state" --> $after_escape_state
EscapeMaybeSpecialOr2HexOr4HexOr8HexOrWhitespace --"u:" --> EscapeHexDigit1Of4
EscapeHexDigit1Of4 --"0-9,A-F: set hex_digit_5" --> EscapeHexDigit2Of4
EscapeHexDigit2Of4 --"0-7 and hex_digit_5 is D:" --> EscapeHexDigit3Of4
EscapeHexDigit2Of4 --"0-9,A-F and hex_digit_5 is not D:" --> EscapeHexDigit3Of4
EscapeHexDigit3Of4 --"0-9,A-F:" --> EscapeHexDigit4Of4
EscapeHexDigit4Of4 --"0-9,A-F: unset after_escape_state, unset hex_digit_{3,4,5}" --> $after_escape_state
EscapeMaybeSpecialOr2HexOr4HexOr8HexOrWhitespace --"U:" --> EscapeHexDigit1Of8
EscapeHexDigit1Of8 --"0:" --> EscapeHexDigit2Of8
EscapeHexDigit2Of8 --"0:" --> EscapeHexDigit3Of8
EscapeHexDigit3Of8 --"0,1: set hex_digit_3" --> EscapeHexDigit4Of8
EscapeHexDigit4Of8 --"0 and hex_digit_3 is 1: set hex_digit_4" --> EscapeHexDigit5Of8
EscapeHexDigit4Of8 --"0-9,A-F and hex_digit_3 is not 1: set hex_digit_4" --> EscapeHexDigit5Of8
EscapeHexDigit5Of8 --"0-9,A-F: set hex_digit_5" --> EscapeHexDigit6Of8
EscapeHexDigit6Of8 --"0-7 and hex_digit_5 is D and hex_digit_3 is 0 and hex_digit_4 is 0:" --> EscapeHexDigit7Of8
EscapeHexDigit6Of8 --"0-9,A-F and not (hex_digit_5 is D and hex_digit_3 is 0 and hex_digit_4 is 0):" --> EscapeHexDigit7Of8
EscapeHexDigit7Of8 --"0-9,A-F:" --> EscapeHexDigit8Of8
EscapeHexDigit8Of8 --"0-9,A-F: unset after_escape_state, unset hex_difit_{3,4,5}" --> $after_escape_state
EscapeMaybeSpecialOr2HexOr4HexOr8HexOrWhitespace --"whitespace (0x20 or 0x09) and string_kind = multiline_basic:" --> MultilineEscapedNewlineBegin
MultilineEscapedNewlineBegin --"whitespace (0x20 or 0x09):" --> MultilineEscapedNewlineBegin
MultilineEscapedNewlineBegin --"newline (0x0a):" --> MultilineEscapedNewlineEnd
MultilineEscapedNewlineBegin --"carriage return (0x0d):" --> MultilineEscapedNewlineBeginNewline
MultilineEscapedNewlineBegin --"newline (0x0a):" --> MultilineEscapedNewlineEnd
MultilineEscapedNewlineEnd --"whitespace (0x20 or 0x09):" --> MultilineEscapedNewlineEnd
MultilineEscapedNewlineEnd --"newline (0x0a):" --> MultilineEscapedNewlineEnd
MultilineEscapedNewlineEnd --"carriage return (0x0d):" --> MultilineEscapedNewlineEndNewline
MultilineEscapedNewlineEndNewline --"newline (0x0a):" --> MultilineEscapedNewlineEnd
MultilineEscapedNewlineEnd --"(anything else): unset after_escape_state, REPEAT THE SAME CHAR" --> $after_escape_state
StringUtf8Byte2Of2 --"2d byte of 2-byte UTF-8 sequence (0x80-0xBF): unset after_utf8_state" --> $after_utf8_state
StringUtf8Byte2Of3 --"2d byte of 3-byte UTF-8 sequence (various depending on the translation table & the first byte):" --> StringUtf8Byte3Of3
StringUtf8Byte3Of3 --"3d byte of 3-byte UTF-8 sequence (0x80-0xBF): unset after_utf8_state, unset leading_utf8_byte" --> $after_utf8_state
StringUtf8Byte2Of4 --"2d byte of 4-byte UTF-8 sequence (various depending on the translation table & the first byte):" --> StringUtf8Byte3Of4
StringUtf8Byte3Of4 --"3d byte of 4-byte UTF-8 sequence (0x80-0xBF):" --> StringUtf8Byte4Of4
StringUtf8Byte4Of4 --"4th byte of 4-byte UTF-8 sequence (0x80-0xBF): unset after_utf8_state, unset leading_utf8_byte" --> $after_utf8_state

Comment --"\n:"--> $after_comment_state
Comment --"allowed-comment-char:"--> Comment
```

multiline basic string. Maybe I must have a `string_kind` variable. I reuse all the states for String. I introduce additional states 1) for recognizing the three leading quotes 2) for recognizing the three to five trailing quotes 3) for recognizing the OPTIONAL leading newline (this is necessary to count string escapes correctly) 4) for recognizing escaped newline. I think an OK strategy is to have the same set of states and just use the "widest" switch & switch on string kind in the portions of the switch that depend on it.

```
escaped = escape escape-seq-char
escape-seq-char =  %x22         ; "    quotation mark  U+0022
escape-seq-char =/ %x5C         ; \    reverse solidus U+005C
escape-seq-char =/ %x62         ; b    backspace       U+0008
escape-seq-char =/ %x65         ; e    escape          U+001B
escape-seq-char =/ %x66         ; f    form feed       U+000C
escape-seq-char =/ %x6E         ; n    line feed       U+000A
escape-seq-char =/ %x72         ; r    carriage return U+000D
escape-seq-char =/ %x74         ; t    tab             U+0009
escape-seq-char =/ %x78 2HEXDIG ; xHH                  U+00HH
escape-seq-char =/ %x75 4HEXDIG ; uHHHH                U+HHHH
escape-seq-char =/ %x55 8HEXDIG ; UHHHHHHHH            U+HHHHHHHH
```

```
point				first		second		third		fourth
0000 .. 007F		00 .. 7F
0080 .. 07FF		C2 .. DF	80 .. BF
0800 .. 0FFF		E0			A0 .. BF	80 .. BF
1000 .. CFFF		E1 .. EC	80 .. BF	80 .. BF
D000 .. D7FF		ED			80 .. 9F	80 .. BF
E000 .. FFFF		EE .. EF	80 .. BF	80 .. BF
10000 .. 3FFFF		F0			90 .. BF	80 .. BF	80 .. BF
40000 .. FFFFF		F1 .. F3	80 .. BF	80 .. BF	80 .. BF
100000 .. 10FFFF	F4			80 .. 8F	80 .. BF	80 .. BF
```

TODO: Do I really need `after_key_state`? Are keys found on context other than keyval? Basically yes, it can occur inside array table header.

```scratch
basic-string = quotation-mark *basic-char quotation-mark

quotation-mark = %x22            ; "

basic-char = basic-unescaped / escaped
basic-unescaped = wschar / %x21 / %x23-5B / %x5D-7E / non-ascii
wschar =  %x20  ; Space
wschar =/ %x09  ; Horizontal tab
non-ascii = %x80-D7FF / %xE000-10FFFF       ;; NB: these are Unicode codepoints rather than bytes

escaped = escape escape-seq-char
escape-seq-char =  %x22         ; "    quotation mark  U+0022
escape-seq-char =/ %x5C         ; \    reverse solidus U+005C
escape-seq-char =/ %x62         ; b    backspace       U+0008
escape-seq-char =/ %x65         ; e    escape          U+001B
escape-seq-char =/ %x66         ; f    form feed       U+000C
escape-seq-char =/ %x6E         ; n    line feed       U+000A
escape-seq-char =/ %x72         ; r    carriage return U+000D
escape-seq-char =/ %x74         ; t    tab             U+0009
escape-seq-char =/ %x78 2HEXDIG ; xHH                  U+00HH
escape-seq-char =/ %x75 4HEXDIG ; uHHHH                U+HHHH
escape-seq-char =/ %x55 8HEXDIG ; UHHHHHHHH            U+HHHHHHHH

comment = comment-start-symbol *allowed-comment-char
comment-start-symbol = %x23 ; #
allowed-comment-char = %x01-09 / %x0E-7F / non-ascii
non-ascii = %x80-D7FF / %xE000-10FFFF

;; OLD definition, I'll follow that for now.
unquoted-key = 1*( ALPHA / DIGIT / %x2D / %x5F ) ; A-Z / a-z / 0-9 / - / _
```
