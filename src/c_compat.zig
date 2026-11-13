const std = @import("std");
const math = std.math;
const mem = std.mem;

const gnm = @import("gnm.zig");
const pm4 = gnm.pm4;

//
// GnmCommandBuffer
//
export fn gnmCmdInit(
    buffer: [*]u32,
    num_dwords: u32,
    gpu_mode: c_int,
    callback: ?CallbackFunc,
    user_data: ?*anyopaque,
) callconv(.c) CommandBuffer {
    return .{
        .buffer = buffer,
        .num_dwords = num_dwords,
        .cur_dword = 0,
        .callback = .{
            .func = if (callback) |cb| cb else &defaultCallback,
            .userdata = user_data,
        },
        .flags = .{
            .enable_predication = false,
            .shader_type = 0,
            .gpu_mode = @backingInt(if (gpu_mode == 0)
                gnm.GpuMode.base
            else
                gnm.GpuMode.neo),
        },
    };
}

fn defaultCallback(cmd: *CommandBuffer, num_dwords: u32, user_data: ?*anyopaque) callconv(.c) bool {
    // unused args
    _ = cmd;
    _ = num_dwords;
    _ = user_data;
    writeDebugMsg(.err, "Command buffer is full, and no custom callback was specified", .{});
    return false;
}

export fn gnmCmdAllocInside(
    cmd: *CommandBuffer,
    num_dwords: u32,
    alignment: u32,
) callconv(.c) ?*anyopaque {
    if (num_dwords == 0) {
        writeDebugMsg(.err, "AllocInside: size must not be 0", .{});
        return null;
    }
    if (alignment < 4) {
        writeDebugMsg(.err, "AllocInside: alignment must be 4 or larger", .{});
        return null;
    }
    if ((alignment & 3) != 0) {
        writeDebugMsg(.err, "AllocInside: alignment must be a multiple of 4", .{});
        return null;
    }

    const dwords_to_alloc = math.cast(u14, num_dwords) orelse {
        writeDebugMsg(.err, "AllocInside: DWORD count 0x{x} is too large", .{
            num_dwords,
        });
        return null;
    };
    const cast_alignment = math.cast(u16, alignment) orelse {
        writeDebugMsg(.err, "AllocInside: alignment 0x{x} is too large", .{
            alignment,
        });
        return null;
    };

    var writer = toWriter(cmd);
    const new_buf = writer.allocInlineMany(u32, dwords_to_alloc, cast_alignment) catch {
        if (!cmd.*.callback.func.?(cmd, dwords_to_alloc, cmd.callback.userdata)) {
            writeDebugMsg(.err, "AllocInside: out of memory", .{});
        }
        return null;
    };

    cmd.cur_dword = writer.current_dword;
    return new_buf.ptr;
}

var msg_handler: ?MessageHandlerFunc = null;
var msg_handler_ud: ?*anyopaque = null;

export fn gnmSetMessageHandler(handler: ?MessageHandlerFunc, user_data: ?*anyopaque) callconv(.c) void {
    msg_handler = handler;
    msg_handler_ud = user_data;
}

pub fn writeDebugMsg(sev: MessageSeverity, comptime format: []const u8, args: anytype) void {
    var buffer: [256]u8 = undefined;
    if (msg_handler) |h| {
        const msg = mem.printSentinel(&buffer, format, args, 0) catch return;
        h(sev, msg, msg_handler_ud);
    }
}

//
// GnmDrawCommandBuffer
//
export fn gnmDrawCmdInitDefaultHardwareState(cmd: *CommandBuffer) callconv(.c) void {
    var dcb = toDcb(cmd);
    dcb.initDefaultHardwareState() catch |err| {
        writeDebugMsg(.err, "initDefaultHardwareState failed with {t}", .{err});
    };
    cmd.cur_dword = dcb.writer.current_dword;
}

export fn gnmDrawCmdDrawIndex(
    cmd: *CommandBuffer,
    index_count: u32,
    maybe_index_addr: ?[*]const u8,
) callconv(.c) void {
    return gnmDrawCmdDrawIndex2(cmd, index_count, maybe_index_addr, .empty);
}

export fn gnmDrawCmdDrawIndex2(
    cmd: *CommandBuffer,
    index_count: u32,
    maybe_index_addr: ?[*]const u8,
    modifier: DrawModifier,
) callconv(.c) void {
    const index_addr = maybe_index_addr orelse {
        writeDebugMsg(.err, "drawIndex's index address is null!", .{});
        return;
    };

    var dcb = toDcb(cmd);
    dcb.drawIndex(
        index_addr,
        index_count,
        .{ .render_target_index = @intCast(modifier.render_target_slice_offset) },
    ) catch |err| {
        writeDebugMsg(.err, "drawIndex failed with {t}", .{err});
    };
    cmd.cur_dword = dcb.writer.current_dword;
}

export fn gnmDrawCmdDrawIndexAuto(
    cmd: *CommandBuffer,
    index_count: u32,
) callconv(.c) void {
    return gnmDrawCmdDrawIndexAuto2(cmd, index_count, .empty);
}

export fn gnmDrawCmdDrawIndexAuto2(
    cmd: *CommandBuffer,
    index_count: u32,
    modifier: DrawModifier,
) callconv(.c) void {
    var dcb = toDcb(cmd);
    dcb.drawIndexAuto(
        index_count,
        .{ .render_target_index = @intCast(modifier.render_target_slice_offset) },
    ) catch |err| {
        writeDebugMsg(.err, "drawIndexAuto failed with {t}", .{err});
    };
    cmd.cur_dword = dcb.writer.current_dword;
}

