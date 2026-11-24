const std = @import("std");
const log = std.log;
const mem = std.mem;

const gnm = @import("gnm.zig");

pub const SurfaceDescription = struct {
    tile_mode: gnm.TileMode,
    image_format: gnm.ImageFormat,
    min_gpu_mode: gnm.GpuMode,

    linear_width: u32,
    linear_height: u32,
    linear_depth: u32,
    base_tiled_pitch: u32,

    num_fragments_per_pixel: u32,
    bits_per_fragment: u32,

    mip_level: u32,
    array_slice: u32,

    flags: packed struct(u32) {
        color_target: bool = false,
        depth_target: bool = false,
        stencil_target: bool = false,
        texture: bool = false,
        cube: bool = false,
        cube_as_array: bool = false,
        volume: bool = false,
        fmask: bool = false,
        overlay: bool = false,
        display: bool = false,
        prt: bool = false,
        power_of_2_pad: bool = false,
        tc_compatible: bool = false,
        _: u19 = 0,
    },
};

pub const TileInfo = extern struct {
    array_mode: c_uint,
    num_banks: c_uint,
    bank_width: c_uint,
    bank_height: c_uint,
    macro_tile_aspect: c_uint,
    tile_split: c_uint,
    pipe_config: c_uint,
};

pub const SurfaceType = enum(c_int) {
    color_display,
    color,
    depth_stencil,
    depth,
    stencil,
    fmask,
    texture_flat,
    texture_volume,
    texture_cubemap,
    rw_texture_flat,
    rw_texture_volume,
    rw_texture_cubemap,
};

pub const SurfaceInfo = extern struct {
    pitch: u32,
    height: u32,
    depth: u32,
    surface_byte_size: u64,

    base_alignment: u32,
    pitch_alignment: u32,
    height_alignment: u32,
    depth_alignment: u32,

    bits_per_element: u32,
    block_width: u32,
    block_height: u32,

    tile_mode: c_uint, // FIXME // gnm.TileMode
    tile_info: TileInfo,

    flags: packed struct(u32) {
        tc_compatible: bool,
        _: u31,
    },
};

pub const SurfaceProperties = struct {
    tile_mode: gnm.TileMode,
    flags: packed struct(u32) {
        color_target: bool,
        depth_target: bool,
        stencil_target: bool,
        texture: bool,
        cube: bool,
        volume: bool,
        fmask: bool,
        cube_as_array: bool,
        overlay: bool,
        display: bool,
        prt: bool,
        pow_to_pad: bool,
        tex_compatible: bool,
        _: u19,
    },
};

pub const TextureInfo = extern struct {
    // type: gnm.TextureType, // FIXME
    type: c_int,
    format: gnm.DataFormat,

    width: u32,
    height: u32,
    pitch: u32,
    depth: u32,

    num_fragments: u32,
    num_mips: u32,
    num_slices: u32,

    tile_mode: c_uint, // gnm.TileMode, // FIXME
    min_gpu_mode: c_uint, // gnm.GpuMode, // FIXME

    power_of_2_pad: bool,
};

pub const Error = error{
    SomeError,
};

extern fn gpaStrError(err: c_int) callconv(.c) [*c]const u8;

const SurfaceDescriptionInternal = extern struct {
    tile_mode: c_uint, // gnm.TileMode, // FIXME
    image_format: c_uint, // gnm.ImageFormat // FIXME
    min_gpu_mode: c_uint, // gnm.GpuMode, // FIXME

    linear_width: u32,
    linear_height: u32,
    linear_depth: u32,
    base_tiled_pitch: u32,

    num_fragments_per_pixel: u32,
    bits_per_fragment: u32,

    mip_level: u32,
    array_slice: u32,
    flags: u32,
};

extern fn gpaComputeSurfaceInfo(out: *SurfaceInfo, tp: *const SurfaceDescriptionInternal) callconv(.c) c_int;
pub fn computeSurfaceInfo(desc: SurfaceDescription) Error!SurfaceInfo {
    var info: SurfaceInfo = undefined;

    const tp: SurfaceDescriptionInternal = .{
        .tile_mode = @backingInt(desc.tile_mode),
        .image_format = @backingInt(desc.image_format),
        .min_gpu_mode = @backingInt(desc.min_gpu_mode),

        .linear_width = desc.linear_width,
        .linear_height = desc.linear_height,
        .linear_depth = desc.linear_depth,
        .base_tiled_pitch = desc.base_tiled_pitch,

        .num_fragments_per_pixel = desc.num_fragments_per_pixel,
        .bits_per_fragment = desc.bits_per_fragment,

        .mip_level = desc.mip_level,
        .array_slice = desc.array_slice,
        .flags = @backingInt(desc.flags),
    };

    const result = gpaComputeSurfaceInfo(&info, &tp);
    if (result != 0) {
        log.err("gpaComputeSurfaceInfo failed with {s}", .{gpaStrError(result)});
        return error.SomeError;
    }
    return info;
}

pub fn findOptimalSurface(args: struct {
    surface_type: SurfaceType,
    bits_per_pixel: u32,
    num_fragments: u32,
    is_mip_mapped: bool,
    min_gpu_mode: gnm.GpuMode,
}) Error!SurfaceProperties {
    var props: SurfacePropertiesInt = undefined;
    const result = gpaFindOptimalSurface(
        &props,
        args.surface_type,
        args.bits_per_pixel,
        args.num_fragments,
        args.is_mip_mapped,
        @backingInt(args.min_gpu_mode),
    );
    if (result != 0) {
        log.err("gpaTileTextureAll failed with {s}", .{gpaStrError(result)});
        return error.SomeError;
    }
    return .{
        .tile_mode = @fromBackingInt(@as(u5, @intCast(@as(c_uint, @intCast(props.tile_mode))))), // yuck
        .flags = @fromBackingInt(props.flags),
    };
}

