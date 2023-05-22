## State diagram

```mermaid
%% I introduce a container stack.
%% stack is empty => after value state is TopLevel
%% stack top is Table => after value state is Table
%% stack top is InlineTable => after value state is InlineTableKeyvalEnd
%% stack top is Array => after value state is Array
%% 
%% when do we push to the stack?
%% 3) when we encounter an inline table open symbol
%% 4) when we encounter an array open symbol
%%
%% when do we pop from the stack?
%% 2) when we are in an array & we encounter array close symbol
%% 3) when we are in an inline table & we encounter inline table close symbol
%%
%% when do we consult the stack?
%% 1) when a value ends:
%%      if stack is empty, we go to TopLevelExpressionEnd
%%      if stack top is InlineTable, we go to InlineTableValueEnd
%%      if stack top is Array, we go to ArrayValueEnd
%% ^ this is the stackState() function.
%%
%% everything which can be inside TopLevel can also be inside Table (i.e. we expect a KV pair or next table/array table)
%% everything which can be inside TopLevel can also be inside ArrayTable (i.e. we expect a KV pair or next table/array table)
%% the same for InlineTable, BUT 1) we don't expect next table/array table 2) comma-separated KV pairs
%% inside Arrays, only values are permitted
%% so yeah, I need to keep a stack. YAY
%%
%% Where might a value occur?
%% - in keyval
%%      - in top level
%%      - in inline table
%%      - in standard table
%%      - in inline table
%% - in an array
%% What may come after value?
%% 1. top level if this was a keyval. And top level after value is indistinguishable from top level before any value (the same tokens might occur)
%% 2. array if this was a value inside array. In this case we may expect a) comma b) array close symbol
%% 3. inline table if this was a value inside inline table. In this case we may expect a) comma b) inline table close symbol
%% my strategy:
%% 1. standard tables, array tables occur on top level. No nesting here, I just emit TableOpen/ArrayTableOpen whenever I see a header. After that I'm on TopLevel, I can emit Keys & Values. I don't attempt to validate anything here.
%% 2. inline tables & arrays have nesting. I.e. inline tables & arrays can be inside inline table and inside array. Ergo I need a stack that has InlineTable/Array inside of it.

TopLevel --"whitespace:" --> TopLevel
TopLevel --"#: set after_comment_state = TopLevelExpressionEnd" --> Comment
TopLevelExpressionEnd --"whitespace:" --> TopLevelExpressionEnd
TopLevelExpressionEnd --"#: set after_comment_state = TopLevelExpressionEnd" --> Comment
TopLevelExpressionEnd --"0x0A (\n):" --> TopLevel
TopLevelExpressionEnd --"0x0D (CR): set after_newline_state = TopLevel" --> Newline
Comment --"allowed-comment-char:"--> Comment
Comment --"(anything else): unset after_comment_state. REPEAT THE SAME CHAR" --> $after_comment_state
TopLevel --"ALPHA | DIGIT | - | _: set after_key_state = KeyMaybeDotOrKeyvalSeparator" --> UnquotedKey
UnquotedKey --"ALPHA | DIGIT | - | _:" --> UnquotedKey
UnquotedKey --"whitespace: emit Key" --> $after_key_state
KeyMaybeDotOrKeyvalSeparator --"whitespace:" --> KeyMaybeDotOrKeyvalSeparator
KeyMaybeDotOrKeyvalSeparator --"0x2e (.): emit DottedKeySeparator" --> DottedKeyPart
KeyMaybeDotOrKeyvalSeparator --"0x3d (=): emit KeyvalSeparator" --> ValueBegin
TopLevel --"0x22 (double quote): set after_key_state = KeyvalSeparator, after_string_state = KeyMaybeDotOrKeyvalSeparator, string_kind = basic, string_is_content_start = true" --> String
TopLevel --"0x27 (single quote): set after_key_state = KeyvalSeparator, after_string_state = KeyMaybeDotOrKeyvalSeparator, string_kind = literal, string_is_content_start = true" --> String

%% val = string / boolean / array / inline-table / date-time / float / integer
%%       Y        Y         Y       Y

%% value: boolean true
ValueBegin --"0x74 (t):" --> TrueLiteral2
TrueLiteral2 --"0x72 (r):" --> TrueLiteral3
TrueLiteral3 --"0x75 (u):" --> TrueLiteral4
TrueLiteral4 --"0x65 (e): emit True" --> stackState()

%% value: boolean false
ValueBegin --"0x66 (f):" --> FalseLiteral2
FalseLiteral2 --"0x61 (a):" --> FalseLiteral3
FalseLiteral3 --"0x6C (l):" --> FalseLiteral4
FalseLiteral4 --"0x73 (s):" --> FalseLiteral5
FalseLiteral5 --"0x65 (e): emit False" --> stackState()

%% value: string
ValueBegin --"0x22 (double quote): set after_string_state = stackState()" --> BasicStringMaybeCharOrClosingQuoteOrLeadingQuote2
ValueBegin --"0x27 (single quote): set after_string_state = stackState()" --> LiteralStringMaybeCharOrClosingQuoteOrLeadingQuote2

%% value: array
ValueBegin --"0x5B ([): push Array to stack, emit ArrayOpen" --> ValueBegin
ValueBegin --"0x5D (]) and Array is top of stack: pop stack, emit ArrayClose" --> stackState()
ValueBegin --"0x23 (#) and Array is top of stack: set after_comment_state = ValueBegin" --> Comment
ValueBegin --"0x0A (\n) and Array is top of stack" --> ValueBegin
ValueBegin --"0x0D (CR) and Array is top of stack: set after_newline_state = ValueBegin" --> Newline
ValueBegin --"whitespace and Array is top of stack" --> ValueBegin
ArrayValueEnd --"0x2C (,):" --> ValueBegin
ArrayValueEnd --"0x5D (]):" pop stack, emit ArrayClose" --> stackState()
ArrayValueEnd --"0x23 (#): set after_comment_state = ArrayValueEnd" --> Comment
ArrayValueEnd --"0x0A (\n)" --> ArrayValueEnd
ArrayValueEnd --"0x0D (CR): set after_newline_state = ArrayValueEnd" --> Newline
ArrayValueEnd --"whitespace" --> ArrayValueEnd

%% array can be empty. Array can have comments anywhere (before val, after val, before closing bracket)
%% initial state: expect value OR closing bracket
%% after value state: expect comma OR closing bracket
%% after comma: expect value OR closing bracket
%% array = array-open [ array-values ] ws-comment-newline array-close
%% 
%% array-open =  %x5B ; [
%% array-close = %x5D ; ]
%% 
%% array-values =  ws-comment-newline val ws-comment-newline array-sep array-values
%% array-values =/ ws-comment-newline val ws-comment-newline [ array-sep ]
%% 
%% array-sep = %x2C  ; , Comma

%% value: inline table
ValueBegin --"0x7B ({): push InlineTable to stack, emit InlineTableOpen" --> InlineTableKey
ValueBegin --"0x7D (}) and InlineTable is top of stack: pop stack, emit InlineTableClose" --> stackState()
ValueBegin --"0x23 (#) and InlineTable is top of stack: set after_comment_state = ValueBegin" --> Comment
ValueBegin --"0x0A (\n) and InlineTable is top of stack" --> ValueBegin
ValueBegin --"0x0D (CR) and InlineTable is top of stack: set after_newline_state = ValueBegin" --> Newline
ValueBegin --"whitespace and InlineTable is top of stack" --> ValueBegin
InlineTableKey --"ALPHA | DIGIT | - | _: set after_key_state = KeyMaybeDotOrKeyvalSeparator" --> UnquotedKey
InlineTableKey --"0x22 (double quote): set after_key_state = KeyvalSeparator, after_string_state = KeyMaybeDotOrKeyvalSeparator, string_kind = basic, string_is_content_start = true" --> String
InlineTableKey --"0x27 (single quote): set after_key_state = KeyvalSeparator, after_string_state = KeyMaybeDotOrKeyvalSeparator, string_kind = literal, string_is_content_start = true" --> String
InlineTableKeyvalEnd --"0x2C (,):" --> ValueBegin
InlineTableKeyvalEnd --"0x7D (}): pop stack, emit InlineTableClose" --> stackState()
InlineTableKeyvalEnd --"0x23 (#): set after_comment_state = InlineTableKeyvalEnd" --> Comment
InlineTableKeyvalEnd --"0x0A (\n)" --> InlineTableKeyvalEnd
InlineTableKeyvalEnd --"0x0D (CR): set after_newline_state = InlineTableKeyvalEnd" --> Newline
InlineTableKeyvalEnd --"whitespace" --> InlineTableKeyvalEnd

%% value: date-time
%% XXX: validate everything. Currently I don't validate years, months, days, hours, minutes, seconds, offsets. Only the shape of the incoming string. That's too bad.
%% But this is really a dedicated step (in development - doesn't mean it shouldn't be baked into the tokenizer code).
%% convention: date component is added only when the component is completed, not right away
ValueBegin --"0x30-0x39 (0-9):" --> DateTimeDigit2
DateTimeDigit2 --"0x30-0x39 (0-9):" --> DateTimeMaybeYearDigit3OrColon
DateTimeMaybeYearDigit3OrColon --"0x3A (:):" --> PartialTimeMinute1
DateTimeMaybeYearDigit3OrColon --"0x30-0x39 (0-9):" --> DateYearDigit4
DateYearDigit4 --"0x30-0x39 (0-9):" --> DateHyphen1
DateHyphen1 --"0x2D (-):" --> DateMonthDigit1
DateMonthDigit1 --"0x30-0x39 (0-9):" --> DateMonthDigit2
DateMonthDigit2 --"0x30-0x39 (0-9):" --> DateHyphen2
DateHyphen2 --"0x2D (-):" --> DateDayDigit1
DateDayDigit1 --"0x30-0x39 (0-9):" --> DateDayDigit2
DateDayDigit2 --"0x30-0x39 (0-9): date_components.add(date)" --> DateMaybeDelimiterOrEnd
DateMaybeDelimiterOrEnd --"0x54 (T):" --> PartialTimeHour1
DateMaybeDelimiterOrEnd --"0x74 (t):" --> PartialTimeHour1
DateMaybeDelimiterOrEnd --"0x20 (space):" --> PartialTimeMaybeHour1OrEnd
DateMaybeDelimiterOrEnd --"(anything else): emit DateTime. REPEAT THE SAME CHAR" --> stackState()
PartialTimeMaybeHour1OrEnd --"0x30-0x39 (0-9):" --> PartialTimeHour2
PartialTimeMaybeHour1OrEnd --"(anything else): emit DateTime. REPEAT THE SAME CHAR" --> stackState()
PartialTimeHour1 --"0x30-0x39 (0-9):" --> PartialTimeHour2
PartialTimeHour2 --"0x30-0x39 (0-9):" --> PartialTimeColon1
PartialTimeColon1 --"0x3A (:):" --> PartialTimeMinute1
PartialTimeMinute1 --"0x30-0x39 (0-9):" --> PartialTimeMinute2
PartialTimeMinute2 --"0x30-0x39 (0-9): date_components.add(time_hours_minutes)" --> PartialTimeMaybeColon2OrOffsetOrEnd
PartialTimeMaybeColon2OrOffsetOrEnd --"0x3A (:):" --> PartialTimeSecond1
PartialTimeSecond1 --"0x30-0x39 (0-9):" --> PartialTimeSecond2
PartialTimeSecond2 --"0x30-0x39 (0-9): date_components.add(time_seconds)" --> PartialTimeMaybeFractionDelimiterOrOffsetOrEnd
PartialTimeMaybeFractionDelimiterOrOffsetOrEnd --"0x2E (.)" --> PartialTimeFractionBegin
PartialTimeMaybeFractionDelimiterOrOffsetOrEnd --"(anything else): emit DateTime. REPEAT THE SAME CHAR" --> stackState()
PartialTimeFractionBegin --"0x30-0x39 (0-9):" --> PartialTimeFractionOrOffsetOrEnd
PartialTimeFractionOrOffsetOrEnd --"0x30-0x39 (0-9)" --> PartialTimeFractionOrOffsetOrEnd
PartialTimeFractionOrOffsetOrEnd --"0x5A (Z): date_components.add(zulu_offset), emit DateTime" --> stackState()
PartialTimeFractionOrOffsetOrEnd --"0x2B (+):" --> PartialTimeOffsetHour1
PartialTimeFractionOrOffsetOrEnd --"0x2D (-):" --> PartialTimeOffsetHour1
PartialTimeOffsetHour1 --"0x30-0x39 (0-9):" --> PartialTimeOffsetHour2
PartialTimeOffsetHour2 --"0x30-0x39 (0-9):" --> PartialTimeOffsetColon
PartialTimeOffsetColon --"0x3A (:):" --> PartialTimeOffsetMinute1
PartialTimeOffsetMinute1 --"0x30-0x39 (0-9):" --> PartialTimeOffsetMinute2
PartialTimeOffsetMinute2 --"0x30-0x39 (0-9): date_components.add(numeric_offset), emit DateTime" --> stackState()
PartialTimeFractionOrOffsetOrEnd --"(anything else): date_components.add(time_seconds_fractions), emit DateTime. REPEAT THE SAME CHAR" --> stackState()
PartialTimeMaybeColon2OrOffsetOrEnd --"0x5A (Z): date_components.add(zulu_offset), emit DateTime" --> stackState()
PartialTimeMaybeColon2OrOffsetOrEnd --"0x2B (+)" --> PartialTimeOffsetHour1
PartialTimeMaybeColon2OrOffsetOrEnd --"0x2D (-)" --> PartialTimeOffsetHour1
PartialTimeMaybeColon2OrOffsetOrEnd --"(anything else): emit DateTime. REPEAT THE SAME CHAR" --> stackState()

%% value: integer. That's pretty crazy.

%% LOGIC FOR STRINGS
%% literal-char = %x09 / %x20-26 /           %x28-7E / non-ascii
%% rrbasic-char = %x09 / %x20-21 / %x23-5B / %x5D-7E / non-ascii
%%                tab    \n     \r               "                '                \
%% uni-char     = %x09 / %x0A / %x0D / %x20-21 / %x22 / %x23-26 / %x27 / %x28-5B / %x5C / %x5D-7E / non-ascii
%%   basic        Y      N      N      Y         N      Y         Y      Y         Y[1]    Y        Y
%%   literal      Y      N      N      Y         Y      Y         N      Y         Y       Y        Y
%%   ml-basic     Y      Y[2]   Y[3]   Y         Y[4]   Y         Y      Y         Y[5]    Y        Y
%%   ml-literal   Y      Y[6]   Y[7]   Y         Y      Y         Y[8]   Y         Y       Y        Y
%%
%%   algo         Y      Y      Y      Y         Y      Y         Y      Y         Y       Y        Y
%%
%%   FOOTNOTES
%%   [1] reverse solidus starts an escape sequence
%%   [2] if \n is the first after leading triple quote, it must be trimmed. It also may be an escaped newline.
%%   [3] \r must be part of CRLF, otherwise it's illegal. If it comes first after leading triple quote, it must be trimmed along with \n. It also may be an escaped newline.
%%   [4] up to 2 double quotes allowed
%%   [5] reverse solidus starts an escape sequence, AND may also start escaped newline
%%   [6] if \n is the first after leading triple quote, it must be trimmed. It also may be an escaped newline.
%%   [7] \r must be part of CRLF, otherwise it's illegal. If it comes first after leading triple quote, it must be trimmed along with \n. It also may be an escaped newline.
%%   [8] up to 2 single quotes allowed
%%   so how it should work:
%%   1) %x09 / %x20-21 / %x23-26 / %x28-5B / %x5D-7E / non-ascii: the same for all (either String->String or String->Utf8Byte2OfX)
%%   2) %x5C: if literal, then just String->String, otherwise start escape sequence (NB: multiline escape sequence can include escaped newline)
%%   3) %x0A, %x0D: if multiline, go to newline mode. Otherwise illegal
%%   4) %x22 (double quote): if literal, just String->String, if basic, then close string, if ml basic, then go into quote state
%%   5) %x27 (single quote): if basic, just String->String, if literal, then close string, if ml literal, then go into quote state

BasicStringMaybeCharOrClosingQuoteOrLeadingQuote2 --"double quote:" --> BasicStringMaybeLeadingQuote3
BasicStringMaybeCharOrClosingQuoteOrLeadingQuote2 --"(anything else): set string_kind = basic, set string_is_content_start = true. REPEAT THE SAME CHAR" --> String
BasicStringMaybeLeadingQuote3 --"double quote: set string_kind = multiline_basic" --> String
BasicStringMaybeLeadingQuote3 --"(anything else): set string_kind = basic, unset after_string_state, set string_is_content_start = true, if after_string_state is ValueBegin, emit String w/ is_key=true. Else TODO. REPEAT THE SAME CHAR" --> $after_string_state
LiteralStringMaybeCharOrClosingQuoteOrLeadingQuote2 --"single quote:" --> LiteralStringMaybeLeadingQuote3
LiteralStringMaybeCharOrClosingQuoteOrLeadingQuote2 --"(anything else): set string_kind = literal, set string_is_content_start = true. REPEAT THE SAME CHAR" --> String
LiteralStringMaybeLeadingQuote3 --"single quote: set string_kind = multiline_literal" --> String
LiteralStringMaybeLeadingQuote3 --"(anything else): set string_kind = literal, unset after_string_state, set string_is_content_start = true, if after_string_state is ValueBegin, emit String w/ is_key=true. Else TODO. REPEAT THE SAME CHAR" --> $after_string_state
String --"%x09 / %x20-21 / %x23-26 / %x28-5B / %x5D-7E: set string_is_content_start = false" --> String
String --"leading byte of 2-byte UTF-8 sequence (0xC2-0xDF): set string_is_content_start = false, set after_utf8_state = String" --> StringUtf8Byte2Of2
StringUtf8Byte2Of2 --"2d byte of 2-byte UTF-8 sequence (0x80-0xBF): unset after_utf8_state" --> $after_utf8_state
String --"leading byte of 3-byte UTF-8 sequence (0xE0, 0xE1-0xEC, 0xED, 0xEE-0xEF): set string_is_content_start = false, set after_utf8_state = String, set leading_utf8_byte" --> StringUtf8Byte2Of3
StringUtf8Byte2Of3 --"2d byte of 3-byte UTF-8 sequence (various depending on the translation table & the first byte):" --> StringUtf8Byte3Of3
StringUtf8Byte3Of3 --"3d byte of 3-byte UTF-8 sequence (0x80-0xBF): unset after_utf8_state, unset leading_utf8_byte" --> $after_utf8_state
String --"leading byte of 4-byte UTF-8 sequence (0xF0, 0xF1-0xF3, 0xF4): set string_is_content_start = false, set after_utf8_state = String, set leading_utf8_byte" --> StringUtf8Byte2Of4
StringUtf8Byte2Of4 --"2d byte of 4-byte UTF-8 sequence (various depending on the translation table & the first byte):" --> StringUtf8Byte3Of4
StringUtf8Byte3Of4 --"3d byte of 4-byte UTF-8 sequence (0x80-0xBF):" --> StringUtf8Byte4Of4
StringUtf8Byte4Of4 --"4th byte of 4-byte UTF-8 sequence (0x80-0xBF): unset after_utf8_state, unset leading_utf8_byte" --> $after_utf8_state
String --"reverse solidus and is literal: set string_is_content_start = false" --> String
String --"reverse solidus and is basic: set string_is_content_start = false, set after_escape_state = String" --> EscapeMaybeSpecialOr2HexOr4HexOr8HexOrWhitespace
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
MultilineEscapedNewlineEnd --"carriage return (0x0d): set after_newline_state = MultilineEscapedNewlineEnd" --> Newline
MultilineEscapedNewlineEnd --"(anything else): unset after_escape_state, REPEAT THE SAME CHAR" --> $after_escape_state
String --"0x0A (newline) and is multiline: set string_is_content_start = false, if string_is_content_start, account for size diff" --> String
String --"0x0D (CR) and is multiline: set string_is_content_start=false, set after_newline_state = String, if string_is_content_start, account for size diff" --> Newline
Newline --"0x0A (newline): unset after_newline_state" --> $after_newline_state
String --"0x22 (double quote) and is literal: set string_is_content_start=false" --> String
String --"0x22 (double quote) and is multiline basic: set string_is_content_start=false" --> BasicStringMaybeQuote2OrChar
BasicStringMaybeQuote2OrChar --"0x22 (double quote):" BasicStringMaybeQuote3OrChar
BasicStringMaybeQuote2OrChar --"(anything else): REPEAT THE SAME CHAR" --> String
BasicStringMaybeQuote3OrChar --"0x22 (double quote):" BasicStringMaybeQuote4OrEnd
BasicStringMaybeQuote3OrChar --"(anything else): REPEAT THE SAME CHAR" --> String
BasicStringMaybeQuote4OrEnd --"0x22 (double quote):" BasicStringMaybeQuote5OrEnd
BasicStringMaybeQuote4OrEnd --"(anything else): unset after_string_state; if after_string_state is ValueBegin, emit String w/ is_key=true. Else TODO. REPAT THE SAME CHAR" --> $after_string_state
BasicStringMaybeQuote5OrEnd --"0x22 (double quote): unset after_string_state; if after_string_state is ValueBegin, emit String w/ is_key=true. Else TODO." --> $after_string_state
BasicStringMaybeQuote5OrEnd --"(anything else): unset after_string_state; if after_string_state is ValueBegin, emit String w/ is_key=true. Else TODO. REPAT THE SAME CHAR" --> $after_string_state
String --"0x27 (single quote) and is basic: set string_is_content_start=false" --> String
String --"0x27 (single quote) and is multiline literal: set string_is_content_start=false" --> LiteralStringMaybeQuote2OrChar
LiteralStringMaybeQuote2OrChar --"0x27 (single quote):" LiteralStringMaybeQuote3OrChar
LiteralStringMaybeQuote2OrChar --"(anything else): REPEAT THE SAME CHAR" --> String
LiteralStringMaybeQuote3OrChar --"0x27 (single quote):" LiteralStringMaybeQuote4OrEnd
LiteralStringMaybeQuote3OrChar --"(anything else): REPEAT THE SAME CHAR" --> String
LiteralStringMaybeQuote4OrEnd --"0x27 (single quote):" LiteralStringMaybeQuote5OrEnd
LiteralStringMaybeQuote4OrEnd --"(anything else): unset after_string_state; if after_string_state is ValueBegin, emit String w/ is_key=true. Else TODO. REPAT THE SAME CHAR" --> $after_string_state
LiteralStringMaybeQuote5OrEnd --"0x27 (single quote): unset after_string_state; if after_string_state is ValueBegin, emit String w/ is_key=true. Else TODO." --> $after_string_state
LiteralStringMaybeQuote5OrEnd --"(anything else): unset after_string_state; if after_string_state is ValueBegin, emit String w/ is_key=true. Else TODO. REPAT THE SAME CHAR" --> $after_string_state
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
```

## Other notes

I probably need my own type for dates & times. A type that preserves the ambiguity inherent in TOML.
