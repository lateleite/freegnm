const std = @import("std");
const builtin = @import("builtin");
const fs = std.fs;
const Io = std.Io;
const mem = std.mem;
const fatal = std.process.fatal;

const gnm = @import("gnm");
const pm4 = gnm.pm4;

pub fn main(init: std.process.Init) !void {
    // const arena = init.arena.allocator();
    const io = init.io;

    var stderr_buffer: [1024]u8 = undefined;
    var stderr_writer = Io.File.stderr().writer(io, &stderr_buffer);
    const stderr = &stderr_writer.interface;
    defer stderr.flush() catch {};

    var stdout_buffer: [1024]u8 = undefined;
    var stdout_writer = Io.File.stdout().writer(io, &stdout_buffer);
    const stdout = &stdout_writer.interface;
    defer stdout.flush() catch {};

    var args_it = init.minimal.args.iterate();
    // skip our path
    _ = args_it.skip();

    const file_path = args_it.next() orelse
        fatal("Please pass an input path to a PM4 packet data file", .{});
    const file = Io.Dir.cwd().openFile(io, file_path, .{}) catch |err| {
        fatal("Failed to open file {s} with {t}", .{ file_path, err });
    };
    defer file.close(io);

    var file_read_buf: [512]u8 = undefined;
    var file_reader = file.reader(io, &file_read_buf);

    var dword_offset: usize = 0;
    var pkt_buffer: [32]u32 = undefined;
    var pkt_reader: pm4.Reader = .init(&file_reader.interface);
    while (pkt_reader.next(&pkt_buffer)) |pkt| : (dword_offset += pkt.data.len + 1) {
        const offset = dword_offset * @sizeOf(u32);
        try stdout.print("{x:08}: {f}\n", .{ offset, pkt });

        if (pkt.header.kind == .pkt3) {
            switch (pkt.header.info.pkt3.it_opcode) {
                else => {},
                .nop => for (0..pkt.header.count + 1) |i| {
                    try stdout.print("  {x:08}\n", .{pkt_buffer[i]});
                },
                .set_context_reg,
                .set_sh_reg,
                .set_uconfig_reg,
                => for (1..pkt.header.count + 1) |i| {
                    try stdout.print("  {x:08}\n", .{pkt_buffer[i]});
                },
            }
        }
    } else |err| switch (err) {
        error.EndOfStream => {},
        else => {
            try stderr.print("Failed to read command with {t}\n", .{err});
        },
    }
}
