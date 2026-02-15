const std = @import("std");

pub fn main(_: std.process.Init.Minimal) !void {
    var gpa: std.heap.GeneralPurposeAllocator(.{ .thread_safe = true }) = .init;
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var ev: std.Io.Evented = undefined;
    try ev.init(allocator, .{});
    defer ev.deinit();
    const io = ev.io();

    var group: std.Io.Group = .init;
    for (0..10_000) |i| {
        group.async(io, maybePrint, .{ io, i });
    }
    try group.await(io);
}

fn maybePrint(io: std.Io, i: usize) !void {
    if (i % 5 != 0) return;
    const stdout = std.Io.File.stdout();
    var buf: [1024]u8 = undefined;
    var wr = stdout.writer(io, &buf);
    wr.interface.print("Hello from number {d}\n", .{i / 5}) catch return error.Canceled;
    wr.flush() catch return error.Canceled;
}
