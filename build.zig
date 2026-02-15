const std = @import("std");
const mb_build = @import("moon_base");
pub const Language = mb_build.Language;

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const lang = b.option(mb_build.Language, "lang", "Version of Lua to build against");

    const mb = b.dependency("moon_base", .{
        .target = target,
        .optimize = optimize,
        .lang = lang,
    });
    const opts = b.addOptions();
    opts.addOption(Language, "lang", lang orelse .lua55);

    const mod = b.addModule("pollux", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
    });
    mod.addImport("mb", mb.module("moon-base"));

    const pollux_lib = mb_build.addLuaDylib(b, mod, target, "pollux");
    const install = b.addInstallLibFile(pollux_lib, pollux_lib.basename(b, b.getInstallStep()));
    b.getInstallStep().dependOn(&install.step);

    // const run_step = b.step("run", "Run the app");

    // const run_cmd = b.addRunArtifact(exe);
    // run_step.dependOn(&run_cmd.step);

    // run_cmd.step.dependOn(b.getInstallStep());

    const mod_tests = b.addTest(.{
        .root_module = mod,
    });

    const run_mod_tests = b.addRunArtifact(mod_tests);

    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&run_mod_tests.step);
}
