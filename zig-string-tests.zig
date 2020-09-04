const std = @import("std");
const ArenaAllocator = std.heap.ArenaAllocator;
const assert = std.debug.assert;
const eql = std.mem.eql;

const zig_string = @import("./zig-string.zig");
const String = zig_string.String;
const Utility = zig_string.Utility;

test "Utility Tests" {
    // getUTF8Size
    assert(Utility.getUTF8Size("A"[0]) == 1);
    assert(Utility.getUTF8Size("\u{5360}"[0]) == 3);
    assert(Utility.getUTF8Size("💯"[0]) == 4);

    // getRealIndex
    const myliteral = "🔥Hello\u{5360}🔥";
    assert(Utility.getIndex(myliteral, 6, true).? == 9);

    // isWhitespace
    assert(Utility.isWhitespace('\n'));

    // isUTF8Byte
    assert(Utility.isUTF8Byte("💯"[3]));
    assert(Utility.isUTF8Byte("\u{5360}"[2]));
    assert(Utility.isUTF8Byte("🔥"[1]));
    assert(!Utility.isUTF8Byte("🔥"[0]));
    assert(!Utility.isUTF8Byte("A"[0]));
}

test "Basic Usage" {
    // Use your favorite allocator
    var arena = ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    // Create your String
    var myString = String.init(&arena.allocator);
    defer myString.deinit();

    // Use functions provided
    try myString.concat("🔥 Hello!");
    _ = myString.pop();
    try myString.concat(", World 🔥");

    // Success!
    assert(myString.cmp("🔥 Hello, World 🔥"));
}

test "String Tests" {
    // Allocator for the String
    const page_allocator = std.heap.page_allocator;
    var arena = std.heap.ArenaAllocator.init(page_allocator);
    defer arena.deinit();

    // This is how we create the String
    var myStr = String.init(&arena.allocator);
    defer myStr.deinit();

    // allocate & capacity
    try myStr.allocate(16);
    assert(myStr.capacity() == 16);
    assert(myStr.size == 0);

    // truncate
    try myStr.truncate();
    assert(myStr.capacity() == myStr.size);
    assert(myStr.capacity() == 0);

    // concat
    try myStr.concat("A");
    try myStr.concat("\u{5360}");
    try myStr.concat("💯");
    try myStr.concat("Hello🔥");

    assert(myStr.size == 17);

    // pop & length
    assert(myStr.len() == 9);
    assert(eql(u8, myStr.pop().?, "🔥"));
    assert(myStr.len() == 8);
    assert(eql(u8, myStr.pop().?, "o"));
    assert(myStr.len() == 7);

    // str & cmp
    assert(myStr.cmp("A\u{5360}💯Hell"));
    assert(myStr.cmp(myStr.str()));

    // charAt
    assert(eql(u8, myStr.charAt(2).?, "💯"));
    assert(eql(u8, myStr.charAt(1).?, "\u{5360}"));
    assert(eql(u8, myStr.charAt(0).?, "A"));

    // insert
    try myStr.insert("🔥", 1);
    assert(eql(u8, myStr.charAt(1).?, "🔥"));
    assert(myStr.cmp("A🔥\u{5360}💯Hell"));

    // find
    assert(myStr.find("🔥").? == 1);
    assert(myStr.find("💯").? == 3);
    assert(myStr.find("Hell").? == 4);

    // remove & removeRange
    try myStr.removeRange(0, 3);
    assert(myStr.cmp("💯Hell"));
    try myStr.remove(myStr.len() - 1);
    assert(myStr.cmp("💯Hel"));

    // trimStart
    try myStr.insert("      ", 0);
    myStr.trimStart();
    assert(myStr.cmp("💯Hel"));

    // trimEnd
    _ = try myStr.concat("lo💯\n      ");
    myStr.trimEnd();
    assert(myStr.cmp("💯Hello💯"));

    // clone
    var testStr = try myStr.clone();
    defer testStr.deinit();
    assert(testStr.cmp(myStr.str()));

    // reverse
    myStr.reverse();
    assert(myStr.cmp("💯olleH💯"));
    myStr.reverse();
    assert(myStr.cmp("💯Hello💯"));

    // repeat
    try myStr.repeat(2);
    assert(myStr.cmp("💯Hello💯💯Hello💯💯Hello💯"));

    // isEmpty
    assert(!myStr.isEmpty());

    // split
    assert(eql(u8, myStr.split("💯", 0).?, ""));
    assert(eql(u8, myStr.split("💯", 1).?, "Hello"));
    assert(eql(u8, myStr.split("💯", 2).?, ""));
    assert(eql(u8, myStr.split("💯", 3).?, "Hello"));

    // toLowercasr & toUppercase
    myStr.toUppercase();
    assert(myStr.cmp("💯HELLO💯💯HELLO💯💯HELLO💯"));
    myStr.toLowercase();
    assert(myStr.cmp("💯hello💯💯hello💯💯hello💯"));

    // substr
    var subStr = try myStr.substr(0, 7);
    defer subStr.deinit();
    assert(subStr.cmp("💯hello💯"));

    // clear
    myStr.clear();
    assert(myStr.len() == 0);
    assert(myStr.size == 0);

    // writer
    const writer = myStr.writer();
    const length = try writer.write("This is a Test!");
    assert(length == 15);

    // owned
    const mySlice = try myStr.toOwned();
    assert(eql(u8, mySlice.?, "This is a Test!"));
    arena.allocator.free(mySlice.?);
}
