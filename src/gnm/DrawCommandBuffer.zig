const std = @import("std");
const math = std.math;
const assert = std.debug.assert;
const builtin = @import("builtin");
const native_os = builtin.os.tag;

const gnm = @import("../gnm.zig");
const pm4 = @import("../pm4.zig");

writer: pm4.Writer,
flags: packed struct {
    predication_enabled: bool,
},

const Self = @This();

pub fn init(backing_memory: []u32) Self {
    return .{
        .writer = .init(backing_memory),
        .flags = .{ .predication_enabled = false },
    };
}

const DriverError = error{DriverFailed} || pm4.Writer.WriteError;
const SetRegisterError = error{TooManyValues} || pm4.Writer.WriteError;

//
// context registers
//
fn setContextRegisterRange(
    self: *Self,
    reg: pm4.ContextRegister,
    values: []const u32,
) SetRegisterError!void {
    const num_values = math.cast(u14, values.len) orelse return error.TooManyValues;

    try self.writer.writeDword(@bitCast(pm4.Header{
        .kind = .pkt3,
        .count = num_values,
        .info = .{ .pkt3 = .{
            .predicate = self.flags.predication_enabled,
            .shader = .graphics,
            .it_opcode = .set_context_reg,
        } },
    }));
    try self.writer.writeDword(@backingInt(reg));
    for (values) |val| try self.writer.writeDword(val);
}
fn setContextRegister(self: *Self, reg: pm4.ContextRegister, value: u32) SetRegisterError!void {
    try self.setContextRegisterRange(reg, &[_]u32{value});
}

pub fn setBlendControl(self: *Self, rt_slot: u3, ctrl: gnm.CbBlendControl) SetRegisterError!void {
    const reg: pm4.ContextRegister = switch (rt_slot) {
        0 => .cb_blend0_control,
        1 => .cb_blend1_control,
        2 => .cb_blend2_control,
        3 => .cb_blend3_control,
        4 => .cb_blend4_control,
        5 => .cb_blend5_control,
        6 => .cb_blend6_control,
        7 => .cb_blend7_control,
    };
    try self.setContextRegister(reg, @backingInt(ctrl));
}

pub fn setDepthClearValue(self: *Self, clear_value: f32) (error{InvalidValue} || SetRegisterError)!void {
    if (clear_value < 0.0 or clear_value > 1.0) return error.InvalidValue;
    try self.setContextRegister(.db_depth_clear, @bitCast(clear_value));
}

pub const SetDepthRenderTargetError = error{
    InvalidHtile,
    InvalidStencilFormat,
    InvalidZFormat,
} || SetRegisterError;

pub fn setDepthRenderTarget(self: *Self, drt: gnm.DepthRenderTarget) SetDepthRenderTargetError!void {
    const num_dwords = 8;
    comptime assert(@sizeOf(u32) * num_dwords <= @sizeOf(@TypeOf(drt)));

    const old_state = self.writer.saveState();
    errdefer self.writer.restoreState(old_state);

    if (drt.z_info.tile_surface_enable and drt.htile_data_base == 0) return error.InvalidHtile;
    if (drt.z_info.format == .invalid and drt.z_read_base == 0) return error.InvalidZFormat;
    if (drt.stencil_info.format == .invalid and drt.z_read_base == 0) return error.InvalidStencilFormat;

    const z_data = @as([*]const u32, @ptrCast(@alignCast(&drt)))[0..num_dwords];
    try self.setContextRegisterRange(.db_z_info, z_data);
    try self.setContextRegister(.db_depth_info, @backingInt(drt.depth_info));
    try self.setContextRegister(.db_depth_view, @backingInt(drt.depth_view));
    try self.setContextRegister(.db_htile_data_base, drt.htile_data_base);
    try self.setContextRegister(.db_htile_surface, @backingInt(drt.htile_surface));

    // hint for something
    // TODO: figure what for. maybe for the official GPU analysis tools?
    try self.writer.writeDword(@bitCast(pm4.Header{
        .kind = .pkt3,
        .count = 0,
        .info = .{ .pkt3 = .{
            .predicate = self.flags.predication_enabled,
            .shader = .graphics,
            .it_opcode = .nop,
        } },
    }));
    try self.writer.writeDword(@bitCast(drt.size));
}
pub fn unsetDepthRenderTarget(self: *Self) SetRegisterError!void {
    try self.setContextRegister(.db_z_info, 0);
    try self.setContextRegister(.db_stencil_info, 0);
}

pub fn setDepthStencilControl(self: *Self, ctrl: gnm.DbDepthControl) SetRegisterError!void {
    try self.setContextRegister(.db_depth_control, @backingInt(ctrl));
}

pub fn setDbRenderControl(self: *Self, ctrl: gnm.DbRenderControl) SetRegisterError!void {
    try self.setContextRegister(.db_render_control, @backingInt(ctrl));
}

pub const GuardBands = struct {
    vert_clip_adj: f32,
    vert_disc_adj: f32,
    horz_clip_adj: f32,
    horz_disc_adj: f32,
};

pub fn setGuardBands(
    self: *Self,
    guard_bands: GuardBands,
) (error{InvalidValue} || SetRegisterError)!void {
    if (guard_bands.vert_clip_adj < 1.0) return error.InvalidValue;
    if (guard_bands.vert_disc_adj < 1.0) return error.InvalidValue;
    if (guard_bands.horz_clip_adj < 1.0) return error.InvalidValue;
    if (guard_bands.horz_disc_adj < 1.0) return error.InvalidValue;

    const bands_values = [_]u32{
        @bitCast(guard_bands.vert_clip_adj),
        @bitCast(guard_bands.vert_disc_adj),
        @bitCast(guard_bands.horz_clip_adj),
        @bitCast(guard_bands.horz_disc_adj),
    };
    try self.setContextRegisterRange(.pa_cl_gb_vert_clip_adj, &bands_values);
}

pub fn setHardwareScreenOffset(
    self: *Self,
    ctrl: gnm.PaSuHardwareScreenOffset,
) (error{InvalidValue} || SetRegisterError)!void {
    if ((ctrl.hw_screen_offset_x & 3) != 0) return error.InvalidValue;
    if ((ctrl.hw_screen_offset_y & 3) != 0) return error.InvalidValue;

    try self.setContextRegister(.pa_su_hardware_screen_offset, @backingInt(ctrl));
}

pub fn setInstanceStepRate(self: *Self, steps: [2]u32) SetRegisterError!void {
    try self.setContextRegisterRange(.vgt_instance_step_rate_0, &steps);
}

pub fn setPrimitiveSetup(self: *Self, ctrl: gnm.PaSuScModeCntl) SetRegisterError!void {
    try self.setContextRegister(.pa_su_sc_mode_cntl, @backingInt(ctrl));
}

// TODO: validate generated registers
pub fn setPixelInputLayout(
    self: *Self,
    vertex_outputs: []const gnm.VertexExportSemantic,
    pixel_inputs: []const gnm.PixelInputSemantic,
    gpu_mode: gnm.GpuMode,
) (error{TooManyInputs} || SetRegisterError)!void {
    if (pixel_inputs.len > 32) return error.TooManyInputs;

    var input_ctrls: [32]u32 = undefined;
    for (input_ctrls[0..pixel_inputs.len], pixel_inputs) |*out_ctrl, input| {
        const matching_vs_output = blk: {
            for (vertex_outputs) |output| {
                if (output.semantic == input.semantic) {
                    break :blk output;
                }
            }
            break :blk null;
        };

        var ctrl: gnm.SpiPsInputCntl = @bitCast(@as(u32, 0));
        if (gpu_mode == .neo and (input.hw.neo.interp_f16.low or input.hw.neo.interp_f16.high)) {
            const UnmatchInterp = struct {
                low: bool,
                high: bool,
            };
            const out_index: u6, const unmatched_interp: UnmatchInterp = if (matching_vs_output) |vs_out|
                .{ vs_out.out_index, .{
                    .low = vs_out.type.low != input.hw.neo.interp_f16.low,
                    .high = vs_out.type.high != input.hw.neo.interp_f16.high,
                } }
            else
                .{ 0x20, .{ .low = false, .high = false } };

            ctrl.fp16_interp_mode = true;
            ctrl.attr0_valid = input.hw.neo.interp_f16.low;
            ctrl.attr1_valid = input.hw.neo.interp_f16.high;

            if (input.hw.neo.interp_f16.low != input.hw.neo.interp_f16.high) {
                ctrl.offset = out_index | @as(u6, if (unmatched_interp.low or unmatched_interp.low) 0x20 else 0);
                ctrl.default_val = if (unmatched_interp.low) input.default_value else input.hw.neo.default_value_f16hi;
            } else {
                ctrl.offset = out_index | @as(u6, if (unmatched_interp.low) 0x20 else 0);
                ctrl.fp16_interp_mode = unmatched_interp.high;
                ctrl.default_val = input.default_value;
                ctrl.default_val_attr1 = input.default_value;
            }
        } else {
            // base
            if (matching_vs_output) |vs_out| {
                ctrl.offset = vs_out.out_index | @as(u6, if (input.hw.base.custom) 0x20 else 0);
                ctrl.flat_shade = input.flat_shade or input.hw.base.custom;
            } else {
                ctrl.offset = 0x20;
            }
            ctrl.default_val = input.default_value;
        }

        out_ctrl.* = @bitCast(ctrl);
    }

    try self.setContextRegisterRange(.spi_ps_input_cntl_0, input_ctrls[0..pixel_inputs.len]);
}

