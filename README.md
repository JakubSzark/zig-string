[![CI](https://github.com/JakubSzark/zig-string/actions/workflows/main.yml/badge.svg)](https://github.com/JakubSzark/zig-string/actions/workflows/main.yml)

# Zig String (A UTF-8 String Library)

This library is a UTF-8 compatible **string** library for the **Zig** programming language. 
I made this for the sole purpose to further my experience and understanding of zig.
Also it may be useful for some people who need it (including myself), with future projects. Project is also open for people to add to and improve. Please check the **issues** to view requested features.

# Basic Usage
```zig
const String = @import("./zig-string.zig").String;
// ...

// Use your favorite allocator
var arena = ArenaAllocator.init(std.heap.page_allocator);
defer arena.deinit();

// Create your String
var myString = String.init(&arena.allocator());
defer myString.deinit();

// Use functions provided
try myString.concat("🔥 Hello!");
_ = myString.pop();
try myString.concat(", World 🔥");

// Success!
assert(myString.cmp("🔥 Hello, World 🔥"));

```

# Things needed
- Optimizations
- Multi-Language toUppercase & toLowercase
- Better documentation
- More Testing

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

Function      | Description                              | Complexity (Best)
--------------|------------------------------------------|-----------
init          | Creates a String with an Allocator       | O(1)
deinit        | De-allocates the String                  | O(1)
len           | Returns count of characters stored       | O(n)
clear         | Clears the contents of the String        | O(n)
allocate      | Sets the internal buffer size            | O(1)
capacity      | Returns the capacity of the String       | O(1)
str           | Returns the String as a slice            | O(1)
concat        | Appends a string literal to the end      | O(n)
cmp           | Compares to string literal               | O(n)
pop           | Removes the last character               | O(1)
substr        | Creates a string from a range            | O(n)
toOwned       | Creates an owned slice of the String     | O(1)
writer        | Returns a std.io.Writer for the String   | O(1)
iterator      | Returns a StringIterator over the String | O(1)
remove        | Removes a character at an index          | O(n)
removeRange   | Removes a range of characters            | O(n)
trimStart     | Remove whitelist from the start          | O(n)
trimEnd       | Remove whitelist from the end            | O(n)
trim          | Removes whitelist from both ends         | O(n)
toLowercase   | Converts (ASCII) characters to lowercase | O(n)
toUppercase   | Converts (ASCII) characters to uppercase | O(n)
find          | Finds first string literal appearance    | O(n)
split         | Returns a slice based on delimiters      | O(nm)
splitToString | Returns a String based on delimiters     | O(nm)
insert        | Inserts a character at an index          | O(n)
reverse       | Reverses all the characters              | O(n)
clone         | Copies this string to a new one          | O(n)
truncate      | Realloc to the length                    | O(1)
isEmpty       | Checks if length is zero                 | O(1)
repeat        | Repeats string n times                   | O(nm)
charAt        | Returns character at index               | O(1)
