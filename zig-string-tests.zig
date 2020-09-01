const std = @import("std");
const Allocator = std.mem.Allocator;
const ArenaAllocator = std.heap.ArenaAllocator;
const assert = std.testing.expect;

const String = @import("./zig-string.zig").String;

test "Basic Usage" {
    // Use your favorite allocator
    var arena = ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    // Create your String
    var myString = String.init(&arena.allocator);
    defer myString.deinit();

    // Use functions provided
    try myString.concat("Hello!");
    _ = myString.pop();
    try myString.concat(", World!");

    // Success!
    assert(myString.cmp("Hello, World!"));
}

test "Basic String Operations" {
    var arena = ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const allocator = &arena.allocator;
    var hello = String.init(allocator);
    defer hello.deinit();

    try hello.setCapacity(13);
    try hello.concat("Hello");
    try hello.concat(", World");

    assert(hello.cmp("Hello, World"));

    try hello.push('!');

    assert(hello.cmp("Hello, World!"));
    assert(hello.len == 13);
    assert(hello.pop().? == '!');

    const helloSub = try hello.substr(0, 5);
    assert(helloSub.cmp("Hello"));
    helloSub.deinit();

    assert(hello.remove(5).? == ',');
    assert(hello.len == 11);
    assert(hello.cmp("Hello World"));
    assert(hello.contains("World"));

    try hello.removeRange(6, hello.len);
    assert(hello.cmp("Hello "));

    try hello.compact();
    assert(hello.capacity() == hello.len);

    var hello2 = try hello.clone();
    defer hello2.deinit();

    assert(hello2.cmp("Hello "));
    try hello2.repeat(2);
    assert(hello2.cmp("Hello Hello Hello "));

    assert(hello.charAt(1).? == 'e');
}

test "Conversion and Query Tests" {
    var arena = ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const allocator = &arena.allocator;
    var myString = String.init(allocator);
    defer myString.deinit();

    try myString.concat("       Test T   ");
    myString.trimStart();
    assert(myString.cmp("Test T   "));
    myString.trimEnd();
    assert(myString.cmp("Test T"));

    myString.toLowercase();
    assert(myString.cmp("test t"));
    myString.toUppercase();
    assert(myString.cmp("TEST T"));
    assert(myString.find('T').? == 0);

    assert(std.mem.eql(u8, myString.split(' ', 0).?, "TEST"));
    assert(std.mem.eql(u8, myString.split(' ', 1).?, "T"));
    assert(myString.split(' ', 2) == null);

    try myString.insert('!', 4);
    assert(myString.cmp("TEST! T"));

    myString.reverse();
    assert(myString.cmp("T !TSET"));
    myString.reverse();

    try myString.insertStr("Hello", 5);
    assert(myString.cmp("TEST!Hello T"));
}