export fn gnmDrawCmdDrawIndexIndirect(
    cmd: *CommandBuffer,
    data_offset: u32,
    stage: c_int,
    vertex_offset_user_sgpr: u8,
    instance_offset_user_sgpr: u8,
) callconv(.c) void {
    return gnmDrawCmdDrawIndexIndirect2(
        cmd,
        data_offset,
        stage,
        vertex_offset_user_sgpr,
        instance_offset_user_sgpr,
        .empty,
    );
}

export fn gnmDrawCmdDrawIndexIndirect2(
    cmd: *CommandBuffer,
    data_offset: u32,
    stage: c_int,
    vertex_offset_user_sgpr: u8,
    instance_offset_user_sgpr: u8,
    modifier: DrawModifier,
) callconv(.c) void {
    const cast_voff = math.cast(u4, vertex_offset_user_sgpr) orelse {
        writeDebugMsg(.err, "drawIndexIndirect's vertex offfset user SGPR {} is too large!", .{
            vertex_offset_user_sgpr,
        });
        return;
    };
    const cast_ioff = math.cast(u4, instance_offset_user_sgpr) orelse {
        writeDebugMsg(.err, "drawIndexIndirect's instance offfset user SGPR {} is too large!", .{
            instance_offset_user_sgpr,
        });
        return;
    };
    const cast_stage = toShaderStage(stage) orelse {
        writeDebugMsg(.err, "drawIndexIndirect's stage value {} is invalid!", .{
            stage,
        });
        return;
    };

    var dcb = toDcb(cmd);
    dcb.drawIndexIndirect(
        data_offset,
        cast_stage,
        cast_voff,
        cast_ioff,
        .{ .render_target_index = @intCast(modifier.render_target_slice_offset) },
    ) catch |err| {
        writeDebugMsg(.err, "drawIndexIndirect failed with {t}", .{err});
    };
    cmd.cur_dword = dcb.writer.current_dword;
}

export fn gnmDrawCmdDrawIndirect(
    cmd: *CommandBuffer,
    data_offset: u32,
    stage: c_int,
    vertex_offset_user_sgpr: u8,
    instance_offset_user_sgpr: u8,
) callconv(.c) void {
    return gnmDrawCmdDrawIndirect2(
        cmd,
        data_offset,
        stage,
        vertex_offset_user_sgpr,
        instance_offset_user_sgpr,
        .empty,
    );
}

export fn gnmDrawCmdDrawIndirect2(
    cmd: *CommandBuffer,
    data_offset: u32,
    stage: c_int,
    vertex_offset_user_sgpr: u8,
    instance_offset_user_sgpr: u8,
    modifier: DrawModifier,
) callconv(.c) void {
    const cast_voff = math.cast(u4, vertex_offset_user_sgpr) orelse {
        writeDebugMsg(.err, "drawIndirect's vertex offfset user SGPR {} is too large!", .{
            vertex_offset_user_sgpr,
        });
        return;
    };
    const cast_ioff = math.cast(u4, instance_offset_user_sgpr) orelse {
        writeDebugMsg(.err, "drawIndirect's instance offfset user SGPR {} is too large!", .{
            instance_offset_user_sgpr,
        });
        return;
    };
    const cast_stage = toShaderStage(stage) orelse {
        writeDebugMsg(.err, "drawIndirect's stage value {} is invalid!", .{
            stage,
        });
        return;
    };

    var dcb = toDcb(cmd);
    dcb.drawIndirect(
        data_offset,
        cast_stage,
        cast_voff,
        cast_ioff,
        .{ .render_target_index = @intCast(modifier.render_target_slice_offset) },
    ) catch |err| {
        writeDebugMsg(.err, "drawIndirect failed with {t}", .{err});
    };
    cmd.cur_dword = dcb.writer.current_dword;
}

export fn gnmDrawCmdSetDepthClearValue(cmd: *CommandBuffer, value: f32) callconv(.c) void {
    var dcb = toDcb(cmd);
    dcb.setDepthClearValue(value) catch |err| {
        writeDebugMsg(.err, "setDepthClearValue failed with {t}", .{err});
    };
    cmd.cur_dword = dcb.writer.current_dword;
}

export fn gnmDrawCmdSetDepthRenderTarget(cmd: *CommandBuffer, dt: *gnm.DepthRenderTarget) callconv(.c) void {
    var dcb = toDcb(cmd);
    dcb.setDepthRenderTarget(dt.*) catch |err| {
        writeDebugMsg(.err, "setDepthRenderTargetfailed with {t}", .{err});
    };
    cmd.cur_dword = dcb.writer.current_dword;
}

export fn gnmDrawCmdSetGuardBands(
    cmd: *CommandBuffer,
    horz_clip: f32,
    vert_clip: f32,
    horz_discard: f32,
    vert_discard: f32,
) callconv(.c) void {
    var dcb = toDcb(cmd);
    dcb.setGuardBands(.{
        .horz_clip_adj = horz_clip,
        .horz_disc_adj = horz_discard,
        .vert_clip_adj = vert_clip,
        .vert_disc_adj = vert_discard,
    }) catch |err| {
        writeDebugMsg(.err, "setGuardBands failed with {t}", .{err});
    };
    cmd.cur_dword = dcb.writer.current_dword;
}

export fn gnmDrawCmdSetHwScreenOffset(
    cmd: *CommandBuffer,
    offset_x: u32,
    offset_y: u32,
) callconv(.c) void {
    const cast_x = math.cast(u9, offset_x) orelse {
        writeDebugMsg(.err, "setHwScreenOffset's offset X {} is too large!", .{offset_x});
        return;
    };
    const cast_y = math.cast(u9, offset_y) orelse {
        writeDebugMsg(.err, "setHwScreenOffset's offset Y {} is too large!", .{offset_y});
        return;
    };

    var dcb = toDcb(cmd);
    dcb.setHardwareScreenOffset(.{
        .hw_screen_offset_x = cast_x,
        .hw_screen_offset_y = cast_y,
    }) catch |err| {
        writeDebugMsg(.err, "setHardwareScreenOffset failed with {t}", .{err});
    };
    cmd.cur_dword = dcb.writer.current_dword;
}

