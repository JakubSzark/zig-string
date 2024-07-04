const std = @import("std");
const assert = std.debug.assert;
const builtin = @import("builtin");

/// A variable length collection of characters
pub const String = struct {
    /// The internal representation of the string
    inner: std.ArrayList(u8),

    /// Errors that may occur when using String
    pub const Error = error{
        OutOfMemory,
        InvalidRange,
    };

    /// Creates a String with an Allocator
    /// ### example
    /// ```zig
    /// var str = String.init(allocator);
    /// // don't forget to deallocate
    /// defer _ = str.deinit();
    /// ```
    /// User is responsible for managing the new String
    pub fn init(allocator: std.mem.Allocator) String {
        // for windows non-ascii characters
        // check if the system is windows
        if (builtin.os.tag == std.Target.Os.Tag.windows) {
            _ = std.os.windows.kernel32.SetConsoleOutputCP(65001);
        }

        return .{ .inner = std.ArrayList(u8).init(allocator) };
    }

    pub fn initWithContents(allocator: std.mem.Allocator, contents: []const u8) Error!String {
        var string = init(allocator);

        try string.concat(contents);

        return string;
    }

    pub fn initWithCapacity(allocator: std.mem.Allocator, num: usize) Error!String {
        // for windows non-ascii characters
        // check if the system is windows
        if (builtin.os.tag == std.Target.Os.Tag.windows) {
            _ = std.os.windows.kernel32.SetConsoleOutputCP(65001);
        }

        return .{ .inner = try std.ArrayList(u8).initCapacity(allocator, num) };
    }

    /// Deallocates the internal buffer
    /// ### usage:
    /// ```zig
    /// var str = String.init(allocator);
    /// // deinit after the closure
    /// defer _ = str.deinit();
    /// ```
    pub fn deinit(self: *String) void {
        self.inner.deinit();
    }

    /// Returns the size of the internal buffer
    pub inline fn capacity(self: String) usize {
        return self.inner.capacity;
    }

    /// Returns the length of the string
    pub inline fn len(self: String) usize {
        return self.inner.items.len;
    }

    /// Allocates `bytes` space for the internal buffer
    pub fn allocate(self: *String, bytes: usize) Error!void {
        if (self.inner.items.len > bytes) {
            self.inner.items.len = bytes;
            return;
        } else {
            self.inner.ensureTotalCapacity(bytes) catch return Error.OutOfMemory;
        }
    }

    /// Allocates exactly `bytes` space for the internal buffer
    pub fn allocatePrecise(self: *String, bytes: usize) Error!void {
        self.inner.ensureTotalCapacityPrecise(bytes) catch return Error.OutOfMemory;
    }

    /// Allocates `bytes` more space for the internal buffer
    pub fn allocateExtra(self: *String, bytes: usize) Error!void {
        self.inner.ensureUnusedCapacity(bytes) catch return Error.OutOfMemory;
    }

    /// Reallocates the the internal buffer to size
    pub fn truncate(self: *String) Error!void {
        try self.allocate(self.len());
    }

    /// Appends a character onto the end of the String
    pub fn concat(self: *String, char: []const u8) Error!void {
        self.inner.appendSlice(char) catch return Error.OutOfMemory;
    }

    /// Inserts a string literal into the String at an index
    pub fn insert(self: *String, literal: []const u8, index: usize) Error!void {
        self.inner.insertSlice(index, literal) catch return Error.OutOfMemory;
    }

    /// Removes the last character from the String
    pub fn pop(self: *String) ?[]const u8 {
        if (self.len() == 0) return null;

        var i: usize = 0;
        while (i < self.len()) {
            const size = String.getUTF8Size(self.str()[i]);
            if (i + size >= self.len()) break;
            i += size;
        }

        const ret = self.inner.items[i..self.len()];
        self.inner.items.len -= (self.inner.items.len - i);
        return ret;
    }

    /// Compares this String with a string literal
    pub fn cmp(self: String, literal: []const u8) bool {
        return std.mem.eql(u8, self.str(), literal);
    }

    /// Compares this String with a string literal
    /// This is an alias for cmp
    pub fn eql(self: String, literal: []const u8) bool {
        return cmp(self.str(), literal);
    }

    /// Returns the String buffer as a string literal
    /// ### usage:
    ///```zig
    ///var mystr = try String.init_with_contents(allocator, "Test String!");
    ///defer _ = mystr.deinit();
    ///std.debug.print("{s}\n", .{mystr.str()});
    ///```
    pub inline fn str(self: String) []u8 {
        return self.inner.items;
    }

    /// Returns an owned slice of this string
    pub fn toOwned(self: String) Error!?[]u8 {
        const string = self.str();
        if (self.inner.allocator.alloc(u8, string.len)) |newStr| {
            std.mem.copyForwards(u8, newStr, string);
            return newStr;
        } else |_| {
            return Error.OutOfMemory;
        }
    }

    /// Returns a character at the specified index
    pub fn charAt(self: String, index: usize) ?[]const u8 {
        if (String.getIndex(self.str(), index, true)) |i| {
            const size = String.getUTF8Size(self.str()[i]);
            return self.str()[i..(i + size)];
        }
    }

    /// Returns amount of characters in the String
    pub fn char_count(self: String) usize {
        var count: usize = 0;
        var i: usize = 0;

        while (i < self.len()) {
            i += String.getUTF8Size(self.inner.items[i]);
            count += 1;
        }

        return count;
    }

    /// Finds the first occurrence of the string literal
    pub fn find(self: String, literal: []const u8) ?usize {
        const index = std.mem.indexOf(u8, self.str()[0..self.len()], literal);
        if (index) |i| {
            return String.getIndex(self.str(), i, false);
        }
    }

    /// Finds the last occurrence of the string literal
    pub fn rfind(self: String, literal: []const u8) ?usize {
        const index = std.mem.lastIndexOf(u8, self.inner.items[0..self.len()], literal);
        if (index) |i| {
            return String.getIndex(self.str(), i, false);
        }
    }

    /// Removes a character at the specified index
    pub fn remove(self: *String, index: usize) Error!void {
        try self.removeRange(index, index + 1);
    }

    /// Removes a range of character from the String
    /// Start (inclusive) - End (Exclusive)
    pub fn removeRange(self: *String, start: usize, end: usize) Error!void {
        const length = self.char_count();
        if (end < start or end > length) return Error.InvalidRange;

        const rStart = String.getIndex(self.str(), start, true).?;
        const rEnd = String.getIndex(self.str(), end, true).?;
        const difference = rEnd - rStart;

        var i: usize = rEnd;
        while (i < self.len()) : (i += 1) {
            self.str()[i - difference] = self.str()[i];
        }

        self.str().len -= difference;
    }

    /// Trims all whitelist characters at the start of the String.
    pub fn trimStart(self: *String, whitelist: []const u8) void {
        var i: usize = 0;
        while (i < self.len()) : (i += 1) {
            const size = String.getUTF8Size(self.str()[i]);
            if (size > 1 or !inWhitelist(self.str()[i], whitelist)) break;
        }

        if (String.getIndex(self.str(), i, false)) |k| {
            self.removeRange(0, k) catch {};
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
        return String.initWithContents(self.allocator, self.str());
    }

    /// Reverses the characters in this String
    pub fn reverse(self: *String) void {
        var i: usize = 0;
        while (i < self.len()) {
            const size = String.getUTF8Size(self.str()[i]);
            if (size > 1) std.mem.reverse(u8, self.str()[i..(i + size)]);
            i += size;
        }

        std.mem.reverse(u8, self.str()[0..self.len()]);
    }

    /// Repeats this String n times
    pub fn repeat(self: *String, n: usize) Error!void {
        try self.allocate(self.len() * (n + 1));

        var i: usize = 1;
        while (i <= n) : (i += 1) {
            var j: usize = 0;
            while (j < self.len()) : (j += 1) {
                self.str()[((i * self.len()) + j)] = self.str()[j];
            }
        }

        self.inner.items.len *= (n + 1);
    }

    /// Checks the String is empty
    pub inline fn isEmpty(self: String) bool {
        return self.len() == 0;
    }

    /// Splits the String into a slice, based on a delimiter and an index
    pub fn split(self: *const String, delimiters: []const u8, index: usize) ?[]const u8 {
        var i: usize = 0;
        var block: usize = 0;
        var start: usize = 0;

        while (i < self.len()) {
            const size = String.getUTF8Size(self.str()[i]);
            if (size == delimiters.len) {
                if (std.mem.eql(u8, delimiters, self.str()[i..(i + size)])) {
                    if (block == index) return self.str()[start..i];
                    start = i + size;
                    block += 1;
                }
            }

            i += size;
        }

        if (i >= self.len() - 1 and block == index) {
            return self.str()[start..self.len()];
        }
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
        self.inner.clearRetainingCapacity();
    }

    /// Converts all (ASCII) uppercase letters to lowercase
    pub fn toLowercase(self: *String) void {
        var i: usize = 0;
        while (i < self.len()()) {
            const size = String.getUTF8Size(self.inner.items[i]);
            if (size == 1) self.inner.items[i] = std.ascii.toLower(self.inner.items[i]);
            i += size;
        }
    }

    /// Converts all (ASCII) uppercase letters to lowercase
    pub fn toUppercase(self: *String) void {
        var i: usize = 0;
        while (i < self.len()()) {
            const size = String.getUTF8Size(self.inner.items[i]);
            if (size == 1) self.inner.items[i] = std.ascii.toUpper(self.inner.items[i]);
            i += size;
        }
    }

    /// Creates a String from a given range
    /// User is responsible for managing the new String
    pub fn substr(self: String, start: usize, end: usize) Error!String {
        var result = String.init(self.allocator);

        if (String.getIndex(self.str(), start, true)) |rStart| {
            if (String.getIndex(self.str(), end, true)) |rEnd| {
                if (rEnd < rStart or rEnd > self.len())
                    return Error.InvalidRange;
                try result.concat(self.str()[rStart..rEnd]);
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
                if (it.index == it.string.size) return null;
                const i = it.index;
                it.index += String.getUTF8Size(it.string.inner.items[i]);
                return it.string.inner.items[i..it.index];
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

    /// Sets the contents of the String
    pub fn setStr(self: *String, contents: []const u8) Error!void {
        self.clear();
        try self.concat(contents);
    }

    /// Checks the start of the string against a literal
    pub fn startsWith(self: *String, literal: []const u8) bool {
        return std.mem.startsWith(u8, self.inner.items, literal);
    }

    /// Checks the end of the string against a literal
    pub fn endsWith(self: *String, literal: []const u8) bool {
        return std.mem.endsWith(u8, self.inner.items, literal);
    }

    /// Replaces all occurrences of a string literal with another
    pub fn replace(self: *String, needle: []const u8, replacement: []const u8) !bool {
        const InputSize = self.len();
        const size = std.mem.replacementSize(u8, self.str()[0..InputSize], needle, replacement);
        self.inner.items = self.allocator.alloc(u8, size) catch {
            return Error.OutOfMemory;
        };
        self.inner.items.len = size;
        const changes = std.mem.replace(u8, self.str()[0..InputSize], needle, replacement, self.self.str());
        if (changes > 0) {
            return true;
        }

        return false;
    }
};