pub fn setRenderTarget(self: *Self, slot: u3, rt: gnm.RenderTarget) SetRegisterError!void {
    const num_dwords = 14;
    comptime assert(@sizeOf(u32) * num_dwords <= @sizeOf(@TypeOf(rt)));

    const old_state = self.writer.saveState();
    errdefer self.writer.restoreState(old_state);

    const reg: pm4.ContextRegister = switch (slot) {
        0 => .cb_color0_base,
        1 => .cb_color1_base,
        2 => .cb_color2_base,
        3 => .cb_color3_base,
        4 => .cb_color4_base,
        5 => .cb_color5_base,
        6 => .cb_color6_base,
        7 => .cb_color7_base,
    };
    const data = @as([*]const u32, @ptrCast(@alignCast(&rt)))[0..num_dwords];
    try self.setContextRegisterRange(reg, data);

    // hint for something
    // TODO: figure what for. maybe for GPU replay tools?
    try self.writer.writeDword(@bitCast(pm4.Header{
        .kind = .pkt3,
        .count = 0,
        .info = .{ .pkt3 = .{
            .predicate = self.flags.predication_enabled,
            .shader = .graphics,
            .it_opcode = .nop,
        } },
    }));
    try self.writer.writeDword(@bitCast(rt.size));
}
pub fn unsetRenderTarget(self: *Self, slot: u3) SetRegisterError!void {
    const reg: pm4.ContextRegister = switch (slot) {
        0 => .cb_color0_info,
        1 => .cb_color1_info,
        2 => .cb_color2_info,
        3 => .cb_color3_info,
        4 => .cb_color4_info,
        5 => .cb_color5_info,
        6 => .cb_color6_info,
        7 => .cb_color7_info,
    };
    try self.setContextRegister(reg, 0);
}

pub fn setRenderTargetMask(self: *Self, mask: gnm.CbTargetMask) SetRegisterError!void {
    try self.setContextRegister(.cb_target_mask, @backingInt(mask));
}

pub fn setScreenScissors(
    self: *Self,
    top_left: gnm.PaScScreenScissorTL,
    bottom_right: gnm.PaScScreenScissorBR,
) (error{InvalidValue} || SetRegisterError)!void {
    if (top_left.tl_x > 16383) return error.InvalidValue;
    if (top_left.tl_y > 16383) return error.InvalidValue;
    if (bottom_right.br_x > 16383) return error.InvalidValue;
    if (bottom_right.br_y > 16383) return error.InvalidValue;

    const scissor_values = [_]u32{ @backingInt(top_left), @backingInt(bottom_right) };
    try self.setContextRegisterRange(.pa_sc_screen_scissor_tl, &scissor_values);
}

pub const ViewportInfo = struct {
    z_min: f32,
    z_max: f32,
    vport: gnm.PaClVPort,
};

pub fn setViewport(self: *Self, index: u4, viewport: ViewportInfo) SetRegisterError!void {
    const old_state = self.writer.saveState();
    errdefer self.writer.restoreState(old_state);

    const depth_register: pm4.ContextRegister = switch (index) {
        0 => .pa_sc_vport_zmin_0,
        1 => .pa_sc_vport_zmin_1,
        2 => .pa_sc_vport_zmin_2,
        3 => .pa_sc_vport_zmin_3,
        4 => .pa_sc_vport_zmin_4,
        5 => .pa_sc_vport_zmin_5,
        6 => .pa_sc_vport_zmin_6,
        7 => .pa_sc_vport_zmin_7,
        8 => .pa_sc_vport_zmin_8,
        9 => .pa_sc_vport_zmin_9,
        10 => .pa_sc_vport_zmin_10,
        11 => .pa_sc_vport_zmin_11,
        12 => .pa_sc_vport_zmin_12,
        13 => .pa_sc_vport_zmin_13,
        14 => .pa_sc_vport_zmin_14,
        15 => .pa_sc_vport_zmin_15,
    };
    const depth_values = [_]u32{ @bitCast(viewport.z_min), @bitCast(viewport.z_max) };
    try self.setContextRegisterRange(depth_register, &depth_values);

    const scale_offset_register: pm4.ContextRegister = switch (index) {
        0 => .pa_cl_vport_xscale,
        1 => .pa_cl_vport_xscale_1,
        2 => .pa_cl_vport_xscale_2,
        3 => .pa_cl_vport_xscale_3,
        4 => .pa_cl_vport_xscale_4,
        5 => .pa_cl_vport_xscale_5,
        6 => .pa_cl_vport_xscale_6,
        7 => .pa_cl_vport_xscale_7,
        8 => .pa_cl_vport_xscale_8,
        9 => .pa_cl_vport_xscale_9,
        10 => .pa_cl_vport_xscale_10,
        11 => .pa_cl_vport_xscale_11,
        12 => .pa_cl_vport_xscale_12,
        13 => .pa_cl_vport_xscale_13,
        14 => .pa_cl_vport_xscale_14,
        15 => .pa_cl_vport_xscale_15,
    };
    const scale_offset_values = [_]u32{
        @bitCast(viewport.vport.x_scale),
        @bitCast(viewport.vport.x_offset),
        @bitCast(viewport.vport.y_scale),
        @bitCast(viewport.vport.y_offset),
        @bitCast(viewport.vport.z_scale),
        @bitCast(viewport.vport.z_offset),
    };
    try self.setContextRegisterRange(scale_offset_register, &scale_offset_values);
}

pub fn setViewportTransformControl(self: *Self, ctrl: gnm.PaClVteCntl) SetRegisterError!void {
    try self.setContextRegister(.pa_cl_vte_cntl, @backingInt(ctrl));
}

//
// persistent registers
//
fn setPersistentRegisterRange(
    self: *Self,
    reg: pm4.ShRegister,
    values: []const u32,
) SetRegisterError!void {
    const num_values = math.cast(u14, values.len) orelse return error.TooManyValues;

    try self.writer.writeDword(@bitCast(pm4.Header{
        .kind = .pkt3,
        .count = num_values,
        .info = .{ .pkt3 = .{
            .predicate = self.flags.predication_enabled,
            .shader = .graphics,
            .it_opcode = .set_sh_reg,
        } },
    }));
    try self.writer.writeDword(@backingInt(reg));
    for (values) |val| try self.writer.writeDword(val);
}

pub const UserDataError = error{InvalidSlot} || SetRegisterError;

fn getUserDataSlotRegister(stage: gnm.ShaderStage, slot: u4) UserDataError!pm4.ShRegister {
    const first_register: pm4.ShRegister = switch (stage) {
        .cs => .compute_user_data_0,
        .ps => .spi_shader_user_data_ps_0,
        .vs => .spi_shader_user_data_vs_0,
        .gs => .spi_shader_user_data_gs_0,
        .es => .spi_shader_user_data_es_0,
        .hs => .spi_shader_user_data_hs_0,
        .ls => .spi_shader_user_data_ls_0,
    };
    const last_register: pm4.ShRegister = switch (stage) {
        .cs => .compute_user_data_15,
        .ps => .spi_shader_user_data_ps_15,
        .vs => .spi_shader_user_data_vs_15,
        .gs => .spi_shader_user_data_gs_15,
        .es => .spi_shader_user_data_es_15,
        .hs => .spi_shader_user_data_hs_15,
        .ls => .spi_shader_user_data_ls_15,
    };
    const slot_register = @backingInt(first_register) + slot;
    if (slot_register > @backingInt(last_register)) return error.InvalidSlot;
    return @fromBackingInt(@intCast(slot_register));
}

pub fn setUserDataBuffer(
    self: *Self,
    stage: gnm.ShaderStage,
    slot: u4,
    buffer: gnm.Buffer,
) UserDataError!void {
    const num_dwords = 4;
    comptime assert(@sizeOf(u32) * num_dwords <= @sizeOf(@TypeOf(buffer)));

    if (slot > gnm.MAX_USERDATA_VSHARP_SLOTS) return error.InvalidSlot;

    const old_state = self.writer.saveState();
    errdefer self.writer.restoreState(old_state);

    // hint for something
    // TODO: figure what for. maybe for GPU replay tools?
    try self.writer.writeDword(@bitCast(pm4.Header{
        .kind = .pkt3,
        .count = 0,
        .info = .{ .pkt3 = .{
            .predicate = self.flags.predication_enabled,
            .shader = .graphics,
            .it_opcode = .nop,
        } },
    }));
    try self.writer.writeDword(@backingInt(UserdataHint.v_sharp));

    const reg = try getUserDataSlotRegister(stage, slot);
    const data = @as([*]const u32, @ptrCast(@alignCast(&buffer)))[0..num_dwords];
    try self.setPersistentRegisterRange(reg, data);
}

pub const UserdataHint = enum(u32) {
    v_sharp = 0x68750004,
    t_sharp = 0x68750005,
    s_sharp = 0x68750006,
};

