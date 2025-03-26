const std = @import("std");
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;
const expectEqualStrings = std.testing.expectEqualStrings;

const String = @import("stringz.zig").String;
const StringUnmanaged = @import("stringz.zig").StringUnmanaged;

test "String Basic Usage" {
    // Create your String
    var myString = String.init(std.testing.allocator);
    defer myString.deinit();

    // Use functions provided
    try myString.concat("🔥 Hello!");
    _ = myString.pop();
    try myString.concat(", World 🔥");

    // Success!
    try expect(myString.cmp("🔥 Hello, World 🔥"));
}

test "String Tests" {
    // This is how we create the String
    var myStr = String.init(std.testing.allocator);
    defer myStr.deinit();

    // allocate & capacity
    try myStr.allocate(16);
    try expectEqual(myStr.capacity(), 16);
    try expectEqual(myStr.size, 0);

    // truncate
    try myStr.truncate();
    try expectEqual(myStr.capacity(), myStr.size);
    try expectEqual(myStr.capacity(), 0);

    // concat
    try myStr.concat("A");
    try myStr.concat("\u{5360}");
    try myStr.concat("💯");
    try myStr.concat("Hello🔥");

    try expectEqual(myStr.size, 17);

    // pop & length
    try expectEqual(myStr.len(), 9);
    try expectEqualStrings(myStr.pop().?, "🔥");
    try expectEqual(myStr.len(), 8);
    try expectEqualStrings(myStr.pop().?, "o");
    try expectEqual(myStr.len(), 7);

    // str & cmp
    try expect(myStr.cmp("A\u{5360}💯Hell"));
    try expect(myStr.cmp(myStr.str()));

    // charAt
    try expectEqualStrings(myStr.charAt(2).?, "💯");
    try expectEqualStrings(myStr.charAt(1).?, "\u{5360}");
    try expectEqualStrings(myStr.charAt(0).?, "A");

    // insert
    try myStr.insert("🔥", 1);
    try expectEqualStrings(myStr.charAt(1).?, "🔥");
    try expect(myStr.cmp("A🔥\u{5360}💯Hell"));

    // find
    try expectEqual(myStr.find("🔥").?, 1);
    try expectEqual(myStr.find("💯").?, 3);
    try expectEqual(myStr.find("Hell").?, 4);

    // remove & removeRange
    try myStr.removeRange(0, 3);
    try expect(myStr.cmp("💯Hell"));
    try myStr.remove(myStr.len() - 1);
    try expect(myStr.cmp("💯Hel"));

    const whitelist = [_]u8{ ' ', '\t', '\n', '\r' };

    // trimStart
    try myStr.insert("      ", 0);
    myStr.trimStart(whitelist[0..]);
    try expect(myStr.cmp("💯Hel"));

    // trimEnd
    _ = try myStr.concat("lo💯\n      ");
    myStr.trimEnd(whitelist[0..]);
    try expect(myStr.cmp("💯Hello💯"));

    // clone
    var testStr = try myStr.clone();
    defer testStr.deinit();
    try expect(testStr.cmp(myStr.str()));

    // reverse
    myStr.reverse();
    try expect(myStr.cmp("💯olleH💯"));
    myStr.reverse();
    try expect(myStr.cmp("💯Hello💯"));

    // repeat
    try myStr.repeat(2);
    try expect(myStr.cmp("💯Hello💯💯Hello💯💯Hello💯"));

    // isEmpty
    try expect(!myStr.isEmpty());

    // split
    try expectEqualStrings(myStr.split("💯", 0).?, "");
    try expectEqualStrings(myStr.split("💯", 1).?, "Hello");
    try expectEqualStrings(myStr.split("💯", 2).?, "");
    try expectEqualStrings(myStr.split("💯", 3).?, "Hello");
    try expectEqualStrings(myStr.split("💯", 5).?, "Hello");
    try expectEqualStrings(myStr.split("💯", 6).?, "");

    var splitStr = String.init(std.testing.allocator);
    defer splitStr.deinit();

    try splitStr.concat("variable='value'");
    try expectEqualStrings(splitStr.split("=", 0).?, "variable");
    try expectEqualStrings(splitStr.split("=", 1).?, "'value'");

    // splitAll
    var splitAllStr = try String.init_with_contents(std.testing.allocator, "THIS IS A  TEST");
    defer splitAllStr.deinit();
    const splitAllSlices = try splitAllStr.splitAll(" ");

    try expectEqual(splitAllSlices.len, 5);
    try expectEqualStrings(splitAllSlices[0], "THIS");
    try expectEqualStrings(splitAllSlices[1], "IS");
    try expectEqualStrings(splitAllSlices[2], "A");
    try expectEqualStrings(splitAllSlices[3], "");
    try expectEqualStrings(splitAllSlices[4], "TEST");

    // splitToString
    var newSplit = try splitStr.splitToString("=", 0);
    try expect(newSplit != null);
    defer newSplit.?.deinit();

    try expectEqualStrings(newSplit.?.str(), "variable");

    // splitAllToStrings
    var splitAllStrings = try splitAllStr.splitAllToStrings(" ");
    defer for (splitAllStrings) |*str| {
        str.deinit();
    };

    try expectEqual(splitAllStrings.len, 5);
    try expectEqualStrings(splitAllStrings[0].str(), "THIS");
    try expectEqualStrings(splitAllStrings[1].str(), "IS");
    try expectEqualStrings(splitAllStrings[2].str(), "A");
    try expectEqualStrings(splitAllStrings[3].str(), "");
    try expectEqualStrings(splitAllStrings[4].str(), "TEST");

    // lines
    const lineSlice = "Line0\r\nLine1\nLine2";

    var lineStr = try String.init_with_contents(std.testing.allocator, lineSlice);
    defer lineStr.deinit();
    var linesSlice = try lineStr.lines();
    defer for (linesSlice) |*str| {
        str.deinit();
    };

    try expectEqual(linesSlice.len, 3);
    try expect(linesSlice[0].cmp("Line0"));
    try expect(linesSlice[1].cmp("Line1"));
    try expect(linesSlice[2].cmp("Line2"));

    // toLowercase & toUppercase
    myStr.toUppercase();
    try expect(myStr.cmp("💯HELLO💯💯HELLO💯💯HELLO💯"));
    myStr.toLowercase();
    try expect(myStr.cmp("💯hello💯💯hello💯💯hello💯"));

    // substr
    var subStr = try myStr.substr(0, 7);
    defer subStr.deinit();
    try expect(subStr.cmp("💯hello💯"));

    // clear
    myStr.clear();
    try expectEqual(myStr.len(), 0);
    try expectEqual(myStr.size, 0);

    // writer
    const writer = myStr.writer();
    const length = try writer.write("This is a Test!");
    try expectEqual(length, 15);

    // owned
    const mySlice = try myStr.toOwned();
    try expectEqualStrings(mySlice.?, "This is a Test!");
    std.testing.allocator.free(mySlice.?);

    // StringIterator
    var i: usize = 0;
    var iter = myStr.iterator();
    while (iter.next()) |ch| {
        if (i == 0) {
            try expectEqualStrings("T", ch);
        }
        i += 1;
    }

    try expectEqual(i, myStr.len());

    // setStr
    const contents = "setStr Test!";
    try myStr.setStr(contents);
    try expect(myStr.cmp(contents));

    // non ascii supports in windows
    // try expectEqual(std.os.windows.kernel32.GetConsoleOutputCP(), 65001);
}