export fn gnmDrawCmdSetIndexBuffer(
    cmd: *CommandBuffer,
    buffer: ?*const anyopaque,
) callconv(.c) void {
    var dcb = toDcb(cmd);
    dcb.setIndexBuffer(buffer) catch |err| {
        writeDebugMsg(.err, "setIndexBuffer failed with {t}", .{err});
    };
    cmd.cur_dword = dcb.writer.current_dword;
}

export fn gnmDrawCmdSetIndexCount(
    cmd: *CommandBuffer,
    count: u32,
) callconv(.c) void {
    var dcb = toDcb(cmd);
    dcb.setIndexCount(count) catch |err| {
        writeDebugMsg(.err, "setIndexCount failed with {t}", .{err});
    };
    cmd.cur_dword = dcb.writer.current_dword;
}

export fn gnmDrawCmdSetIndexSize(
    cmd: *CommandBuffer,
    index_size: c_int,
    cache_policy: c_int,
) callconv(.c) void {
    const cast_size = toIndexSize(index_size) orelse {
        writeDebugMsg(.err, "setIndexSize's index size value {} is invalid!", .{
            index_size,
        });
        return;
    };
    const cast_pol = toCachePolicy(cache_policy) orelse {
        writeDebugMsg(.err, "setIndexSize's cache policy value {} is invalid!", .{
            cache_policy,
        });
        return;
    };

    var dcb = toDcb(cmd);
    dcb.setIndexSize(cast_size, cast_pol) catch |err| {
        writeDebugMsg(.err, "setIndexSize failed with {t}", .{err});
    };
    cmd.cur_dword = dcb.writer.current_dword;
}

export fn gnmDrawCmdSetIndirectArgs(
    cmd: *CommandBuffer,
    args: ?*const gnm.DrawIndirectArgs,
) callconv(.c) void {
    var dcb = toDcb(cmd);
    dcb.setIndirectArgs(args) catch |err| {
        writeDebugMsg(.err, "setIndirectArgs failed with {t}", .{err});
    };
    cmd.cur_dword = dcb.writer.current_dword;
}

export fn gnmDrawCmdSetIndexedIndirectArgs(
    cmd: *CommandBuffer,
    args: ?*const gnm.DrawIndexIndirectArgs,
) callconv(.c) void {
    var dcb = toDcb(cmd);
    dcb.setIndexedIndirectArgs(args) catch |err| {
        writeDebugMsg(.err, "setIndexedIndirectArgs failed with {t}", .{err});
    };
    cmd.cur_dword = dcb.writer.current_dword;
}

export fn gnmDrawCmdSetInstanceStepRate(
    cmd: *CommandBuffer,
    rate0: u32,
    rate1: u32,
) callconv(.c) void {
    var dcb = toDcb(cmd);
    dcb.setInstanceStepRate(.{ rate0, rate1 }) catch |err| {
        writeDebugMsg(.err, "setInstanceStepRate failed with {t}", .{err});
    };
    cmd.cur_dword = dcb.writer.current_dword;
}

export fn gnmDrawCmdSetNumInstances(
    cmd: *CommandBuffer,
    count: u32,
) callconv(.c) void {
    var dcb = toDcb(cmd);
    dcb.setNumInstances(count) catch |err| {
        writeDebugMsg(.err, "setNumInstances failed with {t}", .{err});
    };
    cmd.cur_dword = dcb.writer.current_dword;
}

export fn gnmDrawCmdSetPrimitiveType(
    cmd: *CommandBuffer,
    primitive_type: c_int,
) callconv(.c) void {
    const cast_type = toPrimitiveType(primitive_type) orelse {
        writeDebugMsg(.err, "setPrimitiveType's value {} is invalid!", .{
            primitive_type,
        });
        return;
    };

    var dcb = toDcb(cmd);
    dcb.setPrimitiveType(cast_type) catch |err| {
        writeDebugMsg(.err, "setPrimitiveType failed with {t}", .{err});
    };
    cmd.cur_dword = dcb.writer.current_dword;
}

export fn gnmDrawCmdSetRenderTarget(
    cmd: *CommandBuffer,
    slot: u32,
    maybe_rt: ?*const gnm.RenderTarget,
) callconv(.c) void {
    const cast_slot = math.cast(u3, slot) orelse {
        writeDebugMsg(.err, "setRenderTarget's slot {} is invalid!", .{
            slot,
        });
        return;
    };

    var dcb = toDcb(cmd);
    if (maybe_rt) |rt| {
        dcb.setRenderTarget(cast_slot, rt.*) catch |err| {
            writeDebugMsg(.err, "setRenderTarget failed with {t}", .{err});
        };
    } else {
        dcb.unsetRenderTarget(cast_slot) catch |err| {
            writeDebugMsg(.err, "unsetRenderTarget failed with {t}", .{err});
        };
    }
    cmd.cur_dword = dcb.writer.current_dword;
}

export fn gnmDrawCmdSetRenderTargetMask(
    cmd: *CommandBuffer,
    mask: u32,
) callconv(.c) void {
    var dcb = toDcb(cmd);
    dcb.setRenderTargetMask(@fromBackingInt(mask)) catch |err| {
        writeDebugMsg(.err, "setRenderTargetMask failed with {t}", .{err});
    };
    cmd.cur_dword = dcb.writer.current_dword;
}