pub fn setUserDataPointer(
    self: *Self,
    stage: gnm.ShaderStage,
    slot: u4,
    pointer: ?*const anyopaque,
) UserDataError!void {
    const num_dwords = 2;
    comptime assert(@sizeOf(u32) * num_dwords <= @sizeOf(@TypeOf(pointer)));
    if (slot > gnm.MAX_USERDATA_POINTER_SLOTS) return error.InvalidSlot;

    const reg = try getUserDataSlotRegister(stage, slot);
    const address: u64 = @intFromPtr(pointer);
    const data = [2]u32{
        @truncate(address),
        @truncate(address >> 32),
    };
    try self.setPersistentRegisterRange(reg, &data);
}

pub fn setUserDataSampler(
    self: *Self,
    stage: gnm.ShaderStage,
    slot: u4,
    sampler: gnm.Sampler,
) UserDataError!void {
    const num_dwords = 4;
    comptime assert(@sizeOf(u32) * num_dwords <= @sizeOf(@TypeOf(sampler)));

    if (slot > gnm.MAX_USERDATA_SSHARP_SLOTS) return error.InvalidSlot;

    const old_state = self.writer.saveState();
    errdefer self.writer.restoreState(old_state);

    // hint for something
    // TODO: figure what for. maybe for GPU replay tools?
    try self.writer.writeDword(@bitCast(pm4.Header{
        .kind = .pkt3,
        .count = 0,
        .info = .{ .pkt3 = .{
            .predicate = self.flags.predication_enabled,
            .shader = .graphics,
            .it_opcode = .nop,
        } },
    }));
    try self.writer.writeDword(@backingInt(UserdataHint.s_sharp));

    const reg = try getUserDataSlotRegister(stage, slot);
    const data = @as([*]const u32, @ptrCast(@alignCast(&sampler)))[0..num_dwords];
    try self.setPersistentRegisterRange(reg, data);
}

pub fn setUserDataTexture(
    self: *Self,
    stage: gnm.ShaderStage,
    slot: u4,
    texture: gnm.Texture,
) UserDataError!void {
    const num_dwords = 8;
    comptime assert(@sizeOf(u32) * num_dwords <= @sizeOf(@TypeOf(texture)));

    if (slot > gnm.MAX_USERDATA_TSHARP_SLOTS) return error.InvalidSlot;

    const old_state = self.writer.saveState();
    errdefer self.writer.restoreState(old_state);

    // hint for something
    // TODO: figure what for. maybe for GPU replay tools?
    try self.writer.writeDword(@bitCast(pm4.Header{
        .kind = .pkt3,
        .count = 0,
        .info = .{ .pkt3 = .{
            .predicate = self.flags.predication_enabled,
            .shader = .graphics,
            .it_opcode = .nop,
        } },
    }));
    try self.writer.writeDword(@backingInt(UserdataHint.t_sharp));

    const reg = try getUserDataSlotRegister(stage, slot);
    const data = @as([*]const u32, @ptrCast(@alignCast(&texture)))[0..num_dwords];
    try self.setPersistentRegisterRange(reg, data);
}

//
// user config registers
//
fn setUserRegisterRange(
    self: *Self,
    reg: pm4.UConfigRegister,
    values: []const u32,
) SetRegisterError!void {
    const num_values = math.cast(u14, values.len) orelse return error.TooManyValues;

    try self.writer.writeDword(@bitCast(pm4.Header{
        .kind = .pkt3,
        .count = num_values,
        .info = .{ .pkt3 = .{
            .predicate = self.flags.predication_enabled,
            .shader = .graphics,
            .it_opcode = .set_uconfig_reg,
        } },
    }));
    try self.writer.writeDword(@backingInt(reg));
    for (values) |val| try self.writer.writeDword(val);
}
fn setUserRegister(self: *Self, reg: pm4.UConfigRegister, value: u32) SetRegisterError!void {
    try self.setUserRegisterRange(reg, &[_]u32{value});
}

pub fn setPrimitiveType(self: *Self, prim_type: gnm.PrimitiveType) SetRegisterError!void {
    try self.setUserRegister(.vgt_primitive_type, @backingInt(prim_type));
}

//
// action packet types
//

// TODO: find other valid behaviors
pub const CacheBehavior = enum(u2) {
    none = 0,
    l1_l2_invalidate_and_writeback = 1,
};

pub const WriteEndOfPipeOptions = packed struct {
    pub const CacheWriteType = enum(u2) {
        uncached = 0,
        l2 = 1,
        l2_volatile = 2,
    };

    cache_behavior: CacheBehavior = .none,
    cache_write_type: CacheWriteType = .uncached,
    cache_policy: gnm.CachePolicy = .lru,
};

pub const EventWriteEopError = error{
    InvalidAddress,
} || pm4.Writer.WriteError;

pub fn eventWriteEop(
    self: *Self,
    event: gnm.VgtEventType,
    data_sel: gnm.EventDataSel,
    gpu_address: *anyopaque,
    imm_value: u64,
    options: WriteEndOfPipeOptions,
) EventWriteEopError!void {
    const address: u64 = @intFromPtr(gpu_address);
    if ((address >> 48) != 0) {
        @branchHint(.unlikely);
        return error.InvalidAddress;
    }
    switch (data_sel) {
        .discard => {},
        .send_data_32 => if (address & 3 != 0) {
            @branchHint(.unlikely);
            return error.InvalidAddress;
        },
        .send_data_64,
        .send_sys_clock,
        .send_gpu_clock,
        => if (address & 7 != 0) {
            @branchHint(.unlikely);
            return error.InvalidAddress;
        },
    }

    const packet: CmdEventWriteEop = .{
        .header = .{
            .kind = .pkt3,
            .count = (@sizeOf(CmdEventWriteEop) / @sizeOf(u32)) - 2,
            .info = .{ .pkt3 = .{
                .predicate = self.flags.predication_enabled,
                .shader = .graphics,
                .it_opcode = .event_write_eop,
            } },
        },
        .flags = .{
            .event_type = event,
            .event_index = if (event == .cs_done or event == .ps_done) 6 else 5,
            .tcl1_vol_action_ena = false,
            .tc_vol_action_ena = false,
            .tc_wb_action_ena = switch (options.cache_behavior) {
                .l1_l2_invalidate_and_writeback => true,
                else => false,
            },
            .tcl1_action_ena = switch (options.cache_behavior) {
                .l1_l2_invalidate_and_writeback => true,
                else => false,
            },
            .tc_action_ena = switch (options.cache_behavior) {
                .l1_l2_invalidate_and_writeback => true,
                else => false,
            },
            .invalidate_l2 = false,
            .atc = false,
            .cache_policy = options.cache_policy,
            .@"volatile" = options.cache_write_type == .l2_volatile,
        },
        .address_lo = @truncate(address),
        .flags2 = .{
            .address_hi = @truncate(address >> 32),
            .should_write_to_l2 = options.cache_write_type == .l2 or options.cache_write_type == .l2_volatile,
            .int_sel = if (data_sel != .discard) .send_data_on_confirm else .none,
            .data_sel = data_sel,
        },
        .data_lo = @truncate(imm_value),
        .data_hi = @truncate(imm_value >> 32),
    };
    try self.writer.writeStruct(CmdEventWriteEop, packet);
}

pub const EventWriteEosError = error{
    InvalidAddress,
} || pm4.Writer.WriteError;

pub fn eventWriteEos(
    self: *Self,
    event: gnm.VgtEventType,
    gpu_address: *anyopaque,
    imm_value: u32,
) EventWriteEosError!void {
    const address: u64 = @intFromPtr(gpu_address);
    if (address & 3 != 0) {
        @branchHint(.unlikely);
        return error.UnalignedAddress;
    }
    if ((address >> 48) != 0) {
        @branchHint(.unlikely);
        return error.HighAddress;
    }

    const old_state = self.writer.saveState();
    errdefer self.writer.restoreState(old_state);

    // GNM writes this packet twice for some reason
    for (0..2) |_| {
        try self.writer.writeStruct(CmdEventWriteEos, .{
            .header = .{
                .kind = .pkt3,
                .count = (@sizeOf(CmdEventWriteEos) / @sizeOf(u32)) - 2,
                .info = .{ .pkt3 = .{
                    .predicate = self.flags.predication_enabled,
                    .shader = if (event == .cs_done) .compute else .graphics,
                    .it_opcode = .event_write_eos,
                } },
            },
            .flags = .{
                .event_type = event,
                .event_index = .csdone_psdone,
            },
            .address_lo = @truncate(address),
            .flags2 = .{
                .address_hi = @truncate(address >> 32),
                .command = .store_32bit_data_to_memory,
            },
            .command_argument = .{ .store_32bit = imm_value },
        });
    }
}

pub const WaitOnAddressError = error{
    InvalidAddress,
} || pm4.Writer.WriteError;

pub fn waitOnAddress(
    self: *Self,
    compare_function: gnm.WaitOperation,
    gpu_address: *anyopaque,
    mask: u32,
    reference_value: u32,
) WaitOnAddressError!void {
    const address: u64 = @intFromPtr(gpu_address);
    if (address & 3 != 0) return error.InvalidAddress;

    try self.writer.writeStruct(CmdWaitRegMem, .{
        .header = .{
            .kind = .pkt3,
            .count = (@sizeOf(CmdWaitRegMem) / @sizeOf(u32)) - 2,
            .info = .{ .pkt3 = .{
                .predicate = self.flags.predication_enabled,
                .shader = .graphics,
                .it_opcode = .wait_reg_mem,
            } },
        },
        .flags = .{
            .function = compare_function,
            .mem_space = .memory,
            .operation = .wait_reg_mem,
            .engine = .me,
            .uncached = false,
            .atc = false,
            .cache_policy = .lru,
            .@"volatile" = false,
        },
        .poll_address_lo = @truncate(address),
        .poll_address_hi = @truncate(address >> 32),
        .reference = reference_value,
        .mask = mask,
        .poll_interval = 4,
    });
}

