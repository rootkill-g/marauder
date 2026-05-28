const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const glfw = try buildGlfw(b, target, optimize);

    const host = b.addExecutable(.{
        .name = "marauder-host",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/host/main.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    host.root_module.linkLibrary(glfw);
    host.root_module.addIncludePath(b.path("vendor/glfw/include"));
    host.root_module.link_libc = true;

    const glfw_module = b.createModule(.{ .root_source_file = b.path("vendor/glfw.zig"), .target = target, .optimize = optimize, .link_libc = true });

    host.root_module.addImport("glfw", glfw_module);

    b.installArtifact(host);

    const renderer = b.addExecutable(.{
        .name = "marauder-renderer",
        .root_module = b.createModule(.{ .root_source_file = b.path("src/renderer/main.zig"), .target = target, .optimize = optimize }),
    });

    b.installArtifact(renderer);

    // `zig build run` runs the host, which will eventually spawn the renderer.
    const run_host = b.addSystemCommand(&.{"./zig-out/bin/marauder-host"});
    run_host.step.dependOn(b.getInstallStep());
    const run_step = b.step("run", "Run the host process");
    run_step.dependOn(&run_host.step);
}

fn buildGlfw(b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode) !*std.Build.Step.Compile {
    const lib = b.addLibrary(.{
        .name = "glfw",
        .linkage = .static,
        .root_module = b.createModule(.{ .target = target, .optimize = optimize }),
    });

    lib.root_module.link_libc = true;
    lib.root_module.addIncludePath(b.path("vendor/glfw/include"));

    lib.root_module.addCSourceFiles(.{ .files = &.{
        "vendor/glfw/src/context.c",
        "vendor/glfw/src/init.c",
        "vendor/glfw/src/input.c",
        "vendor/glfw/src/monitor.c",
        "vendor/glfw/src/platform.c",
        "vendor/glfw/src/vulkan.c",
        "vendor/glfw/src/window.c",
        "vendor/glfw/src/egl_context.c",
        "vendor/glfw/src/osmesa_context.c",
        "vendor/glfw/src/null_init.c",
        "vendor/glfw/src/null_monitor.c",
        "vendor/glfw/src/null_window.c",
        "vendor/glfw/src/null_joystick.c",
    }, .flags = &.{} });

    switch (target.result.os.tag) {
        .linux, .freebsd, .netbsd, .openbsd, .dragonfly, .hurd => {
            lib.root_module.addCMacro("_GLFW_X11", "");
            lib.root_module.addCSourceFiles(.{ .files = &.{
                "vendor/glfw/src/x11_init.c",
                "vendor/glfw/src/x11_monitor.c",
                "vendor/glfw/src/x11_window.c",
                "vendor/glfw/src/xkb_unicode.c",
                "vendor/glfw/src/posix_module.c",
                "vendor/glfw/src/posix_time.c",
                "vendor/glfw/src/posix_thread.c",
                "vendor/glfw/src/posix_poll.c",
                "vendor/glfw/src/glx_context.c",
            }, .flags = &.{} });

            lib.root_module.linkSystemLibrary("X11", .{});
        },
        .macos => {
            lib.root_module.addCMacro("_GLFW_COCOA", "");
            lib.root_module.addCSourceFiles(.{ .files = &.{
                "vendor/glfw/src/cocoa_init.m",
                "vendor/glfw/src/cocoa_monitor.m",
                "vendor/glfw/src/cocoa_window.m",
                "vendor/glfw/src/cocoa_joystick.m",
                "vendor/glfw/src/cocoa_time.c",
                "vendor/glfw/src/nsgl_context.m",
                "vendor/glfw/src/posix_module.c",
                "vendor/glfw/src/posix_thread.c",
            }, .flags = &.{} });
            lib.root_module.linkFramework("Cocoa", .{});
            lib.root_module.linkFramework("IOKit", .{});
            lib.root_module.linkFramework("CoreFoundation", .{});
        },
        else => {
            std.debug.print(
                "Marauder supports Linux, FreeBSD, OpenBSD, NetBSD, DragonflyBSD, GNU Hurd, and macOS.\n" ++
                    "Your target '{s}' is not currently supported.\n",
                .{@tagName(target.result.os.tag)},
            );
            @panic("Unsupported Host Operating System");
        },
    }

    return lib;
}