test "String init with contents" {
    const initial_contents = "String with initial contents!";

    // This is how we create the String with contents at the start
    var myStr = try String.init_with_contents(std.testing.allocator, initial_contents);
    defer myStr.deinit();
    try expectEqualStrings(myStr.str(), initial_contents);
}

test "String startsWith Tests" {
    var myString = String.init(std.testing.allocator);
    defer myString.deinit();

    try myString.concat("bananas");
    try expect(myString.startsWith("bana"));
    try expect(!myString.startsWith("abc"));
}

test "String endsWith Tests" {
    var myString = String.init(std.testing.allocator);
    defer myString.deinit();

    try myString.concat("asbananas");
    try expect(myString.endsWith("nas"));
    try expect(!myString.endsWith("abc"));

    try myString.truncate();
    try myString.concat("💯hello💯💯hello💯💯hello💯");
    std.debug.print("", .{});
    try expect(myString.endsWith("hello💯"));
}

test "String replace Tests" {
    // Create your String
    var myString = String.init(std.testing.allocator);
    defer myString.deinit();

    try myString.concat("hi,how are you");
    var result = try myString.replace("hi,", "");
    try expect(result);
    try expectEqualStrings(myString.str(), "how are you");

    result = try myString.replace("abc", " ");
    try expect(!result);

    myString.clear();
    try myString.concat("💯hello💯💯hello💯💯hello💯");
    _ = try myString.replace("hello", "hi");
    try expectEqualStrings(myString.str(), "💯hi💯💯hi💯💯hi💯");
}