pub fn waitFlipDone(
    self: *Self,
    video_handle: i32,
    display_buffer_index: i32,
) DriverError!void {
    const old_state = self.writer.saveState();
    errdefer self.writer.restoreState(old_state);

    const num_cmd_dwords = 7;
    const cmd_dwords = try self.writer.reserveDwords(num_cmd_dwords);
    const result = gnmDriverInsertWaitFlipDone(
        cmd_dwords.ptr,
        num_cmd_dwords,
        video_handle,
        display_buffer_index,
    );
    if (result != 0) return error.DriverFailed;
}

pub fn waitGraphicsWrites(
    self: *Self,
    mask: gnm.WaitGraphicsTargetMask,
) pm4.Writer.WriteError!void {
    try self.writer.writeStruct(CmdAcquireMem, .{
        .header = .{
            .kind = .pkt3,
            .count = (@sizeOf(CmdAcquireMem) / @sizeOf(u32)) - 2,
            .info = .{ .pkt3 = .{
                .predicate = self.flags.predication_enabled,
                .shader = .graphics,
                .it_opcode = .acquire_mem,
            } },
        },
        .flags = .{
            .coher_cntl = .{
                .cb0_dest_base_ena = mask.cb0_dest_base_ena,
                .cb1_dest_base_ena = mask.cb1_dest_base_ena,
                .cb2_dest_base_ena = mask.cb2_dest_base_ena,
                .cb3_dest_base_ena = mask.cb3_dest_base_ena,
                .cb4_dest_base_ena = mask.cb4_dest_base_ena,
                .cb5_dest_base_ena = mask.cb5_dest_base_ena,
                .cb6_dest_base_ena = mask.cb6_dest_base_ena,
                .cb7_dest_base_ena = mask.cb7_dest_base_ena,
                .db_dest_base_ena = mask.db_dest_base_ena,
                .tcl1_vol_action_ena = true,
                .tc_vol_action_ena = true,
                .tc_wb_action_ena = true,
                .cb_action_ena = mask.cb0_dest_base_ena or
                    mask.cb1_dest_base_ena or
                    mask.cb2_dest_base_ena or
                    mask.cb3_dest_base_ena or
                    mask.cb4_dest_base_ena or
                    mask.cb5_dest_base_ena or
                    mask.cb6_dest_base_ena or
                    mask.cb7_dest_base_ena,
                .db_action_ena = mask.db_dest_base_ena,
            },
            .engine = .me,
        },
        .coher_size_lo = 0xffffffff,
        .coher_size_hi = .{ .value = 0xff },
        .coher_base_lo = 0,
        .coher_base_hi = .{ .value = 0 },
        .poll_interval = .{ .value = 10 },
    });
}

pub const WriteInlineDataError = error{
    DataOverflow,
    InvalidAddress,
} || pm4.Writer.WriteError;

pub const WriteInlineDataOptions = struct {
    write_confirm: bool,
};

pub fn writeDataInline(
    self: *Self,
    gpu_address: *anyopaque,
    data: []const u32,
    options: WriteInlineDataOptions,
) WriteInlineDataError!void {
    const address: u64 = @intFromPtr(gpu_address);
    if (address & 3 != 0) {
        @branchHint(.unlikely);
        return error.InvalidAddress;
    }

    const old_state = self.writer.saveState();
    errdefer self.writer.restoreState(old_state);

    const packet_count =
        math.cast(u14, (@sizeOf(CmdWriteData) / @sizeOf(u32)) - 2 + data.len) orelse
        return error.DataOverflow;

    const packet: CmdWriteData = .{
        .header = .{
            .kind = .pkt3,
            .count = packet_count,
            .info = .{ .pkt3 = .{
                .predicate = self.flags.predication_enabled,
                .shader = .graphics,
                .it_opcode = .write_data,
            } },
        },
        .flags = .{
            .dst_sel = .memory_async,
            .wr_one_addr = false,
            .wr_confirm = options.write_confirm,
            .atc = false,
            .cache_policy = .bypass,
            .@"volatile" = false,
            .engine_sel = .me,
        },
        .dst_addr_lo = @truncate(gpu_address),
        .dst_addr_hi = @truncate(gpu_address >> 32),
    };
    try self.writer.writeStruct(CmdWriteData, packet);

    for (data) |data_word| {
        try self.writer.writeDword(data_word);
    }
}

pub const FlushShaderCachesOptions = packed struct {
    cb_flush_invalidate: bool = false,
    db_flush_invalidate: bool = false,
    sq_kcache_invalidate: bool = false,
    sq_icache_invalidate: bool = false,
    sync_command_processor: bool = false,
};

pub fn flushShaderCachesBlocking(
    self: *Self,
    cache_behavior: CacheBehavior,
    options: FlushShaderCachesOptions,
) pm4.Writer.WriteError!void {
    try self.writer.writeStruct(CmdAcquireMem, .{
        .header = .{
            .kind = .pkt3,
            .count = (@sizeOf(CmdAcquireMem) / @sizeOf(u32)) - 2,
            .info = .{ .pkt3 = .{
                .predicate = self.flags.predication_enabled,
                .shader = .graphics,
                .it_opcode = .acquire_mem,
            } },
        },
        .flags = .{
            .coher_cntl = .{
                .tcl1_vol_action_ena = false,
                .tc_vol_action_ena = false,
                .tc_wb_action_ena = switch (cache_behavior) {
                    .l1_l2_invalidate_and_writeback => true,
                    else => false,
                },
                .tcl1_action_ena = switch (cache_behavior) {
                    .l1_l2_invalidate_and_writeback => true,
                    else => false,
                },
                .tc_action_ena = switch (cache_behavior) {
                    .l1_l2_invalidate_and_writeback => true,
                    else => false,
                },
                .cb_action_ena = options.cb_flush_invalidate,
                .db_action_ena = options.db_flush_invalidate,
                .sh_kcache_action_ena = options.sq_kcache_invalidate,
                .sh_icache_action_ena = options.sq_icache_invalidate,
            },
            .engine = if (options.sync_command_processor) 0 else 1,
        },
        .coher_size_lo = 1,
        .coher_size_hi = .{ .value = 0 },
        .coher_base_lo = 0,
        .coher_base_hi = .{ .value = 0 },
        .poll_interval = .{ .value = 10 },
    });
}

//
// wrappers to GnmDriver
// the DWORD counts are from libSceGnmDriver
//
pub const DrawOptions = packed struct {
    render_target_index: u3 = 0, // NEO only
};

pub fn drawIndex(
    self: *Self,
    indices_gpu_address: *const anyopaque,
    num_indices: u32,
    options: DrawOptions,
) DriverError!void {
    const old_state = self.writer.saveState();
    errdefer self.writer.restoreState(old_state);

    const num_cmd_dwords = 10;
    const cmd_dwords = try self.writer.reserveDwords(num_cmd_dwords);
    const result = gnmDriverDrawIndex(
        cmd_dwords.ptr,
        num_cmd_dwords,
        num_indices,
        @intFromPtr(indices_gpu_address),
        .{
            .predication = self.flags.predication_enabled,
            .render_target_index = options.render_target_index,
        },
    );
    if (result != 0) return error.DriverFailed;
}

pub fn drawIndexAuto(self: *Self, num_indices: u32, options: DrawOptions) DriverError!void {
    const old_state = self.writer.saveState();
    errdefer self.writer.restoreState(old_state);

    const num_cmd_dwords = 7;
    const cmd_dwords = try self.writer.reserveDwords(num_cmd_dwords);
    const result = gnmDriverDrawIndexAuto(
        cmd_dwords.ptr,
        num_cmd_dwords,
        num_indices,
        .{
            .predication = self.flags.predication_enabled,
            .render_target_index = options.render_target_index,
        },
    );
    if (result != 0) return error.DriverFailed;
}

pub fn drawIndexIndirect(
    self: *Self,
    data_offset: u32,
    stage: gnm.ShaderStage,
    vertex_offset_user_sgpr: u4,
    instance_offset_user_sgpr: u4,
    options: DrawOptions,
) DriverError!void {
    const old_state = self.writer.saveState();
    errdefer self.writer.restoreState(old_state);

    const num_cmd_dwords = 9;
    const cmd_dwords = try self.writer.reserveDwords(num_cmd_dwords);
    const result = gnmDriverDrawIndexIndirect(
        cmd_dwords.ptr,
        num_cmd_dwords,
        data_offset,
        @backingInt(stage),
        vertex_offset_user_sgpr,
        instance_offset_user_sgpr,
        .{
            .predication = self.flags.predication_enabled,
            .render_target_index = options.render_target_index,
        },
    );
    if (result != 0) return error.DriverFailed;
}