export fn gnmDrawCmdSetScreenScissor(
    cmd: *CommandBuffer,
    left: i32,
    top: i32,
    right: i32,
    bottom: i32,
) callconv(.c) void {
    const cast_left = math.cast(i16, left) orelse {
        writeDebugMsg(.err, "setViewport's left {} is invalid!", .{left});
        return;
    };
    const cast_top = math.cast(i16, top) orelse {
        writeDebugMsg(.err, "setViewport's top {} is invalid!", .{top});
        return;
    };
    const cast_right = math.cast(i16, right) orelse {
        writeDebugMsg(.err, "setViewport's right {} is invalid!", .{right});
        return;
    };
    const cast_bottom = math.cast(i16, bottom) orelse {
        writeDebugMsg(.err, "setViewport's bottom {} is invalid!", .{bottom});
        return;
    };

    var dcb = toDcb(cmd);
    dcb.setScreenScissors(
        .{ .tl_x = cast_left, .tl_y = cast_top },
        .{ .br_x = cast_right, .br_y = cast_bottom },
    ) catch |err| {
        writeDebugMsg(.err, "setScreenScissors failed with {t}", .{err});
    };
    cmd.cur_dword = dcb.writer.current_dword;
}

export fn gnmDrawCmdSetViewport(
    cmd: *CommandBuffer,
    viewport_id: i32,
    info: *const SetViewportInfo,
) callconv(.c) void {
    const cast_id = math.cast(u4, viewport_id) orelse {
        writeDebugMsg(.err, "setViewport's viewport {} is invalid!", .{
            viewport_id,
        });
        return;
    };

    var dcb = toDcb(cmd);
    dcb.setViewport(cast_id, .{
        .z_min = info.d_min,
        .z_max = info.d_max,
        .vport = .{
            .x_scale = info.scale[0],
            .y_scale = info.scale[1],
            .z_scale = info.scale[2],
            .x_offset = info.offset[0],
            .y_offset = info.offset[1],
            .z_offset = info.offset[2],
        },
    }) catch |err| {
        writeDebugMsg(.err, "setViewport failed with {t}", .{err});
    };
    cmd.cur_dword = dcb.writer.current_dword;
}

export fn gnmDrawCmdSetPsShader(
    cmd: *CommandBuffer,
    regs: *const gnm.PsStageRegisters,
) callconv(.c) void {
    var dcb = toDcb(cmd);
    dcb.setShaderPixel(regs.*) catch |err| {
        writeDebugMsg(.err, "setPsShader failed with {t}", .{err});
    };
    cmd.cur_dword = dcb.writer.current_dword;
}

export fn gnmDrawCmdSetEmbeddedPsShader(
    cmd: *CommandBuffer,
    id: c_int,
) callconv(.c) void {
    const cast_id = toEmbeddedPixelShader(id) orelse {
        writeDebugMsg(.err, "setEmbeddedPsShader's id {} is invalid!", .{
            id,
        });
        return;
    };

    var dcb = toDcb(cmd);
    dcb.setEmbeddedShaderPixel(cast_id) catch |err| {
        writeDebugMsg(.err, "setEmbeddedPsShader failed with {t}", .{err});
    };
    cmd.cur_dword = dcb.writer.current_dword;
}

export fn gnmDrawCmdSetVsShader(
    cmd: *CommandBuffer,
    regs: *const gnm.VsStageRegisters,
    shader_modifier: u32,
) callconv(.c) void {
    var dcb = toDcb(cmd);
    dcb.setShaderVertex(regs.*, shader_modifier) catch |err| {
        writeDebugMsg(.err, "setVsShader failed with {t}", .{err});
    };
    cmd.cur_dword = dcb.writer.current_dword;
}

export fn gnmDrawCmdSetEmbeddedVsShader(
    cmd: *CommandBuffer,
    id: c_int,
    shader_modifier: u32,
) callconv(.c) void {
    const cast_id = toEmbeddedVertexShader(id) orelse {
        writeDebugMsg(.err, "setEmbeddedVsShader's id {} is invalid!", .{
            id,
        });
        return;
    };

    var dcb = toDcb(cmd);
    dcb.setEmbeddedShaderVertex(cast_id, shader_modifier) catch |err| {
        writeDebugMsg(.err, "setEmbeddedVsShader failed with {t}", .{err});
    };
    cmd.cur_dword = dcb.writer.current_dword;
}

export fn gnmDrawCmdSetPsInputUsage(
    cmd: *CommandBuffer,
    vs_outputs_ptr: ?[*]const gnm.VertexExportSemantic,
    num_vs_exports: u32,
    ps_inputs_ptr: ?[*]const gnm.PixelInputSemantic,
    num_ps_inputs: u32,
) callconv(.c) void {
    const vs_outputs: []const gnm.VertexExportSemantic = if (vs_outputs_ptr) |ptr|
        ptr[0..num_vs_exports]
    else if (num_vs_exports == 0)
        &.{}
    else
        return writeDebugMsg(.err, "setPsInputLayout's num_vs_outputs must be non-zero if vs_outputs are non-NULL!", .{});
    const ps_inputs: []const gnm.PixelInputSemantic = if (ps_inputs_ptr) |ptr|
        ptr[0..num_ps_inputs]
    else if (num_ps_inputs == 0)
        &.{}
    else
        return writeDebugMsg(.err, "setPsInputLayout's num_ps_inputs must be non-zero if ps_inputs are non-NULL!", .{});

    const gpu_mode = toGpuMode(cmd.flags.gpu_mode) orelse {
        writeDebugMsg(.err, "setPsInputLayout's command buffer has an invalid GPU mode {}!", .{
            cmd.flags.gpu_mode,
        });
        return;
    };

    var dcb = toDcb(cmd);
    dcb.setPixelInputLayout(vs_outputs, ps_inputs, gpu_mode) catch |err| {
        writeDebugMsg(.err, "setPsInputLayout failed with {t}", .{err});
    };
    cmd.cur_dword = dcb.writer.current_dword;
}