extern fn gpaFindOptimalSurface(
    outprops: *SurfacePropertiesInt,
    surfacetype: SurfaceType,
    bpp: u32,
    numfrags: u32,
    mipmapped: bool,
    mingpumode: c_int,
) callconv(.c) c_int;

const SurfacePropertiesInt = extern struct {
    tile_mode: c_uint, // FIXME: gnm.TileMode
    flags: u32,
};

extern fn gpaTileTextureAll(
    inbuf: *const anyopaque,
    inlen: usize,
    outbuf: *anyopaque,
    outlen: usize,
    texinfo: *const TextureInfo,
    newtiling: c_int,
) callconv(.c) c_int;
pub fn tileTextureAll(
    input: []const u8,
    output: []u8,
    tex_info: TextureInfo,
    new_tile_mode: gnm.TileMode,
) Error!void {
    const result = gpaTileTextureAll(
        input.ptr,
        input.len,
        output.ptr,
        output.len,
        &tex_info,
        @backingInt(new_tile_mode),
    );
    if (result != 0) {
        log.err("gpaTileTextureAll failed with {s}", .{gpaStrError(result)});
        return error.SomeError;
    }
}

const testing = std.testing;

test "find ideal surface" {
    const surf_props = try findOptimalSurface(.{
        .surface_type = .color,
        .bits_per_pixel = 32,
        .num_fragments = 1,
        .is_mip_mapped = false,
        .min_gpu_mode = .base,
    });

    try testing.expectEqual(gnm.TileMode.thin_2d_thin, surf_props.tile_mode);
}

test "computing surface info" {
    {
        const surf_info = try computeSurfaceInfo(.{
            .tile_mode = .thin_2d_thin,
            .image_format = .bc7,
            .min_gpu_mode = .base,

            .linear_width = 32,
            .linear_height = 32,
            .linear_depth = 1,
            .base_tiled_pitch = 8,

            .num_fragments_per_pixel = 1,
            .bits_per_fragment = 8,

            .mip_level = 0,
            .array_slice = 0,
            .flags = .{},
        });

        try testing.expectEqual(256, surf_info.pitch);
        try testing.expectEqual(128, surf_info.height);
        try testing.expectEqual(1, surf_info.depth);
        try testing.expectEqual(32768, surf_info.surface_byte_size);
        try testing.expectEqual(32768, surf_info.base_alignment);
        try testing.expectEqual(256, surf_info.pitch_alignment);
        try testing.expectEqual(128, surf_info.height_alignment);
        try testing.expectEqual(1, surf_info.depth_alignment);
        try testing.expectEqual(8, surf_info.bits_per_element);
        try testing.expectEqual(256, surf_info.block_width);
        try testing.expectEqual(128, surf_info.block_height);
    }
    {
        const surf_info = try computeSurfaceInfo(.{
            .tile_mode = .thin_1d_thin,
            .image_format = .@"16_16_16_16",
            .min_gpu_mode = .base,

            .linear_width = 128,
            .linear_height = 64,
            .linear_depth = 1,
            .base_tiled_pitch = 8,

            .num_fragments_per_pixel = 1,
            .bits_per_fragment = 64,

            .mip_level = 0,
            .array_slice = 0,
            .flags = .{},
        });

        try testing.expectEqual(128, surf_info.pitch);
        try testing.expectEqual(64, surf_info.height);
        try testing.expectEqual(1, surf_info.depth);
        try testing.expectEqual(65536, surf_info.surface_byte_size);
        try testing.expectEqual(256, surf_info.base_alignment);
        try testing.expectEqual(8, surf_info.pitch_alignment);
        try testing.expectEqual(8, surf_info.height_alignment);
        try testing.expectEqual(1, surf_info.depth_alignment);
        try testing.expectEqual(64, surf_info.bits_per_element);
        try testing.expectEqual(8, surf_info.block_width);
        try testing.expectEqual(8, surf_info.block_height);
    }
    {
        const surf_info = try computeSurfaceInfo(.{
            .tile_mode = .display_linear_aligned,
            .image_format = .@"8_8_8_8",
            .min_gpu_mode = .base,

            .linear_width = 512,
            .linear_height = 1024,
            .linear_depth = 1,
            .base_tiled_pitch = 4,

            .num_fragments_per_pixel = 1,
            .bits_per_fragment = 32,

            .mip_level = 0,
            .array_slice = 0,
            .flags = .{},
        });

        try testing.expectEqual(512, surf_info.pitch);
        try testing.expectEqual(1024, surf_info.height);
        try testing.expectEqual(1, surf_info.depth);
        try testing.expectEqual(2097152, surf_info.surface_byte_size);
        try testing.expectEqual(256, surf_info.base_alignment);
        try testing.expectEqual(16, surf_info.pitch_alignment);
        try testing.expectEqual(1, surf_info.height_alignment);
        try testing.expectEqual(1, surf_info.depth_alignment);
        try testing.expectEqual(32, surf_info.bits_per_element);
        try testing.expectEqual(1, surf_info.block_width);
        try testing.expectEqual(1, surf_info.block_height);
    }
}