test "String rfind Tests" {
    var myString = try String.init_with_contents(std.testing.allocator, "💯hi💯💯hi💯💯hi💯");
    defer myString.deinit();

    try expectEqual(myString.rfind("hi"), 9);
}

test "String toCapitalized Tests" {
    var myString = try String.init_with_contents(std.testing.allocator, "love and be loved");
    defer myString.deinit();

    myString.toCapitalized();

    try expectEqualStrings(myString.str(), "Love And Be Loved");
}

test "String includes Tests" {
    var myString = try String.init_with_contents(std.testing.allocator, "love and be loved");
    defer myString.deinit();

    var needle = try String.init_with_contents(std.testing.allocator, "be");
    defer needle.deinit();

    try expect(myString.includesLiteral("and"));
    try expect(myString.includesString(needle));

    try needle.concat("t");

    try expect(myString.includesLiteral("tiger") == false);
    try expect(myString.includesString(needle) == false);

    needle.clear();

    try expect(myString.includesLiteral("") == false);
    try expect(myString.includesString(needle) == false);
}

test "StringUnmanaged Basic Usage" {
    const allocator = std.testing.allocator;

    // Create your String
    var myString = StringUnmanaged.init();
    defer myString.deinit(allocator);

    // Use functions provided
    try myString.concat(allocator, "🔥 Hello!");
    _ = myString.pop();
    try myString.concat(allocator, ", World 🔥");

    // Success!
    try expect(myString.cmp("🔥 Hello, World 🔥"));
}

