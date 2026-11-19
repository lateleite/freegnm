const std = @import("std");
const Io = std.Io;
const mem = std.mem;
const assert = std.debug.assert;

const gnm = @import("../gnm.zig");
const pm4 = @import("../pm4.zig");

input: *Io.Reader,

const Reader = @This();

pub fn init(input: *Io.Reader) Reader {
    return .{
        .input = input,
    };
}

pub const NextError = error{
    BufferTooSmall,
    InvalidPacketKind,
    InvalidPacketCount,
} || Io.Reader.Error;

pub fn next(self: *Reader, pkt_data_buffer: []u32) NextError!Packet {
    const reader = self.input;
    const header = try reader.takeStruct(pm4.Header, .little);

    const dwords_to_read = @as(u16, header.count) + 1;
    if (dwords_to_read > pkt_data_buffer.len) {
        @branchHint(.unlikely);
        return error.BufferTooSmall;
    }

    const expected_dwords: ?u16 = switch (header.kind) {
        .pkt0 => 2,
        .pkt2 => 2,
        .pkt3 => switch (header.info.pkt3.it_opcode) {
            else => null, // TODO: add in any missing packet sizes
            .nop => 2 + @as(u16, header.count),
            .draw_preamble => 4,
            .draw_index_2 => 6,
            .draw_index_offset_2 => 5,
            .draw_index_auto => 3,
            .draw_index_immd => 3,
            .index_type => 2,
            .index_attributes_indirect => 4,
            .index_buffer_size => 2,
            .num_instances => 2,
            .index_base => 3,
            .set_base => 4,
            .load_config_reg,
            .load_context_reg,
            .load_sh_reg,
            => 5 + @as(u16, header.count),
            .load_context_reg_index,
            .load_sh_reg_index,
            => 5 + @as(u16, header.count),
            .wait_reg_mem => 7,
            .event_write => 2, // TODO: or 4 in certain situations
            .event_write_eop => 6,
            .strmout_buffer_update => 6,
            .context_control => 3,
            .set_predication => 3,
            .surface_sync => 5,
            .dispatch_direct => 5,
            .dispatch_indirect => 3, // TODO: or 4 with MEC
            .clear_state => 2,
            .event_write_eos => 5,
            .scratch_ram_write => 3,
            .write_const_ram => 2,
            .dump_const_ram => 5,
            .load_const_ram => 5,
            .increment_ce_counter => 2,
            .increment_de_counter => 2,
            .wait_on_ce_counter => 2,
            .wait_on_de_counter_diff => 2,
            .indirect_buffer_const => 4,
            .indirect_buffer => 4,
            .set_sh_reg_offset => 4,
            .draw_index_indirect => 5,
            .draw_index_indirect_multi => 10,
            .draw_index_multi_auto => 4,
            .draw_indirect => 5,
            .draw_indirect_multi => 10,
            .mpeg_index => 4,
            .cond_exec => 4,
            .cond_write => 9,
            .pred_exec => 2,
            .atomic_mem => 9,
            .atomic_gds => 2,
            .occlusion_query => 5,
            .cp_dma => 6,
            .reg_rmw => 4,
            .write_data => 4,
            .preamble_cntl => 2,
            .set_context_reg_indirect => 2,
            .mem_semaphore => 3,
            .pfp_sync_me => 2,
            .copy_data => 6,
            .acquire_mem => 7,
            .dma_data => 7,
            .release_mem => 7,
            .rewind => 2,
            .set_config_reg,
            .set_context_reg,
            .set_sh_reg,
            .set_sh_reg_index,
            .set_uconfig_reg,
            => 2 + @as(u16, header.count),
        },
        _ => return error.InvalidPacketKind,
    };
    if (expected_dwords) |expected| {
        if (expected != dwords_to_read + 1) {
            @branchHint(.unlikely);
            return error.InvalidPacketCount;
        }
    }

    const packet_data = pkt_data_buffer[0..dwords_to_read];
    try reader.readSliceEndian(u32, packet_data, .little);

    return .{
        .header = header,
        .data = packet_data,
    };
}