export fn gnmDrawCmdSetVsharpUserData(
    cmd: *CommandBuffer,
    stage: c_int,
    start_user_data_slot: u32,
    buffer_ptr: ?*const gnm.Buffer,
) callconv(.c) void {
    const cast_stage = toShaderStage(stage) orelse {
        writeDebugMsg(.err, "setVsharpUserData's stage value {} is invalid!", .{
            stage,
        });
        return;
    };
    const cast_start = math.cast(u4, start_user_data_slot) orelse {
        writeDebugMsg(.err, "setVsharpUserData's start_user_data_slot value {} is too large!", .{
            start_user_data_slot,
        });
        return;
    };
    const buffer = buffer_ptr orelse {
        writeDebugMsg(.err, "setVsharpUserData's buffer must not be NULL!", .{});
        return;
    };

    var dcb = toDcb(cmd);
    dcb.setUserDataBuffer(cast_stage, cast_start, buffer.*) catch |err| {
        writeDebugMsg(.err, "setVsharpUserData failed with {t}", .{err});
    };
    cmd.cur_dword = dcb.writer.current_dword;
}

export fn gnmDrawCmdSetTsharpUserData(
    cmd: *CommandBuffer,
    stage: c_int,
    start_user_data_slot: u32,
    texture_ptr: ?*const gnm.Texture,
) callconv(.c) void {
    const cast_stage = toShaderStage(stage) orelse {
        writeDebugMsg(.err, "setTsharpUserData's stage value {} is invalid!", .{
            stage,
        });
        return;
    };
    const cast_start = math.cast(u4, start_user_data_slot) orelse {
        writeDebugMsg(.err, "setTsharpUserData's start_user_data_slot value {} is too large!", .{
            start_user_data_slot,
        });
        return;
    };
    const texture = texture_ptr orelse {
        writeDebugMsg(.err, "setTsharpUserData's texture must not be NULL!", .{});
        return;
    };

    var dcb = toDcb(cmd);
    dcb.setUserDataTexture(cast_stage, cast_start, texture.*) catch |err| {
        writeDebugMsg(.err, "setTsharpUserData failed with {t}", .{err});
    };
    cmd.cur_dword = dcb.writer.current_dword;
}

export fn gnmDrawCmdSetSsharpUserData(
    cmd: *CommandBuffer,
    stage: c_int,
    start_user_data_slot: u32,
    sampler_ptr: ?*const gnm.Sampler,
) callconv(.c) void {
    const cast_stage = toShaderStage(stage) orelse {
        writeDebugMsg(.err, "setSsharpUserData's stage value {} is invalid!", .{
            stage,
        });
        return;
    };
    const cast_start = math.cast(u4, start_user_data_slot) orelse {
        writeDebugMsg(.err, "setSsharpUserData's start_user_data_slot value {} is too large!", .{
            start_user_data_slot,
        });
        return;
    };
    const sampler = sampler_ptr orelse {
        writeDebugMsg(.err, "setSsharpUserData's sampler must not be NULL!", .{});
        return;
    };

    var dcb = toDcb(cmd);
    dcb.setUserDataSampler(cast_stage, cast_start, sampler.*) catch |err| {
        writeDebugMsg(.err, "setSsharpUserData failed with {t}", .{err});
    };
    cmd.cur_dword = dcb.writer.current_dword;
}

export fn gnmDrawCmdSetPointerUserData(
    cmd: *CommandBuffer,
    stage: c_int,
    start_user_data_slot: u32,
    ptr: ?*const anyopaque,
) callconv(.c) void {
    const cast_stage = toShaderStage(stage) orelse {
        writeDebugMsg(.err, "setPointerUserData's stage value {} is invalid!", .{
            stage,
        });
        return;
    };
    const cast_start = math.cast(u4, start_user_data_slot) orelse {
        writeDebugMsg(.err, "setPointerUserData's start_user_data_slot value {} is too large!", .{
            start_user_data_slot,
        });
        return;
    };

    var dcb = toDcb(cmd);
    dcb.setUserDataPointer(cast_stage, cast_start, ptr) catch |err| {
        writeDebugMsg(.err, "setPointerUserData failed with {t}", .{err});
    };
    cmd.cur_dword = dcb.writer.current_dword;
}

export fn gnmDrawCmdSetBlendControl(
    cmd: *CommandBuffer,
    rt_index: u32,
    maybe_ctrl: ?*const BlendControl,
) callconv(.c) void {
    const cast_index = math.cast(u3, rt_index) orelse {
        writeDebugMsg(.err, "setBlendControl's render target index value {} is too large!", .{
            rt_index,
        });
        return;
    };
    const ctrl = maybe_ctrl orelse {
        writeDebugMsg(.err, "setBlendControl's control cannot be NULL!", .{});
        return;
    };
    const reg = ctrl.toRegister() orelse {
        writeDebugMsg(.err, "setBlendControl's control has invalid values!", .{});
        return;
    };

    var dcb = toDcb(cmd);
    dcb.setBlendControl(cast_index, reg) catch |err| {
        writeDebugMsg(.err, "setBlendControl failed with {t}", .{err});
    };
    cmd.cur_dword = dcb.writer.current_dword;
}

export fn gnmDrawCmdSetDepthStencilControl(
    cmd: *CommandBuffer,
    maybe_ctrl: ?*const DepthStencilControl,
) callconv(.c) void {
    const ctrl = maybe_ctrl orelse {
        writeDebugMsg(.err, "setDepthStencilControl's control cannot be NULL!", .{});
        return;
    };
    const reg = ctrl.toRegister() orelse {
        writeDebugMsg(.err, "setDepthStencilControl's control has invalid values!", .{});
        return;
    };

    var dcb = toDcb(cmd);
    dcb.setDepthStencilControl(reg) catch |err| {
        writeDebugMsg(.err, "setDepthStencilControl failed with {t}", .{err});
    };
    cmd.cur_dword = dcb.writer.current_dword;
}

