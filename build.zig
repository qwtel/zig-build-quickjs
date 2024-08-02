const std = @import("std");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const mode = b.standardOptimizeOption(.{});

    const lib = b.addStaticLibrary(.{
        .name = "qjs",
        .target = target,
        .optimize = mode,
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
        "-funsigned-char",
        "-fno-sanitize=undefined",
    };

    // if(CMAKE_SYSTEM_NAME STREQUAL "WASI")
    //     add_compile_definitions(
    //         _WASI_EMULATED_PROCESS_CLOCKS
    //         _WASI_EMULATED_SIGNAL
    //     )
    //     add_link_options(
    //         -lwasi-emulated-process-clocks
    //         -lwasi-emulated-signal
    //     )
    // endif()

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
        "libbf.c",
        "libregexp.c",
        "libunicode.c",
        "quickjs.c",
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

    lib.defineCMacro("_GNU_SOURCE", "1"); // XXX: can we just set that optimistically?
    if (target.result.os.tag == .windows) {
        lib.defineCMacro("WIN32_LEAN_AND_MEAN", "1");
        lib.defineCMacro("_WIN32_WINNT", "0x0602");
        if (target.result.abi != .msvc) {
            lib.defineCMacro("_MSC_VER", "1900"); // HACK: Setting fake MSC version to trigger the right code paths in cutils
            lib.linkSystemLibrary("kernel32"); // XXX: why does this not work when abi is msvc?
        } else { // abi == .msvc
            // TODO: make this work
        }
    }

    if (target.result.os.tag != .windows and target.result.os.tag != .wasi) {
        lib.linkSystemLibrary("pthread");
    }

    if (mode == .Debug) {
        lib.defineCMacro("DUMP_LEAKS", "1");
    }

    lib.installHeadersDirectory(b.path("."), "", .{});

    b.installArtifact(lib);
}