pub const Packet = struct {
    header: pm4.Header,
    data: []const u32,

    pub fn readStruct(self: Packet, index: u32, comptime T: type) T {
        comptime assert(@sizeOf(T) >= @sizeOf(u32));
        comptime assert(@sizeOf(T) % @sizeOf(u32) == 0);

        const struct_dwords = @sizeOf(T) / @sizeOf(u32);
        assert(index + struct_dwords <= self.data);

        const data: *const T = @ptrCast(@alignCast(self.data[index..]));
        return data.*;
    }

    pub fn format(self: Packet, writer: *Io.Writer) !void {
        switch (self.header.kind) {
            else => try writer.print("[unknown packet kind {}]", .{@backingInt(self.header.kind)}),
            .pkt0 => try writer.print("pkt0_draw, base_index {}", .{self.header.info.pkt0.base_index}),
            .pkt2 => try writer.writeAll("pkt2_nop"),
            .pkt3 => {
                const opcode = self.header.info.pkt3.it_opcode;

                // command name
                try writer.print("pkt3_{t}", .{opcode});

                // command arguments
                switch (self.header.info.pkt3.it_opcode) {
                    else => {},
                    .nop => try writer.print("(count={})", .{self.header.count}),
                    .index_buffer_size => try writer.print("(count={})", .{self.data[0]}),
                    .index_base => {
                        const base = self.data[0] + (@as(u64, self.data[1]) << 32);
                        try writer.print("(base={x})", .{base});
                    },
                    .draw_index_2 => {
                        const max_count = self.data[0];
                        const base_va = self.data[1] + (@as(u64, self.data[2]) << 32);
                        const count = self.data[3];
                        try writer.print("(max_count={}, base_va={x}, count={})", .{ max_count, base_va, count });
                    },
                    .draw_index_auto => {
                        const count = self.data[0];
                        try writer.print("(count={})", .{count});
                    },
                    .draw_index_offset_2 => {
                        const max_count = self.data[0];
                        const base_va = self.data[1] + (@as(u64, self.data[2]) << 32);
                        const count = self.data[3];
                        try writer.print("(max_count={}, base_va={x}, count={})", .{ max_count, base_va, count });
                    },
                    .wait_reg_mem => {
                        const op: u3 = @truncate(self.data[0]);
                        const addr = self.data[1] + (@as(u64, self.data[2]) << 32);
                        const ref = self.data[3];
                        const mask = self.data[4];
                        const poll_int = self.data[5];
                        try writer.print("(op={}, addr={x}, ref={x}, mask={x}, poll_int={})", .{ op, addr, ref, mask, poll_int });
                    },
                    .event_write_eop => {
                        const flags = self.data[0];
                        const addr = self.data[1] + ((@as(u64, self.data[2]) & 0xffff) << 32);
                        const flags2: u16 = @truncate(self.data[2] >> 16);
                        const data = self.data[3] + (@as(u64, self.data[4]) << 32);
                        try writer.print("(flags={x}, addr={x}, flags2={x}, data={x})", .{ flags, addr, flags2, data });
                    },
                    .event_write_eos => {
                        const eos_type: u6 = @truncate(self.data[0]);
                        const addr = self.data[1] + ((@as(u64, self.data[2]) & 0xffff) << 32);
                        const sel: u16 = @truncate(self.data[2] >> 16);
                        const val = self.data[3];
                        try writer.print("(type={x}, addr={x}, sel={x}, val={x})", .{ eos_type, addr, sel, val });
                    },
                    .dma_data => {
                        const src_sel: u2 = @truncate(self.data[0] << 25);
                        const dst_sel: u2 = @truncate(self.data[0] << 20);
                        const src_va = self.data[1] + (@as(u64, self.data[2]) << 32);
                        const dst_va = self.data[3] + (@as(u64, self.data[4]) << 32);
                        const length: u21 = @truncate(self.data[5]);
                        const wr_confirm = ((self.data[2] >> 21) & 1) != 0;
                        try writer.print("(src_sel={x}, dst_sel={x}, src_va={x}, dst_va={x}, length={x} wr_confirm={})", .{ src_sel, dst_sel, src_va, dst_va, length, wr_confirm });
                    },
                    .acquire_mem => {
                        const coher_ctrl = self.data[0];
                        const coher_size = self.data[1] + ((@as(u64, self.data[2]) & 0xffffff) << 32);
                        const coher_base = self.data[3] + ((@as(u64, self.data[4]) & 0xffffff) << 32);
                        const poll_int: u16 = @truncate(self.data[5]);
                        try writer.print("(ctrl={x}, cohersize={x}, coherbase={x}, pollint={})", .{ coher_ctrl, coher_size, coher_base, poll_int });
                    },
                    .set_context_reg => {
                        const reg: pm4.ContextRegister = @fromBackingInt(self.data[0]);
                        try writer.print("(reg={t})", .{reg});
                    },
                    .set_sh_reg => {
                        const reg: pm4.ShRegister = @fromBackingInt(self.data[0]);
                        try writer.print("(reg={t})", .{reg});
                    },
                    .set_uconfig_reg => {
                        const reg: pm4.UConfigRegister = @fromBackingInt(self.data[0]);
                        try writer.print("(reg={t})", .{reg});
                    },
                }

                // flags
                // try writer.print(" [{t}]", .{self.header.info.pkt3.shader});
                if (self.header.info.pkt3.predicate) {
                    try writer.writeAll(" [pred]");
                }
            },
        }
    }
};

