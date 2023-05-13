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

const StringEscapes = union(enum) {
    None,
    Some: struct {
        /// len(unescaped string) - len(escaped string). Always < 0.
        size_diff: isize,
    },
};

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
    InlineTableOpen,
    InlineTableClose,
    ArrayTableOpen,
    ArrayTableClose,
    TableOpen,
    TableClose,
    InlineTableOpen,
    InlineTableClose,
    DottedKeySeparator,

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

    Integer: struct {
        count: usize,
        pub fn slice(self: @This(), input: []const u8, i: usize) []const u8 {
            return input[i - self.count .. i];
        }
    },

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
