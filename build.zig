// skein-static (#52, split out of skein by #71): the static file handler, a
// skein app. Zig 0.16.0, wasm32-wasi, over the SDK (skein-sdk: `cbor`, `sk`).
//
//   zig build        → zig-out/bin/static.wasm
//   zig build bin    the same, written to bin/static.wasm (the app tree's module; committed)
//   zig build test   content types, paths, escapes refused, If-None-Match — natively
//
// The build is reproducible: bin/static.wasm's raw CID is the one skein pinned
// for `static` (bafkreiewar6biptwbkvwmrymqixp24nyekcv6skzibbw57mnkwuiykvazu at 0.1.0).
const std = @import("std");

pub fn build(b: *std.Build) void {
    const wasi = b.resolveTargetQuery(.{ .cpu_arch = .wasm32, .os_tag = .wasi });
    const exe = b.addExecutable(.{ .name = "static", .root_module = module(b, wasi, .ReleaseSafe, true) });
    b.installArtifact(exe);

    const bin = b.addUpdateSourceFiles();
    bin.addCopyFileToSource(exe.getEmittedBin(), "bin/static.wasm");
    b.step("bin", "write the module into the app tree: bin/static.wasm").dependOn(&bin.step);

    const tests = b.addTest(.{ .root_module = module(b, b.standardTargetOptions(.{}), .Debug, false) });
    const test_step = b.step("test", "Content types, paths, escapes refused, If-None-Match");
    test_step.dependOn(&b.addRunArtifact(tests).step);
}

fn module(b: *std.Build, t: std.Build.ResolvedTarget, o: std.builtin.OptimizeMode, strip: bool) *std.Build.Module {
    const sdk = b.dependency("skein_sdk", .{ .target = t, .optimize = o, .wallet = false });
    return b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = t,
        .optimize = o,
        .strip = strip,
        .imports = &.{ .{ .name = "cbor", .module = sdk.module("cbor") }, .{ .name = "sk", .module = sdk.module("sk") } },
    });
}