pub fn drawIndirect(
    self: *Self,
    data_offset: u32,
    stage: gnm.ShaderStage,
    vertex_offset_user_sgpr: u4,
    instance_offset_user_sgpr: u4,
    options: DrawOptions,
) DriverError!void {
    const old_state = self.writer.saveState();
    errdefer self.writer.restoreState(old_state);

    const num_cmd_dwords = 9;
    const cmd_dwords = try self.writer.reserveDwords(num_cmd_dwords);
    const result = gnmDriverDrawIndirect(
        cmd_dwords.ptr,
        num_cmd_dwords,
        data_offset,
        @backingInt(stage),
        vertex_offset_user_sgpr,
        instance_offset_user_sgpr,
        .{
            .predication = self.flags.predication_enabled,
            .render_target_index = options.render_target_index,
        },
    );
    if (result != 0) return error.DriverFailed;
}

pub const DispatchOptions = packed struct {
    ordered_append: bool = false,
    ordered_append_mode: gnm.ComputeDispatchInitiator.OrderedAppendMode = .index_per_wavefront,
};

pub fn dispatch(
    self: *Self,
    thread_group_x: u31,
    thread_group_y: u31,
    thread_group_z: u31,
    options: DispatchOptions,
) DriverError!void {
    const old_state = self.writer.saveState();
    errdefer self.writer.restoreState(old_state);

    const num_cmd_dwords = 9;

    if (native_os == .ps4) {
        const cmd_dwords = try self.writer.reserveDwords(num_cmd_dwords);
        const result = gnmDriverDispatchDirect(
            cmd_dwords.ptr,
            num_cmd_dwords,
            thread_group_x,
            thread_group_y,
            thread_group_z,
            .{
                .predication = self.flags.predication_enabled,
                .ordered_append = options.ordered_append,
                .ordered_append_mode = options.ordered_append_mode,
            },
        );
        if (result != 0) {
            std.debug.print("dispatch: driver failed with {}\n", .{result});
            return error.DriverFailed;
        }
    } else {
        const packet: CmdDispatchDirect = .{
            .header = .{
                .kind = .pkt3,
                .count = (@sizeOf(CmdDispatchDirect) / @sizeOf(u32)) - 2,
                .info = .{ .pkt3 = .{
                    .predicate = self.flags.predication_enabled,
                    .shader = .compute,
                    .it_opcode = .dispatch_direct,
                } },
            },
            .dim_x = thread_group_x,
            .dim_y = thread_group_y,
            .dim_z = thread_group_z,
            .dispatch_initiator = .{
                .compute_shader_en = true,
                .ordered_append = options.ordered_append,
                .ordered_append_mode = options.ordered_append_mode,
            },
        };
        try self.writer.writeStruct(CmdDispatchDirect, packet);
        try self.writer.writeDword(@bitCast(pm4.Header{
            .kind = .pkt3,
            .count = num_cmd_dwords - (self.writer.current_dword - old_state),
            .info = .{ .pkt3 = .{
                .predicate = self.flags.predication_enabled,
                .shader = .graphics,
                .it_opcode = .nop,
            } },
        }));
    }
}

pub fn initDefaultHardwareState(self: *Self) DriverError!void {
    const old_state = self.writer.saveState();
    errdefer self.writer.restoreState(old_state);

    const num_cmd_dwords = 256;
    const cmd_dwords = try self.writer.reserveDwords(num_cmd_dwords);
    const result = gnmDriverDrawInitDefaultHardwareState350(
        cmd_dwords.ptr,
        num_cmd_dwords,
    );
    if (result != num_cmd_dwords) return error.DriverFailed;
}

pub fn setEmbeddedShaderPixel(
    self: *Self,
    shader_id: gnm.EmbeddedShaderPixel,
) DriverError!void {
    const old_state = self.writer.saveState();
    errdefer self.writer.restoreState(old_state);

    const num_cmd_dwords = 40;
    const cmd_dwords = try self.writer.reserveDwords(num_cmd_dwords);
    const result = gnmDriverSetEmbeddedPsShader(
        cmd_dwords.ptr,
        num_cmd_dwords,
        @backingInt(shader_id),
    );
    if (result != 0) return error.DriverFailed;
}

pub fn setEmbeddedShaderVertex(
    self: *Self,
    shader_id: gnm.EmbeddedShaderVertex,
    shader_modifier: u32,
) DriverError!void {
    const old_state = self.writer.saveState();
    errdefer self.writer.restoreState(old_state);

    const num_cmd_dwords = 29;
    const cmd_dwords = try self.writer.reserveDwords(num_cmd_dwords);
    const result = gnmDriverSetEmbeddedVsShader(
        cmd_dwords.ptr,
        num_cmd_dwords,
        @backingInt(shader_id),
        shader_modifier,
    );
    if (result != 0) return error.DriverFailed;
}

pub fn setCsShader(self: *Self, registers: gnm.CsStageRegisters) DriverError!void {
    const old_state = self.writer.saveState();
    errdefer self.writer.restoreState(old_state);

    const num_cmd_dwords = 25;

    if (native_os == .ps4) {
        const cmd_dwords = try self.writer.reserveDwords(num_cmd_dwords);
        const result = gnmDriverSetCsShaderWithModifier(
            cmd_dwords.ptr,
            num_cmd_dwords,
            &registers,
            .{},
        );
        if (result != 0) {
            std.debug.print("setCsShader: driver failed with {}\n", .{result});
            return error.DriverFailed;
        }
    } else {
        const addresses = [2]u32{
            registers.compute_pgm_lo,
            0,
        };
        try self.setPersistentRegisterRange(.compute_pgm_lo, &addresses);
        const resources = [2]u32{
            registers.compute_pgm_rsrc1,
            registers.compute_pgm_rsrc2,
        };
        try self.setPersistentRegisterRange(.compute_pgm_rsrc1, &resources);
        const num_threads = [3]u32{
            registers.compute_num_thread_x,
            registers.compute_num_thread_y,
            registers.compute_num_thread_z,
        };
        try self.setPersistentRegisterRange(.compute_num_thread_x, &num_threads);
        try self.writer.writeDword(@bitCast(pm4.Header{
            .kind = .pkt3,
            .count = num_cmd_dwords - (self.writer.current_dword - old_state),
            .info = .{ .pkt3 = .{
                .predicate = self.flags.predication_enabled,
                .shader = .graphics,
                .it_opcode = .nop,
            } },
        }));
    }
}

pub fn setShaderPixel(self: *Self, registers: gnm.PsStageRegisters) DriverError!void {
    const old_state = self.writer.saveState();
    errdefer self.writer.restoreState(old_state);

    const num_cmd_dwords = 40;
    const cmd_dwords = try self.writer.reserveDwords(num_cmd_dwords);
    const result = gnmDriverSetPsShader350(
        cmd_dwords.ptr,
        num_cmd_dwords,
        &registers,
    );
    if (result != 0) return error.DriverFailed;
}

pub fn setShaderVertex(
    self: *Self,
    registers: gnm.VsStageRegisters,
    shader_modifier: u32,
) DriverError!void {
    const old_state = self.writer.saveState();
    errdefer self.writer.restoreState(old_state);

    const num_cmd_dwords = 29;
    const cmd_dwords = try self.writer.reserveDwords(num_cmd_dwords);
    const result = gnmDriverSetVsShader(
        cmd_dwords.ptr,
        num_cmd_dwords,
        &registers,
        shader_modifier,
    );
    if (result != 0) return error.DriverFailed;
}

pub fn setIndexBuffer(
    self: *Self,
    buffer: ?*const anyopaque,
) (error{InvalidAddress} || pm4.Writer.WriteError)!void {
    const address: u64 = @intFromPtr(buffer);
    if (address == 0 or (address >> 48) != 0) {
        @branchHint(.unlikely);
        return error.InvalidAddress;
    }

    try self.writer.writeStruct(CmdDrawIndexBase, .{
        .header = .{
            .kind = .pkt3,
            .count = (@sizeOf(CmdDrawIndexBase) / @sizeOf(u32)) - 2,
            .info = .{ .pkt3 = .{
                .predicate = self.flags.predication_enabled,
                .shader = .graphics,
                .it_opcode = .index_base,
            } },
        },
        .addr_lo = @truncate(address),
        .data = .{
            .addr_hi = @truncate(address >> 32),
            .base_select = 0,
        },
    });
}

pub fn setIndexCount(
    self: *Self,
    count: u32,
) pm4.Writer.WriteError!void {
    try self.writer.writeStruct(CmdDrawIndexBufferSize, .{
        .header = .{
            .kind = .pkt3,
            .count = (@sizeOf(CmdDrawIndexBufferSize) / @sizeOf(u32)) - 2,
            .info = .{ .pkt3 = .{
                .predicate = self.flags.predication_enabled,
                .shader = .graphics,
                .it_opcode = .index_buffer_size,
            } },
        },
        .num_indices = count,
    });
}

pub fn setIndexSize(
    self: *Self,
    index_size: gnm.IndexSize,
    cache_policy: gnm.CachePolicy,
) pm4.Writer.WriteError!void {
    try self.writer.writeStruct(CmdDrawIndexType, .{
        .header = .{
            .kind = .pkt3,
            .count = (@sizeOf(CmdDrawIndexType) / @sizeOf(u32)) - 2,
            .info = .{ .pkt3 = .{
                .predicate = self.flags.predication_enabled,
                .shader = .graphics,
                .it_opcode = .index_type,
            } },
        },
        .vgt_dma_index_type = .{
            .index_type = index_size,
            .swap_mode = .none,
            .buf_type = .mem,
            .rdreq_policy = cache_policy,
            .atc = false,
            .not_eop = false,
            .req_path = cache_policy != .bypass,
        },
    });
}

