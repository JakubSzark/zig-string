# Zig String (A UTF-8 String Library)

[![CI](https://github.com/JakubSzark/zig-string/actions/workflows/main.yml/badge.svg)](https://github.com/JakubSzark/zig-string/actions/workflows/main.yml) ![Github Repo Issues](https://img.shields.io/github/issues/JakubSzark/zig-string?style=flat) ![GitHub Repo stars](https://img.shields.io/github/stars/JakubSzark/zig-string?style=social)

This library is a UTF-8 compatible **string** library for the **Zig** programming language.
I made this for the sole purpose to further my experience and understanding of zig.
Also it may be useful for some people who need it (including myself), with future projects. Project is also open for people to add to and improve. Please check the **issues** to view requested features.

# Basic Usage

```zig
const std = @import("std");
const String = @import("zig-string.zig").String;
// ...

// Use your favorite allocator
var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
defer arena.deinit();

// Create your String
var myString = String.init(arena.allocator());
defer myString.deinit();

// Use functions provided
try myString.concat("🔥 Hello!");
_ = myString.pop();
try myString.concat(", World 🔥");

// Success!
std.debug.assert(myString.cmp("🔥 Hello, World 🔥"));

```

# Installation

Add this to your build.zig.zon

```zig
.dependencies = .{
    .string = .{
        .url = "https://github.com/JakubSzark/zig-string/archive/refs/heads/master.tar.gz",
        //the correct hash will be suggested by zig
    }
}
```
Or run:

```bash
zig fetch --save git+https://github.com/JakubSzark/zig-string.git
```

And add this to you build.zig

```zig
    const string = b.dependency("string", .{
        .target = target,
        .optimize = optimize,
    });
    exe.root_module.addImport("string", string.module("string"));

```

You can then import the library into your code like this

```zig
const String = @import("string").String;
```

# How to Contribute

1. Fork
2. Clone
3. Add Features (Use Zig FMT)
4. Make a Test
5. Pull Request
6. Success!

# Working Features

If there are any issues with <b>complexity</b> please <b>open an issue</b>
(I'm no expert when it comes to complexity)

| Function           | Description                                                              |
| ------------------ | ------------------------------------------------------------------------ |
| allocate           | Sets the internal buffer size                                            |
| capacity           | Returns the capacity of the String                                       |
| charAt             | Returns character at index                                               |
| clear              | Clears the contents of the String                                        |
| clone              | Copies this string to a new one                                          |
| cmp                | Compares to string literal                                               |
| concat             | Appends a string literal to the end                                      |
| deinit             | De-allocates the String                                                  |
| find               | Finds first string literal appearance                                    |
| rfind              | Finds last string literal appearance                                     |
| includesLiteral    | Whether or not the provided literal is in the String                     |
| includesString     | Whether or not the provided String is within the String                  |
| init               | Creates a String with an Allocator                                       |
| init_with_contents | Creates a String with specified contents                                 |
| insert             | Inserts a character at an index                                          |
| isEmpty            | Checks if length is zero                                                 |
| iterator           | Returns a StringIterator over the String                                 |
| len                | Returns count of characters stored                                       |
| pop                | Removes the last character                                               |
| remove             | Removes a character at an index                                          |
| removeRange        | Removes a range of characters                                            |
| repeat             | Repeats string n times                                                   |
| reverse            | Reverses all the characters                                              |
| split              | Returns a slice based on delimiters and index                            |
| splitAll           | Returns a slice of slices based on delimiters                            |
| splitToString      | Returns a String based on delimiters and index                           |
| splitAllToStrings  | Returns a slice of Strings based on delimiters                           |
| lines              | Returns a slice of Strings split by newlines                             |
| str                | Returns the String as a slice                                            |
| substr             | Creates a string from a range                                            |
| toLowercase        | Converts (ASCII) characters to lowercase                                 |
| toOwned            | Creates an owned slice of the String                                     |
| toUppercase        | Converts (ASCII) characters to uppercase                                 |
| toCapitalized      | Converts the first (ASCII) character of each word to uppercase           |
| trim               | Removes whitelist from both ends                                         |
| trimEnd            | Remove whitelist from the end                                            |
| trimStart          | Remove whitelist from the start                                          |
| truncate           | Realloc to the length                                                    |
| setStr             | Set's buffer value from string literal                                   |
| writer             | Returns a std.io.Writer for the String                                   |
| startsWith         | Determines if the given string begins with the given value               |
| endsWith           | Determines if the given string ends with the given value                 |
| replace            | Replace all occurrences of the search string with the replacement string |
