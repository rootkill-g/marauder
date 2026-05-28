const std = @import("std");
const glfw = @import("glfw");

pub fn main(init: std.process.Init) !void {
    if (glfw.glfwInit() == glfw.GLFW_FALSE) {
        std.debug.print("Failed to initialize glfw", .{});
        return error.GlfwInitFailed;
    }
    defer glfw.glfwTerminate();

    glfw.glfwWindowHint(glfw.GLFW_CLIENT_API, glfw.GLFW_NO_API);

    const window = glfw.glfwCreateWindow(1024, 768, "marauder", null, null) orelse {
        std.debug.print("Failed to create window\n", .{});
        return error.WindowCreationFailed;
    };
    defer glfw.glfwDestroyWindow(window);

    std.debug.print("marauder host started\n", .{});

    // spawn renderer engine
    spawnRenderer(init.io, init.gpa) catch |err| {
        std.debug.print("Failed to spawn renderer: {s}\n", .{@errorName(err)});
        return err;
    };

    while (glfw.glfwWindowShouldClose(window) == glfw.GLFW_FALSE) {
        glfw.glfwPollEvents();
    }
}

fn spawnRenderer(io: std.Io, gpa: std.mem.Allocator) !void {
    const self_dir = try std.process.executableDirPathAlloc(io, gpa);
    defer gpa.free(self_dir);

    const renderer_path = try std.fs.path.join(gpa, &.{ self_dir, "marauder-renderer" });
    defer gpa.free(renderer_path);

    const argv = [_][]const u8{renderer_path};
    _ = try std.process.spawn(io, .{ .argv = &argv });
}
