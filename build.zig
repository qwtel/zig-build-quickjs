const std = @import("std");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const mode = b.standardOptimizeOption(.{});

    const txiki_extras = b.option(bool, "extras", "Define ZIG_BUILD_TXIKI_EXTRAS") orelse false;

    const lib = b.addLibrary(.{
        .linkage = .static,
        .name = "qjs",
        .root_module = b.createModule(.{
            .target = target,
            .optimize = mode,
        }),
    });

    lib.addIncludePath(b.path("."));

    const common_flags: []const []const u8 = &.{
        "-std=c11",
        "-Wno-implicit-fallthrough",
        "-Wno-sign-compare",
        "-Wno-missing-field-initializers",
        "-Wno-unused-parameter",
        "-Wno-unused-but-set-variable",
        "-Wno-array-bounds",
        "-Wno-format-truncation",
        "-Wno-format-zero-length",
        "-funsigned-char",
        "-fno-sanitize=undefined",
    };

    if (target.result.os.tag == .wasi) {
        lib.root_module.addCMacro("_WASI_EMULATED_PROCESS_CLOCKS", "1");
        lib.root_module.addCMacro("_WASI_EMULATED_SIGNAL", "1");
        // XXX: Zig build doesn't have a way to set link options (afaik)
        // add_link_options(
        //     -lwasi-emulated-process-clocks
        //     -lwasi-emulated-signal
        // )
    }

    var flags = common_flags;
    if (mode == .Debug) {
        const debug_flags: []const []const u8 = &.{
            "-ggdb", // XXX: Is this even necessary?
            "-fno-omit-frame-pointer",
        };

        flags = common_flags ++ debug_flags;
    }

    const files: []const []const u8 = &.{
        "cutils.c",
        "libregexp.c",
        "libunicode.c",
        "quickjs.c",
        "xsum.c",
    };

    // XXX: does that make any sense??
    // const config_qjs_libc = b.option(bool, "qjs-libc", "Build standard library modules as part of the library") orelse false;
    // if (config_qjs_libc) {
    // files = files ++ &.{"quickjs-libc.c"};
    // } else {
    // }

    lib.addCSourceFiles(.{
        .files = files,
        .flags = flags,
    });
    lib.linkLibC();

    lib.root_module.addCMacro("_GNU_SOURCE", "1");
    if (target.result.os.tag == .windows) {
        lib.root_module.addCMacro("WIN32_LEAN_AND_MEAN", "1");
        lib.root_module.addCMacro("_WIN32_WINNT", "0x0602"); // ???
    }

    if (target.result.os.tag != .windows and target.result.os.tag != .wasi) {
        lib.linkSystemLibrary("pthread");
    }

    if (mode == .Debug) {
        lib.root_module.addCMacro("DUMP_LEAKS", "0x4000");
    }

    if (txiki_extras) {
        lib.root_module.addCMacro("ZIG_BUILD_TXIKI_EXTRAS", "1");
    }

    lib.installHeadersDirectory(b.path("."), "", .{});

    b.installArtifact(lib);
}