pub fn setIndirectArgs(
    self: *Self,
    args: ?*const gnm.DrawIndirectArgs,
) SetBaseError!void {
    try self.setBase(args);
}

pub fn setIndexedIndirectArgs(
    self: *Self,
    args: ?*const gnm.DrawIndexIndirectArgs,
) SetBaseError!void {
    try self.setBase(args);
}

const SetBaseError = error{
    InvalidAddress,
} || pm4.Writer.WriteError;

fn setBase(
    self: *Self,
    base: ?*const anyopaque,
) SetBaseError!void {
    const address: u64 = @intFromPtr(base);
    if ((address >> 48) != 0) {
        @branchHint(.unlikely);
        return error.InvalidAddress;
    }

    try self.writer.writeStruct(CmdDrawSetBase, .{
        .header = .{
            .kind = .pkt3,
            .count = (@sizeOf(CmdDrawSetBase) / @sizeOf(u32)) - 2,
            .info = .{ .pkt3 = .{
                .predicate = self.flags.predication_enabled,
                .shader = .graphics,
                .it_opcode = .set_base,
            } },
        },
        .info = .{ .base_index = 1 },
        .address_lo = @truncate(address),
        .data = .{
            .address_hi = @truncate(address >> 32),
        },
    });
}

pub fn setNumInstances(self: *Self, count: u32) SetBaseError!void {
    try self.writer.writeStruct(CmdDrawNumInstances, .{
        .header = .{
            .kind = .pkt3,
            .count = (@sizeOf(CmdDrawNumInstances) / @sizeOf(u32)) - 2,
            .info = .{ .pkt3 = .{
                .predicate = self.flags.predication_enabled,
                .shader = .graphics,
                .it_opcode = .num_instances,
            } },
        },
        .count = count,
    });
}
//
// packets' layouts
//
pub const CmdAcquireMem = extern struct {
    pub const Engine = enum(u1) {
        me = 0,
        pfp = 1,
    };

    header: pm4.Header,
    flags: packed struct(u32) {
        coher_cntl: gnm.CoherCntl,
        engine: Engine,
    },
    coher_size_lo: u32,
    coher_size_hi: packed struct(u32) {
        value: u8,
        rsvd: u16 = 0,
        _: u8 = 0,
    },
    coher_base_lo: u32,
    coher_base_hi: packed struct(u32) {
        value: u24,
        _: u8 = 0,
    },
    poll_interval: packed struct(u32) {
        value: u16,
        _: u16 = 0,
    },
};

pub const CmdDrawIndexBase = extern struct {
    header: pm4.Header,
    addr_lo: u32,
    data: packed struct(u32) {
        addr_hi: u16,
        _: u14 = 0,
        base_select: u2,
    },
};

pub const CmdDispatchDirect = extern struct {
    header: pm4.Header,
    dim_x: u32,
    dim_y: u32,
    dim_z: u32,
    dispatch_initiator: gnm.ComputeDispatchInitiator,
};

pub const CmdDrawIndexBufferSize = extern struct {
    header: pm4.Header,
    num_indices: u32,
};

pub const CmdDrawIndexType = extern struct {
    header: pm4.Header,
    vgt_dma_index_type: packed struct(u32) {
        index_type: gnm.IndexSize,
        swap_mode: SwapMode,
        buf_type: DmaBufType,
        rdreq_policy: gnm.CachePolicy,
        atc: bool,
        not_eop: bool,
        req_path: bool,
        _: u21 = 0,
    },
};

pub const CmdDrawNumInstances = extern struct {
    header: pm4.Header,
    count: u32,
};

pub const CmdDrawSetBase = extern struct {
    header: pm4.Header,
    info: packed struct(u32) {
        base_index: u4,
        _: u28 = 0,
    },
    address_lo: u32,
    data: packed struct(u32) {
        address_hi: u16,
        _: u16 = 0,
    },
};

pub const CmdDmaData = extern struct {
    pub const Engine = enum(u1) {
        me = 0,
        pfp = 1,
    };
    pub const Selector = enum(u2) {
        dst_addr = 0,
        gds = 1,
        nowhere = 2,
        dst_addr_tc_l2 = 3,

        pub fn isAddress(self: Selector) bool {
            return self == .dst_addr or self == .dst_addr_tc_l2;
        }
    };
    pub const AddressSpace = enum(u1) {
        memory = 0,
        register = 1,
    };
    pub const AddressIncrementControl = enum(u1) {
        increment = 0,
        no_increment = 1,
    };

    header: pm4.Header,
    flags: packed struct(u32) {
        engine: Engine,
        _: u11 = 0,
        src_atc: bool = false,
        src_cache_policy: gnm.CachePolicy,
        src_volatile: bool = false,
        _2: u4 = 0,
        dst_sel: Selector,
        _3: u2 = 0,
        dst_atc: bool = false,
        dst_cache_policy: gnm.CachePolicy,
        dst_volatile: bool = false,
        _4: u1 = 0,
        src_sel: Selector,
        cp_sync: bool = false,
    },

    src_addr_lo: u32,
    src_addr_hi: u32,
    dst_addr_lo: u32,
    dst_addr_hi: u32,

    command: packed struct(u32) {
        byte_count: u21,
        disable_wr_confirm: bool,
        src_swap: SwapMode,
        dst_swap: SwapMode,
        src_addr_space: AddressSpace,
        dst_addr_space: AddressSpace,
        src_addr_inc: AddressIncrementControl,
        dst_addr_inc: AddressIncrementControl,
        raw_wait: bool,
        _: u1 = 0,
    },
};

pub const CmdEventWriteEop = extern struct {
    header: pm4.Header,
    flags: packed struct(u32) {
        event_type: gnm.VgtEventType,
        _: u2 = 0,
        event_index: u4,
        tcl1_vol_action_ena: bool,
        tc_vol_action_ena: bool,
        _2: u1 = 0,
        tc_wb_action_ena: bool,
        tcl1_action_ena: bool,
        tc_action_ena: bool,
        _3: u2 = 0,
        invalidate_l2: bool,
        _4: u3 = 0,
        atc: bool,
        cache_policy: gnm.CachePolicy,
        @"volatile": bool,
        _5: u4 = 0,
    },
    address_lo: u32,
    flags2: packed struct(u32) {
        address_hi: u16,
        should_write_to_l2: bool,
        _: u7 = 0,
        int_sel: gnm.EventIntSel,
        _2: u3 = 0,
        data_sel: gnm.EventDataSel,
    },
    data_lo: u32,
    data_hi: u32,
};

pub const CmdEventWriteEos = extern struct {
    pub const EventIndex = enum(u4) {
        csdone_psdone = 6,
    };
    pub const Command = enum(u3) {
        store_append_count_to_memory = 0,
        store_gds_data_to_memory = 1,
        store_32bit_data_to_memory = 2,
    };

    header: pm4.Header,
    flags: packed struct(u32) {
        event_type: gnm.VgtEventType,
        _: u2 = 0,
        event_index: EventIndex,
        _2: u20 = 0,
    },
    address_lo: u32,
    flags2: packed struct(u32) {
        address_hi: u16,
        _: u13 = 0,
        command: Command,
    },
    command_argument: extern union {
        store_gds: packed struct(u32) {
            gds_index: u16,
            size: u16,
        },
        store_32bit: u32,
    },
};

pub const CmdWaitRegMem = extern struct {
    pub const Engine = enum(u2) {
        me = 0,
        pfp = 1,
        ce = 2,
    };

    pub const MemorySpace = enum(u2) {
        register = 0,
        memory = 1,
        tc_l2 = 2,
    };
    pub const OperationType = enum(u2) {
        wait_reg_mem = 0,
        wr_wait_wr_reg = 1,
    };

    header: pm4.Header,
    flags: packed struct(u32) {
        function: gnm.WaitOperation,
        _: u1 = 0,
        mem_space: MemorySpace,
        operation: OperationType,
        engine: Engine,
        uncached: bool,
        _2: u13 = 0,
        atc: bool,
        cache_policy: gnm.CachePolicy,
        @"volatile": bool,
        _3: u4 = 0,
    },
    poll_address_lo: u32,
    poll_address_hi: u32,
    reference: u32,
    mask: u32,
    poll_interval: u32,
};

pub const CmdWriteData = extern struct {
    pub const Engine = enum(u2) {
        me = 0,
        pfp = 1,
        ce = 2,
    };

    pub const DstSel = enum(u4) {
        register = 0,
        memory_sync = 1,
        tc_l2 = 2,
        gds = 3,
        memory_async = 5,
    };

    header: pm4.Header,
    flags: packed struct(u32) {
        _: u8 = 0,
        dst_sel: DstSel,
        _2: u4 = 0,
        wr_one_addr: bool,
        _3: u3 = 0,
        wr_confirm: bool,
        _4: u3 = 0,
        atc: bool,
        cache_policy: gnm.CachePolicy,
        @"volatile": bool,
        _5: u2 = 0,
        engine_sel: Engine,
    },
    dst_addr_lo: u32,
    dst_addr_hi: u32,
};

const DmaBufType = enum(u2) {
    mem = 0,
    ring = 1,
    setup = 2,
};

const SwapMode = enum(u2) {
    none = 0,
    @"8_in_16" = 1,
    @"8_in_32" = 2,
    @"8_in_64" = 3,
};

