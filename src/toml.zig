const StringKind = enum {
    const Self = @This();

    some_basic,
    basic,
    multiline_basic,
    some_literal,
    literal,
    multiline_literal,

    pub fn isBasic(self: Self) bool {
        return switch (self) {
            .some_basic, .basic, .multiline_basic => true,
            .some_literal, .literal, .multiline_literal => false,
        };
    }

    pub fn isLiteral(self: Self) bool {
        return !self.isBasic();
    }
};

const DateTimeKind = enum {
    offset_date_time,
    local_date_time,
    local_date,
    local_time,
};

const IntegerBase = enum {
    binary,
    octal,
    decimal,
    hexadecimal,
};

const TimeOffsetKind = enum {
    greenwhich,
    numeric,
};

const StringEscapes = union(enum) {
    None,
    Some: struct {
        /// len(unescaped string) - len(escaped string). Always < 0.
        size_diff: isize,
    },
};

const DateTimeComponent = enum {
    date,
    time_hours_minutes,
    time_seconds,
    time_seconds_fractions,
    zulu_offset,
    numeric_offset,
};

const DateTimeComponentSet = std.bit_set.IntegerBitSet(@typeInfo(DateTimeComponent).Enum.fields.len);

// On top level, I skip whitespace and comments (and my after comment state is still at top level)
// On top level, I expect a key-value pair or a table
//
// TOML consists of newline-separated expressions.
//
// An expression is k=v or table (or maybe just a comment). May have trailing & leading whitespace.
pub const Token = union(enum) {
    True,
    False,
    ArrayOpen,
    ArrayClose,
    ArrayTableOpen,
    TableOpen,
    InlineTableOpen,
    InlineTableClose,
    DottedKeySeparator,
    KeyvalSeparator,

    /// Unquoted key
    Key: struct {
        count: usize,
        pub fn slice(self: @This(), input: []const u8, i: usize) []const u8 {
            return input[i - self.count .. i];
        }
    },

    /// A string value or a quoted key (a quoted key is indicated by .is_key = true)
    String: struct {
        count: usize,
        kind: StringKind,
        is_key: bool,
        escapes: StringEscapes,
        pub fn slice(self: @This(), input: []const u8, i: usize) []const u8 {
            return input[i - self.count .. i];
        }
    },

    Integer: i64,

    Float: struct {
        count: usize,
        pub fn slice(self: @This(), input: []const u8, i: usize) []const u8 {
            return input[i - self.count .. i];
        }
    },

    Comment: struct {
        count: usize,
        pub fn slice(self: @This(), input: []const u8, i: usize) []const u8 {
            return input[i - self.count .. i];
        }
    },

    DateTime: struct {
        count: usize,
        kind: DateTimeKind,
        pub fn slice(self: @This(), input: []const u8, i: usize) []const u8 {
            return input[i - self.count .. i];
        }
    },
};

pub const StreamingParser = struct {
    integer_base: IntegerBase = undefined,

    pub const State = enum(u8) {
        /// Waiting for anythong appropriate on the top level (key-value pair, table, array table, comment)
        TopLevel,
        /// Waiting for either the table key or the second bracket of array table key open
        MaybeTableKeyOrArrayTableKeyOpen2,
        /// Waiting for table key
        TableKey,
        /// Waiting for array table key
        ArrayTableKey,
        /// Waiting for the second bracket of array table key close
        ArrayTableKeyClose2,
        /// Waiting for the first key-value pair of a table (or next table/array table)
        TableBegin,
        Table,
        ArrayTableBegin,
        ArrayTable,
        InlineTableBegin,
        InlineTable,
        ArrayValueEnd,
    };
};
