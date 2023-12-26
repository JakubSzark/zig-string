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
var myString = String.init(arena.allocator());
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

Function      | Description                              
--------------|------------------------------------------
init          | Creates a String with an Allocator       
init_with_contents| Creates a String with specified contents 
deinit        | De-allocates the String                  
len           | Returns count of characters stored       
clear         | Clears the contents of the String        
allocate      | Sets the internal buffer size            
capacity      | Returns the capacity of the String       
str           | Returns the String as a slice           
concat        | Appends a string literal to the end      
cmp           | Compares to string literal              
pop           | Removes the last character              
substr        | Creates a string from a range          
toOwned       | Creates an owned slice of the String     
writer        | Returns a std.io.Writer for the String   
iterator      | Returns a StringIterator over the String 
remove        | Removes a character at an index          
removeRange   | Removes a range of characters            
trimStart     | Remove whitelist from the start          
trimEnd       | Remove whitelist from the end            
trim          | Removes whitelist from both ends         
toLowercase   | Converts (ASCII) characters to lowercase 
toUppercase   | Converts (ASCII) characters to uppercase 
find          | Finds first string literal appearance    
split         | Returns a slice based on delimiters      
splitToString | Returns a String based on delimiters     
insert        | Inserts a character at an index          
reverse       | Reverses all the characters              
clone         | Copies this string to a new one         
truncate      | Realloc to the length                    
isEmpty       | Checks if length is zero                 
repeat        | Repeats string n times                  
charAt        | Returns character at index               
