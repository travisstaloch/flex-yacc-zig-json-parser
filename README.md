# About
Explore using a flex/yacc parser from zig to build a json Ast.  The resulting json parser is able to parse complex json files such as [twitter.json](https://github.com/simdjson/simdjson/blob/master/jsonexamples/twitter.json), build a `std.json.Value` Ast, and print it using `std.json.stringify()`.


- [x] use the [zig build system](build.zig) to run flex and yacc, creating lexer and parser .c files. Thanks to @MasterQ32 for showing the way in [apigen](https://github.com/MasterQ32/apigen)!
- [x] pass a zig ParseState struct back and forth between zig and c
  - [x] duplicate ParseState declarations, one in [src/parse-json.zig](src/parse-json.zig), and one in [src/parser.h](src/parser.h)
  - [x] export methods in [src/parse-json.zig](src/parse-json.zig)
  - [x] reference and call those methods from [src/json-parser.y](src/json-parser.y)
- [x] diagnostics
  - [x] select and save input file name from zig main(), assign `yyin`
  - [x] use `%locations` option in [src/json-parser.y](src/json-parser.y)
  - [x] provide `YY_USER_ACTION` in [src/json-scanner.l](src/json-scanner.l) which updates `yyloc`
  - [x] error format `<file>:<line>:<column> <message>`
    - [x] `yyerror()` in [src/json-parser.y](src/json-parser.y)
- [x] allow valid utf-8 in strings

# References

- https://github.com/MasterQ32/apigen
- https://lloydrochester.com/post/flex-bison/json-parse/
- https://gist.github.com/justjkk/436828/
- https://westes.github.io/flex/
- https://stackoverflow.com/questions/9611682/flexlexer-support-for-unicode