test "StringUnmanaged Tests" {
    const allocator = std.testing.allocator;

    // This is how we create the String
    var myStr = StringUnmanaged.init();
    defer myStr.deinit(allocator);

    // allocate & capacity
    try myStr.allocate(allocator, 16);
    try expectEqual(myStr.capacity(), 16);
    try expectEqual(myStr.size, 0);

    // truncate
    try myStr.truncate(allocator);
    try expectEqual(myStr.capacity(), myStr.size);
    try expectEqual(myStr.capacity(), 0);

    // concat
    try myStr.concat(allocator, "A");
    try myStr.concat(allocator, "\u{5360}");
    try myStr.concat(allocator, "💯");
    try myStr.concat(allocator, "Hello🔥");

    try expectEqual(myStr.size, 17);

    // pop & length
    try expectEqual(myStr.len(), 9);
    try expectEqualStrings(myStr.pop().?, "🔥");
    try expectEqual(myStr.len(), 8);
    try expectEqualStrings(myStr.pop().?, "o");
    try expectEqual(myStr.len(), 7);

    // str & cmp
    try expect(myStr.cmp("A\u{5360}💯Hell"));
    try expect(myStr.cmp(myStr.str()));

    // charAt
    try expectEqualStrings(myStr.charAt(2).?, "💯");
    try expectEqualStrings(myStr.charAt(1).?, "\u{5360}");
    try expectEqualStrings(myStr.charAt(0).?, "A");

    // insert
    try myStr.insert(allocator, "🔥", 1);
    try expectEqualStrings(myStr.charAt(1).?, "🔥");
    try expect(myStr.cmp("A🔥\u{5360}💯Hell"));

    // find
    try expectEqual(myStr.find("🔥").?, 1);
    try expectEqual(myStr.find("💯").?, 3);
    try expectEqual(myStr.find("Hell").?, 4);

    // remove & removeRange
    try myStr.removeRange(0, 3);
    try expect(myStr.cmp("💯Hell"));
    try myStr.remove(myStr.len() - 1);
    try expect(myStr.cmp("💯Hel"));

    const whitelist = [_]u8{ ' ', '\t', '\n', '\r' };

    // trimStart
    try myStr.insert(allocator, "      ", 0);
    myStr.trimStart(whitelist[0..]);
    try expect(myStr.cmp("💯Hel"));

    // trimEnd
    _ = try myStr.concat(allocator, "lo💯\n      ");
    myStr.trimEnd(whitelist[0..]);
    try expect(myStr.cmp("💯Hello💯"));

    // clone
    var testStr = try myStr.clone(allocator);
    defer testStr.deinit(allocator);
    try expect(testStr.cmp(myStr.str()));

    // reverse
    myStr.reverse();
    try expect(myStr.cmp("💯olleH💯"));
    myStr.reverse();
    try expect(myStr.cmp("💯Hello💯"));

    // repeat
    try myStr.repeat(allocator, 2);
    try expect(myStr.cmp("💯Hello💯💯Hello💯💯Hello💯"));

    // isEmpty
    try expect(!myStr.isEmpty());

    // split
    try expectEqualStrings(myStr.split("💯", 0).?, "");
    try expectEqualStrings(myStr.split("💯", 1).?, "Hello");
    try expectEqualStrings(myStr.split("💯", 2).?, "");
    try expectEqualStrings(myStr.split("💯", 3).?, "Hello");
    try expectEqualStrings(myStr.split("💯", 5).?, "Hello");
    try expectEqualStrings(myStr.split("💯", 6).?, "");

    var splitStr = StringUnmanaged.init();
    defer splitStr.deinit(allocator);

    try splitStr.concat(allocator, "variable='value'");
    try expectEqualStrings(splitStr.split("=", 0).?, "variable");
    try expectEqualStrings(splitStr.split("=", 1).?, "'value'");

    // splitAll
    var splitAllStr = try StringUnmanaged.init_with_contents(allocator, "THIS IS A  TEST");
    defer splitAllStr.deinit(allocator);
    const splitAllSlices = try splitAllStr.splitAll(" ");

    try expectEqual(splitAllSlices.len, 5);
    try expectEqualStrings(splitAllSlices[0], "THIS");
    try expectEqualStrings(splitAllSlices[1], "IS");
    try expectEqualStrings(splitAllSlices[2], "A");
    try expectEqualStrings(splitAllSlices[3], "");
    try expectEqualStrings(splitAllSlices[4], "TEST");

    // splitToString
    var newSplit = try splitStr.splitToString(allocator, "=", 0);
    try expect(newSplit != null);
    defer newSplit.?.deinit(allocator);

    try expectEqualStrings(newSplit.?.str(), "variable");

    // splitAllToStrings
    var splitAllStrings = try splitAllStr.splitAllToStrings(allocator, " ");
    defer for (splitAllStrings) |*str| {
        str.deinit(allocator);
    };

    try expectEqual(splitAllStrings.len, 5);
    try expectEqualStrings(splitAllStrings[0].str(), "THIS");
    try expectEqualStrings(splitAllStrings[1].str(), "IS");
    try expectEqualStrings(splitAllStrings[2].str(), "A");
    try expectEqualStrings(splitAllStrings[3].str(), "");
    try expectEqualStrings(splitAllStrings[4].str(), "TEST");

    // lines
    const lineSlice = "Line0\r\nLine1\nLine2";

    var lineStr = try StringUnmanaged.init_with_contents(allocator, lineSlice);
    defer lineStr.deinit(allocator);
    var linesSlice = try lineStr.lines(allocator);
    defer for (linesSlice) |*str| {
        str.deinit(allocator);
    };

    try expectEqual(linesSlice.len, 3);
    try expect(linesSlice[0].cmp("Line0"));
    try expect(linesSlice[1].cmp("Line1"));
    try expect(linesSlice[2].cmp("Line2"));

    // toLowercase & toUppercase
    myStr.toUppercase();
    try expect(myStr.cmp("💯HELLO💯💯HELLO💯💯HELLO💯"));
    myStr.toLowercase();
    try expect(myStr.cmp("💯hello💯💯hello💯💯hello💯"));

    // substr
    var subStr = try myStr.substr(allocator, 0, 7);
    defer subStr.deinit(allocator);
    try expect(subStr.cmp("💯hello💯"));

    // clear
    myStr.clear();
    try expectEqual(myStr.len(), 0);
    try expectEqual(myStr.size, 0);

    // owned
    try myStr.concat(allocator, "This is a Test!");
    const mySlice = try myStr.toOwned(allocator);
    try expectEqualStrings(mySlice.?, "This is a Test!");
    allocator.free(mySlice.?);

    // StringIterator
    var i: usize = 0;
    var iter = myStr.iterator();
    while (iter.next()) |ch| {
        if (i == 0) {
            try expectEqualStrings("T", ch);
        }
        i += 1;
    }

    try expectEqual(i, myStr.len());

    // setStr
    const contents = "setStr Test!";
    try myStr.setStr(allocator, contents);
    try expect(myStr.cmp(contents));

    // non ascii supports in windows
    // try expectEqual(std.os.windows.kernel32.GetConsoleOutputCP(), 65001);
}

