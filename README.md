# Zig String
A UTF-8 String Library made in Zig

I made this for the sole purpose to further my experience and understanding of zig.
Also it may be useful for some people who need it (including myself), with future projects.

# Things needed
- Optimizations
- Any missing useful functionality
- Better documentation
- More Tests

# How to Contribute
1. Fork
2. Clone
3. Add Features (Use Zig FMT)
4. Make Pull Request
5. Success!

# Working Features
If there are any issues with <b>complexity</b> please <b>open an issue</b>
(I'm no expert when it comes to complexity)

Function      | Description                          | Complexity (Best)
--------------|--------------------------------------|-----------
init          | Creates a String with an Allocator   | O(1)
deinit        | De-allocates the String              | O(1)
clear         | Clears the contents of the String    | O(n)
setCapacity   | Sets the internal buffer size        | O(1)
capacity      | Returns the capacity of the String   | O(1)
str           | Returns the String as a slice        | O(1)
concat        | Appends a string literal to the end  | O(n)?
push          | Appends a character to the end       | O(1)
cmp           | Compares to string literal           | O(n)
pop           | Removes the last character           | O(1)
substr        | Creates a string from a range        | O(n)
remove        | Removes a character at an index      | O(n)
removeRange   | Removes a range of characters        | O(n)
contains      | Whether a string literal is present  | O(n)
trimStart     | Remove whitespace from the start     | O(n)
trimEnd       | Remove whitespace from the end       | O(n)
trim          | Removes whitespace from both ends    | O(n)
toLowercase   | Converts characters to lowercase     | O(n)
toUppercase   | Converts characters to uppercase     | O(n)
find          | Finds a character                    | O(n)
split         | Returns a slice based on delimiter   | O(n)
insert        | Inserts a character at an index      | O(n)
insertStr     | Inserts string literal at index      | O(nm)
reverse       | Reverses all the characters          | O(n)
clone         | Copies this string to a new one      | O(n)
compact       | Realloc to the length                | O(1)
isEmpty       | Checks if length is zero             | O(1)
repeat        | Repeats string n times               | O(nm)
charAt        | Returns character at index           | O(1)
