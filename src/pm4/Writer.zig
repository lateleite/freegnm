const std = @import("std");
const math = std.math;
const mem = std.mem;
const assert = std.debug.assert;

const pm4 = @import("../pm4.zig");

backing_memory: []u32,
current_dword: u32,

const Writer = @This();

pub fn init(backing_memory: []u32) Writer {
    return Writer{
        .backing_memory = backing_memory,
        .current_dword = 0,
    };
}

pub fn reset(self: *Writer) void {
    self.current_dword = 0;
}

pub fn getWritten(self: *Writer) []u32 {
    return self.backing_memory[0..self.current_dword];
}

pub const WriteError = error{Overflow};

pub fn checkCapacity(self: Writer, num_dwords: u32) WriteError!void {
    if (self.current_dword + num_dwords > self.backing_memory.len) {
        @branchHint(.unlikely);
        return error.Overflow;
    }
}

pub fn writeDword(self: *Writer, value: u32) WriteError!void {
    try self.checkCapacity(1);

    const swapped_value = mem.nativeToLittle(u32, value);
    self.backing_memory[self.current_dword] = swapped_value;
    self.current_dword += 1;
}

pub fn writeStruct(self: *Writer, comptime T: type, value: T) WriteError!void {
    comptime {
        assert(@sizeOf(T) > 0);
        assert(@sizeOf(T) % 4 == 0);
    }

    const type_dwords = @sizeOf(T) / 4;
    const value_dwords = @as([*]const u32, @ptrCast(@alignCast(&value)))[0..type_dwords];

    try self.checkCapacity(type_dwords);

    for (value_dwords) |dw| {
        const swapped_dw = mem.nativeToLittle(u32, dw);
        self.backing_memory[self.current_dword] = swapped_dw;
        self.current_dword += 1;
    }
}

pub fn reserveDwords(self: *Writer, num_dwords: u32) WriteError![]u32 {
    try self.checkCapacity(num_dwords);

    const result = self.backing_memory[self.current_dword..][0..num_dwords];
    self.current_dword += num_dwords;
    return result;
}

pub fn allocInlineMany(
    self: *Writer,
    comptime T: type,
    count: u14,
    alignment: u16,
) WriteError![]align(4) T {
    assert(alignment != 0 and (alignment & 3) == 0);

    const length: u32 = @sizeOf(T) * count;
    const aligned_length = mem.alignForward(u32, length, alignment);
    const len_dwords = aligned_length / @sizeOf(u32);

    const cur_offset = self.current_dword * @sizeOf(u32);
    const aligned_offset = mem.alignForward(u32, cur_offset, alignment);

    const unaligned_len = aligned_offset - cur_offset;
    const unaligned_dwords = unaligned_len / @sizeOf(u32);

    const needed_dwords_data = unaligned_dwords + len_dwords;
    const needed_dwords_full = 1 + needed_dwords_data;

    assert(needed_dwords_full >= 2);
    try self.checkCapacity(needed_dwords_full);

    const dword_count = math.cast(u14, needed_dwords_full - 2) orelse {
        @branchHint(.unlikely);
        return error.Overflow;
    };

    try self.writeDword(@bitCast(pm4.Header{
        .kind = .pkt3,
        .count = dword_count,
        .info = .{ .pkt3 = .{
            .predicate = false,
            .shader = .graphics,
            .it_opcode = .nop,
        } },
    }));
    const memory = try self.reserveDwords(needed_dwords_data);
    const aligned_memory = memory[unaligned_dwords..];

    return @as([*]align(4) T, @ptrCast(@alignCast(aligned_memory)))[0..count];
}

pub fn allocInline(self: *Writer, comptime T: type, alignment: u16) WriteError!*align(4) T {
    const result = try self.allocInlineMany(T, 1, alignment);
    return &result[0];
}

pub fn saveState(self: Writer) u32 {
    return self.current_dword;
}

pub fn restoreState(self: *Writer, state: u32) void {
    self.current_dword = state;
}

const testing = std.testing;

test "packet writing" {
    var buf: [32]u32 = undefined;
    var w = Writer.init(&buf);

    try w.writeDword(0xc0301020);
    try w.writeDword(0x99999999);
    try w.writeDword(0x98765432);
    try testing.expectEqual(0xc0301020, buf[0]);
    try testing.expectEqual(0x99999999, buf[1]);
    try testing.expectEqual(0x98765432, buf[2]);
}