const testing = std.testing;
const test_data = @import("test_data");

test "packet parsing" {
    const EXPECTED_KINDS = [_]pm4.Header.Kind{
        .pkt3, .pkt3, .pkt3, .pkt3, .pkt3,
        .pkt3, .pkt3, .pkt3, .pkt3, .pkt3,
        .pkt3, .pkt3, .pkt3, .pkt3, .pkt3,
        .pkt3, .pkt3, .pkt3, .pkt3, .pkt3,
        .pkt3, .pkt3, .pkt3, .pkt3, .pkt3,
        .pkt3, .pkt3, .pkt3, .pkt3, .pkt3,
        .pkt3, .pkt3, .pkt3, .pkt3, .pkt3,
        .pkt3, .pkt3, .pkt3, .pkt3, .pkt3,
        .pkt3, .pkt3, .pkt3, .pkt3, .pkt3,
        .pkt3, .pkt3, .pkt3, .pkt3, .pkt3,
        .pkt3, .pkt3, .pkt3, .pkt3, .pkt3,
        .pkt3, .pkt3, .pkt3, .pkt3, .pkt3,
        .pkt3, .pkt3, .pkt3,
    };

    const cmd_data = &test_data.pm4_packet;

    var reader: Io.Reader = .fixed(cmd_data);
    var parser: Reader = .init(&reader);

    var pkt_buffer: [64]u32 = undefined;

    for (EXPECTED_KINDS) |expected_kind| {
        const pkt = try parser.next(&pkt_buffer);
        try testing.expectEqual(expected_kind, pkt.header.kind);
    }
}

test "bad packet parsing" {
    const cmd_data: []const u32 = &[_]u32{
        0xc0016900, 0x00000000, 0x00000000, 0xd0016900, 0x00000000,
    };

    var reader: Io.Reader = .fixed(@ptrCast(cmd_data));
    var parser = Reader.init(&reader);

    var pkt_buffer: [64]u32 = undefined;
    {
        const pkt = try parser.next(&pkt_buffer);
        try testing.expectEqual(.pkt3, pkt.header.kind);
        try testing.expectEqual(.set_context_reg, pkt.header.info.pkt3.it_opcode);
    }
    try testing.expectError(error.BufferTooSmall, parser.next(&pkt_buffer));
}

