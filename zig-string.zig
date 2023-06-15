const std = @import("std");
const assert = std.debug.assert;

/// A variable length collection of characters
pub const String = struct {
    /// The internal character buffer
    buffer: ?[]u8,
    /// The allocator used for managing the buffer
    allocator: std.mem.Allocator,
    /// The total size of the String
    size: usize,

    /// Errors that may occur when using String
    pub const Error = error{
        OutOfMemory,
        InvalidRange,
    };

    /// Creates a String with an Allocator
    /// User is responsible for managing the new String
    pub fn init(allocator: std.mem.Allocator) String {
        return .{
            .buffer = null,
            .allocator = allocator,
            .size = 0,
        };
    }

    pub fn init_with_contents(allocator: std.mem.Allocator, contents: []const u8) Error!String {
        var string = init(allocator);

        try string.concat(contents);

        return string;
    }

    /// Deallocates the internal buffer
    pub fn deinit(self: *String) void {
        if (self.buffer) |buffer| self.allocator.free(buffer);
    }

    /// Returns the size of the internal buffer
    pub fn capacity(self: String) usize {
        if (self.buffer) |buffer| return buffer.len;
        return 0;
    }

    /// Allocates space for the internal buffer
    pub fn allocate(self: *String, bytes: usize) Error!void {
        if (self.buffer) |buffer| {
            if (bytes < self.size) self.size = bytes; // Clamp size to capacity
            self.buffer = self.allocator.realloc(buffer, bytes) catch {
                return Error.OutOfMemory;
            };
        } else {
            self.buffer = self.allocator.alloc(u8, bytes) catch {
                return Error.OutOfMemory;
            };
        }
    }

    /// Reallocates the the internal buffer to size
    pub fn truncate(self: *String) Error!void {
        try self.allocate(self.size);
    }

    /// Appends a character onto the end of the String
    pub fn concat(self: *String, char: []const u8) Error!void {
        try self.insert(char, self.len());
    }

    /// Inserts a string literal into the String at an index
    pub fn insert(self: *String, literal: []const u8, index: usize) Error!void {
        // Make sure buffer has enough space
        if (self.buffer) |buffer| {
            if (self.size + literal.len > buffer.len) {
                try self.allocate((self.size + literal.len) * 2);
            }
        } else {
            try self.allocate((literal.len) * 2);
        }

        const buffer = self.buffer.?;

        // If the index is >= len, then simply push to the end.
        // If not, then copy contents over and insert literal.
        if (index == self.len()) {
            var i: usize = 0;
            while (i < literal.len) : (i += 1) {
                buffer[self.size + i] = literal[i];
            }
        } else {
            if (String.getIndex(buffer, index, true)) |k| {
                // Move existing contents over
                var i: usize = buffer.len - 1;
                while (i >= k) : (i -= 1) {
                    if (i + literal.len < buffer.len) {
                        buffer[i + literal.len] = buffer[i];
                    }

                    if (i == 0) break;
                }

                i = 0;
                while (i < literal.len) : (i += 1) {
                    buffer[index + i] = literal[i];
                }
            }
        }

        self.size += literal.len;
    }

    /// Removes the last character from the String
    pub fn pop(self: *String) ?[]const u8 {
        if (self.size == 0) return null;

        if (self.buffer) |buffer| {
            var i: usize = 0;
            while (i < self.size) {
                const size = String.getUTF8Size(buffer[i]);
                if (i + size >= self.size) break;
                i += size;
            }

            const ret = buffer[i..self.size];
            self.size -= (self.size - i);
            return ret;
        }

        return null;
    }

    /// Compares this String with a string literal
    pub fn cmp(self: String, literal: []const u8) bool {
        if (self.buffer) |buffer| {
            return std.mem.eql(u8, buffer[0..self.size], literal);
        }
        return false;
    }

    /// Returns the String as a string literal
    pub fn str(self: String) []const u8 {
        if (self.buffer) |buffer| return buffer[0..self.size];
        return "";
    }

    /// Returns an owned slice of this string
    pub fn toOwned(self: String) Error!?[]u8 {
        if (self.buffer != null) {
            const string = self.str();
            if (self.allocator.alloc(u8, string.len)) |newStr| {
                std.mem.copy(u8, newStr, string);
                return newStr;
            } else |_| {
                return Error.OutOfMemory;
            }
        }

        return null;
    }

    /// Returns a character at the specified index
    pub fn charAt(self: String, index: usize) ?[]const u8 {
        if (self.buffer) |buffer| {
            if (String.getIndex(buffer, index, true)) |i| {
                const size = String.getUTF8Size(buffer[i]);
                return buffer[i..(i + size)];
            }
        }
        return null;
    }

    /// Returns amount of characters in the String
    pub fn len(self: String) usize {
        if (self.buffer) |buffer| {
            var length: usize = 0;
            var i: usize = 0;

            while (i < self.size) {
                i += String.getUTF8Size(buffer[i]);
                length += 1;
            }

            return length;
        } else {
            return 0;
        }
    }

    /// Finds the first occurrence of the string literal
    pub fn find(self: String, literal: []const u8) ?usize {
        if (self.buffer) |buffer| {
            const index = std.mem.indexOf(u8, buffer[0..self.size], literal);
            if (index) |i| {
                return String.getIndex(buffer, i, false);
            }
        }

        return null;
    }

    /// Removes a character at the specified index
    pub fn remove(self: *String, index: usize) Error!void {
        try self.removeRange(index, index + 1);
    }

    /// Removes a range of character from the String
    /// Start (inclusive) - End (Exclusive)
    pub fn removeRange(self: *String, start: usize, end: usize) Error!void {
        const length = self.len();
        if (end < start or end > length) return Error.InvalidRange;

        if (self.buffer) |buffer| {
            const rStart = String.getIndex(buffer, start, true).?;
            const rEnd = String.getIndex(buffer, end, true).?;
            const difference = rEnd - rStart;

            var i: usize = rEnd;
            while (i < self.size) : (i += 1) {
                buffer[i - difference] = buffer[i];
            }

            self.size -= difference;
        }
    }

    /// Trims all whitelist characters at the start of the String.
    pub fn trimStart(self: *String, whitelist: []const u8) void {
        if (self.buffer) |buffer| {
            var i: usize = 0;
            while (i < self.size) : (i += 1) {
                const size = String.getUTF8Size(buffer[i]);
                if (size > 1 or !inWhitelist(buffer[i], whitelist)) break;
            }

            if (String.getIndex(buffer, i, false)) |k| {
                self.removeRange(0, k) catch {};
            }
        }
    }

    /// Trims all whitelist characters at the end of the String.
    pub fn trimEnd(self: *String, whitelist: []const u8) void {
        self.reverse();
        self.trimStart(whitelist);
        self.reverse();
    }

    /// Trims all whitelist characters from both ends of the String
    pub fn trim(self: *String, whitelist: []const u8) void {
        self.trimStart(whitelist);
        self.trimEnd(whitelist);
    }

    /// Copies this String into a new one
    /// User is responsible for managing the new String
    pub fn clone(self: String) Error!String {
        var newString = String.init(self.allocator);
        try newString.concat(self.str());
        return newString;
    }

    /// Reverses the characters in this String
    pub fn reverse(self: *String) void {
        if (self.buffer) |buffer| {
            var i: usize = 0;
            while (i < self.size) {
                const size = String.getUTF8Size(buffer[i]);
                if (size > 1) std.mem.reverse(u8, buffer[i..(i + size)]);
                i += size;
            }

            std.mem.reverse(u8, buffer[0..self.size]);
        }
    }

    /// Repeats this String n times
    pub fn repeat(self: *String, n: usize) Error!void {
        try self.allocate(self.size * (n + 1));
        if (self.buffer) |buffer| {
            var i: usize = 1;
            while (i <= n) : (i += 1) {
                var j: usize = 0;
                while (j < self.size) : (j += 1) {
                    buffer[((i * self.size) + j)] = buffer[j];
                }
            }

            self.size *= (n + 1);
        }
    }

    /// Checks the String is empty
    pub inline fn isEmpty(self: String) bool {
        return self.size == 0;
    }

    /// Splits the String into a slice, based on a delimiter and an index
    pub fn split(self: *const String, delimiters: []const u8, index: usize) ?[]const u8 {
        if (self.buffer) |buffer| {
            var i: usize = 0;
            var block: usize = 0;
            var start: usize = 0;

            while (i < self.size) {
                const size = String.getUTF8Size(buffer[i]);
                if (size == delimiters.len) {
                    if (std.mem.eql(u8, delimiters, buffer[i..(i + size)])) {
                        if (block == index) return buffer[start..i];
                        start = i + size;
                        block += 1;
                    }
                }

                i += size;
            }

            if (i >= self.size - 1 and block == index) {
                return buffer[start..self.size];
            }
        }

        return null;
    }

    /// Splits the String into a new string, based on delimiters and an index
    /// The user of this function is in charge of the memory of the new String.
    pub fn splitToString(self: *const String, delimiters: []const u8, index: usize) Error!?String {
        if (self.split(delimiters, index)) |block| {
            var string = String.init(self.allocator);
            try string.concat(block);
            return string;
        }

        return null;
    }

    /// Clears the contents of the String but leaves the capacity
    pub fn clear(self: *String) void {
        if (self.buffer) |buffer| {
            for (buffer) |*ch| ch.* = 0;
            self.size = 0;
        }
    }

    /// Converts all (ASCII) uppercase letters to lowercase
    pub fn toLowercase(self: *String) void {
        if (self.buffer) |buffer| {
            var i: usize = 0;
            while (i < self.size) {
                const size = String.getUTF8Size(buffer[i]);
                if (size == 1) buffer[i] = std.ascii.toLower(buffer[i]);
                i += size;
            }
        }
    }

    /// Converts all (ASCII) uppercase letters to lowercase
    pub fn toUppercase(self: *String) void {
        if (self.buffer) |buffer| {
            var i: usize = 0;
            while (i < self.size) {
                const size = String.getUTF8Size(buffer[i]);
                if (size == 1) buffer[i] = std.ascii.toUpper(buffer[i]);
                i += size;
            }
        }
    }

    /// Creates a String from a given range
    /// User is responsible for managing the new String
    pub fn substr(self: String, start: usize, end: usize) Error!String {
        var result = String.init(self.allocator);

        if (self.buffer) |buffer| {
            if (String.getIndex(buffer, start, true)) |rStart| {
                if (String.getIndex(buffer, end, true)) |rEnd| {
                    if (rEnd < rStart or rEnd > self.size)
                        return Error.InvalidRange;
                    try result.concat(buffer[rStart..rEnd]);
                }
            }
        }

        return result;
    }

    // Writer functionality for the String.
    pub usingnamespace struct {
        pub const Writer = std.io.Writer(*String, Error, appendWrite);

        pub fn writer(self: *String) Writer {
            return .{ .context = self };
        }

        fn appendWrite(self: *String, m: []const u8) !usize {
            try self.concat(m);
            return m.len;
        }
    };

    // Iterator support
    pub usingnamespace struct {
        pub const StringIterator = struct {
            string: *const String,
            index: usize,

            pub fn next(it: *StringIterator) ?[]const u8 {
                if (it.string.buffer) |buffer| {
                    if (it.index == it.string.size) return null;
                    var i = it.index;
                    it.index += String.getUTF8Size(buffer[i]);
                    return buffer[i..it.index];
                } else {
                    return null;
                }
            }
        };

        pub fn iterator(self: *const String) StringIterator {
            return StringIterator{
                .string = self,
                .index = 0,
            };
        }
    };

    /// Returns whether or not a character is whitelisted
    fn inWhitelist(char: u8, whitelist: []const u8) bool {
        var i: usize = 0;
        while (i < whitelist.len) : (i += 1) {
            if (whitelist[i] == char) return true;
        }

        return false;
    }

    /// Checks if byte is part of UTF-8 character
    inline fn isUTF8Byte(byte: u8) bool {
        return ((byte & 0x80) > 0) and (((byte << 1) & 0x80) == 0);
    }

    /// Returns the real index of a unicode string literal
    fn getIndex(unicode: []const u8, index: usize, real: bool) ?usize {
        var i: usize = 0;
        var j: usize = 0;
        while (i < unicode.len) {
            if (real) {
                if (j == index) return i;
            } else {
                if (i == index) return j;
            }
            i += String.getUTF8Size(unicode[i]);
            j += 1;
        }

        return null;
    }

    /// Returns the UTF-8 character's size
    inline fn getUTF8Size(char: u8) u3 {
        return std.unicode.utf8ByteSequenceLength(char) catch {
            return 1;
        };
    }

    /// Converts all (including Unicode) characters uppercase to lowercase
    pub fn uniToLowercase(self: *String) !void {
        @setEvalBranchQuota(5000);
        const upperToLowerMap = std.ComptimeStringMap([]const u8, .{
            .{ "A", "a" },
            .{ "B", "b" },
            .{ "C", "c" },
            .{ "D", "d" },
            .{ "E", "e" },
            .{ "F", "f" },
            .{ "G", "g" },
            .{ "H", "h" },
            .{ "I", "i" },
            .{ "J", "j" },
            .{ "K", "k" },
            .{ "L", "l" },
            .{ "M", "m" },
            .{ "N", "n" },
            .{ "O", "o" },
            .{ "P", "p" },
            .{ "Q", "q" },
            .{ "R", "r" },
            .{ "S", "s" },
            .{ "T", "t" },
            .{ "U", "u" },
            .{ "V", "v" },
            .{ "W", "w" },
            .{ "X", "x" },
            .{ "Y", "y" },
            .{ "Z", "z" },
            .{ "À", "à" },
            .{ "Á", "á" },
            .{ "Â", "â" },
            .{ "Ã", "ã" },
            .{ "Ä", "ä" },
            .{ "Å", "å" },
            .{ "Æ", "æ" },
            .{ "Ç", "ç" },
            .{ "È", "è" },
            .{ "É", "é" },
            .{ "Ê", "ê" },
            .{ "Ë", "ë" },
            .{ "Ì", "ì" },
            .{ "Í", "í" },
            .{ "Î", "î" },
            .{ "Ï", "ï" },
            .{ "Ð", "ð" },
            .{ "Ñ", "ñ" },
            .{ "Ò", "ò" },
            .{ "Ó", "ó" },
            .{ "Ô", "ô" },
            .{ "Õ", "õ" },
            .{ "Ö", "ö" },
            .{ "Ø", "ø" },
            .{ "Ù", "ù" },
            .{ "Ú", "ú" },
            .{ "Û", "û" },
            .{ "Ü", "ü" },
            .{ "Ý", "ý" },
            .{ "Þ", "þ" },
            .{ "Ÿ", "ÿ" },
            .{ "Ā", "ā" },
            .{ "Ă", "ă" },
            .{ "Ą", "ą" },
            .{ "Ć", "ć" },
            .{ "Ĉ", "ĉ" },
            .{ "Ċ", "ċ" },
            .{ "Č", "č" },
            .{ "Ď", "ď" },
            .{ "Đ", "đ" },
            .{ "Ē", "ē" },
            .{ "Ĕ", "ĕ" },
            .{ "Ė", "ė" },
            .{ "Ę", "ę" },
            .{ "Ě", "ě" },
            .{ "Ĝ", "ĝ" },
            .{ "Ğ", "ğ" },
            .{ "Ġ", "ġ" },
            .{ "Ģ", "ģ" },
            .{ "Ĥ", "ĥ" },
            .{ "Ħ", "ħ" },
            .{ "Ĩ", "ĩ" },
            .{ "Ī", "ī" },
            .{ "Ĭ", "ĭ" },
            .{ "Į", "į" },
            .{ "I", "ı" },
            .{ "Ĳ", "ĳ" },
            .{ "Ĵ", "ĵ" },
            .{ "Ķ", "ķ" },
            .{ "Ĺ", "ĺ" },
            .{ "Ļ", "ļ" },
            .{ "Ľ", "ľ" },
            .{ "Ŀ", "ŀ" },
            .{ "Ł", "ł" },
            .{ "Ń", "ń" },
            .{ "Ņ", "ņ" },
            .{ "Ň", "ň" },
            .{ "Ŋ", "ŋ" },
            .{ "Ō", "ō" },
            .{ "Ŏ", "ŏ" },
            .{ "Ő", "ő" },
            .{ "Œ", "œ" },
            .{ "Ŕ", "ŕ" },
            .{ "Ŗ", "ŗ" },
            .{ "Ř", "ř" },
            .{ "Ś", "ś" },
            .{ "Ŝ", "ŝ" },
            .{ "Ş", "ş" },
            .{ "Š", "š" },
            .{ "Ţ", "ţ" },
            .{ "Ť", "ť" },
            .{ "Ŧ", "ŧ" },
            .{ "Ũ", "ũ" },
            .{ "Ū", "ū" },
            .{ "Ŭ", "ŭ" },
            .{ "Ů", "ů" },
            .{ "Ű", "ű" },
            .{ "Ų", "ų" },
            .{ "Ŵ", "ŵ" },
            .{ "Ŷ", "ŷ" },
            .{ "Ź", "ź" },
            .{ "Ż", "ż" },
            .{ "Ž", "ž" },
            .{ "Ƃ", "ƃ" },
            .{ "Ƅ", "ƅ" },
            .{ "Ƈ", "ƈ" },
            .{ "Ƌ", "ƌ" },
            .{ "Ƒ", "ƒ" },
            .{ "Ƙ", "ƙ" },
            .{ "Ơ", "ơ" },
            .{ "Ƣ", "ƣ" },
            .{ "Ƥ", "ƥ" },
            .{ "Ƨ", "ƨ" },
            .{ "Ƭ", "ƭ" },
            .{ "Ư", "ư" },
            .{ "Ƴ", "ƴ" },
            .{ "Ƶ", "ƶ" },
            .{ "Ƹ", "ƹ" },
            .{ "Ƽ", "ƽ" },
            .{ "Ǆ", "ǆ" },
            .{ "Ǉ", "ǉ" },
            .{ "Ǌ", "ǌ" },
            .{ "Ǎ", "ǎ" },
            .{ "Ǐ", "ǐ" },
            .{ "Ǒ", "ǒ" },
            .{ "Ǔ", "ǔ" },
            .{ "Ǖ", "ǖ" },
            .{ "Ǘ", "ǘ" },
            .{ "Ǚ", "ǚ" },
            .{ "Ǜ", "ǜ" },
            .{ "Ǟ", "ǟ" },
            .{ "Ǡ", "ǡ" },
            .{ "Ǣ", "ǣ" },
            .{ "Ǥ", "ǥ" },
            .{ "Ǧ", "ǧ" },
            .{ "Ǩ", "ǩ" },
            .{ "Ǫ", "ǫ" },
            .{ "Ǭ", "ǭ" },
            .{ "Ǯ", "ǯ" },
            .{ "Ǳ", "ǳ" },
            .{ "Ǵ", "ǵ" },
            .{ "Ǻ", "ǻ" },
            .{ "Ǽ", "ǽ" },
            .{ "Ǿ", "ǿ" },
            .{ "Ȁ", "ȁ" },
            .{ "Ȃ", "ȃ" },
            .{ "Ȅ", "ȅ" },
            .{ "Ȇ", "ȇ" },
            .{ "Ȉ", "ȉ" },
            .{ "Ȋ", "ȋ" },
            .{ "Ȍ", "ȍ" },
            .{ "Ȏ", "ȏ" },
            .{ "Ȑ", "ȑ" },
            .{ "Ȓ", "ȓ" },
            .{ "Ȕ", "ȕ" },
            .{ "Ȗ", "ȗ" },
            .{ "Ɓ", "ɓ" },
            .{ "Ɔ", "ɔ" },
            .{ "Ɗ", "ɗ" },
            .{ "Ǝ", "ɘ" },
            .{ "Ə", "ə" },
            .{ "Ɛ", "ɛ" },
            .{ "Ɠ", "ɠ" },
            .{ "Ɣ", "ɣ" },
            .{ "Ɨ", "ɨ" },
            .{ "Ɩ", "ɩ" },
            .{ "Ɯ", "ɯ" },
            .{ "Ɲ", "ɲ" },
            .{ "Ɵ", "ɵ" },
            .{ "Ʃ", "ʃ" },
            .{ "Ʈ", "ʈ" },
            .{ "Ʊ", "ʊ" },
            .{ "Ʋ", "ʋ" },
            .{ "Ʒ", "ʒ" },
            .{ "Ά", "ά" },
            .{ "Έ", "έ" },
            .{ "Ή", "ή" },
            .{ "Ί", "ί" },
            .{ "Α", "α" },
            .{ "Β", "β" },
            .{ "Γ", "γ" },
            .{ "Δ", "δ" },
            .{ "Ε", "ε" },
            .{ "Ζ", "ζ" },
            .{ "Η", "η" },
            .{ "Θ", "θ" },
            .{ "Ι", "ι" },
            .{ "Κ", "κ" },
            .{ "Λ", "λ" },
            .{ "Μ", "μ" },
            .{ "Ν", "ν" },
            .{ "Ξ", "ξ" },
            .{ "Ο", "ο" },
            .{ "Π", "π" },
            .{ "Ρ", "ρ" },
            .{ "Σ", "σ" },
            .{ "Τ", "τ" },
            .{ "Υ", "υ" },
            .{ "Φ", "φ" },
            .{ "Χ", "χ" },
            .{ "Ψ", "ψ" },
            .{ "Ω", "ω" },
            .{ "Ϊ", "ϊ" },
            .{ "Ϋ", "ϋ" },
            .{ "Ό", "ό" },
            .{ "Ύ", "ύ" },
            .{ "Ώ", "ώ" },
            .{ "Ϣ", "ϣ" },
            .{ "Ϥ", "ϥ" },
            .{ "Ϧ", "ϧ" },
            .{ "Ϩ", "ϩ" },
            .{ "Ϫ", "ϫ" },
            .{ "Ϭ", "ϭ" },
            .{ "Ϯ", "ϯ" },
            .{ "А", "а" },
            .{ "Б", "б" },
            .{ "В", "в" },
            .{ "Г", "г" },
            .{ "Д", "д" },
            .{ "Е", "е" },
            .{ "Ж", "ж" },
            .{ "З", "з" },
            .{ "И", "и" },
            .{ "Й", "й" },
            .{ "К", "к" },
            .{ "Л", "л" },
            .{ "М", "м" },
            .{ "Н", "н" },
            .{ "О", "о" },
            .{ "П", "п" },
            .{ "Р", "р" },
            .{ "С", "с" },
            .{ "Т", "т" },
            .{ "У", "у" },
            .{ "Ф", "ф" },
            .{ "Х", "х" },
            .{ "Ц", "ц" },
            .{ "Ч", "ч" },
            .{ "Ш", "ш" },
            .{ "Щ", "щ" },
            .{ "Ъ", "ъ" },
            .{ "Ы", "ы" },
            .{ "Ь", "ь" },
            .{ "Э", "э" },
            .{ "Ю", "ю" },
            .{ "Я", "я" },
            .{ "Ё", "ё" },
            .{ "Ђ", "ђ" },
            .{ "Ѓ", "ѓ" },
            .{ "Є", "є" },
            .{ "Ѕ", "ѕ" },
            .{ "І", "і" },
            .{ "Ї", "ї" },
            .{ "Ј", "ј" },
            .{ "Љ", "љ" },
            .{ "Њ", "њ" },
            .{ "Ћ", "ћ" },
            .{ "Ќ", "ќ" },
            .{ "Ў", "ў" },
            .{ "Џ", "џ" },
            .{ "Ѡ", "ѡ" },
            .{ "Ѣ", "ѣ" },
            .{ "Ѥ", "ѥ" },
            .{ "Ѧ", "ѧ" },
            .{ "Ѩ", "ѩ" },
            .{ "Ѫ", "ѫ" },
            .{ "Ѭ", "ѭ" },
            .{ "Ѯ", "ѯ" },
            .{ "Ѱ", "ѱ" },
            .{ "Ѳ", "ѳ" },
            .{ "Ѵ", "ѵ" },
            .{ "Ѷ", "ѷ" },
            .{ "Ѹ", "ѹ" },
            .{ "Ѻ", "ѻ" },
            .{ "Ѽ", "ѽ" },
            .{ "Ѿ", "ѿ" },
            .{ "Ҁ", "ҁ" },
            .{ "Ґ", "ґ" },
            .{ "Ғ", "ғ" },
            .{ "Ҕ", "ҕ" },
            .{ "Җ", "җ" },
            .{ "Ҙ", "ҙ" },
            .{ "Қ", "қ" },
            .{ "Ҝ", "ҝ" },
            .{ "Ҟ", "ҟ" },
            .{ "Ҡ", "ҡ" },
            .{ "Ң", "ң" },
            .{ "Ҥ", "ҥ" },
            .{ "Ҧ", "ҧ" },
            .{ "Ҩ", "ҩ" },
            .{ "Ҫ", "ҫ" },
            .{ "Ҭ", "ҭ" },
            .{ "Ү", "ү" },
            .{ "Ұ", "ұ" },
            .{ "Ҳ", "ҳ" },
            .{ "Ҵ", "ҵ" },
            .{ "Ҷ", "ҷ" },
            .{ "Ҹ", "ҹ" },
            .{ "Һ", "һ" },
            .{ "Ҽ", "ҽ" },
            .{ "Ҿ", "ҿ" },
            .{ "Ӂ", "ӂ" },
            .{ "Ӄ", "ӄ" },
            .{ "Ӈ", "ӈ" },
            .{ "Ӌ", "ӌ" },
            .{ "Ӑ", "ӑ" },
            .{ "Ӓ", "ӓ" },
            .{ "Ӕ", "ӕ" },
            .{ "Ӗ", "ӗ" },
            .{ "Ә", "ә" },
            .{ "Ӛ", "ӛ" },
            .{ "Ӝ", "ӝ" },
            .{ "Ӟ", "ӟ" },
            .{ "Ӡ", "ӡ" },
            .{ "Ӣ", "ӣ" },
            .{ "Ӥ", "ӥ" },
            .{ "Ӧ", "ӧ" },
            .{ "Ө", "ө" },
            .{ "Ӫ", "ӫ" },
            .{ "Ӯ", "ӯ" },
            .{ "Ӱ", "ӱ" },
            .{ "Ӳ", "ӳ" },
            .{ "Ӵ", "ӵ" },
            .{ "Ӹ", "ӹ" },
            .{ "Ա", "ա" },
            .{ "Բ", "բ" },
            .{ "Գ", "գ" },
            .{ "Դ", "դ" },
            .{ "Ե", "ե" },
            .{ "Զ", "զ" },
            .{ "Է", "է" },
            .{ "Ը", "ը" },
            .{ "Թ", "թ" },
            .{ "Ժ", "ժ" },
            .{ "Ի", "ի" },
            .{ "Լ", "լ" },
            .{ "Խ", "խ" },
            .{ "Ծ", "ծ" },
            .{ "Կ", "կ" },
            .{ "Հ", "հ" },
            .{ "Ձ", "ձ" },
            .{ "Ղ", "ղ" },
            .{ "Ճ", "ճ" },
            .{ "Մ", "մ" },
            .{ "Յ", "յ" },
            .{ "Ն", "ն" },
            .{ "Շ", "շ" },
            .{ "Ո", "ո" },
            .{ "Չ", "չ" },
            .{ "Պ", "պ" },
            .{ "Ջ", "ջ" },
            .{ "Ռ", "ռ" },
            .{ "Ս", "ս" },
            .{ "Վ", "վ" },
            .{ "Տ", "տ" },
            .{ "Ր", "ր" },
            .{ "Ց", "ց" },
            .{ "Ւ", "ւ" },
            .{ "Փ", "փ" },
            .{ "Ք", "ք" },
            .{ "Օ", "օ" },
            .{ "Ֆ", "ֆ" },
            .{ "Ⴀ", "ა" },
            .{ "Ⴁ", "ბ" },
            .{ "Ⴂ", "გ" },
            .{ "Ⴃ", "დ" },
            .{ "Ⴄ", "ე" },
            .{ "Ⴅ", "ვ" },
            .{ "Ⴆ", "ზ" },
            .{ "Ⴇ", "თ" },
            .{ "Ⴈ", "ი" },
            .{ "Ⴉ", "კ" },
            .{ "Ⴊ", "ლ" },
            .{ "Ⴋ", "მ" },
            .{ "Ⴌ", "ნ" },
            .{ "Ⴍ", "ო" },
            .{ "Ⴎ", "პ" },
            .{ "Ⴏ", "ჟ" },
            .{ "Ⴐ", "რ" },
            .{ "Ⴑ", "ს" },
            .{ "Ⴒ", "ტ" },
            .{ "Ⴓ", "უ" },
            .{ "Ⴔ", "ფ" },
            .{ "Ⴕ", "ქ" },
            .{ "Ⴖ", "ღ" },
            .{ "Ⴗ", "ყ" },
            .{ "Ⴘ", "შ" },
            .{ "Ⴙ", "ჩ" },
            .{ "Ⴚ", "ც" },
            .{ "Ⴛ", "ძ" },
            .{ "Ⴜ", "წ" },
            .{ "Ⴝ", "ჭ" },
            .{ "Ⴞ", "ხ" },
            .{ "Ⴟ", "ჯ" },
            .{ "Ⴠ", "ჰ" },
            .{ "Ⴡ", "ჱ" },
            .{ "Ⴢ", "ჲ" },
            .{ "Ⴣ", "ჳ" },
            .{ "Ⴤ", "ჴ" },
            .{ "Ⴥ", "ჵ" },
            .{ "Ḁ", "ḁ" },
            .{ "Ḃ", "ḃ" },
            .{ "Ḅ", "ḅ" },
            .{ "Ḇ", "ḇ" },
            .{ "Ḉ", "ḉ" },
            .{ "Ḋ", "ḋ" },
            .{ "Ḍ", "ḍ" },
            .{ "Ḏ", "ḏ" },
            .{ "Ḑ", "ḑ" },
            .{ "Ḓ", "ḓ" },
            .{ "Ḕ", "ḕ" },
            .{ "Ḗ", "ḗ" },
            .{ "Ḙ", "ḙ" },
            .{ "Ḛ", "ḛ" },
            .{ "Ḝ", "ḝ" },
            .{ "Ḟ", "ḟ" },
            .{ "Ḡ", "ḡ" },
            .{ "Ḣ", "ḣ" },
            .{ "Ḥ", "ḥ" },
            .{ "Ḧ", "ḧ" },
            .{ "Ḩ", "ḩ" },
            .{ "Ḫ", "ḫ" },
            .{ "Ḭ", "ḭ" },
            .{ "Ḯ", "ḯ" },
            .{ "Ḱ", "ḱ" },
            .{ "Ḳ", "ḳ" },
            .{ "Ḵ", "ḵ" },
            .{ "Ḷ", "ḷ" },
            .{ "Ḹ", "ḹ" },
            .{ "Ḻ", "ḻ" },
            .{ "Ḽ", "ḽ" },
            .{ "Ḿ", "ḿ" },
            .{ "Ṁ", "ṁ" },
            .{ "Ṃ", "ṃ" },
            .{ "Ṅ", "ṅ" },
            .{ "Ṇ", "ṇ" },
            .{ "Ṉ", "ṉ" },
            .{ "Ṋ", "ṋ" },
            .{ "Ṍ", "ṍ" },
            .{ "Ṏ", "ṏ" },
            .{ "Ṑ", "ṑ" },
            .{ "Ṓ", "ṓ" },
            .{ "Ṕ", "ṕ" },
            .{ "Ṗ", "ṗ" },
            .{ "Ṙ", "ṙ" },
            .{ "Ṛ", "ṛ" },
            .{ "Ṝ", "ṝ" },
            .{ "Ṟ", "ṟ" },
            .{ "Ṡ", "ṡ" },
            .{ "Ṣ", "ṣ" },
            .{ "Ṥ", "ṥ" },
            .{ "Ṧ", "ṧ" },
            .{ "Ṩ", "ṩ" },
            .{ "Ṫ", "ṫ" },
            .{ "Ṭ", "ṭ" },
            .{ "Ṯ", "ṯ" },
            .{ "Ṱ", "ṱ" },
            .{ "Ṳ", "ṳ" },
            .{ "Ṵ", "ṵ" },
            .{ "Ṷ", "ṷ" },
            .{ "Ṹ", "ṹ" },
            .{ "Ṻ", "ṻ" },
            .{ "Ṽ", "ṽ" },
            .{ "Ṿ", "ṿ" },
            .{ "Ẁ", "ẁ" },
            .{ "Ẃ", "ẃ" },
            .{ "Ẅ", "ẅ" },
            .{ "Ẇ", "ẇ" },
            .{ "Ẉ", "ẉ" },
            .{ "Ẋ", "ẋ" },
            .{ "Ẍ", "ẍ" },
            .{ "Ẏ", "ẏ" },
            .{ "Ẑ", "ẑ" },
            .{ "Ẓ", "ẓ" },
            .{ "Ẕ", "ẕ" },
            .{ "Ạ", "ạ" },
            .{ "Ả", "ả" },
            .{ "Ấ", "ấ" },
            .{ "Ầ", "ầ" },
            .{ "Ẩ", "ẩ" },
            .{ "Ẫ", "ẫ" },
            .{ "Ậ", "ậ" },
            .{ "Ắ", "ắ" },
            .{ "Ằ", "ằ" },
            .{ "Ẳ", "ẳ" },
            .{ "Ẵ", "ẵ" },
            .{ "Ặ", "ặ" },
            .{ "Ẹ", "ẹ" },
            .{ "Ẻ", "ẻ" },
            .{ "Ẽ", "ẽ" },
            .{ "Ế", "ế" },
            .{ "Ề", "ề" },
            .{ "Ể", "ể" },
            .{ "Ễ", "ễ" },
            .{ "Ệ", "ệ" },
            .{ "Ỉ", "ỉ" },
            .{ "Ị", "ị" },
            .{ "Ọ", "ọ" },
            .{ "Ỏ", "ỏ" },
            .{ "Ố", "ố" },
            .{ "Ồ", "ồ" },
            .{ "Ổ", "ổ" },
            .{ "Ỗ", "ỗ" },
            .{ "Ộ", "ộ" },
            .{ "Ớ", "ớ" },
            .{ "Ờ", "ờ" },
            .{ "Ở", "ở" },
            .{ "Ỡ", "ỡ" },
            .{ "Ợ", "ợ" },
            .{ "Ụ", "ụ" },
            .{ "Ủ", "ủ" },
            .{ "Ứ", "ứ" },
            .{ "Ừ", "ừ" },
            .{ "Ử", "ử" },
            .{ "Ữ", "ữ" },
            .{ "Ự", "ự" },
            .{ "Ỳ", "ỳ" },
            .{ "Ỵ", "ỵ" },
            .{ "Ỷ", "ỷ" },
            .{ "Ỹ", "ỹ" },
            .{ "Ἀ", "ἀ" },
            .{ "Ἁ", "ἁ" },
            .{ "Ἂ", "ἂ" },
            .{ "Ἃ", "ἃ" },
            .{ "Ἄ", "ἄ" },
            .{ "Ἅ", "ἅ" },
            .{ "Ἆ", "ἆ" },
            .{ "Ἇ", "ἇ" },
            .{ "Ἐ", "ἐ" },
            .{ "Ἑ", "ἑ" },
            .{ "Ἒ", "ἒ" },
            .{ "Ἓ", "ἓ" },
            .{ "Ἔ", "ἔ" },
            .{ "Ἕ", "ἕ" },
            .{ "Ἠ", "ἠ" },
            .{ "Ἡ", "ἡ" },
            .{ "Ἢ", "ἢ" },
            .{ "Ἣ", "ἣ" },
            .{ "Ἤ", "ἤ" },
            .{ "Ἥ", "ἥ" },
            .{ "Ἦ", "ἦ" },
            .{ "Ἧ", "ἧ" },
            .{ "Ἰ", "ἰ" },
            .{ "Ἱ", "ἱ" },
            .{ "Ἲ", "ἲ" },
            .{ "Ἳ", "ἳ" },
            .{ "Ἴ", "ἴ" },
            .{ "Ἵ", "ἵ" },
            .{ "Ἶ", "ἶ" },
            .{ "Ἷ", "ἷ" },
            .{ "Ὀ", "ὀ" },
            .{ "Ὁ", "ὁ" },
            .{ "Ὂ", "ὂ" },
            .{ "Ὃ", "ὃ" },
            .{ "Ὄ", "ὄ" },
            .{ "Ὅ", "ὅ" },
            .{ "Ὑ", "ὑ" },
            .{ "Ὓ", "ὓ" },
            .{ "Ὕ", "ὕ" },
            .{ "Ὗ", "ὗ" },
            .{ "Ὠ", "ὠ" },
            .{ "Ὡ", "ὡ" },
            .{ "Ὢ", "ὢ" },
            .{ "Ὣ", "ὣ" },
            .{ "Ὤ", "ὤ" },
            .{ "Ὥ", "ὥ" },
            .{ "Ὦ", "ὦ" },
            .{ "Ὧ", "ὧ" },
            .{ "ᾈ", "ᾀ" },
            .{ "ᾉ", "ᾁ" },
            .{ "ᾊ", "ᾂ" },
            .{ "ᾋ", "ᾃ" },
            .{ "ᾌ", "ᾄ" },
            .{ "ᾍ", "ᾅ" },
            .{ "ᾎ", "ᾆ" },
            .{ "ᾏ", "ᾇ" },
            .{ "ᾘ", "ᾐ" },
            .{ "ᾙ", "ᾑ" },
            .{ "ᾚ", "ᾒ" },
            .{ "ᾛ", "ᾓ" },
            .{ "ᾜ", "ᾔ" },
            .{ "ᾝ", "ᾕ" },
            .{ "ᾞ", "ᾖ" },
            .{ "ᾟ", "ᾗ" },
            .{ "ᾨ", "ᾠ" },
            .{ "ᾩ", "ᾡ" },
            .{ "ᾪ", "ᾢ" },
            .{ "ᾫ", "ᾣ" },
            .{ "ᾬ", "ᾤ" },
            .{ "ᾭ", "ᾥ" },
            .{ "ᾮ", "ᾦ" },
            .{ "ᾯ", "ᾧ" },
            .{ "Ᾰ", "ᾰ" },
            .{ "Ᾱ", "ᾱ" },
            .{ "Ῐ", "ῐ" },
            .{ "Ῑ", "ῑ" },
            .{ "Ῠ", "ῠ" },
            .{ "Ῡ", "ῡ" },
            .{ "Ⓐ", "ⓐ" },
            .{ "Ⓑ", "ⓑ" },
            .{ "Ⓒ", "ⓒ" },
            .{ "Ⓓ", "ⓓ" },
            .{ "Ⓔ", "ⓔ" },
            .{ "Ⓕ", "ⓕ" },
            .{ "Ⓖ", "ⓖ" },
            .{ "Ⓗ", "ⓗ" },
            .{ "Ⓘ", "ⓘ" },
            .{ "Ⓙ", "ⓙ" },
            .{ "Ⓚ", "ⓚ" },
            .{ "Ⓛ", "ⓛ" },
            .{ "Ⓜ", "ⓜ" },
            .{ "Ⓝ", "ⓝ" },
            .{ "Ⓞ", "ⓞ" },
            .{ "Ⓟ", "ⓟ" },
            .{ "Ⓠ", "ⓠ" },
            .{ "Ⓡ", "ⓡ" },
            .{ "Ⓢ", "ⓢ" },
            .{ "Ⓣ", "ⓣ" },
            .{ "Ⓤ", "ⓤ" },
            .{ "Ⓥ", "ⓥ" },
            .{ "Ⓦ", "ⓦ" },
            .{ "Ⓧ", "ⓧ" },
            .{ "Ⓨ", "ⓨ" },
            .{ "Ⓩ", "ⓩ" },
            .{ "Ａ", "ａ" },
            .{ "Ｂ", "ｂ" },
            .{ "Ｃ", "ｃ" },
            .{ "Ｄ", "ｄ" },
            .{ "Ｅ", "ｅ" },
            .{ "Ｆ", "ｆ" },
            .{ "Ｇ", "ｇ" },
            .{ "Ｈ", "ｈ" },
            .{ "Ｉ", "ｉ" },
            .{ "Ｊ", "ｊ" },
            .{ "Ｋ", "ｋ" },
            .{ "Ｌ", "ｌ" },
            .{ "Ｍ", "ｍ" },
            .{ "Ｎ", "ｎ" },
            .{ "Ｏ", "ｏ" },
            .{ "Ｐ", "ｐ" },
            .{ "Ｑ", "ｑ" },
            .{ "Ｒ", "ｒ" },
            .{ "Ｓ", "ｓ" },
            .{ "Ｔ", "ｔ" },
            .{ "Ｕ", "ｕ" },
            .{ "Ｖ", "ｖ" },
            .{ "Ｗ", "ｗ" },
            .{ "Ｘ", "ｘ" },
            .{ "Ｙ", "ｙ" },
            .{ "Ｚ", "ｚ" },
        });

        if (self.buffer) |buffer| {
            var i: usize = 0;
            while (i < self.size) {
                const char_size = String.getUTF8Size(buffer[i]);
                if (upperToLowerMap.get(buffer[i .. i + char_size])) |replacement|
                    std.mem.copyForwards(u8, buffer[i .. i + char_size], replacement);
                i += char_size;
            }
        }
    }

    /// Converts all (including Unicode) characters lowercase to uppercase
    pub fn uniToUppercase(self: *String) !void {
        @setEvalBranchQuota(5000);
        const lowerToUpperMap = std.ComptimeStringMap([]const u8, .{
            .{ "a", "A" },
            .{ "b", "B" },
            .{ "c", "C" },
            .{ "d", "D" },
            .{ "e", "E" },
            .{ "f", "F" },
            .{ "g", "G" },
            .{ "h", "H" },
            .{ "i", "I" },
            .{ "j", "J" },
            .{ "k", "K" },
            .{ "l", "L" },
            .{ "m", "M" },
            .{ "n", "N" },
            .{ "o", "O" },
            .{ "p", "P" },
            .{ "q", "Q" },
            .{ "r", "R" },
            .{ "s", "S" },
            .{ "t", "T" },
            .{ "u", "U" },
            .{ "v", "V" },
            .{ "w", "W" },
            .{ "x", "X" },
            .{ "y", "Y" },
            .{ "z", "Z" },
            .{ "à", "À" },
            .{ "á", "Á" },
            .{ "â", "Â" },
            .{ "ã", "Ã" },
            .{ "ä", "Ä" },
            .{ "å", "Å" },
            .{ "æ", "Æ" },
            .{ "ç", "Ç" },
            .{ "è", "È" },
            .{ "é", "É" },
            .{ "ê", "Ê" },
            .{ "ë", "Ë" },
            .{ "ì", "Ì" },
            .{ "í", "Í" },
            .{ "î", "Î" },
            .{ "ï", "Ï" },
            .{ "ð", "Ð" },
            .{ "ñ", "Ñ" },
            .{ "ò", "Ò" },
            .{ "ó", "Ó" },
            .{ "ô", "Ô" },
            .{ "õ", "Õ" },
            .{ "ö", "Ö" },
            .{ "ø", "Ø" },
            .{ "ù", "Ù" },
            .{ "ú", "Ú" },
            .{ "û", "Û" },
            .{ "ü", "Ü" },
            .{ "ý", "Ý" },
            .{ "þ", "Þ" },
            .{ "ÿ", "Ÿ" },
            .{ "ā", "Ā" },
            .{ "ă", "Ă" },
            .{ "ą", "Ą" },
            .{ "ć", "Ć" },
            .{ "ĉ", "Ĉ" },
            .{ "ċ", "Ċ" },
            .{ "č", "Č" },
            .{ "ď", "Ď" },
            .{ "đ", "Đ" },
            .{ "ē", "Ē" },
            .{ "ĕ", "Ĕ" },
            .{ "ė", "Ė" },
            .{ "ę", "Ę" },
            .{ "ě", "Ě" },
            .{ "ĝ", "Ĝ" },
            .{ "ğ", "Ğ" },
            .{ "ġ", "Ġ" },
            .{ "ģ", "Ģ" },
            .{ "ĥ", "Ĥ" },
            .{ "ħ", "Ħ" },
            .{ "ĩ", "Ĩ" },
            .{ "ī", "Ī" },
            .{ "ĭ", "Ĭ" },
            .{ "į", "Į" },
            .{ "ı", "I" },
            .{ "ĳ", "Ĳ" },
            .{ "ĵ", "Ĵ" },
            .{ "ķ", "Ķ" },
            .{ "ĺ", "Ĺ" },
            .{ "ļ", "Ļ" },
            .{ "ľ", "Ľ" },
            .{ "ŀ", "Ŀ" },
            .{ "ł", "Ł" },
            .{ "ń", "Ń" },
            .{ "ņ", "Ņ" },
            .{ "ň", "Ň" },
            .{ "ŋ", "Ŋ" },
            .{ "ō", "Ō" },
            .{ "ŏ", "Ŏ" },
            .{ "ő", "Ő" },
            .{ "œ", "Œ" },
            .{ "ŕ", "Ŕ" },
            .{ "ŗ", "Ŗ" },
            .{ "ř", "Ř" },
            .{ "ś", "Ś" },
            .{ "ŝ", "Ŝ" },
            .{ "ş", "Ş" },
            .{ "š", "Š" },
            .{ "ţ", "Ţ" },
            .{ "ť", "Ť" },
            .{ "ŧ", "Ŧ" },
            .{ "ũ", "Ũ" },
            .{ "ū", "Ū" },
            .{ "ŭ", "Ŭ" },
            .{ "ů", "Ů" },
            .{ "ű", "Ű" },
            .{ "ų", "Ų" },
            .{ "ŵ", "Ŵ" },
            .{ "ŷ", "Ŷ" },
            .{ "ź", "Ź" },
            .{ "ż", "Ż" },
            .{ "ž", "Ž" },
            .{ "ƃ", "Ƃ" },
            .{ "ƅ", "Ƅ" },
            .{ "ƈ", "Ƈ" },
            .{ "ƌ", "Ƌ" },
            .{ "ƒ", "Ƒ" },
            .{ "ƙ", "Ƙ" },
            .{ "ơ", "Ơ" },
            .{ "ƣ", "Ƣ" },
            .{ "ƥ", "Ƥ" },
            .{ "ƨ", "Ƨ" },
            .{ "ƭ", "Ƭ" },
            .{ "ư", "Ư" },
            .{ "ƴ", "Ƴ" },
            .{ "ƶ", "Ƶ" },
            .{ "ƹ", "Ƹ" },
            .{ "ƽ", "Ƽ" },
            .{ "ǆ", "Ǆ" },
            .{ "ǉ", "Ǉ" },
            .{ "ǌ", "Ǌ" },
            .{ "ǎ", "Ǎ" },
            .{ "ǐ", "Ǐ" },
            .{ "ǒ", "Ǒ" },
            .{ "ǔ", "Ǔ" },
            .{ "ǖ", "Ǖ" },
            .{ "ǘ", "Ǘ" },
            .{ "ǚ", "Ǚ" },
            .{ "ǜ", "Ǜ" },
            .{ "ǟ", "Ǟ" },
            .{ "ǡ", "Ǡ" },
            .{ "ǣ", "Ǣ" },
            .{ "ǥ", "Ǥ" },
            .{ "ǧ", "Ǧ" },
            .{ "ǩ", "Ǩ" },
            .{ "ǫ", "Ǫ" },
            .{ "ǭ", "Ǭ" },
            .{ "ǯ", "Ǯ" },
            .{ "ǳ", "Ǳ" },
            .{ "ǵ", "Ǵ" },
            .{ "ǻ", "Ǻ" },
            .{ "ǽ", "Ǽ" },
            .{ "ǿ", "Ǿ" },
            .{ "ȁ", "Ȁ" },
            .{ "ȃ", "Ȃ" },
            .{ "ȅ", "Ȅ" },
            .{ "ȇ", "Ȇ" },
            .{ "ȉ", "Ȉ" },
            .{ "ȋ", "Ȋ" },
            .{ "ȍ", "Ȍ" },
            .{ "ȏ", "Ȏ" },
            .{ "ȑ", "Ȑ" },
            .{ "ȓ", "Ȓ" },
            .{ "ȕ", "Ȕ" },
            .{ "ȗ", "Ȗ" },
            .{ "ɓ", "Ɓ" },
            .{ "ɔ", "Ɔ" },
            .{ "ɗ", "Ɗ" },
            .{ "ɘ", "Ǝ" },
            .{ "ə", "Ə" },
            .{ "ɛ", "Ɛ" },
            .{ "ɠ", "Ɠ" },
            .{ "ɣ", "Ɣ" },
            .{ "ɨ", "Ɨ" },
            .{ "ɩ", "Ɩ" },
            .{ "ɯ", "Ɯ" },
            .{ "ɲ", "Ɲ" },
            .{ "ɵ", "Ɵ" },
            .{ "ʃ", "Ʃ" },
            .{ "ʈ", "Ʈ" },
            .{ "ʊ", "Ʊ" },
            .{ "ʋ", "Ʋ" },
            .{ "ʒ", "Ʒ" },
            .{ "ά", "Ά" },
            .{ "έ", "Έ" },
            .{ "ή", "Ή" },
            .{ "ί", "Ί" },
            .{ "α", "Α" },
            .{ "β", "Β" },
            .{ "γ", "Γ" },
            .{ "δ", "Δ" },
            .{ "ε", "Ε" },
            .{ "ζ", "Ζ" },
            .{ "η", "Η" },
            .{ "θ", "Θ" },
            .{ "ι", "Ι" },
            .{ "κ", "Κ" },
            .{ "λ", "Λ" },
            .{ "μ", "Μ" },
            .{ "ν", "Ν" },
            .{ "ξ", "Ξ" },
            .{ "ο", "Ο" },
            .{ "π", "Π" },
            .{ "ρ", "Ρ" },
            .{ "σ", "Σ" },
            .{ "τ", "Τ" },
            .{ "υ", "Υ" },
            .{ "φ", "Φ" },
            .{ "χ", "Χ" },
            .{ "ψ", "Ψ" },
            .{ "ω", "Ω" },
            .{ "ϊ", "Ϊ" },
            .{ "ϋ", "Ϋ" },
            .{ "ό", "Ό" },
            .{ "ύ", "Ύ" },
            .{ "ώ", "Ώ" },
            .{ "ϣ", "Ϣ" },
            .{ "ϥ", "Ϥ" },
            .{ "ϧ", "Ϧ" },
            .{ "ϩ", "Ϩ" },
            .{ "ϫ", "Ϫ" },
            .{ "ϭ", "Ϭ" },
            .{ "ϯ", "Ϯ" },
            .{ "а", "А" },
            .{ "б", "Б" },
            .{ "в", "В" },
            .{ "г", "Г" },
            .{ "д", "Д" },
            .{ "е", "Е" },
            .{ "ж", "Ж" },
            .{ "з", "З" },
            .{ "и", "И" },
            .{ "й", "Й" },
            .{ "к", "К" },
            .{ "л", "Л" },
            .{ "м", "М" },
            .{ "н", "Н" },
            .{ "о", "О" },
            .{ "п", "П" },
            .{ "р", "Р" },
            .{ "с", "С" },
            .{ "т", "Т" },
            .{ "у", "У" },
            .{ "ф", "Ф" },
            .{ "х", "Х" },
            .{ "ц", "Ц" },
            .{ "ч", "Ч" },
            .{ "ш", "Ш" },
            .{ "щ", "Щ" },
            .{ "ъ", "Ъ" },
            .{ "ы", "Ы" },
            .{ "ь", "Ь" },
            .{ "э", "Э" },
            .{ "ю", "Ю" },
            .{ "я", "Я" },
            .{ "ё", "Ё" },
            .{ "ђ", "Ђ" },
            .{ "ѓ", "Ѓ" },
            .{ "є", "Є" },
            .{ "ѕ", "Ѕ" },
            .{ "і", "І" },
            .{ "ї", "Ї" },
            .{ "ј", "Ј" },
            .{ "љ", "Љ" },
            .{ "њ", "Њ" },
            .{ "ћ", "Ћ" },
            .{ "ќ", "Ќ" },
            .{ "ў", "Ў" },
            .{ "џ", "Џ" },
            .{ "ѡ", "Ѡ" },
            .{ "ѣ", "Ѣ" },
            .{ "ѥ", "Ѥ" },
            .{ "ѧ", "Ѧ" },
            .{ "ѩ", "Ѩ" },
            .{ "ѫ", "Ѫ" },
            .{ "ѭ", "Ѭ" },
            .{ "ѯ", "Ѯ" },
            .{ "ѱ", "Ѱ" },
            .{ "ѳ", "Ѳ" },
            .{ "ѵ", "Ѵ" },
            .{ "ѷ", "Ѷ" },
            .{ "ѹ", "Ѹ" },
            .{ "ѻ", "Ѻ" },
            .{ "ѽ", "Ѽ" },
            .{ "ѿ", "Ѿ" },
            .{ "ҁ", "Ҁ" },
            .{ "ґ", "Ґ" },
            .{ "ғ", "Ғ" },
            .{ "ҕ", "Ҕ" },
            .{ "җ", "Җ" },
            .{ "ҙ", "Ҙ" },
            .{ "қ", "Қ" },
            .{ "ҝ", "Ҝ" },
            .{ "ҟ", "Ҟ" },
            .{ "ҡ", "Ҡ" },
            .{ "ң", "Ң" },
            .{ "ҥ", "Ҥ" },
            .{ "ҧ", "Ҧ" },
            .{ "ҩ", "Ҩ" },
            .{ "ҫ", "Ҫ" },
            .{ "ҭ", "Ҭ" },
            .{ "ү", "Ү" },
            .{ "ұ", "Ұ" },
            .{ "ҳ", "Ҳ" },
            .{ "ҵ", "Ҵ" },
            .{ "ҷ", "Ҷ" },
            .{ "ҹ", "Ҹ" },
            .{ "һ", "Һ" },
            .{ "ҽ", "Ҽ" },
            .{ "ҿ", "Ҿ" },
            .{ "ӂ", "Ӂ" },
            .{ "ӄ", "Ӄ" },
            .{ "ӈ", "Ӈ" },
            .{ "ӌ", "Ӌ" },
            .{ "ӑ", "Ӑ" },
            .{ "ӓ", "Ӓ" },
            .{ "ӕ", "Ӕ" },
            .{ "ӗ", "Ӗ" },
            .{ "ә", "Ә" },
            .{ "ӛ", "Ӛ" },
            .{ "ӝ", "Ӝ" },
            .{ "ӟ", "Ӟ" },
            .{ "ӡ", "Ӡ" },
            .{ "ӣ", "Ӣ" },
            .{ "ӥ", "Ӥ" },
            .{ "ӧ", "Ӧ" },
            .{ "ө", "Ө" },
            .{ "ӫ", "Ӫ" },
            .{ "ӯ", "Ӯ" },
            .{ "ӱ", "Ӱ" },
            .{ "ӳ", "Ӳ" },
            .{ "ӵ", "Ӵ" },
            .{ "ӹ", "Ӹ" },
            .{ "ա", "Ա" },
            .{ "բ", "Բ" },
            .{ "գ", "Գ" },
            .{ "դ", "Դ" },
            .{ "ե", "Ե" },
            .{ "զ", "Զ" },
            .{ "է", "Է" },
            .{ "ը", "Ը" },
            .{ "թ", "Թ" },
            .{ "ժ", "Ժ" },
            .{ "ի", "Ի" },
            .{ "լ", "Լ" },
            .{ "խ", "Խ" },
            .{ "ծ", "Ծ" },
            .{ "կ", "Կ" },
            .{ "հ", "Հ" },
            .{ "ձ", "Ձ" },
            .{ "ղ", "Ղ" },
            .{ "ճ", "Ճ" },
            .{ "մ", "Մ" },
            .{ "յ", "Յ" },
            .{ "ն", "Ն" },
            .{ "շ", "Շ" },
            .{ "ո", "Ո" },
            .{ "չ", "Չ" },
            .{ "պ", "Պ" },
            .{ "ջ", "Ջ" },
            .{ "ռ", "Ռ" },
            .{ "ս", "Ս" },
            .{ "վ", "Վ" },
            .{ "տ", "Տ" },
            .{ "ր", "Ր" },
            .{ "ց", "Ց" },
            .{ "ւ", "Ւ" },
            .{ "փ", "Փ" },
            .{ "ք", "Ք" },
            .{ "օ", "Օ" },
            .{ "ֆ", "Ֆ" },
            .{ "ა", "Ⴀ" },
            .{ "ბ", "Ⴁ" },
            .{ "გ", "Ⴂ" },
            .{ "დ", "Ⴃ" },
            .{ "ე", "Ⴄ" },
            .{ "ვ", "Ⴅ" },
            .{ "ზ", "Ⴆ" },
            .{ "თ", "Ⴇ" },
            .{ "ი", "Ⴈ" },
            .{ "კ", "Ⴉ" },
            .{ "ლ", "Ⴊ" },
            .{ "მ", "Ⴋ" },
            .{ "ნ", "Ⴌ" },
            .{ "ო", "Ⴍ" },
            .{ "პ", "Ⴎ" },
            .{ "ჟ", "Ⴏ" },
            .{ "რ", "Ⴐ" },
            .{ "ს", "Ⴑ" },
            .{ "ტ", "Ⴒ" },
            .{ "უ", "Ⴓ" },
            .{ "ფ", "Ⴔ" },
            .{ "ქ", "Ⴕ" },
            .{ "ღ", "Ⴖ" },
            .{ "ყ", "Ⴗ" },
            .{ "შ", "Ⴘ" },
            .{ "ჩ", "Ⴙ" },
            .{ "ც", "Ⴚ" },
            .{ "ძ", "Ⴛ" },
            .{ "წ", "Ⴜ" },
            .{ "ჭ", "Ⴝ" },
            .{ "ხ", "Ⴞ" },
            .{ "ჯ", "Ⴟ" },
            .{ "ჰ", "Ⴠ" },
            .{ "ჱ", "Ⴡ" },
            .{ "ჲ", "Ⴢ" },
            .{ "ჳ", "Ⴣ" },
            .{ "ჴ", "Ⴤ" },
            .{ "ჵ", "Ⴥ" },
            .{ "ḁ", "Ḁ" },
            .{ "ḃ", "Ḃ" },
            .{ "ḅ", "Ḅ" },
            .{ "ḇ", "Ḇ" },
            .{ "ḉ", "Ḉ" },
            .{ "ḋ", "Ḋ" },
            .{ "ḍ", "Ḍ" },
            .{ "ḏ", "Ḏ" },
            .{ "ḑ", "Ḑ" },
            .{ "ḓ", "Ḓ" },
            .{ "ḕ", "Ḕ" },
            .{ "ḗ", "Ḗ" },
            .{ "ḙ", "Ḙ" },
            .{ "ḛ", "Ḛ" },
            .{ "ḝ", "Ḝ" },
            .{ "ḟ", "Ḟ" },
            .{ "ḡ", "Ḡ" },
            .{ "ḣ", "Ḣ" },
            .{ "ḥ", "Ḥ" },
            .{ "ḧ", "Ḧ" },
            .{ "ḩ", "Ḩ" },
            .{ "ḫ", "Ḫ" },
            .{ "ḭ", "Ḭ" },
            .{ "ḯ", "Ḯ" },
            .{ "ḱ", "Ḱ" },
            .{ "ḳ", "Ḳ" },
            .{ "ḵ", "Ḵ" },
            .{ "ḷ", "Ḷ" },
            .{ "ḹ", "Ḹ" },
            .{ "ḻ", "Ḻ" },
            .{ "ḽ", "Ḽ" },
            .{ "ḿ", "Ḿ" },
            .{ "ṁ", "Ṁ" },
            .{ "ṃ", "Ṃ" },
            .{ "ṅ", "Ṅ" },
            .{ "ṇ", "Ṇ" },
            .{ "ṉ", "Ṉ" },
            .{ "ṋ", "Ṋ" },
            .{ "ṍ", "Ṍ" },
            .{ "ṏ", "Ṏ" },
            .{ "ṑ", "Ṑ" },
            .{ "ṓ", "Ṓ" },
            .{ "ṕ", "Ṕ" },
            .{ "ṗ", "Ṗ" },
            .{ "ṙ", "Ṙ" },
            .{ "ṛ", "Ṛ" },
            .{ "ṝ", "Ṝ" },
            .{ "ṟ", "Ṟ" },
            .{ "ṡ", "Ṡ" },
            .{ "ṣ", "Ṣ" },
            .{ "ṥ", "Ṥ" },
            .{ "ṧ", "Ṧ" },
            .{ "ṩ", "Ṩ" },
            .{ "ṫ", "Ṫ" },
            .{ "ṭ", "Ṭ" },
            .{ "ṯ", "Ṯ" },
            .{ "ṱ", "Ṱ" },
            .{ "ṳ", "Ṳ" },
            .{ "ṵ", "Ṵ" },
            .{ "ṷ", "Ṷ" },
            .{ "ṹ", "Ṹ" },
            .{ "ṻ", "Ṻ" },
            .{ "ṽ", "Ṽ" },
            .{ "ṿ", "Ṿ" },
            .{ "ẁ", "Ẁ" },
            .{ "ẃ", "Ẃ" },
            .{ "ẅ", "Ẅ" },
            .{ "ẇ", "Ẇ" },
            .{ "ẉ", "Ẉ" },
            .{ "ẋ", "Ẋ" },
            .{ "ẍ", "Ẍ" },
            .{ "ẏ", "Ẏ" },
            .{ "ẑ", "Ẑ" },
            .{ "ẓ", "Ẓ" },
            .{ "ẕ", "Ẕ" },
            .{ "ạ", "Ạ" },
            .{ "ả", "Ả" },
            .{ "ấ", "Ấ" },
            .{ "ầ", "Ầ" },
            .{ "ẩ", "Ẩ" },
            .{ "ẫ", "Ẫ" },
            .{ "ậ", "Ậ" },
            .{ "ắ", "Ắ" },
            .{ "ằ", "Ằ" },
            .{ "ẳ", "Ẳ" },
            .{ "ẵ", "Ẵ" },
            .{ "ặ", "Ặ" },
            .{ "ẹ", "Ẹ" },
            .{ "ẻ", "Ẻ" },
            .{ "ẽ", "Ẽ" },
            .{ "ế", "Ế" },
            .{ "ề", "Ề" },
            .{ "ể", "Ể" },
            .{ "ễ", "Ễ" },
            .{ "ệ", "Ệ" },
            .{ "ỉ", "Ỉ" },
            .{ "ị", "Ị" },
            .{ "ọ", "Ọ" },
            .{ "ỏ", "Ỏ" },
            .{ "ố", "Ố" },
            .{ "ồ", "Ồ" },
            .{ "ổ", "Ổ" },
            .{ "ỗ", "Ỗ" },
            .{ "ộ", "Ộ" },
            .{ "ớ", "Ớ" },
            .{ "ờ", "Ờ" },
            .{ "ở", "Ở" },
            .{ "ỡ", "Ỡ" },
            .{ "ợ", "Ợ" },
            .{ "ụ", "Ụ" },
            .{ "ủ", "Ủ" },
            .{ "ứ", "Ứ" },
            .{ "ừ", "Ừ" },
            .{ "ử", "Ử" },
            .{ "ữ", "Ữ" },
            .{ "ự", "Ự" },
            .{ "ỳ", "Ỳ" },
            .{ "ỵ", "Ỵ" },
            .{ "ỷ", "Ỷ" },
            .{ "ỹ", "Ỹ" },
            .{ "ἀ", "Ἀ" },
            .{ "ἁ", "Ἁ" },
            .{ "ἂ", "Ἂ" },
            .{ "ἃ", "Ἃ" },
            .{ "ἄ", "Ἄ" },
            .{ "ἅ", "Ἅ" },
            .{ "ἆ", "Ἆ" },
            .{ "ἇ", "Ἇ" },
            .{ "ἐ", "Ἐ" },
            .{ "ἑ", "Ἑ" },
            .{ "ἒ", "Ἒ" },
            .{ "ἓ", "Ἓ" },
            .{ "ἔ", "Ἔ" },
            .{ "ἕ", "Ἕ" },
            .{ "ἠ", "Ἠ" },
            .{ "ἡ", "Ἡ" },
            .{ "ἢ", "Ἢ" },
            .{ "ἣ", "Ἣ" },
            .{ "ἤ", "Ἤ" },
            .{ "ἥ", "Ἥ" },
            .{ "ἦ", "Ἦ" },
            .{ "ἧ", "Ἧ" },
            .{ "ἰ", "Ἰ" },
            .{ "ἱ", "Ἱ" },
            .{ "ἲ", "Ἲ" },
            .{ "ἳ", "Ἳ" },
            .{ "ἴ", "Ἴ" },
            .{ "ἵ", "Ἵ" },
            .{ "ἶ", "Ἶ" },
            .{ "ἷ", "Ἷ" },
            .{ "ὀ", "Ὀ" },
            .{ "ὁ", "Ὁ" },
            .{ "ὂ", "Ὂ" },
            .{ "ὃ", "Ὃ" },
            .{ "ὄ", "Ὄ" },
            .{ "ὅ", "Ὅ" },
            .{ "ὑ", "Ὑ" },
            .{ "ὓ", "Ὓ" },
            .{ "ὕ", "Ὕ" },
            .{ "ὗ", "Ὗ" },
            .{ "ὠ", "Ὠ" },
            .{ "ὡ", "Ὡ" },
            .{ "ὢ", "Ὢ" },
            .{ "ὣ", "Ὣ" },
            .{ "ὤ", "Ὤ" },
            .{ "ὥ", "Ὥ" },
            .{ "ὦ", "Ὦ" },
            .{ "ὧ", "Ὧ" },
            .{ "ᾀ", "ᾈ" },
            .{ "ᾁ", "ᾉ" },
            .{ "ᾂ", "ᾊ" },
            .{ "ᾃ", "ᾋ" },
            .{ "ᾄ", "ᾌ" },
            .{ "ᾅ", "ᾍ" },
            .{ "ᾆ", "ᾎ" },
            .{ "ᾇ", "ᾏ" },
            .{ "ᾐ", "ᾘ" },
            .{ "ᾑ", "ᾙ" },
            .{ "ᾒ", "ᾚ" },
            .{ "ᾓ", "ᾛ" },
            .{ "ᾔ", "ᾜ" },
            .{ "ᾕ", "ᾝ" },
            .{ "ᾖ", "ᾞ" },
            .{ "ᾗ", "ᾟ" },
            .{ "ᾠ", "ᾨ" },
            .{ "ᾡ", "ᾩ" },
            .{ "ᾢ", "ᾪ" },
            .{ "ᾣ", "ᾫ" },
            .{ "ᾤ", "ᾬ" },
            .{ "ᾥ", "ᾭ" },
            .{ "ᾦ", "ᾮ" },
            .{ "ᾧ", "ᾯ" },
            .{ "ᾰ", "Ᾰ" },
            .{ "ᾱ", "Ᾱ" },
            .{ "ῐ", "Ῐ" },
            .{ "ῑ", "Ῑ" },
            .{ "ῠ", "Ῠ" },
            .{ "ῡ", "Ῡ" },
            .{ "ⓐ", "Ⓐ" },
            .{ "ⓑ", "Ⓑ" },
            .{ "ⓒ", "Ⓒ" },
            .{ "ⓓ", "Ⓓ" },
            .{ "ⓔ", "Ⓔ" },
            .{ "ⓕ", "Ⓕ" },
            .{ "ⓖ", "Ⓖ" },
            .{ "ⓗ", "Ⓗ" },
            .{ "ⓘ", "Ⓘ" },
            .{ "ⓙ", "Ⓙ" },
            .{ "ⓚ", "Ⓚ" },
            .{ "ⓛ", "Ⓛ" },
            .{ "ⓜ", "Ⓜ" },
            .{ "ⓝ", "Ⓝ" },
            .{ "ⓞ", "Ⓞ" },
            .{ "ⓟ", "Ⓟ" },
            .{ "ⓠ", "Ⓠ" },
            .{ "ⓡ", "Ⓡ" },
            .{ "ⓢ", "Ⓢ" },
            .{ "ⓣ", "Ⓣ" },
            .{ "ⓤ", "Ⓤ" },
            .{ "ⓥ", "Ⓥ" },
            .{ "ⓦ", "Ⓦ" },
            .{ "ⓧ", "Ⓧ" },
            .{ "ⓨ", "Ⓨ" },
            .{ "ⓩ", "Ⓩ" },
            .{ "ａ", "Ａ" },
            .{ "ｂ", "Ｂ" },
            .{ "ｃ", "Ｃ" },
            .{ "ｄ", "Ｄ" },
            .{ "ｅ", "Ｅ" },
            .{ "ｆ", "Ｆ" },
            .{ "ｇ", "Ｇ" },
            .{ "ｈ", "Ｈ" },
            .{ "ｉ", "Ｉ" },
            .{ "ｊ", "Ｊ" },
            .{ "ｋ", "Ｋ" },
            .{ "ｌ", "Ｌ" },
            .{ "ｍ", "Ｍ" },
            .{ "ｎ", "Ｎ" },
            .{ "ｏ", "Ｏ" },
            .{ "ｐ", "Ｐ" },
            .{ "ｑ", "Ｑ" },
            .{ "ｒ", "Ｒ" },
            .{ "ｓ", "Ｓ" },
            .{ "ｔ", "Ｔ" },
            .{ "ｕ", "Ｕ" },
            .{ "ｖ", "Ｖ" },
            .{ "ｗ", "Ｗ" },
            .{ "ｘ", "Ｘ" },
            .{ "ｙ", "Ｙ" },
            .{ "ｚ", "Ｚ" },
        });

        if (self.buffer) |buffer| {
            var i: usize = 0;
            while (i < self.size) {
                const char_size = String.getUTF8Size(buffer[i]);
                if (lowerToUpperMap.get(buffer[i .. i + char_size])) |replacement|
                    std.mem.copyForwards(u8, buffer[i .. i + char_size], replacement);
                i += char_size;
            }
        }
    }
};
