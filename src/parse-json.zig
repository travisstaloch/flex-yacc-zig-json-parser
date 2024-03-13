const std = @import("std");
const log = std.log.scoped(.json);
const Value = std.json.Value;

extern fn yylex() i32;
extern const yylineno: i32;
extern const yytext: [*:0]const u8;
extern var yyin: ?*std.c.FILE;
extern fn yyparse(*ParseState) i32;

const ParseState = extern struct {
    parents: *std.ArrayListUnmanaged(*Value),
    value: ?*Value,
    arena: *const std.mem.Allocator,
    file_name: [*:0]const u8,
    strings: *std.StringHashMapUnmanaged(void),

    const Fmt = struct {
        state: *const ParseState,
        pub fn format(
            f: Fmt,
            comptime _fmt: []const u8,
            options: std.fmt.FormatOptions,
            writer: anytype,
        ) !void {
            _ = _fmt;
            _ = options;
            const nodetag = if (f.state.value) |v| @tagName(v.*) else "null";
            const parenttag = if (f.state.parents.items.len != 0)
                @tagName(f.state.parents.items[f.state.parents.items.len - 1].*)
            else
                "null";
            try writer.print("value {s} parent {s}", .{ nodetag, parenttag });
        }
    };

    fn fmt(state: *const ParseState) Fmt {
        return .{ .state = state };
    }

    fn dump(state: *const ParseState) void {
        log.debug("{}", .{state.fmt()});
    }

    fn pop(state: *ParseState) void {
        state.value = state.parents.popOrNull() orelse return;
    }

    fn onValue(state: *ParseState, value: Value) !void {
        if (state.value == null)
            state.value = try state.arena.create(Value);
        state.value.?.* = value;
    }

    fn internString(state: *ParseState, str: []const u8) ![]const u8 {
        const gop = try state.strings.getOrPut(state.arena.*, str);
        if (!gop.found_existing)
            gop.key_ptr.* = try state.arena.dupe(u8, str);
        return gop.key_ptr.*;
    }

    fn arrValue(state: *ParseState) !void {
        if (state.value) |v| try state.parents.append(state.arena.*, v);
        state.value = try state.value.?.array.addOne();
    }

    fn member(state: *ParseState, key: [*:0]const u8) !void {
        const s = std.mem.span(key);
        const unquoted = s[1 .. s.len - 1];
        const k = try state.internString(unquoted);
        const v = state.value.?;
        try state.parents.append(state.arena.*, v);
        const vgop = try v.object.getOrPut(k);
        state.value = vgop.value_ptr;
    }

    fn string(state: *ParseState, str: [*:0]const u8) !void {
        const s = std.mem.span(str);
        const unquoted = s[1 .. s.len - 1];
        try state.onValue(.{ .string = try state.internString(unquoted) });
        state.pop();
    }

    fn decimal(state: *ParseState, str: [*:0]const u8) !void {
        const s = std.mem.span(str);
        const f = std.fmt.parseFloat(f64, s) catch unreachable;
        const v: Value = if (std.math.isFinite(f))
            .{ .float = f }
        else
            .{ .number_string = try state.internString(s) };
        try state.onValue(v);
        state.pop();
    }

    fn integer(state: *ParseState, str: [*:0]const u8) !void {
        const s = std.mem.span(str);
        const v: Value = if (std.fmt.parseInt(i64, s, 10)) |i|
            .{ .integer = i }
        else |e| switch (e) {
            error.Overflow => .{ .number_string = try state.internString(s) },
            error.InvalidCharacter => unreachable,
        };
        try state.onValue(v);
        state.pop();
    }
};

export fn start_obj(state: *ParseState) void {
    log.debug("start_obj {}", .{state.fmt()});
    state.onValue(.{ .object = .{
        .allocator = state.arena.*,
        .unmanaged = .{},
        .ctx = .{},
    } }) catch @panic("OOM");
}

export fn end_obj(state: *ParseState) void {
    log.debug("start_obj {}", .{state.fmt()});
    state.pop();
}

export fn start_arr(state: *ParseState) void {
    log.debug("start_arr {}", .{state.fmt()});
    state.onValue(.{ .array = std.json.Array.init(state.arena.*) }) catch
        @panic("OOM");
}

export fn end_arr(state: *ParseState) void {
    log.debug("end_arr {}", .{state.fmt()});
    state.pop();
}

export fn arr_value(state: *ParseState) void {
    log.debug("arr_value()", .{});
    state.arrValue() catch @panic("OOM");
}

export fn member(state: *ParseState, str: [*:0]const u8) void {
    log.debug("member {s} {}", .{ str, state.fmt() });
    state.member(str) catch @panic("OOM");
}

export fn string(state: *ParseState, str: [*:0]const u8) void {
    log.debug("string {s} {}", .{ str, state.fmt() });
    state.string(str) catch @panic("OOM");
}

export fn decimal(state: *ParseState, str: [*:0]const u8) void {
    log.debug("decimal {s} {}", .{ str, state.fmt() });
    state.decimal(str) catch @panic("OOM");
}

export fn integer(state: *ParseState, str: [*:0]const u8) void {
    log.debug("integer {s}", .{str});
    state.integer(str) catch @panic("OOM");
}

export fn vtrue(state: *ParseState) void {
    log.debug("true", .{});
    state.onValue(.{ .bool = true }) catch @panic("OOM");
    state.pop();
}

export fn vfalse(state: *ParseState) void {
    log.debug("false", .{});
    state.onValue(.{ .bool = false }) catch @panic("OOM");
    state.pop();
}

export fn vnull(state: *ParseState) void {
    log.debug("null", .{});
    state.onValue(.null) catch @panic("OOM");
    state.pop();
}

pub const std_options = .{ .log_level = .warn };

pub fn main() !void {
    // while (true) {
    //     const tok: i32 = yylex();
    //     log.debug("{} {s}", .{ tok, yytext });
    //     if (tok == 0) break;
    // }

    var gpa_state = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(gpa_state.deinit() == .ok);
    const gpa = gpa_state.allocator();
    var arena_state = std.heap.ArenaAllocator.init(gpa);
    defer arena_state.deinit();
    const arena = arena_state.allocator();
    const args = try std.process.argsAlloc(arena);
    if (args.len != 2) {
        std.debug.print("missing argument: json file path\n", .{});
        return error.Args;
    }
    var parents = std.ArrayListUnmanaged(*Value){};
    var strings = std.StringHashMapUnmanaged(void){};
    var state = ParseState{
        .parents = &parents,
        .value = null,
        .arena = &arena,
        .file_name = args[1],
        .strings = &strings,
    };

    yyin = std.c.fopen(args[1], "r") orelse {
        std.debug.print("couldn't open file {s}\n", .{args[1]});
        return error.FileNotFound;
    };
    defer _ = std.c.fclose(yyin.?);

    const result = yyparse(@ptrCast(&state));
    log.debug("parse result {}", .{result});
    if (result == 0) {
        const stdout = std.io.getStdOut().writer();
        try std.json.stringify(state.value.?.*, .{ .escape_unicode = false }, stdout);
        try stdout.writeByte('\n');
    } else return error.Syntax;
}
