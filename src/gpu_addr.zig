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

pub const SurfaceInfo = struct {
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

    tile_mode: gnm.TileMode,
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

pub const Error = error{
    SomeError,
};

extern fn gpaStrError(err: c_int) callconv(.c) [*c]const u8;

const SurfaceDescriptionInternal = extern struct {
    tile_mode: c_uint,
    image_format: c_uint,
    min_gpu_mode: c_uint,

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

pub fn computeSurfaceInfo(desc: SurfaceDescription) Error!SurfaceInfo {
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

    var info: SurfaceInfoInternal = undefined;
    const result = gpaComputeSurfaceInfo(&info, &tp);
    if (result != 0) {
        log.err("gpaComputeSurfaceInfo failed with {s}", .{gpaStrError(result)});
        return error.SomeError;
    }

    return .{
        .pitch = info.pitch,
        .height = info.height,
        .depth = info.depth,
        .surface_byte_size = info.surface_byte_size,

        .base_alignment = info.base_alignment,
        .pitch_alignment = info.pitch_alignment,
        .height_alignment = info.height_alignment,
        .depth_alignment = info.depth_alignment,

        .bits_per_element = info.bits_per_element,
        .block_width = info.block_width,
        .block_height = info.block_height,

        .tile_mode = @fromBackingInt(@intCast(info.tile_mode)),
        .tile_info = info.tile_info,

        .flags = @fromBackingInt(@backingInt(info.flags)),
    };
}
extern fn gpaComputeSurfaceInfo(out: *SurfaceInfoInternal, tp: *const SurfaceDescriptionInternal) callconv(.c) c_int;

const SurfaceInfoInternal = extern struct {
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

    tile_mode: c_uint,
    tile_info: TileInfo,

    flags: packed struct(u32) {
        tc_compatible: bool,
        _: u31,
    },
};

pub fn findOptimalSurface(args: struct {
    surface_type: SurfaceType,
    bits_per_pixel: u32,
    num_fragments: u32,
    is_mip_mapped: bool,
    min_gpu_mode: gnm.GpuMode,
}) Error!SurfaceProperties {
    var props: SurfacePropertiesInternal = undefined;
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
    outprops: *SurfacePropertiesInternal,
    surfacetype: SurfaceType,
    bpp: u32,
    numfrags: u32,
    mipmapped: bool,
    mingpumode: c_int,
) callconv(.c) c_int;

const SurfacePropertiesInternal = extern struct {
    tile_mode: c_uint,
    flags: u32,
};

pub const TextureInfo = struct {
    type: gnm.TextureType,
    tile_mode: gnm.TileMode,
    format: gnm.DataFormat,
    min_gpu_mode: gnm.GpuMode,

    width: u32,
    height: u32,
    depth: u32,
    pitch: u32,

    num_fragments: u32,
    num_mips: u32,
    num_slices: u32,

    power_of_2_pad: bool,
};

pub fn tileTextureAll(
    input: []const u8,
    output: []u8,
    tex_info: TextureInfo,
    new_tile_mode: gnm.TileMode,
) Error!void {
    const int_info: TextureInfoInternal = .{
        .type = @backingInt(tex_info.type),
        .format = tex_info.format,

        .width = tex_info.width,
        .height = tex_info.height,
        .pitch = tex_info.pitch,
        .depth = tex_info.depth,

        .num_fragments = tex_info.num_fragments,
        .num_mips = tex_info.num_mips,
        .num_slices = tex_info.num_slices,

        .tile_mode = @backingInt(tex_info.tile_mode),
        .min_gpu_mode = @backingInt(tex_info.min_gpu_mode),

        .power_of_2_pad = tex_info.power_of_2_pad,
    };

    const result = gpaTileTextureAll(
        input.ptr,
        input.len,
        output.ptr,
        output.len,
        &int_info,
        @backingInt(new_tile_mode),
    );
    if (result != 0) {
        log.err("gpaTileTextureAll failed with {s}", .{gpaStrError(result)});
        return error.SomeError;
    }
}

extern fn gpaTileTextureAll(
    inbuf: *const anyopaque,
    inlen: usize,
    outbuf: *anyopaque,
    outlen: usize,
    texinfo: *const TextureInfoInternal,
    newtiling: c_uint,
) callconv(.c) c_int;

const TextureInfoInternal = extern struct {
    type: c_uint,
    format: gnm.DataFormat,

    width: u32,
    height: u32,
    pitch: u32,
    depth: u32,

    num_fragments: u32,
    num_mips: u32,
    num_slices: u32,

    tile_mode: c_uint,
    min_gpu_mode: c_uint,

    power_of_2_pad: bool,
};

pub fn tileSurface(
    input: []const u8,
    output: []u8,
    surf_desc: SurfaceDescription,
    desired_tile_mode: gnm.TileMode,
) Error!void {
    const src_desc: SurfaceDescriptionInternal = .{
        .tile_mode = @backingInt(surf_desc.tile_mode),
        .image_format = @backingInt(surf_desc.image_format),
        .min_gpu_mode = @backingInt(surf_desc.min_gpu_mode),

        .linear_width = surf_desc.linear_width,
        .linear_height = surf_desc.linear_height,
        .linear_depth = surf_desc.linear_depth,
        .base_tiled_pitch = surf_desc.base_tiled_pitch,

        .num_fragments_per_pixel = surf_desc.num_fragments_per_pixel,
        .bits_per_fragment = surf_desc.bits_per_fragment,

        .mip_level = surf_desc.mip_level,
        .array_slice = surf_desc.array_slice,
        .flags = @backingInt(surf_desc.flags),
    };
    const dst_desc: SurfaceDescriptionInternal = .{
        .tile_mode = @backingInt(desired_tile_mode),
        .image_format = @backingInt(surf_desc.image_format),
        .min_gpu_mode = @backingInt(surf_desc.min_gpu_mode),

        .linear_width = surf_desc.linear_width,
        .linear_height = surf_desc.linear_height,
        .linear_depth = surf_desc.linear_depth,
        .base_tiled_pitch = surf_desc.base_tiled_pitch,

        .num_fragments_per_pixel = surf_desc.num_fragments_per_pixel,
        .bits_per_fragment = surf_desc.bits_per_fragment,

        .mip_level = surf_desc.mip_level,
        .array_slice = surf_desc.array_slice,
        .flags = @backingInt(surf_desc.flags),
    };

    const result = gpaTileSurface(
        output.ptr,
        output.len,
        input.ptr,
        input.len,
        &src_desc,
        &dst_desc,
    );
    if (result != 0) {
        log.err("gpaTileSurface failed with {s}", .{gpaStrError(result)});
        return error.SomeError;
    }
}

extern fn gpaTileSurface(
    out_buf: [*]u8,
    out_len: usize,
    in_buf: [*]const u8,
    in_len: usize,
    src_desc: *const SurfaceDescriptionInternal,
    dst_desc: *const SurfaceDescriptionInternal,
) callconv(.c) c_int;

const testing = std.testing;
const test_data = @import("test_data");

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

test "surface tiling" {
    const alloc = testing.allocator;
    {
        //
        // linear_general to 1d_thin
        //
        const input_detiled = test_data.surf_2d_8888_32x32_linear_general;
        const expected_out = test_data.surf_2d_8888_32x32_thin_1d_thin;

        const out_data = try alloc.alloc(u8, input_detiled.len);
        defer alloc.free(out_data);

        try tileSurface(input_detiled, out_data, .{
            .tile_mode = .display_linear_general,
            .image_format = .@"8_8_8_8",
            .min_gpu_mode = .base,

            .linear_width = 32,
            .linear_height = 32,
            .linear_depth = 1,
            .base_tiled_pitch = 32,

            .num_fragments_per_pixel = 1,
            .bits_per_fragment = 32,

            .mip_level = 0,
            .array_slice = 0,
            .flags = .{},
        }, .thin_1d_thin);

        try testing.expectEqualSlices(u8, expected_out, out_data);
    }
    {
        //
        // 1d_thin to linear_general
        //
        const input_detiled = test_data.surf_2d_8888_32x32_thin_1d_thin;
        const expected_out = test_data.surf_2d_8888_32x32_linear_general;

        const out_data = try alloc.alloc(u8, input_detiled.len);
        defer alloc.free(out_data);

        try tileSurface(input_detiled, out_data, .{
            .tile_mode = .thin_1d_thin,
            .image_format = .@"8_8_8_8",
            .min_gpu_mode = .base,

            .linear_width = 32,
            .linear_height = 32,
            .linear_depth = 1,
            .base_tiled_pitch = 32,

            .num_fragments_per_pixel = 1,
            .bits_per_fragment = 32,

            .mip_level = 0,
            .array_slice = 0,
            .flags = .{},
        }, .display_linear_general);

        try testing.expectEqualSlices(u8, expected_out, out_data);
    }
}

test "texture tiling" {
    const alloc = testing.allocator;
    {
        //
        // linear_general to 1d_thin
        //
        const input_detiled = test_data.surf_2d_8888_32x32_linear_general;
        const expected_out = test_data.surf_2d_8888_32x32_thin_1d_thin;

        const out_data = try alloc.alloc(u8, input_detiled.len);
        defer alloc.free(out_data);

        try tileTextureAll(input_detiled, out_data, .{
            .type = .@"2d",
            .tile_mode = .display_linear_general,
            .format = .r8g8b8a8_unorm,
            .min_gpu_mode = .base,

            .width = 32,
            .height = 32,
            .depth = 1,
            .pitch = 32,

            .num_fragments = 1,
            .num_mips = 1,
            .num_slices = 1,
            .power_of_2_pad = false,
        }, .thin_1d_thin);

        try testing.expectEqualSlices(u8, expected_out, out_data);
    }
    {
        //
        // 1d_thin to linear_general
        //
        const input_detiled = test_data.surf_2d_8888_32x32_thin_1d_thin;
        const expected_out = test_data.surf_2d_8888_32x32_linear_general;

        const out_data = try alloc.alloc(u8, input_detiled.len);
        defer alloc.free(out_data);

        try tileTextureAll(input_detiled, out_data, .{
            .type = .@"2d",
            .tile_mode = .thin_1d_thin,
            .format = .r8g8b8a8_unorm,
            .min_gpu_mode = .base,

            .width = 32,
            .height = 32,
            .depth = 1,
            .pitch = 32,

            .num_fragments = 1,
            .num_mips = 1,
            .num_slices = 1,
            .power_of_2_pad = false,
        }, .display_linear_general);

        try testing.expectEqualSlices(u8, expected_out, out_data);
    }
}