test "packet formating" {
    const EXPECTED_STRINGS = [_][]const u8{
        "pkt3_set_context_reg(reg=db_render_control)",
        "pkt3_set_context_reg(reg=db_depth_control)",
        "pkt3_set_sh_reg(reg=spi_shader_pgm_lo_vs)",
        "pkt3_set_sh_reg(reg=spi_shader_pgm_rsrc1_vs)",
        "pkt3_set_context_reg(reg=pa_cl_vs_out_cntl)",
        "pkt3_set_context_reg(reg=spi_vs_out_config)",
        "pkt3_set_context_reg(reg=spi_shader_pos_format)",
        "pkt3_nop(count=10)",
        "pkt3_set_sh_reg(reg=spi_shader_pgm_lo_ps)",
        "pkt3_set_sh_reg(reg=spi_shader_pgm_rsrc1_ps)",
        "pkt3_set_context_reg(reg=spi_shader_z_format)",
        "pkt3_set_context_reg(reg=spi_ps_input_ena)",
        "pkt3_set_context_reg(reg=spi_ps_in_control)",
        "pkt3_set_context_reg(reg=spi_baryc_cntl)",
        "pkt3_set_context_reg(reg=db_shader_control)",
        "pkt3_set_context_reg(reg=cb_shader_mask)",
        "pkt3_nop(count=10)",
        "pkt3_nop(count=3)",
        "pkt3_nop(count=3)",
        "pkt3_set_sh_reg(reg=spi_shader_user_data_ps_0)",
        "pkt3_set_context_reg(reg=pa_sc_vport_zmin_0)",
        "pkt3_set_context_reg(reg=pa_cl_vport_xscale)",
        "pkt3_set_context_reg(reg=pa_cl_vte_cntl)",
        "pkt3_set_context_reg(reg=pa_sc_screen_scissor_tl)",
        "pkt3_set_context_reg(reg=pa_su_hardware_screen_offset)",
        "pkt3_set_context_reg(reg=pa_cl_gb_vert_clip_adj)",
        "pkt3_set_context_reg(reg=cb_color0_base)",
        "pkt3_nop(count=0)",
        "pkt3_set_context_reg(reg=cb_target_mask)",
        "pkt3_set_uconfig_reg(reg=vgt_primitive_type)",
        "pkt3_draw_index_auto(count=3)",
        "pkt3_nop(count=2)",
        "pkt3_acquire_mem(ctrl=605c040, cohersize=ffffffffff, coherbase=0, pollint=10)",
        "pkt3_set_context_reg(reg=pa_su_sc_mode_cntl)",
        "pkt3_set_context_reg(reg=cb_color0_base)",
        "pkt3_nop(count=0)",
        "pkt3_set_context_reg(reg=cb_target_mask)",
        "pkt3_set_context_reg(reg=pa_sc_vport_zmin_0)",
        "pkt3_set_context_reg(reg=pa_cl_vport_xscale)",
        "pkt3_set_context_reg(reg=pa_cl_vte_cntl)",
        "pkt3_set_context_reg(reg=pa_sc_screen_scissor_tl)",
        "pkt3_set_context_reg(reg=pa_su_hardware_screen_offset)",
        "pkt3_set_context_reg(reg=pa_cl_gb_vert_clip_adj)",
        "pkt3_set_sh_reg(reg=spi_shader_pgm_lo_vs)",
        "pkt3_set_sh_reg(reg=spi_shader_pgm_rsrc1_vs)",
        "pkt3_set_context_reg(reg=pa_cl_vs_out_cntl)",
        "pkt3_set_context_reg(reg=spi_vs_out_config)",
        "pkt3_set_context_reg(reg=spi_shader_pos_format)",
        "pkt3_nop(count=10)",
        "pkt3_set_sh_reg(reg=spi_shader_pgm_lo_ps)",
        "pkt3_set_sh_reg(reg=spi_shader_pgm_rsrc1_ps)",
        "pkt3_set_context_reg(reg=spi_shader_z_format)",
        "pkt3_set_context_reg(reg=spi_ps_input_ena)",
        "pkt3_set_context_reg(reg=spi_ps_in_control)",
        "pkt3_set_context_reg(reg=spi_baryc_cntl)",
        "pkt3_set_context_reg(reg=db_shader_control)",
        "pkt3_set_context_reg(reg=cb_shader_mask)",
        "pkt3_nop(count=10)",
        "pkt3_set_context_reg(reg=spi_ps_input_cntl_0)",
        "pkt3_set_uconfig_reg(reg=vgt_primitive_type)",
        "pkt3_draw_index_auto(count=3)",
        "pkt3_nop(count=2)",
        "pkt3_event_write_eop(flags=504, addr=201360200, flags2=4300, data=1)",
    };

    const cmd_data = &test_data.pm4_packet;

    var reader: Io.Reader = .fixed(cmd_data);
    var parser: Reader = .init(&reader);

    var pkt_buffer: [64]u32 = undefined;

    var string_buf: [256]u8 = undefined;
    var string_writer: Io.Writer = .fixed(&string_buf);

    for (EXPECTED_STRINGS) |expected_str| {
        const pkt = try parser.next(&pkt_buffer);
        try string_writer.print("{f}", .{pkt});
        const actual_string = string_writer.buffered();

        try testing.expectEqualStrings(expected_str, actual_string);

        string_writer.end = 0;
    }
}