comptime {
    assert(@sizeOf(CmdAcquireMem) == 0x1c);
    assert(@sizeOf(CmdDrawIndexBase) == 0xc);
    assert(@sizeOf(CmdDrawIndexBufferSize) == 0x8);
    assert(@sizeOf(CmdDrawIndexType) == 0x8);
    assert(@sizeOf(CmdDrawNumInstances) == 0x8);
    assert(@sizeOf(CmdDrawSetBase) == 0x10);
    assert(@sizeOf(CmdDispatchDirect) == 0x14);
    assert(@sizeOf(CmdEventWriteEop) == 0x18);
    assert(@sizeOf(CmdEventWriteEos) == 0x14);
    assert(@sizeOf(CmdWaitRegMem) == 0x1c);
    assert(@sizeOf(CmdWriteData) == 0x10);
}

//
// PS4 driver functions
//

// TODO: implement these driver calls for egemu/generic here or there?
const DriverDrawFlags = packed struct(u32) {
    predication: bool,
    _: u28 = 0,
    /// Used in NEO/Pro only.
    render_target_index: u3,
};
const DriverDispatchFlags = packed struct(u32) {
    predication: bool,
    _: u2 = 0,
    ordered_append: bool,
    ordered_append_mode: gnm.ComputeDispatchInitiator.OrderedAppendMode,
    _2: u27 = 0,
};
const DriverSetCsShaderModifier = packed struct(u32) {
    _: u7 = 0,
    tgid_x_en: bool = false,
    tgid_y_en: bool = false,
    tgid_z_en: bool = false,
    tg_size_en: bool = false,
    _2: u21 = 0,
};

// TODO: move driver implementations to here
extern fn gnmDriverDrawIndex(
    cmd: [*]u32,
    num_cmd_dwords: u32,
    num_indices: u32,
    index_addr: u64,
    flags: DriverDrawFlags,
) i32;
extern fn gnmDriverDrawIndexAuto(
    cmd: [*]u32,
    num_cmd_dwords: u32,
    num_indices: u32,
    flags: DriverDrawFlags,
) i32;
extern fn gnmDriverDrawIndexIndirect(
    cmd: [*]u32,
    num_cmd_dwords: u32,
    data_offset: u32,
    stage: u32,
    vertex_offset_user_sgpr: u32,
    instance_offset_user_sgpr: u32,
    flags: DriverDrawFlags,
) i32;
extern fn gnmDriverDrawIndirect(
    cmd: [*]u32,
    num_cmd_dwords: u32,
    data_offset: u32,
    stage: u32,
    vertex_offset_user_sgpr: u32,
    instance_offset_user_sgpr: u32,
    flags: DriverDrawFlags,
) i32;
extern fn gnmDriverDispatchDirect(
    cmd: [*]u32,
    num_cmd_dwords: u32,
    thread_group_x: u32,
    thread_group_y: u32,
    thread_group_z: u32,
    flags: DriverDispatchFlags,
) i32;
extern fn gnmDriverDrawInitDefaultHardwareState350(
    cmd: [*]u32,
    num_cmd_dwords: u32,
) i32;
extern fn gnmDriverSetEmbeddedPsShader(
    cmd: [*]u32,
    num_cmd_dwords: u32,
    shader_id: i32,
) i32;
extern fn gnmDriverSetEmbeddedVsShader(
    cmd: [*]u32,
    num_cmd_dwords: u32,
    shader_id: i32,
    shader_modifier: u32,
) i32;
extern fn gnmDriverSetCsShaderWithModifier(
    cmd: [*]u32,
    num_cmd_dwords: u32,
    registers: *const gnm.CsStageRegisters,
    modifier: DriverSetCsShaderModifier,
) i32;
extern fn gnmDriverSetPsShader350(
    cmd: [*]u32,
    num_cmd_dwords: u32,
    registers: *const gnm.PsStageRegisters,
) i32;
extern fn gnmDriverSetVsShader(
    cmd: [*]u32,
    num_cmd_dwords: u32,
    registers: *const gnm.VsStageRegisters,
    shader_modifier: u32,
) i32;
extern fn gnmDriverInsertWaitFlipDone(
    cmd: [*]u32,
    num_cmd_dwords: u32,
    video_handle: i32,
    display_buffer_index: i32,
) i32;
// extern "SceGnmDriver" fn sceGnmDrawIndex(
//     cmd: [*]u32,
//     num_cmd_dwords: u32,
//     num_indices: u32,
//     index_addr: u64,
//     flags: DriverDrawFlags,
// ) i32;
// extern "SceGnmDriver" fn sceGnmDrawIndexAuto(
//     cmd: [*]u32,
//     num_cmd_dwords: u32,
//     num_indices: u32,
//     flags: DriverDrawFlags,
// ) i32;
// extern "SceGnmDriver" fn sceGnmDrawIndexIndirect(
//     cmd: [*]u32,
//     num_cmd_dwords: u32,
//     data_offset: u32,
//     stage: u32,
//     vertex_offset_user_sgpr: u32,
//     instance_offset_user_sgpr: u32,
//     flags: DriverDrawFlags,
// ) i32;
// extern "SceGnmDriver" fn sceGnmDrawIndirect(
//     cmd: [*]u32,
//     num_cmd_dwords: u32,
//     data_offset: u32,
//     stage: u32,
//     vertex_offset_user_sgpr: u32,
//     instance_offset_user_sgpr: u32,
//     flags: DriverDrawFlags,
// ) i32;
// extern "SceGnmDriver" fn sceGnmDispatchDirect(
//     cmd: [*]u32,
//     num_cmd_dwords: u32,
//     thread_group_x: u32,
//     thread_group_y: u32,
//     thread_group_z: u32,
//     flags: DriverDispatchFlags,
// ) i32;
// extern "SceGnmDriver" fn sceGnmDrawInitDefaultHardwareState350(
//     cmd: [*]u32,
//     num_cmd_dwords: u32,
// ) i32;
// extern "SceGnmDriver" fn sceGnmSetEmbeddedPsShader(
//     cmd: [*]u32,
//     num_cmd_dwords: u32,
//     shader_id: i32,
// ) i32;
// extern "SceGnmDriver" fn sceGnmSetEmbeddedVsShader(
//     cmd: [*]u32,
//     num_cmd_dwords: u32,
//     shader_id: i32,
//     shader_modifier: u32,
// ) i32;
// extern "SceGnmDriver" fn sceGnmSetCsShaderWithModifier(
//     cmd: [*]u32,
//     num_cmd_dwords: u32,
//     registers: *const gnm.CsStageRegisters,
//     modifier: DriverSetCsShaderModifier,
// ) i32;
// extern "SceGnmDriver" fn sceGnmSetPsShader350(
//     cmd: [*]u32,
//     num_cmd_dwords: u32,
//     registers: *const gnm.PsStageRegisters,
// ) i32;
// extern "SceGnmDriver" fn sceGnmSetVsShader(
//     cmd: [*]u32,
//     num_cmd_dwords: u32,
//     registers: *const gnm.VsStageRegisters,
//     shader_modifier: u32,
// ) i32;
// extern "SceGnmDriver" fn sceGnmInsertWaitFlipDone(
//     cmd: [*]u32,
//     num_cmd_dwords: u32,
//     video_handle: i32,
//     display_buffer_index: i32,
// ) i32;

const testing = std.testing;
const test_data = @import("test_data");

fn testGetLabelAddress(vid_handle: i32, out_addr: *u64) callconv(.c) i32 {
    const cast_handle: u32 = @bitCast(vid_handle);
    out_addr.* = (@as(u64, cast_handle) << 4) | 0xabcd120000000000;
    return 0;
}

