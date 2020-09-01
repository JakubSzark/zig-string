const std = @import("std");
const Allocator = std.mem.Allocator;
const ArenaAllocator = std.heap.ArenaAllocator;
const defaultCapacity: usize = 16;

const StringError = error{
    OutOfMemory,
    InvalidRange,
};
/// A variable length string literal
// TODO: Add Memory Warnings
// TODO: Determine if Error or Optional Return
pub const String = struct {
    /// The internal buffer of the string.
    /// Use str() instead of accessing the buffer itself.
    buffer: ?[]u8,
    /// The allocator to use when managing the buffer
    allocator: *Allocator,
    /// The length of the String.
    len: usize,

    /// Creates a String with the desired Allocator
    pub fn init(allocator: *Allocator) String {
        return .{
            .buffer = null,
            .allocator = allocator,
            .len = 0,
        };
    }

    /// De-allocates the String's internal buffer
    pub fn deinit(self: String) void {
        if (self.buffer) |buffer| {
            self.allocator.free(buffer);
        }
    }

    /// Clears the contents of the String but leaves its capacity.
    pub fn clear(self: *String) void {
        if (self.buffer) |buffer| {
            for (buffer) |*ch| *ch = 0;
        }
        self.len = 0;
    }

    /// Allocates the internal buffer with the specified capacity.
    pub fn setCapacity(self: *String, newCapacity: usize) StringError!void {
        if (self.buffer) |buffer| {
            if (newCapacity == buffer.len) return;
            if (self.allocator.realloc(buffer, newCapacity)) |newBuffer| {
                if (newCapacity < self.len) self.len = newCapacity;
                self.buffer = newBuffer;
            } else |err| {
                return StringError.OutOfMemory;
            }
        } else {
            if (self.allocator.alloc(u8, newCapacity)) |newBuffer| {
                self.buffer = newBuffer;
            } else |err| {
                return StringError.OutOfMemory;
            }
        }
    }

    /// Returns the internal capacity of the String
    pub fn capacity(self: String) usize {
        if (self.buffer) |buffer| {
            return buffer.len;
        } else {
            return 0;
        }
    }

    /// Returns the String as a string literal.
    /// This is preferred way to read the String.
    pub fn str(self: String) []const u8 {
        if (self.buffer) |buffer| {
            return buffer[0..self.len];
        } else {
            return "";
        }
    }

    /// Concatinates a string literal to this String.
    pub fn concat(self: *String, literal: []const u8) StringError!void {
        if (self.buffer) |buffer| {
            // If the `literal` size is bigger than the capacity. Make more space!
            if ((literal.len + self.len) > buffer.len) {
                try self.setCapacity((literal.len * 2) + self.len);
            }
        } else {
            try self.setCapacity(literal.len);
        }

        // Copy `literal` contents to the end of this String
        std.mem.copy(u8, self.buffer.?[self.len..], literal);
        self.len += literal.len;
    }

    /// Appends a character to the end of the String
    pub fn push(self: *String, char: u8) StringError!void {
        if (self.buffer) |buffer| {
            if (self.len + 1 > buffer.len) {
                try self.setCapacity(buffer.len * 2);
            }
        } else {
            try self.setCapacity(defaultCapacity);
        }

        self.buffer.?[self.len] = char;
        self.len += 1;
    }

    /// Compares this String with a string literal.
    pub fn cmp(self: String, other: []const u8) bool {
        return std.mem.eql(u8, self.str(), other);
    }

    /// Removes the last character from the String.
    /// Returns the removed character if successful.
    pub fn pop(self: *String) ?u8 {
        if (self.len > 0) {
            if (self.buffer) |buffer| {
                const result = buffer[self.len - 1];
                self.len -= 1;
                return result;
            }
        }

        return null;
    }

    /// Creates a String from a slice
    pub fn substr(self: String, start: usize, end: usize) StringError!String {
        var result = String.init(self.allocator);
        if (end < start or end > self.len) return StringError.InvalidRange;
        try result.concat(self.str()[start..end]);
        return result;
    }

    /// Removes a character at the specified index.
    /// Returns the removed character is successful.
    pub fn remove(self: *String, index: usize) ?u8 {
        if (index < self.len) {
            if (self.buffer) |buffer| {
                var i: usize = index;
                const ch = buffer[index];
                while (i + 1 < self.len) : (i += 1) {
                    buffer[i] = buffer[i + 1];
                }

                self.len -= 1;
                return ch;
            }
        }

        return null;
    }

    /// Removes a range of characters from the String.
    /// Start (inclusive) - End (exclusive)
    pub fn removeRange(self: *String, start: usize, end: usize) StringError!void {
        if (end < start or end > self.len) return StringError.InvalidRange;

        if (self.buffer) |buffer| {
            var i: usize = end;
            const range = (end - start);
            while (i < self.len) : (i += 1) {
                buffer[i - range] = buffer[i];
            }

            self.len -= range;
        }
    }

    /// Checks whether this String contains the string literal
    pub fn contains(self: String, literal: []const u8) bool {
        var i: usize = 0;
        var j: usize = 0;

        if (self.buffer) |buffer| {
            while (i < self.len) : (i += 1) {
                if (buffer[i] == literal[j]) {
                    j += 1;
                    if (j >= literal.len) {
                        return true;
                    }
                } else {
                    j = 0;
                }
            }
        }

        return false;
    }

    /// Determines whether a character is whitespace
    fn isWhitespace(char: u8) bool {
        return char == ' ' or char == '\t' or char == '\n' or char == '\r';
    }

    /// Removes all whitespace on the left of the String
    pub fn trimStart(self: *String) void {
        var i: usize = 0;
        if (self.buffer) |buffer| {
            while (isWhitespace(buffer[i])) : (i += 1) {}
            var j: usize = 0;
            var k: usize = i;
            while (k < self.len) : ({
                j += 1;
                k += 1;
            }) {
                buffer[j] = buffer[k];
            }

            self.len -= i;
        }
    }

    /// Removes all whitespace on the right of the String
    pub fn trimEnd(self: *String) void {
        if (self.buffer) |buffer| {
            var i: usize = self.len - 1;
            var j: usize = 0;
            while (isWhitespace(buffer[i])) : ({
                i -= 1;
                j += 1;
            }) {}
            self.len -= j;
        }
    }

    /// Removes all whitespace from the left and right of the String
    pub fn trim(self: *String) void {
        self.trimStart();
        self.trimEnd();
    }

    /// Converts all uppercase letters to lowercase
    pub fn toLowercase(self: *String) void {
        if (self.buffer) |buffer| {
            var i: usize = 0;
            while (i < self.len) : (i += 1) {
                if (buffer[i] >= 65 and buffer[i] <= 90) {
                    buffer[i] += 32;
                }
            }
        }
    }

    /// Converts all uppercase letters to lowercase
    pub fn toUppercase(self: *String) void {
        if (self.buffer) |buffer| {
            var i: usize = 0;
            while (i < self.len) : (i += 1) {
                if (buffer[i] >= 97 and buffer[i] <= 122) {
                    buffer[i] -= 32;
                }
            }
        }
    }

    /// Returns the index of first instance of a character from the String
    pub fn find(self: *String, char: u8) ?usize {
        if (self.buffer) |buffer| {
            var i: usize = 0;
            while (i < self.len) : (i += 1) {
                if (buffer[i] == char) return i;
            }
        }

        return null;
    }

    /// Splits the String into a slice based on a delimiter and an index.
    pub fn split(self: String, delimiter: u8, index: usize) ?[]u8 {
        if (self.buffer) |buffer| {
            var i: usize = 0;
            var j: usize = 0;
            var k: usize = 0;
            while (i < self.len and k < self.len) : (i += 1) {
                if (j == index and i == self.len - 1) {
                    return buffer[k..self.len];
                }

                if (buffer[i] == delimiter) {
                    if (j == index) {
                        return buffer[k..i];
                    }

                    j += 1;
                    k = i + 1;
                }
            }
        }

        return null;
    }

    /// Inserts a character into the String at the specified index
    pub fn insert(self: *String, char: u8, index: usize) StringError!void {
        if (self.buffer) |buffer| {
            if (index >= self.len) {
                try self.push(char);
                return;
            }

            if (self.len + 1 > buffer.len) {
                try self.setCapacity(self.len * 2);
            }

            self.len += 1;

            var i: usize = index;
            var temp: u8 = buffer[i];
            while (i < self.len) : (i += 1) {
                if (i == index) {
                    buffer[i] = char;
                    continue;
                }

                const temp2 = buffer[i];
                buffer[i] = temp;
                temp = temp2;
            }
        }
    }

    /// Inserts a string literal into the String at the specified index
    pub fn insertStr(self: *String, literal: []const u8, index: usize) StringError!void {
        if (self.buffer) |buffer| {
            if (index >= self.len) {
                try self.concat(literal);
                return;
            }

            try self.setCapacity(self.len + literal.len);
            std.mem.copy(u8, buffer[(index + literal.len)..], buffer[index..self.len]);
            std.mem.copy(u8, buffer[index..], literal);
            self.len += literal.len;
        }
    }

    /// Reverses all the characters in the String
    pub fn reverse(self: *String) void {
        if (self.buffer) |buffer| {
            var i: usize = 0;
            var j: usize = self.len - 1;
            while (i != j and j > i) : ({
                i += 1;
                j -= 1;
            }) {
                const temp = buffer[i];
                buffer[i] = buffer[j];
                buffer[j] = temp;
            }
        }
    }

    /// Copies this String into a new String
    pub fn clone(self: String) StringError!String {
        return self.substr(0, self.len);
    }

    /// Reduces the capacity of the String to its len
    pub fn compact(self: *String) StringError!void {
        if (self.capacity() == self.len) return;
        try self.setCapacity(self.len);
    }

    /// Returns whether the length of the String is zero
    pub fn isEmpty(self: String) bool {
        return self.len == 0;
    }

    /// Repeats the String n times
    pub fn repeat(self: *String, n: usize) StringError!void {
        try self.setCapacity(self.len * (n + 1));
        if (self.buffer) |buffer| {
            var i: usize = 1;
            var j: usize = 0;
            while (i <= n) : (i += 1) {
                while (j < self.len) : (j += 1) {
                    buffer[((i * self.len) + j)] = buffer[j];
                }

                j = 0;
            }

            self.len *= (n + 1);
        }
    }

    /// Returns a character at the specified index
    pub fn charAt(self: String, index: usize) ?u8 {
        if (self.buffer) |buffer| {
            if (index < self.len) return buffer[index];
        }

        return null;
    }
};
