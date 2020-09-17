const std = @import("std");
const assert = std.debug.assert;

/// A variable length collection of characters
pub const String = struct {
    /// The internal character buffer
    buffer: ?[]u8,
    /// The allocator used for managing the buffer
    allocator: *std.mem.Allocator,
    /// The total size of the String
    size: usize,

    /// Errors that may occur when using String
    pub const Error = error{
        OutOfMemory,
        InvalidRange,
    };

    /// Creates a String with an Allocator
    /// User is responsible for managing the new String
    pub fn init(allocator: *std.mem.Allocator) String {
        return .{
            .buffer = null,
            .allocator = allocator,
            .size = 0,
        };
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
            self.buffer = self.allocator.realloc(buffer, bytes) catch |err| {
                return Error.OutOfMemory;
            };
        } else {
            self.buffer = self.allocator.alloc(u8, bytes) catch |err| {
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
            if (Utility.getIndex(buffer, index, true)) |k| {
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
                const size = Utility.getUTF8Size(buffer[i]);
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
        if (self.buffer) |buffer| {
            const string = self.str();
            if (self.allocator.alloc(u8, string.len)) |newStr| {
                std.mem.copy(u8, newStr, string);
                return newStr;
            } else |err| {
                return Error.OutOfMemory;
            }
        }

        return null;
    }

    /// Returns a character at the specified index
    pub fn charAt(self: String, index: usize) ?[]const u8 {
        if (self.buffer) |buffer| {
            if (Utility.getIndex(buffer, index, true)) |i| {
                const size = Utility.getUTF8Size(buffer[i]);
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
                i += Utility.getUTF8Size(buffer[i]);
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
            var i: usize = 0;
            var j: usize = 0;
            while (i < self.size) : (i += 1) {
                if (buffer[i] == literal[j]) {
                    if (j >= literal.len - 1)
                        return Utility.getIndex(buffer, i - j, false);
                    j += 1;
                } else {
                    j = 0;
                }
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
            const rStart = Utility.getIndex(buffer, start, true).?;
            const rEnd = Utility.getIndex(buffer, end, true).?;
            const difference = rEnd - rStart;

            var i: usize = rEnd;
            while (i < self.size) : (i += 1) {
                buffer[i - difference] = buffer[i];
            }

            self.size -= difference;
        }
    }

    /// Trims all whitespace at the start of the String
    pub fn trimStart(self: *String) void {
        if (self.buffer) |buffer| {
            var i: usize = 0;
            while (i < self.size) {
                const size = Utility.getUTF8Size(buffer[i]);
                if (!Utility.isWhitespace(buffer[i])) break;
                i += size;
            }

            if (Utility.getIndex(buffer, i, false)) |k| {
                self.removeRange(0, k) catch |err| {};
            }
        }
    }

    /// Trims all whitespace characters at the end of the String
    pub fn trimEnd(self: *String) void {
        if (self.buffer) |buffer| {
            var i: usize = self.size - 1;
            var j: usize = 0;
            while (i >= 0) : ({
                i -= 1;
                j += 1;
            }) {
                if (!Utility.isWhitespace(buffer[i])) break;
                if (i == 0) break;
            }

            self.size -= j;
        }
    }

    /// Trims all whitespace from both ends of the String
    pub fn trim(self: *String) void {
        self.trimStart();
        self.trimEnd();
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
            std.mem.reverse(u8, buffer[0..self.size]);
            var i: usize = self.size - 1;
            while (i >= 0) : (i -= 1) {
                const size = Utility.getUTF8Size(buffer[i]) - 1;
                if (size > 0) {
                    std.mem.reverse(u8, buffer[(i - size)..(i + 1)]);
                }
                i -= size;
                if (i == 0) break;
            }
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

    /// Splits the String into a slice based on a delimiter and an index
    pub fn split(self: String, delimiter: []const u8, index: usize) ?[]const u8 {
        if (self.buffer) |buffer| {
            var i: usize = 0;
            var block: usize = 0;
            var start: usize = 0;

            while (i < self.size) {
                const size = Utility.getUTF8Size(buffer[i]);
                if (size == delimiter.len) {
                    if (std.mem.eql(u8, delimiter, buffer[i..(i + size)])) {
                        if (block == index) return buffer[start..i];
                        start = i + size;
                        block += 1;
                    }
                }

                i += size;
            }
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
            while (i < self.size) : (i += 1) {
                if (buffer[i] >= 65 and buffer[i] <= 90) {
                    buffer[i] += 32;
                }
            }
        }
    }

    /// Converts all (ASCII) uppercase letters to lowercase
    pub fn toUppercase(self: *String) void {
        if (self.buffer) |buffer| {
            var i: usize = 0;
            while (i < self.size) : (i += 1) {
                if (buffer[i] >= 97 and buffer[i] <= 122) {
                    buffer[i] -= 32;
                }
            }
        }
    }

    /// Creates a String from a given range
    /// User is responsible for managing the new String
    pub fn substr(self: String, start: usize, end: usize) Error!String {
        var result = String.init(self.allocator);

        if (self.buffer) |buffer| {
            if (Utility.getIndex(buffer, start, true)) |rStart| {
                if (Utility.getIndex(buffer, end, true)) |rEnd| {
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
            string: *String,
            index: usize,

            pub fn next(it: *StringIterator) ?[]const u8 {
                if (it.string.buffer) |buffer| {
                    if (it.index == it.string.size) return null;
                    var i = it.index;
                    it.index += Utility.getUTF8Size(buffer[i]);
                    return buffer[i..it.index];
                } else {
                    return null;
                }
            }
        };

        pub fn iterator(self: *String) StringIterator {
            return StringIterator{
                .string = self,
                .index = 0,
            };
        }
    };
};

/// Contains UTF-8 utility functions
pub const Utility = struct {
    /// Returns whether a character is whitespace
    pub inline fn isWhitespace(ch: u8) bool {
        return ch == ' ' or ch == '\n' or ch == '\t' or ch == '\r';
    }

    /// Checks if byte is part of UTF-8 character
    pub inline fn isUTF8Byte(byte: u8) bool {
        return ((byte & 0x80) > 0) and (((byte << 1) & 0x80) == 0);
    }

    /// Returns the real index of a unicode string literal
    pub fn getIndex(unicode: []const u8, index: usize, real: bool) ?usize {
        var i: usize = 0;
        var j: usize = 0;
        while (i < unicode.len) {
            if (real) {
                if (j == index) return i;
            } else {
                if (i == index) return j;
            }
            i += Utility.getUTF8Size(unicode[i]);
            j += 1;
        }

        return null;
    }

    /// Returns the UTF-8 character's size
    pub inline fn getUTF8Size(char: u8) u3 {
        if (char & 0x80 == 0) {
            return 1;
        } else if ((char << 2) & 0x80 == 0) {
            return 2;
        } else if ((char << 3) & 0x80 == 0) {
            return 3;
        } else {
            return 4;
        }
    }
};