test "dcb usage" {
    const gpa = gnm.gpu_addr;

    gnm.platInit(.{
        .gpu_mode = 0,
        .get_buffer_label_address = &testGetLabelAddress,
    });
    // reset platform params for other tests
    defer gnm.platInit(.{
        .gpu_mode = 0,
        .get_buffer_label_address = null,
    });

    const gpu_mode: gnm.GpuMode = .base;
    const color_fmt: gnm.DataFormat = .r8g8b8a8_srgb;
    const surf_info = try gpa.findOptimalSurface(.color_display, color_fmt.surface.getBitsPerElement(), 1, false, gpu_mode);

    var rt = try gnm.RenderTarget.create(.{
        .format = color_fmt,
        .width = 1920,
        .height = 1080,
        .pitch = 0,
        .num_slices = 1,
        .num_samples = 1,
        .num_fragments = 1,
        .tile_mode_hint = @fromBackingInt(@as(u5, @intCast(@as(c_uint, @intCast(surf_info.tile_mode))))), // yuck
        .min_gpu_mode = gpu_mode,
    });

    rt.setBaseAddress(0x34567800);

    // const depth_fmt: gnm.DataFormat = .z_f32;
    // const depth_surf_info = try gpa.computeSurfaceInfo(.{
    //     .tile_mode = .depth_2d_thin_64,
    //     .min_gpu_mode = gpu_mode,

    //     .linear_width = 1920,
    //     .linear_height = 1080,
    //     .linear_depth = 1,
    //     .num_fragments_per_pixel = 1,
    //     .base_tiled_pitch = 0,

    //     .mip_level = 0,
    //     .array_slice = 0,
    //     .surface_flags = .{
    //         .depth_target = true,
    //         .display = true,
    //     },
    //     .bits_per_fragment = depth_fmt.surface.getBitSize(),
    //     .is_block_compressed = depth_fmt.surface.isBlockCompressed(),
    // });

    // var drt = try gnm.DepthRenderTarget.create(.{
    //     .z_format = .f32,
    //     .stencil_format = .invalid,
    //     .width = 1920,
    //     .height = 1080,
    //     .pitch = 0,
    //     .num_slices = 1,
    //     .num_fragments = 1,
    //     .tile_mode_hint = surf_info.tile_mode,
    //     .min_gpu_mode = gpu_mode,
    // });
    // _ = &depth_surf_info; // TODO: use this?
    // _ = &drt; // TODO: use this?

    const vs_regs: gnm.VsStageRegisters = .{
        .spi_shader_pgm_lo_vs = 0x65432100,
        .spi_shader_pgm_hi_vs = 0,
        .spi_shader_pgm_rsrc1_vs = .empty,
        .spi_shader_pgm_rsrc2_vs = .empty,
        .spi_vs_out_config = .empty,
        .spi_shader_pos_format = .{},
        .pa_cl_vs_out_cntl = .{},
    };
    const ps_regs: gnm.PsStageRegisters = .{
        .spi_shader_pgm_lo_ps = 0x21876500,
        .spi_shader_pgm_hi_ps = 0,
        .spi_shader_pgm_rsrc1_ps = .empty,
        .spi_shader_pgm_rsrc2_ps = .empty,
        .spi_shader_z_format = .empty,
        .spi_shader_col_format = .{},
        .spi_ps_input_ena = .{},
        .spi_ps_input_addr = .empty,
        .spi_ps_in_control = .empty,
        .spi_baryc_cntl = .empty,
        .db_shader_control = .empty,
        .cb_shader_mask = .{},
    };
    const index_mem = 0xaabbccddeeff00;
    const label_mem = 0xeeddccbbaa00;

    const texture = try gnm.Texture.create(.{
        .format = .r8g8b8a8_srgb,
        .type = .@"2d",
        .width = 32,
        .height = 32,
        .depth = 1,
        .pitch = 32,

        .num_mips = 1,
        .num_slices = 1,
        .num_fragments = 1,

        .tile_mode_hint = .display_linear_general,
        .min_gpu_mode = .base,
    });

    const sampler: gnm.Sampler = .{
        .reg1 = .{
            .min_lod = 0,
            .max_lod = 0xfff,
        },
        .reg2 = .{
            .xy_min_filter = .bilinear,
            .xy_mag_filter = .bilinear,
            .z_filter = .point,
            .mip_filter = .linear,
        },
    };

    const const_buf: gnm.Buffer = .createConst(@ptrFromInt(0x2323232345454540), 256);

    var cmd_buffer: [gnm.MAX_COMMAND_DWORDS]u32 = undefined;
    var cmd: gnm.DrawCommandBuffer = .init(&cmd_buffer);

    try cmd.initDefaultHardwareState();

    const buf32 = try cmd.writer.allocInline(u32, @alignOf(u32));
    buf32.* = 0xbbccddee;
    const buf64 = try cmd.writer.allocInline(u64, @alignOf(u64));
    buf64.* = 0xff11223344556677;
    const some_buf = try cmd.writer.allocInlineMany(u8, 0x18, @sizeOf(u32));
    @memset(some_buf, 0xcc);

    try cmd.waitFlipDone(0x4321, 2);
    try cmd.setRenderTarget(0, rt);
    try cmd.setRenderTargetMask(.{ .target0_enable = .on });

    try cmd.setViewport(0, .{
        .z_min = 0.0,
        .z_max = 1.0,
        .vport = .{
            .x_scale = 1920 * 0.5,
            .y_scale = -1080 * 0.5,
            .z_scale = 0.5,
            .x_offset = 0.0 + 1920 * 0.5,
            .y_offset = 0.0 + 1080 * 0.5,
            .z_offset = 0.5,
        },
    });
    try cmd.setViewportTransformControl(.{
        .vport_x_scale_ena = true,
        .vport_x_offset_ena = true,
        .vport_y_scale_ena = true,
        .vport_y_offset_ena = true,
        .vport_z_scale_ena = true,
        .vport_z_offset_ena = true,
        .vtx_xy_fmt = false,
        .vtx_z_fmt = false,
        .vtx_w0_fmt = true,
    });

    try cmd.setScreenScissors(.{ .tl_x = 0, .tl_y = 0 }, .{ .br_x = 1920, .br_y = 1080 });
    try cmd.setHardwareScreenOffset(.{ .hw_screen_offset_x = 60, .hw_screen_offset_y = 32 });
    try cmd.setGuardBands(.{
        .horz_clip_adj = 33.133335,
        .vert_clip_adj = 59.629631,
        .horz_disc_adj = 1.0,
        .vert_disc_adj = 1.0,
    });

    try cmd.setUserDataTexture(.ps, 0, texture);
    try cmd.setUserDataSampler(.ps, 8, sampler);

    try cmd.setUserDataBuffer(.ps, 12, const_buf);

    try cmd.setShaderVertex(vs_regs, 123);
    try cmd.setShaderPixel(ps_regs);

    const vertex_outputs = [_]gnm.VertexExportSemantic{
        .{ .semantic = 0, .out_index = 1, .type = .{ .low = true } },
        .{ .semantic = 1, .out_index = 2, .type = .{} },
        .{ .semantic = 2, .out_index = 3, .type = .{} },
    };
    const pixel_inputs = [_]gnm.PixelInputSemantic{
        .{ .semantic = 0, .default_value = .@"1_1_1_1", .hw = .{ .neo = .{ .interp_f16 = .{ .low = true } } } },
        .{ .semantic = 1, .hw = .{ .base = .{} } },
        .{ .semantic = 2, .sel_linear = true, .hw = .{ .base = .{ .custom = true } } },
    };

    try cmd.setPixelInputLayout(&vertex_outputs, &pixel_inputs, gpu_mode);

    try cmd.setEmbeddedShaderVertex(.fullscreen, 0);
    try cmd.setEmbeddedShaderPixel(.null_rg32);

    try cmd.setBlendControl(0, .{
        .color_src_blend = .src_alpha,
        .color_comb_fcn = .dst_plus_src,
        .color_dest_blend = .one_minus_src_alpha,
        .alpha_src_blend = .constant_color,
        .alpha_comb_fcn = .src_minus_dst,
        .alpha_dest_blend = .one_minus_constant_color,
        .separate_alpha_blend = true,
        .enable = true,
    });
    try cmd.setDbRenderControl(.{
        .depth_clear_enable = false,
        .stencil_clear_enable = false,
        .resummarize_enable = false,
        .depth_copy = false,
        .stencil_copy = false,
        .stencil_compress_disable = false,
        .depth_compress_disable = false,
        .copy_centroid = false,
        .copy_sample = 0,
        .decompress_enable = true,
    });
    try cmd.setDepthStencilControl(.{
        .stencil_enable = false,
        .z_enable = true,
        .z_write_enable = true,
        .depth_bounds_enable = false,
        .z_func = .greater_equal,
        .backface_enable = false,
        .stencil_func = .always,
        .stencil_func_backface = .always,
        .enable_color_writes_on_depth_fail = false,
        .disable_color_writes_on_depth_pass = false,
    });
    try cmd.setPrimitiveSetup(.{
        .cull_front = false,
        .cull_back = false,
        .face = .cw,
        .poly_mode = .disable,
        .polymode_front_ptype = .triangles,
        .polymode_back_ptype = .triangles,
        .poly_offset_front_enable = false,
        .poly_offset_back_enable = false,
        .vtx_window_offset_enable = false,
        .provoking_vtx_last = false,
        .persp_corr_dis = false,
    });

    try cmd.setPrimitiveType(.tri_list);
    try cmd.setIndexSize(.@"32", .lru);
    try cmd.drawIndex(@ptrFromInt(index_mem), 3, .{});

    try cmd.setPrimitiveType(.rect_list);
    try cmd.setIndexSize(.@"16", .lru);
    try cmd.drawIndexAuto(3, .{});

    try cmd.setInstanceStepRate(.{ 4, 2 });
    try cmd.setNumInstances(50);
    try cmd.drawIndex(@ptrFromInt(index_mem), 24, .{});

    try cmd.setIndirectArgs(@ptrFromInt(0xbbee12345678));
    try cmd.drawIndirect(0, .es, 0, 0, .{});

    try cmd.setIndexCount(5555);
    try cmd.setIndexBuffer(@ptrFromInt(0x123123123ee));
    try cmd.setIndexedIndirectArgs(@ptrFromInt(0x5678aaccbbe8));
    try cmd.drawIndexIndirect(0xefd0, .vs, 4, 8, .{});

    try cmd.eventWriteEop(.cache_flush_ts, .send_data_64, @ptrFromInt(label_mem), 1, .{});
    try cmd.waitOnAddress(.equal, @ptrFromInt(label_mem), 1, 0xffffffff);
    try cmd.waitGraphicsWrites(.{ .cb0_dest_base_ena = true, .db_dest_base_ena = true });

    const written_data = cmd.writer.getWritten();
    const expected_data: []const u32 = @ptrCast(&test_data.dcb);

    try testing.expectEqualSlices(u32, expected_data, written_data);
}
