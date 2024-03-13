const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // TODO: Make yacc/bison package so we can get rid of system dependency
    const parser_gen = b.addSystemCommand(&.{ "yacc", "-d" });
    const parser_c_source = parser_gen.addPrefixedOutputFileArg("-o", "parser.yy.c");
    parser_gen.addFileArg(.{ .path = "src/json-parser.y" });

    // const lexer_gen = b.addSystemCommand(&.{"flex"});
    const flex_dep = b.dependency("flex", .{});
    const flex = flex_dep.artifact("flex");
    const lexer_gen = b.addRunArtifact(flex);
    const lexer_c_source = lexer_gen.addPrefixedOutputFileArg("-o", "lexer.yy.c");
    lexer_gen.addFileArg(.{ .path = "src/json-scanner.l" });
    lexer_gen.step.dependOn(&parser_gen.step);

    const exe = b.addExecutable(.{
        .name = "parse-json",
        .root_source_file = .{ .path = "src/parse-json.zig" },
        .target = target,
        .optimize = optimize,
    });
    exe.linkLibC();
    exe.addIncludePath(.{ .path = "src" });
    exe.addIncludePath(parser_c_source.dirname());
    exe.addCSourceFile(.{ .file = parser_c_source });
    exe.addCSourceFile(.{ .file = lexer_c_source });
    b.installArtifact(exe);
    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }
    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
    // const exe_unit_tests = b.addTest(.{
    //     .root_source_file = .{ .path = "src/main.zig" },
    //     .target = target,
    //     .optimize = optimize,
    // });
    // const run_exe_unit_tests = b.addRunArtifact(exe_unit_tests);
    // const test_step = b.step("test", "Run unit tests");
    // test_step.dependOn(&run_exe_unit_tests.step);
}