test "packet formating with C interface" {
    const EXPECTED_STRINGS = [_][]const u8{
        "pkt3_set_context_reg(reg=db_render_control)",
        "pkt3_set_context_reg(reg=db_depth_control)",
        "pkt3_set_sh_reg(reg=spi_shader_pgm_lo_vs)",
        "pkt3_set_sh_reg(reg=spi_shader_pgm_rsrc1_vs)",
        "pkt3_set_context_reg(reg=pa_cl_vs_out_cntl)",
        "pkt3_set_context_reg(reg=spi_vs_out_config)",
        "pkt3_set_context_reg(reg=spi_shader_pos_format)",
        "pkt3_nop(count=10)",
        "pkt3_set_sh_reg(reg=spi_shader_pgm_lo_ps)",
        "pkt3_set_sh_reg(reg=spi_shader_pgm_rsrc1_ps)",
        "pkt3_set_context_reg(reg=spi_shader_z_format)",
        "pkt3_set_context_reg(reg=spi_ps_input_ena)",
        "pkt3_set_context_reg(reg=spi_ps_in_control)",
        "pkt3_set_context_reg(reg=spi_baryc_cntl)",
        "pkt3_set_context_reg(reg=db_shader_control)",
        "pkt3_set_context_reg(reg=cb_shader_mask)",
        "pkt3_nop(count=10)",
        "pkt3_nop(count=3)",
        "pkt3_nop(count=3)",
        "pkt3_set_sh_reg(reg=spi_shader_user_data_ps_0)",
        "pkt3_set_context_reg(reg=pa_sc_vport_zmin_0)",
        "pkt3_set_context_reg(reg=pa_cl_vport_xscale)",
        "pkt3_set_context_reg(reg=pa_cl_vte_cntl)",
        "pkt3_set_context_reg(reg=pa_sc_screen_scissor_tl)",
        "pkt3_set_context_reg(reg=pa_su_hardware_screen_offset)",
        "pkt3_set_context_reg(reg=pa_cl_gb_vert_clip_adj)",
        "pkt3_set_context_reg(reg=cb_color0_base)",
        "pkt3_nop(count=0)",
        "pkt3_set_context_reg(reg=cb_target_mask)",
        "pkt3_set_uconfig_reg(reg=vgt_primitive_type)",
        "pkt3_draw_index_auto(count=3)",
        "pkt3_nop(count=2)",
        "pkt3_acquire_mem(ctrl=605c040, cohersize=ffffffffff, coherbase=0, pollint=10)",
        "pkt3_set_context_reg(reg=pa_su_sc_mode_cntl)",
        "pkt3_set_context_reg(reg=cb_color0_base)",
        "pkt3_nop(count=0)",
        "pkt3_set_context_reg(reg=cb_target_mask)",
        "pkt3_set_context_reg(reg=pa_sc_vport_zmin_0)",
        "pkt3_set_context_reg(reg=pa_cl_vport_xscale)",
        "pkt3_set_context_reg(reg=pa_cl_vte_cntl)",
        "pkt3_set_context_reg(reg=pa_sc_screen_scissor_tl)",
        "pkt3_set_context_reg(reg=pa_su_hardware_screen_offset)",
        "pkt3_set_context_reg(reg=pa_cl_gb_vert_clip_adj)",
        "pkt3_set_sh_reg(reg=spi_shader_pgm_lo_vs)",
        "pkt3_set_sh_reg(reg=spi_shader_pgm_rsrc1_vs)",
        "pkt3_set_context_reg(reg=pa_cl_vs_out_cntl)",
        "pkt3_set_context_reg(reg=spi_vs_out_config)",
        "pkt3_set_context_reg(reg=spi_shader_pos_format)",
        "pkt3_nop(count=10)",
        "pkt3_set_sh_reg(reg=spi_shader_pgm_lo_ps)",
        "pkt3_set_sh_reg(reg=spi_shader_pgm_rsrc1_ps)",
        "pkt3_set_context_reg(reg=spi_shader_z_format)",
        "pkt3_set_context_reg(reg=spi_ps_input_ena)",
        "pkt3_set_context_reg(reg=spi_ps_in_control)",
        "pkt3_set_context_reg(reg=spi_baryc_cntl)",
        "pkt3_set_context_reg(reg=db_shader_control)",
        "pkt3_set_context_reg(reg=cb_shader_mask)",
        "pkt3_nop(count=10)",
        "pkt3_set_context_reg(reg=spi_ps_input_cntl_0)",
        "pkt3_set_uconfig_reg(reg=vgt_primitive_type)",
        "pkt3_draw_index_auto(count=3)",
        "pkt3_nop(count=2)",
        "pkt3_event_write_eop(flags=504, addr=201360200, flags2=4300, data=1)",
    };

    const c = @import("../c_compat.zig");

    const cmd_data = &test_data.pm4_packet;
    var decoder: c.Pm4Decoder = .{
        .buffer = @ptrCast(cmd_data),
        .max_dwords = cmd_data.len / @sizeOf(u32),
        .cur_dwords = 0,
    };

    for (EXPECTED_STRINGS) |expected_str| {
        var pkt: c.Pm4Packet = undefined;
        var pkt_data: [32]u32 = undefined;

        var err = c.pm4DecodePacket(&decoder, &pkt, &pkt_data, pkt_data.len);
        try testing.expectEqual(c.Pm4Error.ok, err);

        var string_buf: [255:0]u8 = undefined;
        err = c.pm4FormatPacket(&decoder, &pkt, &string_buf, string_buf.len);
        try testing.expectEqual(c.Pm4Error.ok, err);

        const actual_string = mem.sliceTo(&string_buf, 0);
        try testing.expectEqualStrings(expected_str, actual_string);
    }
}