export fn gnmDrawCmdSetDbRenderControl(
    cmd: *CommandBuffer,
    maybe_ctrl: ?*const DbRenderControl,
) callconv(.c) void {
    const ctrl = maybe_ctrl orelse {
        writeDebugMsg(.err, "setDbRenderControl's control cannot be NULL!", .{});
        return;
    };
    const reg = ctrl.toRegister() orelse {
        writeDebugMsg(.err, "setDbRenderControl's control has invalid values!", .{});
        return;
    };

    var dcb = toDcb(cmd);
    dcb.setDbRenderControl(reg) catch |err| {
        writeDebugMsg(.err, "setDbRenderControl failed with {t}", .{err});
    };
    cmd.cur_dword = dcb.writer.current_dword;
}

export fn gnmDrawCmdSetPrimitiveSetup(
    cmd: *CommandBuffer,
    maybe_ctrl: ?*const PrimitiveSetup,
) callconv(.c) void {
    const ctrl = maybe_ctrl orelse {
        writeDebugMsg(.err, "setPrimitiveSetup's control cannot be NULL!", .{});
        return;
    };
    const reg = ctrl.toRegister() orelse {
        writeDebugMsg(.err, "setPrimitiveSetup's control has invalid values!", .{});
        return;
    };

    var dcb = toDcb(cmd);
    dcb.setPrimitiveSetup(reg) catch |err| {
        writeDebugMsg(.err, "setPrimitiveSetup failed with {t}", .{err});
    };
    cmd.cur_dword = dcb.writer.current_dword;
}

export fn gnmDrawCmdSetViewportTransformControl(
    cmd: *CommandBuffer,
    maybe_ctrl: ?*const ViewportTransformControl,
) callconv(.c) void {
    const ctrl = maybe_ctrl orelse {
        writeDebugMsg(.err, "setViewportTransformControl's control cannot be NULL!", .{});
        return;
    };
    const reg = ctrl.toRegister();

    var dcb = toDcb(cmd);
    dcb.setViewportTransformControl(reg) catch |err| {
        writeDebugMsg(.err, "setViewportTransformControl failed with {t}", .{err});
    };
    cmd.cur_dword = dcb.writer.current_dword;
}

export fn gnmDrawCmdEventWriteEop(
    cmd: *CommandBuffer,
    event: c_int,
    gpu_address: ?*anyopaque,
    data_sel: c_int,
    imm_value: u64,
) callconv(.c) void {
    const cast_event = toEventType(event) orelse {
        writeDebugMsg(.err, "eventWriteEop's event value {} is invalid!", .{
            event,
        });
        return;
    };
    const cast_sel = toEventDataSel(data_sel) orelse {
        writeDebugMsg(.err, "eventWriteEop's data selection value {} is invalid!", .{
            data_sel,
        });
        return;
    };
    const address = gpu_address orelse {
        writeDebugMsg(.err, "eventWriteEop's GPU address can't be NULL!", .{});
        return;
    };

    var dcb = toDcb(cmd);
    dcb.eventWriteEop(cast_event, cast_sel, address, imm_value, .{}) catch |err| {
        writeDebugMsg(.err, "eventWriteEop failed with {t}", .{err});
    };
    cmd.cur_dword = dcb.writer.current_dword;
}

export fn gnmDrawCmdWaitGraphicsWrite(
    cmd: *CommandBuffer,
    targets: c_int,
) callconv(.c) void {
    const cast_targets: c_uint = @bitCast(targets);

    var dcb = toDcb(cmd);
    dcb.waitGraphicsWrites(@fromBackingInt(cast_targets)) catch |err| {
        writeDebugMsg(.err, "waitGraphicsWrites failed with {t}", .{err});
    };
    cmd.cur_dword = dcb.writer.current_dword;
}

export fn gnmDrawCmdWaitOnAddress(
    cmd: *CommandBuffer,
    compare_function: c_int,
    gpu_address: ?*anyopaque,
    reference_value: u32,
    mask: u32,
) callconv(.c) void {
    const cast_func = toWaitOperation(compare_function) orelse {
        writeDebugMsg(.err, "waitOnAddress's compare function value {} is invalid!", .{
            compare_function,
        });
        return;
    };
    const address = gpu_address orelse {
        writeDebugMsg(.err, "waitOnAddress's GPU address can't be NULL!", .{});
        return;
    };

    var dcb = toDcb(cmd);
    dcb.waitOnAddress(cast_func, address, mask, reference_value) catch |err| {
        writeDebugMsg(.err, "waitOnAddress failed with {t}", .{err});
    };
    cmd.cur_dword = dcb.writer.current_dword;
}

export fn gnmDrawCmdWaitUntilSafeForRendering(
    cmd: *CommandBuffer,
    video_handle: i32,
    display_buffer_index: i32,
) callconv(.c) void {
    var dcb = toDcb(cmd);
    dcb.waitFlipDone(video_handle, display_buffer_index) catch |err| {
        writeDebugMsg(.err, "waitUntilSafeForRendering failed with {t}", .{err});
    };
    cmd.cur_dword = dcb.writer.current_dword;
}

//
// conversion utilities
//
pub fn toWriter(cmd: *CommandBuffer) pm4.Writer {
    return .{
        .backing_memory = cmd.buffer[0..cmd.num_dwords],
        .current_dword = cmd.cur_dword,
    };
}

pub fn toDcb(cmd: *CommandBuffer) gnm.DrawCommandBuffer {
    return .{
        .writer = toWriter(cmd),
        .flags = .{
            .predication_enabled = cmd.flags.enable_predication,
        },
    };
}