test "StringUnmanaged init with contents" {
    const allocator = std.testing.allocator;
    const initial_contents = "String with initial contents!";

    // This is how we create the String with contents at the start
    var myStr = try StringUnmanaged.init_with_contents(allocator, initial_contents);
    defer myStr.deinit(allocator);
    try expectEqualStrings(myStr.str(), initial_contents);
}

test "sStringUnmanaged tartsWith Tests" {
    const allocator = std.testing.allocator;

    var myString = StringUnmanaged.init();
    defer myString.deinit(allocator);

    try myString.concat(allocator, "bananas");
    try expect(myString.startsWith("bana"));
    try expect(!myString.startsWith("abc"));
}

test "StringUnmanaged endsWith Tests" {
    const allocator = std.testing.allocator;

    var myString = StringUnmanaged.init();
    defer myString.deinit(allocator);

    try myString.concat(allocator, "asbananas");
    try expect(myString.endsWith("nas"));
    try expect(!myString.endsWith("abc"));

    try myString.truncate(allocator);
    try myString.concat(allocator, "💯hello💯💯hello💯💯hello💯");
    std.debug.print("", .{});
    try expect(myString.endsWith("hello💯"));
}

test "StringUnmanaged replace Tests" {
    const allocator = std.testing.allocator;

    // Create your String
    var myString = StringUnmanaged.init();
    defer myString.deinit(allocator);

    try myString.concat(allocator, "hi,how are you");
    var result = try myString.replace(allocator, "hi,", "");
    try expect(result);
    try expectEqualStrings(myString.str(), "how are you");

    result = try myString.replace(allocator, "abc", " ");
    try expect(!result);

    myString.clear();
    try myString.concat(allocator, "💯hello💯💯hello💯💯hello💯");
    _ = try myString.replace(allocator, "hello", "hi");
    try expectEqualStrings(myString.str(), "💯hi💯💯hi💯💯hi💯");
}

test "StringUnmanaged rfind Tests" {
    const allocator = std.testing.allocator;

    var myString = try StringUnmanaged.init_with_contents(allocator, "💯hi💯💯hi💯💯hi💯");
    defer myString.deinit(allocator);

    try expectEqual(myString.rfind("hi"), 9);
}

test "StringUnmanaged toCapitalized Tests" {
    const allocator = std.testing.allocator;

    var myString = try StringUnmanaged.init_with_contents(allocator, "love and be loved");
    defer myString.deinit(allocator);

    myString.toCapitalized();

    try expectEqualStrings(myString.str(), "Love And Be Loved");
}

test "StringUnmanaged includes Tests" {
    const allocator = std.testing.allocator;

    var myString = try StringUnmanaged.init_with_contents(allocator, "love and be loved");
    defer myString.deinit(allocator);

    var needle = try StringUnmanaged.init_with_contents(allocator, "be");
    defer needle.deinit(allocator);

    try expect(myString.includesLiteral("and"));
    try expect(myString.includesString(needle));

    try needle.concat(allocator, "t");

    try expect(myString.includesLiteral("tiger") == false);
    try expect(myString.includesString(needle) == false);

    needle.clear();

    try expect(myString.includesLiteral("") == false);
    try expect(myString.includesString(needle) == false);
}