pub fn toBlendOp(value: c_int) ?gnm.BlendOp {
    return switch (value) {
        else => null,
        0 => .zero,
        1 => .one,
        2 => .src_color,
        3 => .one_minus_src_color,
        4 => .src_alpha,
        5 => .one_minus_src_alpha,
        6 => .dest_alpha,
        7 => .one_minus_dest_alpha,
        8 => .dest_color,
        9 => .one_minus_dest_color,
        10 => .src_alpha_saturate,
        13 => .constant_color,
        14 => .one_minus_constant_color,
        15 => .src1_color,
        16 => .inverse_src1_color,
        17 => .src1_alpha,
        18 => .inverse_src1_alpha,
        19 => .constant_alpha,
        20 => .one_minus_constant_alpha,
    };
}

pub fn toCachePolicy(value: c_int) ?gnm.CachePolicy {
    return switch (value) {
        else => null,
        0 => .lru,
        1 => .stream,
        2 => .bypass,
    };
}

pub fn toCombFunc(value: c_int) ?gnm.CombFunc {
    return switch (value) {
        else => null,
        0 => .dst_plus_src,
        1 => .src_minus_dst,
        2 => .min_dst_src,
        3 => .max_dst_src,
        4 => .dst_minus_src,
    };
}

pub fn toDepthCompare(value: c_int) ?gnm.DepthCompare {
    return switch (value) {
        else => null,
        0 => .never,
        1 => .less,
        2 => .equal,
        3 => .less_equal,
        4 => .greater,
        5 => .not_equal,
        6 => .greater_equal,
        7 => .always,
    };
}

pub fn toEmbeddedPixelShader(value: c_int) ?gnm.EmbeddedShaderPixel {
    return switch (value) {
        else => null,
        0 => .null,
        1 => .null_rg32,
    };
}

pub fn toEmbeddedVertexShader(value: c_int) ?gnm.EmbeddedShaderVertex {
    return switch (value) {
        else => null,
        0 => .fullscreen,
    };
}

pub fn toEventDataSel(value: c_int) ?gnm.EventDataSel {
    return switch (value) {
        else => null,
        0 => .discard,
        1 => .send_data_32,
        2 => .send_data_64,
        3 => .send_sys_clock,
        4 => .send_gpu_clock,
    };
}

pub fn toEventType(value: c_int) ?gnm.VgtEventType {
    return switch (value) {
        else => null,
        0x4 => .cache_flush_ts,
        0x14 => .cache_flush_and_inv_ts_event,
        0x28 => .bottom_of_pipe_ts,
        0x2d => .flush_and_inv_cb_data_ts,
        0x2f => .cs_done,
        0x30 => .ps_done,
    };
}

pub fn toFaceOrientation(value: c_int) ?gnm.FaceOrientation {
    return switch (value) {
        else => null,
        0 => .ccw,
        1 => .cw,
    };
}

pub fn toFillMode(value: c_int) ?gnm.FillMode {
    return switch (value) {
        else => null,
        0 => .points,
        1 => .lines,
        2 => .triangles,
    };
}

pub fn toGpuMode(value: c_int) ?gnm.GpuMode {
    return switch (value) {
        else => null,
        0 => .base,
        1 => .neo,
    };
}

pub fn toIndexSize(value: c_int) ?gnm.IndexSize {
    return switch (value) {
        else => null,
        0 => .@"16",
        1 => .@"32",
        2 => .@"8",
    };
}

pub fn toPrimitiveType(value: c_int) ?gnm.PrimitiveType {
    return switch (value) {
        else => null,
        0 => .none,
        1 => .point_list,
        2 => .line_list,
        3 => .line_strip,
        4 => .tri_list,
        5 => .tri_fan,
        6 => .tri_strip,
        9 => .patch,
        10 => .line_list_adj,
        11 => .line_strip_adj,
        12 => .tri_list_adj,
        13 => .tri_strip_adj,
        16 => .tri_with_wflags,
        17 => .rect_list,
        18 => .line_loop,
        19 => .quad_list,
        20 => .quad_strip,
        21 => .polygon,
    };
}

pub fn toShaderStage(value: c_int) ?gnm.ShaderStage {
    return switch (value) {
        else => null,
        0 => .cs,
        1 => .ps,
        2 => .vs,
        3 => .gs,
        4 => .es,
        5 => .hs,
        6 => .ls,
    };
}

pub fn toWaitOperation(value: c_int) ?gnm.WaitOperation {
    return switch (value) {
        else => null,
        0 => .always,
        1 => .less,
        2 => .less_equal,
        3 => .equal,
        4 => .not_equal,
        5 => .greater_equal,
        6 => .greater,
    };
}

//
// C structures,
// must be kept in sync with C headers
//
pub const CommandBuffer = extern struct {
    buffer: [*]u32,
    num_dwords: u32,
    cur_dword: u32,
    callback: CommandCallback,
    flags: Flags,

    pub const Flags = extern struct {
        enable_predication: bool,
        shader_type: u8,
        gpu_mode: c_int,
    };
};

pub const CallbackFunc = *const fn (cb: *CommandBuffer, sizedwords: u32, userdata: ?*anyopaque) callconv(.c) bool;
pub const CommandCallback = extern struct {
    func: ?CallbackFunc = null,
    userdata: ?*anyopaque = null,
};

pub const MessageSeverity = enum(c_uint) {
    warn = 0,
    err = 1,
};
pub const MessageHandlerFunc = *const fn (
    severity: MessageSeverity,
    message: [*:0]const u8,
    user_data: ?*anyopaque,
) callconv(.c) void;

// DrawCommandBuffer types
pub const BlendControl = extern struct {
    blend_enabled: bool,
    color_func: c_int, // GnmCombFunc
    color_src_mult: c_int, // GnmBlendOp
    color_dst_mult: c_int, // GnmBlendOp
    alpha_func: c_int, // GnmCombFunc
    alpha_src_mult: c_int, // GnmBlendOp
    alpha_dst_mult: c_int, // GnmBlendOp
    separate_alpha_enable: bool,

    pub fn toRegister(self: BlendControl) ?gnm.CbBlendControl {
        return .{
            .color_src_blend = toBlendOp(self.color_src_mult) orelse return null,
            .color_comb_fcn = toCombFunc(self.color_func) orelse return null,
            .color_dest_blend = toBlendOp(self.color_dst_mult) orelse return null,
            .alpha_src_blend = toBlendOp(self.alpha_src_mult) orelse return null,
            .alpha_comb_fcn = toCombFunc(self.alpha_func) orelse return null,
            .alpha_dest_blend = toBlendOp(self.alpha_dst_mult) orelse return null,
            .separate_alpha_blend = self.separate_alpha_enable,
            .enable = self.blend_enabled,
            .disable_rop_3 = false,
        };
    }
};

pub const DbRenderControl = extern struct {
    depth_clear_enable: bool,
    stencil_clear_enable: bool,
    htile_resummarize_enable: bool,
    depth_write_back_pol: bool,
    stencil_write_back_pol: bool,
    force_depth_decompress: bool,
    copy_centroid_enable: bool,
    copy_sample_index: u8,
    copy_depth_to_color_enable: bool,
    copy_stencil_to_color_enable: bool,

    pub fn toRegister(self: DbRenderControl) ?gnm.DbRenderControl {
        return .{
            .depth_clear_enable = self.depth_clear_enable,
            .stencil_clear_enable = self.stencil_clear_enable,
            .resummarize_enable = self.htile_resummarize_enable,
            .depth_copy = false,
            .stencil_copy = false,
            .stencil_compress_disable = self.stencil_write_back_pol,
            .depth_compress_disable = self.depth_write_back_pol,
            .copy_centroid = self.copy_centroid_enable,
            .copy_sample = math.cast(u4, self.copy_sample_index) orelse return null,
            .decompress_enable = self.force_depth_decompress,
        };
    }
};

pub const DepthStencilControl = extern struct {
    z_write: bool,
    z_func: c_int, // GnmDepthCompare
    stencil_func: c_int, // GnmDepthCompare
    stencil_back_func: c_int, // GnmDepthCompare
    separate_stencil_enable: bool,
    depth_enable: bool,
    stencil_enable: bool,
    depth_bounds_enable: bool,

    pub fn toRegister(self: DepthStencilControl) ?gnm.DbDepthControl {
        return .{
            .stencil_enable = self.stencil_enable,
            .z_enable = self.depth_enable,
            .z_write_enable = self.z_write,
            .depth_bounds_enable = self.depth_bounds_enable,
            .z_func = toDepthCompare(self.z_func) orelse return null,
            .backface_enable = self.separate_stencil_enable,
            .stencil_func = toDepthCompare(self.stencil_func) orelse return null,
            .stencil_func_backface = toDepthCompare(self.stencil_back_func) orelse return null,
            .enable_color_writes_on_depth_fail = false,
            .disable_color_writes_on_depth_pass = false,
        };
    }
};

pub const PrimitiveSetup = extern struct {
    cull_front: bool,
    cull_back: bool,
    front_face: c_int, // GnmFaceOrientation
    front_mode: c_int, // GnmFillMode
    back_mode: c_int, // GnmFillMode
    front_offset_mode: bool,
    back_offset_mode: bool,
    vertex_window_offset_enable: bool,
    provoking_vtx_last: bool,
    perspective_correction_disable: bool,

    pub fn toRegister(self: PrimitiveSetup) ?gnm.PaSuScModeCntl {
        const front_mode = toFillMode(self.front_mode) orelse return null;
        const back_mode = toFillMode(self.back_mode) orelse return null;
        return .{
            .cull_front = self.cull_front,
            .cull_back = self.cull_back,
            .face = toFaceOrientation(self.front_face) orelse return null,
            .poly_mode = if (front_mode != .triangles or back_mode != .triangles)
                .dual_mode
            else
                .disable,
            .polymode_front_ptype = front_mode,
            .polymode_back_ptype = back_mode,
            .poly_offset_front_enable = self.front_offset_mode,
            .poly_offset_back_enable = self.back_offset_mode,
            .vtx_window_offset_enable = self.vertex_window_offset_enable,
            .provoking_vtx_last = self.provoking_vtx_last,
            .persp_corr_dis = self.perspective_correction_disable,
        };
    }
};

pub const ViewportTransformControl = extern struct {
    scale_x: bool,
    offset_x: bool,
    scale_y: bool,
    offset_y: bool,
    scale_z: bool,
    offset_z: bool,
    perspective_divide_xy: bool,
    perspective_divide_z: bool,
    invert_w: bool,

    pub fn toRegister(self: ViewportTransformControl) gnm.PaClVteCntl {
        return .{
            .vport_x_scale_ena = self.scale_x,
            .vport_x_offset_ena = self.offset_x,
            .vport_y_scale_ena = self.scale_y,
            .vport_y_offset_ena = self.offset_y,
            .vport_z_scale_ena = self.scale_z,
            .vport_z_offset_ena = self.offset_z,
            .vtx_xy_fmt = self.perspective_divide_xy,
            .vtx_z_fmt = self.perspective_divide_z,
            .vtx_w0_fmt = self.invert_w,
        };
    }
};

pub const DrawModifier = extern struct {
    render_target_slice_offset: u32,

    pub const empty: DrawModifier = .{
        .render_target_slice_offset = 0,
    };
};

pub const SetViewportInfo = extern struct {
    d_min: f32,
    d_max: f32,
    scale: [3]f32,
    offset: [3]f32,
};
