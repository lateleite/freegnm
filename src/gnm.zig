const std = @import("std");
const math = std.math;
const mem = std.mem;
const assert = std.debug.assert;

pub const DrawCommandBuffer = @import("gnm/DrawCommandBuffer.zig");
pub const gcn = @import("gcn.zig");
pub const gpu_addr = @import("gpu_addr.zig");
pub const pm4 = @import("pm4.zig");
pub const psb = @import("psb.zig");

/// Maximum count of DWORDs (u32) that a command buffer may have
pub const MAX_COMMAND_DWORDS = 0xfffff; // referenced in PKT3_INDIRECT_BUFFER

pub const NUM_WAVEFRONT_THREADS = 64;

pub const ALIGNMENT_BUFFER_BYTES = 4;
pub const ALIGNMENT_SHADER_BYTES = 256;

pub const MAX_USERDATA_SSHARP_SLOTS = 12;
pub const MAX_USERDATA_TSHARP_SLOTS = 8;
pub const MAX_USERDATA_VSHARP_SLOTS = 12;
pub const MAX_USERDATA_POINTER_SLOTS = 14;

pub const GpuMode = enum(u1) {
    base = 0,
    neo = 1,
};

pub const EventDataSel = enum(u3) {
    discard = 0,
    send_data_32 = 1,
    send_data_64 = 2,
    send_sys_clock = 3,
    send_gpu_clock = 4,
};

pub const EventIntSel = enum(u2) {
    none = 0,
    send_int = 1,
    send_int_on_confirm = 2,
    send_data_on_confirm = 3,
};

pub const CachePolicy = enum(u2) {
    lru = 0,
    stream = 1,
    bypass = 2,
};

pub const WaitOperation = enum(u3) {
    always = 0,
    less = 1,
    less_equal = 2,
    equal = 3,
    not_equal = 4,
    greater_equal = 5,
    greater = 6,
};

pub const Engine = enum(u2) {
    me = 0,
    pfp = 1,
    ce = 2,
};

pub const WaitGraphicsTargetMask = packed struct(u32) {
    cb0_dest_base_ena: bool = false,
    cb1_dest_base_ena: bool = false,
    cb2_dest_base_ena: bool = false,
    cb3_dest_base_ena: bool = false,
    cb4_dest_base_ena: bool = false,
    cb5_dest_base_ena: bool = false,
    cb6_dest_base_ena: bool = false,
    cb7_dest_base_ena: bool = false,
    db_dest_base_ena: bool = false,
    _: u23 = 0,
};

pub const CoherCntl = packed struct(u31) {
    dest_base_0_ena: bool = false,
    dest_base_1_ena: bool = false,
    tc_sd_action_ena: bool = false,
    tc_nc_action_ena: bool = false,
    _: u2 = 0,
    cb0_dest_base_ena: bool = false,
    cb1_dest_base_ena: bool = false,
    cb2_dest_base_ena: bool = false,
    cb3_dest_base_ena: bool = false,
    cb4_dest_base_ena: bool = false,
    cb5_dest_base_ena: bool = false,
    cb6_dest_base_ena: bool = false,
    cb7_dest_base_ena: bool = false,
    db_dest_base_ena: bool = false,
    tcl1_vol_action_ena: bool = false,
    tc_vol_action_ena: bool = false,
    _2: u1 = 0,
    tc_wb_action_ena: bool = false,
    dest_base_2_ena: bool = false,
    _3: u1 = 0,
    dest_base_3_ena: bool = false,
    tcl1_action_ena: bool = false,
    tc_action_ena: bool = false,
    _4: u1 = 0,
    cb_action_ena: bool = false,
    db_action_ena: bool = false,
    sh_kcache_action_ena: bool = false,
    sh_kcache_vol_action_ena: bool = false,
    sh_icache_action_ena: bool = false,
    sh_kcache_wb_action_ena: bool = false,
};

pub const IndexSize = enum(u2) {
    @"16" = 0,
    @"32" = 1,
    @"8" = 2,
};

pub const PrimitiveType = enum(u6) {
    none = 0,
    point_list = 1,
    line_list = 2,
    line_strip = 3,
    tri_list = 4,
    tri_fan = 5,
    tri_strip = 6,
    patch = 9,
    line_list_adj = 10,
    line_strip_adj = 11,
    tri_list_adj = 12,
    tri_strip_adj = 13,
    tri_with_wflags = 16,
    rect_list = 17,
    line_loop = 18,
    quad_list = 19,
    quad_strip = 20,
    polygon = 21,
};

pub const ShaderStage = enum(u8) {
    cs = 0,
    ps = 1,
    vs = 2,
    gs = 3,
    es = 4,
    hs = 5,
    ls = 6,
};

pub const TileMode = enum(u5) {
    depth_2d_thin_64 = 0,
    depth_2d_thin_128 = 1,
    depth_2d_thin_256 = 2,
    depth_2d_thin_512 = 3,
    depth_2d_thin_1k = 4,
    depth_1d_thin = 5,
    depth_2d_thin_prt_256 = 6,
    depth_2d_thin_prt_1k = 7,

    display_linear_aligned = 8,
    display_1d_thin = 9,
    display_2d_thin = 10,
    display_thin_prt = 11,
    display_2d_thin_prt = 12,

    thin_1d_thin = 13,
    thin_2d_thin = 14,
    thin_3d_thin = 15,
    thin_thin_prt = 16,
    thin_2d_thin_prt = 17,
    thin_3d_thin_prt = 18,

    thick_1d_thick = 19,
    thick_2d_thick = 20,
    thick_3d_thick = 21,
    thick_thick_prt = 22,
    thick_2d_thick_prt = 23,
    thick_3d_thick_prt = 24,
    thick_2d_xthick = 25,
    thick_3d_xthick = 26,

    rotated_1d_thin = 27,
    rotated_2d_thin = 28,
    rotated_thin_prt = 29,
    rotated_2d_thin_prt = 30,

    display_linear_general = 31,
};

pub const VertexInputSemantic = packed struct(u32) {
    semantic: u8,
    vgpr: u8,
    size_in_elements: u8,
    _: u8 = 0,
};

pub const VsPsHalfInterpType = packed struct(u2) {
    low: bool = false,
    high: bool = false,
};

pub const VertexExportSemantic = packed struct(u16) {
    semantic: u8,
    out_index: u5,
    _: u1 = 0,
    type: VsPsHalfInterpType,
};

pub const PixelDefaultValue = enum(u2) {
    @"0_0_0_0" = 0,
    @"0_0_0_1" = 1,
    @"1_1_1_0" = 2,
    @"1_1_1_1" = 3,
};

pub const PixelInputSemantic = packed struct(u16) {
    semantic: u8,
    default_value: PixelDefaultValue = .@"0_0_0_0",
    flat_shade: bool = false,
    sel_linear: bool = false,
    hw: packed union {
        base: packed struct(u4) {
            custom: bool = false,
            _: u3 = 0,
        },
        neo: packed struct(u4) {
            default_value_f16hi: PixelDefaultValue = .@"0_0_0_0",
            interp_f16: VsPsHalfInterpType = .{},
        },
    },
};

pub const BlendOp = enum(u5) {
    zero = 0,
    one = 1,
    src_color = 2,
    one_minus_src_color = 3,
    src_alpha = 4,
    one_minus_src_alpha = 5,
    dest_alpha = 6,
    one_minus_dest_alpha = 7,
    dest_color = 8,
    one_minus_dest_color = 9,
    src_alpha_saturate = 10,
    constant_color = 13,
    one_minus_constant_color = 14,
    src1_color = 15,
    inverse_src1_color = 16,
    src1_alpha = 17,
    inverse_src1_alpha = 18,
    constant_alpha = 19,
    one_minus_constant_alpha = 20,
};

pub const CombFunc = enum(u3) {
    dst_plus_src = 0,
    src_minus_dst = 1,
    min_dst_src = 2,
    max_dst_src = 3,
    dst_minus_src = 4,
};

pub const DepthCompare = enum(u3) {
    never = 0,
    less = 1,
    equal = 2,
    less_equal = 3,
    greater = 4,
    not_equal = 5,
    greater_equal = 6,
    always = 7,
};

pub const FaceOrientation = enum(u1) {
    ccw = 0,
    cw = 1,
};

pub const FillMode = enum(u3) {
    points = 0,
    lines = 1,
    triangles = 2,
};

pub const PolyMode = enum(u2) {
    disable = 0,
    dual_mode = 1,
};

pub const BufferFormat = enum(u4) {
    invalid = 0,
    @"8" = 1,
    @"16" = 2,
    @"8_8" = 3,
    @"32" = 4,
    @"16_16" = 5,
    @"10_11_11" = 6,
    @"11_11_10" = 7,
    @"10_10_10_2" = 8,
    @"2_10_10_10" = 9,
    @"8_8_8_8" = 10,
    @"32_32" = 11,
    @"16_16_16_16" = 12,
    @"32_32_32" = 13,
    @"32_32_32_32" = 14,
    reserved = 15,

    pub fn getBitSize(format: BufferFormat) u8 {
        return switch (format) {
            .invalid => 0,
            .@"8" => 8,
            .@"16", .@"8_8" => 16,
            .@"32", .@"16_16", .@"10_11_11", .@"11_11_10", .@"10_10_10_2", .@"2_10_10_10", .@"8_8_8_8" => 32,
            .@"32_32", .@"16_16_16_16" => 64,
            .@"32_32_32" => 96,
            .@"32_32_32_32" => 128,
            .reserved => unreachable,
        };
    }
};

pub const BufNumFormat = enum(u3) {
    unorm = 0,
    snorm = 1,
    uscaled = 2,
    sscaled = 3,
    uint = 4,
    sint = 5,
    snorm_ogl = 6,
    float = 7,
};

pub const Channel = enum(u3) {
    constant_0 = 0,
    constant_1 = 1,
    x = 4,
    y = 5,
    z = 6,
    w = 7,
};

pub const GeneralMemoryType = packed struct {
    l1: MemoryTypeL1, // 0x1c
    l1_scalar: MemoryTypeL1s, // 0x60
    l2: MemoryTypeL2, // 0x3

    pub const READ_ONLY = GeneralMemoryType{
        .l1 = .read_only,
        .l1_scalar = .cache_lru,
        .l2 = .{},
    };
    pub const PRIVATE = GeneralMemoryType{
        .l1 = .non_coherent_non_volatile,
        .l1_scalar = .cache_bypass,
        .l2 = .{},
    };
    pub const GPU_COHERENT = GeneralMemoryType{
        .l1 = .uncached,
        .l1_scalar = .cache_bypass,
        .l2 = .{
            .gpu_coherent = true,
        },
    };
    pub const SYSTEM_COHERENT = GeneralMemoryType{
        .l1 = .uncached,
        .l1_scalar = .cache_bypass,
        .l2 = .{
            .system_coherent = true,
        },
    };
    pub const UNCACHED = GeneralMemoryType{
        .l1 = .uncached,
        .l1_scalar = .cache_bypass,
        .l2 = .{
            .gpu_coherent = true,
            .system_coherent = true,
        },
    };
};

// TODO: what does each bit represent?
pub const MemoryTypeL1s = enum(u2) {
    cache_lru = 0,
    cache_bypass = 3,
};

pub const MemoryTypeL2 = packed struct(u2) {
    gpu_coherent: bool = false,
    system_coherent: bool = false,
};

// TODO: what do these mean???
pub const MemoryTypeL1 = enum(u3) {
    non_coherent_non_volatile = 0,
    non_coherent = 1,
    cache_coherent = 2,
    uncached = 3,
    read_only = 4,
};

pub const BufferType = enum(u2) {
    buf = 0,
    reserved_1 = 1,
    reserved_2 = 2,
    reserved_3 = 3,
};

pub const Buffer = extern struct {
    pub fn createConstFromSlice(comptime T: type, slice: []T) Buffer {
        return Buffer.createConst(slice.ptr, @sizeOf(T) * slice.len);
    }

    pub fn createConst(address: *anyopaque, byte_len: u32) Buffer {
        const addr_u64: u64 = @intFromPtr(address);
        return Buffer{
            .reg0 = .{ .base_address = @truncate(addr_u64) },
            .reg1 = .{
                .base_address_hi = @truncate(addr_u64 >> 32),
                .mtype_l1s = .cache_lru,
                .mtype_l2 = .{ .gpu_coherent = false, .system_coherent = false },
                .stride = 16,
                .cache_swizzle = false,
                .swizzle_enable = false,
            },
            .reg2 = .{ .num_records = byte_len / 16 },
            .reg3 = .{
                .dst_sel_x = .x,
                .dst_sel_y = .y,
                .dst_sel_z = .z,
                .dst_sel_w = .w,
                .num_format = .float,
                .data_format = .@"32_32_32_32",
                .element_size = 0,
                .index_stride = 0,
                .add_tid_enable = false,
                .atc = false,
                .hash_enable = false,
                .is_heap = false,
                .mtype = .read_only,
                .type = .buf,
            },
        };
    }

    pub const CreateDataError = error{
        InvalidFormat,
        Overflow,
        UnalignedAddress,
    };

    pub fn createDataFromSlice(comptime T: type, slice: []T, format: DataFormat) CreateDataError!Buffer {
        const len_u32 = math.cast(u32, @sizeOf(T) * slice.len) orelse return error.Overflow;
        return Buffer.createData(slice.ptr, format, len_u32);
    }

    pub fn createData(address: *anyopaque, format: DataFormat, num_elements: u32) CreateDataError!Buffer {
        const elem_byte_len = format.surface.getBitsPerElement() / 8;
        const min_alignment = @min(4, elem_byte_len);
        const addr_u64: u64 = @intFromPtr(address);

        if ((addr_u64 & (min_alignment - 1)) != 0) return error.UnalignedAddress;

        return Buffer{
            .reg0 = .{ .base_address = @truncate(addr_u64) },
            .reg1 = .{
                .base_address_hi = @truncate(addr_u64 >> 32),
                .mtype_l1s = .cache_lru,
                .mtype_l2 = .{ .gpu_coherent = false, .system_coherent = false },
                .stride = elem_byte_len,
                .cache_swizzle = false,
                .swizzle_enable = false,
            },
            .reg2 = .{ .num_records = num_elements },
            .reg3 = .{
                .dst_sel_x = format.channel_x,
                .dst_sel_y = format.channel_y,
                .dst_sel_z = format.channel_z,
                .dst_sel_w = format.channel_w,
                .num_format = try format.channel.toBuffer(),
                .data_format = try format.surface.toBuffer(),
                .element_size = 0,
                .index_stride = 0,
                .add_tid_enable = false,
                .atc = false,
                .hash_enable = false,
                .is_heap = false,
                .mtype = .non_coherent_non_volatile,
                .type = .buf,
            },
        };
    }

    pub fn createVertex(
        address: *anyopaque,
        format: DataFormat,
        stride: u14,
        num_elements: u32,
    ) error{ InvalidFormat, InvalidStride, UnalignedAddress }!Buffer {
        const elem_byte_len = format.surface.getBitsPerElement() / 8;
        const min_alignment = @min(4, elem_byte_len);
        const addr_u64: u64 = @intFromPtr(address);

        if ((addr_u64 & (min_alignment - 1)) != 0) return error.UnalignedAddress;
        if (stride == 0 and num_elements != elem_byte_len) return error.InvalidStride;

        return Buffer{
            .reg0 = .{ .base_address = @truncate(addr_u64) },
            .reg1 = .{
                .base_address_hi = @truncate(addr_u64 >> 32),
                .mtype_l1s = .cache_lru,
                .mtype_l2 = .{ .gpu_coherent = false, .system_coherent = false },
                .stride = stride,
                .cache_swizzle = false,
                .swizzle_enable = false,
            },
            .reg2 = .{ .num_records = num_elements },
            .reg3 = .{
                .dst_sel_x = format.channel_x,
                .dst_sel_y = format.channel_y,
                .dst_sel_z = format.channel_z,
                .dst_sel_w = format.channel_w,
                .num_format = try format.channel.toBuffer(),
                .data_format = try format.surface.toBuffer(),
                .element_size = 0,
                .index_stride = 0,
                .add_tid_enable = false,
                .atc = false,
                .hash_enable = false,
                .is_heap = false,
                .mtype = .non_coherent_non_volatile,
                .type = .buf,
            },
        };
    }

    reg0: packed struct(u32) {
        // 256 byte aligned, also used for fmask-ptr.
        base_address: u32,
    },
    reg1: packed struct(u32) {
        base_address_hi: u12,
        // mtype for scalar L1, or KCache
        mtype_l1s: MemoryTypeL1s,
        // mtype for L2
        mtype_l2: MemoryTypeL2,
        // byte stride
        stride: u14,
        // buffer access. optionally swizzle texture cache TC L1 cache banks
        cache_swizzle: bool,
        // is swizzle enabled
        swizzle_enable: bool,
    },
    reg2: packed struct(u32) {
        // in units of stride
        num_records: u32,
    },
    reg3: packed struct(u32) {
        // channel X to W
        dst_sel_x: Channel,
        dst_sel_y: Channel,
        dst_sel_z: Channel,
        dst_sel_w: Channel,
        // numeric data type
        num_format: BufNumFormat,
        // number and size of each field
        data_format: BufferFormat,
        // 2, 4, 8 or 16 bytes. used for swizzled buffer addressing
        element_size: u2,
        // 8, 16, 32 or 64. used for swizzled buffer addressing
        index_stride: u2,
        // add thread ID to the index for address calculation
        add_tid_enable: bool,
        // if 0: resource is in GPUVM memory space;
        // if 1: resource is in ATC memory space
        atc: bool,
        // buffer addresses are hashed for better cache performance
        hash_enable: bool,
        // is buffer is a heap?
        // it's out of range if offset is 0 or >= than numrecords
        is_heap: bool,
        // memory type for L1, controls cache behavior
        mtype: MemoryTypeL1,
        // if type == 0 then it's a buffer.
        // overlaps with the upper 2 bits of texture's 4 bit type
        type: BufferType,
    },

    pub fn getBaseAddress(self: Buffer) u56 {
        const addr_lo: u56 = self.reg0.base_address;
        const addr_hi: u56 = self.reg1.base_address_hi;
        return addr_lo | (addr_hi << 32);
    }
    pub fn getBaseAddressAs(self: Buffer, comptime T: type) [*]T {
        const address: u64 = self.reg0.base_address | (@as(u64, @intCast(self.reg1.base_address_hi)) << 32);
        return @ptrFromInt(address);
    }

    pub fn setMemoryType(self: *Buffer, options: GeneralMemoryType) void {
        self.reg1.mtype_l1s = options.l1_scalar;
        self.reg1.mtype_l2 = options.l2;
        self.reg3.mtype = options.l1;
    }
};

pub const RenderTargetFormat = enum(u5) {
    invalid = 0,
    @"8" = 1,
    @"16" = 2,
    @"8_8" = 3,
    @"32" = 4,
    @"16_16" = 5,
    @"10_11_11" = 6,
    @"11_11_10" = 7,
    @"10_10_10_2" = 8,
    @"2_10_10_10" = 9,
    @"8_8_8_8" = 10,
    @"32_32" = 11,
    @"16_16_16_16" = 12,
    @"32_32_32" = 13,
    @"32_32_32_32" = 14,
    @"5_6_5" = 16,
    @"1_5_5_5" = 17,
    @"5_5_5_1" = 18,
    @"4_4_4_4" = 19,
    @"8_24" = 20,
    @"24_8" = 21,
    x24_8_32 = 22,

    pub fn getBitSize(format: RenderTargetFormat) u8 {
        return switch (format) {
            .invalid => 0,
            .@"8" => return 8,
            .@"16", .@"8_8" => return 16,
            .@"32", .@"16_16", .@"10_11_11", .@"11_11_10", .@"10_10_10_2", .@"2_10_10_10", .@"8_8_8_8" => return 32,
            .@"32_32", .@"16_16_16_16" => return 64,
            .@"32_32_32" => return 96,
            .@"32_32_32_32" => return 128,
            .@"5_6_5", .@"1_5_5_5", .@"5_5_5_1", .@"4_4_4_4" => return 16,
            .@"8_24", .@"24_8" => return 32,
            .x24_8_32 => return 64,
        };
    }
};

pub const SurfaceNumber = enum(u3) {
    unorm = 0,
    snorm = 1,
    uint = 4,
    sint = 5,
    srgb = 6,
    float = 7,
};

pub const SurfaceSwap = enum(u2) {
    std = 0,
    alt = 1,
    std_reverse = 2,
    alt_reverse = 3,
};

pub const RenderTarget = extern struct {
    pub const init: RenderTarget = .{
        .base = 0,
        .pitch = .{
            .tile_max = 0,
            .fmask_tile_max = 0,
        },
        .slice = .{
            .tile_max = 0,
        },
        .view = .{
            .slice_start = 0,
            .slice_max = 0,
        },
        .info = .{
            .format = .invalid,
            .channel_type = .unorm,
            .channel_order = .std,
            .fast_clear = false,
            .compression = false,
            .is_normalized = false,
            .is_int = false,
            .is_scaled = false,
            .cmask_is_linear = false,
            .fmask_compression_mode = 0,
            .dcc_enable = false,
            .cmask_addr_type = 0,
            .alt_tile_mode = false,
        },
        .attrib = .{
            .tile_mode = .depth_2d_thin_64,
            .fmask_tile_mode = .depth_2d_thin_64,
            .num_samples = 0,
            .num_fragments = 0,
            .force_dst_alpha_one = false,
        },
        .dcc_control = .{
            .overwrite_combine_disable = false,
            .max_ncompressed_blocksize = 0,
            .min_compressed_blocksize = 0,
            .max_compressed_blocksize = 0,
            .color_transform = 0,
            .independent_64b_blocks = false,
        },
        .cmask = .{
            .base256b = 0,
        },
        .cmask_slice = .{
            .tile_max = 0,
        },
        .fmask = .{
            .base256b = 0,
        },
        .fmask_slice = .{
            .tile_max = 0,
        },
        .clear_word0 = 0,
        .clear_word1 = 0,
        .dcc_base = 0,
        .size = .{
            .width = 0,
            .height = 0,
        },
    };

    base: u32,
    pitch: packed struct(u32) {
        tile_max: u11,
        _: u9 = 0,
        fmask_tile_max: u11,
        _2: u1 = 0,
    },
    slice: packed struct(u32) {
        tile_max: u22,
        _: u10 = 0,
    },
    view: packed struct(u32) {
        slice_start: u11,
        _: u2 = 0,
        slice_max: u11,
        _2: u8 = 0,
    },
    info: packed struct(u32) {
        _: u2 = 0,
        format: RenderTargetFormat,
        _2: u1 = 0,
        channel_type: SurfaceNumber,
        channel_order: SurfaceSwap,
        fast_clear: bool,
        compression: bool,
        is_normalized: bool,
        is_int: bool,
        _3: u1 = 0,
        is_scaled: bool,
        cmask_is_linear: bool,
        _4: u6 = 0,
        fmask_compression_mode: u2,
        dcc_enable: bool,
        cmask_addr_type: u2,
        alt_tile_mode: bool,
    },
    attrib: packed struct(u32) {
        tile_mode: TileMode,
        fmask_tile_mode: TileMode,
        _: u2 = 0,
        num_samples: u3,
        num_fragments: u2,
        force_dst_alpha_one: bool,
        _2: u14 = 0,
    },
    dcc_control: packed struct(u32) {
        overwrite_combine_disable: bool,
        _: u1 = 0,
        max_ncompressed_blocksize: u2,
        min_compressed_blocksize: u1,
        max_compressed_blocksize: u2,
        color_transform: u2,
        independent_64b_blocks: bool,
        _2: u22 = 0,
    },
    cmask: packed struct(u32) {
        base256b: u32,
    },
    cmask_slice: packed struct(u32) {
        tile_max: u14,
        _: u18 = 0,
    },
    fmask: packed struct(u32) {
        base256b: u32,
    },
    fmask_slice: packed struct(u32) {
        tile_max: u22,
        _: u10 = 0,
    },
    clear_word0: u32,
    clear_word1: u32,
    dcc_base: u32,
    _: u32 = 0, // unused, TODO: remove this?
    // not a real register
    size: packed struct(u32) {
        width: u14,
        _: u2 = 0,
        height: u14,
        _2: u2 = 0,
    },

    pub fn getBaseAddress(self: RenderTarget) u56 {
        return @as(u56, self.base) << 8;
    }
    pub fn getBaseAddressAs(self: RenderTarget, comptime T: type) [*]T {
        return @ptrFromInt(self.getBaseAddress());
    }

    pub fn setBaseAddress(self: *RenderTarget, address: u56) void {
        assert(mem.isAligned(address, 256));
        // TODO: implement swizzle mask
        self.base = @truncate(address >> 8);
    }

    pub fn getPitch(self: RenderTarget) u16 {
        return (@as(u16, self.pitch.tile_max) + 1) * 8;
    }
    pub fn getSliceSize(self: RenderTarget) u32 {
        return ((@as(u32, self.slice.tile_max) + 1) * 64) / self.getPitch();
    }

    pub const CreateInfo = struct {
        format: DataFormat,

        width: u32,
        height: u32,
        pitch: u32,

        num_slices: u32,
        num_samples: u32,
        num_fragments: u32,

        tile_mode_hint: TileMode,
        min_gpu_mode: GpuMode,
        flags: u32 = 0, // FIXME
    };
    const CreateInfoInternal = extern struct {
        // format: DataFormat,
        format: u32, // TODO: fix type

        width: u32,
        height: u32,
        pitch: u32,

        num_slices: u32,
        num_samples: u32,
        num_fragments: u32,

        tile_mode_hint: u32, // FIXME
        min_gpu_mode: u32, // FIXME
        flags: u32 = 0, // FIXME
    };
    extern fn gnmCreateRenderTarget(rt: *RenderTarget, createinfo: *const CreateInfoInternal) c_int;
    pub fn create(ci: CreateInfo) error{ InvalidFormat, Unknown }!RenderTarget {
        var rt: RenderTarget = .init;
        const result = gnmCreateRenderTarget(&rt, &.{
            .format = @bitCast(ci.format),
            .width = ci.width,
            .height = ci.height,
            .pitch = ci.pitch,
            .num_slices = ci.num_slices,
            .num_samples = ci.num_samples,
            .num_fragments = ci.num_fragments,
            .tile_mode_hint = @backingInt(ci.tile_mode_hint),
            .min_gpu_mode = @backingInt(ci.min_gpu_mode),
            .flags = ci.flags,
        });
        if (result != 0) {
            std.debug.print("gnmCreateRenderTarget failed with {s}\n", .{gnmStrError(result)});
            return error.Unknown;
        }
        return rt;
    }

    pub const SizeInfo = struct {
        length: u64,
        alignment: u32,

        pub const empty: SizeInfo = .{
            .length = 0,
            .alignment = 0,
        };
    };
    extern fn gnmRtCalcByteSize(
        outsize: *u64,
        outalign: *u32,
        rt: *const RenderTarget,
    ) c_int;
    pub fn calcByteSize(self: RenderTarget) error{Unknown}!SizeInfo {
        var info: SizeInfo = .empty;
        const result = gnmRtCalcByteSize(&info.length, &info.alignment, &self);
        if (result != 0) return error.Unknown;
        return info;
    }
};

pub const BorderColor = enum(u2) {
    trans_black = 0,
    opaque_black = 1,
    opaque_white = 2,
    from_table = 3,
};
pub const Filter = enum(u2) {
    point = 0,
    bilinear = 1,
    aniso_point = 2,
    aniso_bilinear = 3,
};
pub const FilterMode = enum(u2) {
    blend = 0,
    min = 1,
    max = 2,
};
pub const MipFilter = enum(u2) {
    none = 0,
    point = 1,
    linear = 2,
};
pub const TexClamp = enum(u3) {
    wrap = 0,
    mirror = 1,
    clamp_last_texel = 2,
    mirror_once_last_texel = 3,
    clamp_half_border = 4,
    mirror_once_half_border = 5,
    clamp_border = 6,
    mirror_once_border = 7,
};
pub const ZFilter = enum(u2) {
    none = 0,
    point = 1,
    linear = 2,
};

pub const Sampler = extern struct {
    reg0: packed struct(u32) {
        // clamp/wrap modes
        clamp_x: TexClamp = .wrap,
        clamp_y: TexClamp = .wrap,
        clamp_z: TexClamp = .wrap,
        max_aniso_ratio: u3 = 0,
        depth_compare_func: DepthCompare = .never,
        // force address coords to be unormalized
        force_unnormalized: bool = false,
        aniso_threshold: u3 = 0,
        mc_coord_trunc: bool = false,
        force_degamma: bool = false,
        aniso_bias: u6 = 0,
        trunc_coord: bool = false,
        disable_cube_wrap: bool = false,
        filter_mode: FilterMode = .blend,
        _: u1 = 0,
    } = .{},
    reg1: packed struct(u32) {
        min_lod: u12 = 0,
        max_lod: u12 = 0,
        perf_mip: u4 = 0,
        perf_z: u4 = 0,
    } = .{},
    reg2: packed struct(u32) {
        lod_bias: u14 = 0,
        lod_bias_sec: u6 = 0,
        // magnification filter
        xy_mag_filter: Filter = .point,
        // minification filter
        xy_min_filter: Filter = .point,
        z_filter: ZFilter = .none,
        mip_filter: MipFilter = .none,
        // when mipfilter == point, add 0.5 before clamping
        mip_point_preclamp: bool = false,
        disable_lsb_ceil: bool = false,
        _: u2 = 0,
    } = .{},
    reg3: packed struct(u32) {
        border_color_ptr: u12 = 0,
        _: u18 = 0,
        border_color_type: BorderColor = .trans_black,
    } = .{},

    pub fn getAnisotropyRatio(self: Sampler) u8 {
        return self.reg0.max_aniso_ratio >> 1;
    }
};

pub const ZFormat = enum(u2) {
    invalid = 0,
    d16 = 1,
    f32 = 3,

    pub fn getBitSize(format: ZFormat) u8 {
        return switch (format) {
            .d16 => 16,
            .f32 => 32,
            .invalid => 0,
        };
    }
};

pub const ZOrder = enum(u2) {
    late_z = 0,
    early_z_then_late_z = 1,
    re_z = 2,
    early_z_then_re_z = 3,
};

pub const ConservativeZExport = enum(u2) {
    export_any_z = 0,
    export_less_than_z = 1,
    export_greater_than_z = 2,
    export_reserved = 3,
};

pub const StencilFormat = enum(u1) {
    invalid = 0,
    u8 = 1,

    pub fn getBitSize(format: StencilFormat) u8 {
        return switch (format) {
            .u8 => 8,
            .invalid => 0,
        };
    }
};

pub const DepthRenderTarget = extern struct {
    pub const init: DepthRenderTarget = .{
        .z_info = .{
            .format = .invalid,
            .num_samples = 0,
            .tile_split = 0,
            .tile_mode_index = 0,
            .allow_exp_clear = false,
            .tile_surface_enable = false,
            .zrange_precision = 0,
        },
        .stencil_info = .{
            .format = .invalid,
            .tile_split = 0,
            .tile_mode_index = 0,
            .allow_exp_clear = false,
            .tile_stencil_disable = false,
        },
        .z_read_base = 0,
        .stencil_read_base = 0,
        .z_write_base = 0,
        .stencil_write_base = 0,
        .depth_size = .{
            .pitch_tile_max = 0,
            .height_tile_max = 0,
        },
        .depth_slice = .{
            .slice_tile = 0,
        },
        .depth_view = .{
            .slice_start = 0,
            .slice_max = 0,
        },
        .htile_data_base = 0,
        .htile_surface = .{
            .linear = false,
            .tc_compatible = false,
        },
        .depth_info = .{
            .linear = false,
            .tc_compatible = false,
        },
        .size = .{
            .width = 0,
            .height = 0,
        },
    };

    z_info: packed struct(u32) {
        format: ZFormat,
        num_samples: u2,
        _: u9 = 0,
        tile_split: u3,
        _2: u4 = 0,
        tile_mode_index: u3,
        _3: u4 = 0,
        allow_exp_clear: bool,
        _4: u1 = 0,
        tile_surface_enable: bool,
        _5: u1 = 0,
        zrange_precision: u1,
    },
    stencil_info: packed struct(u32) {
        format: StencilFormat,
        _: u12 = 0,
        tile_split: u3,
        _2: u4 = 0,
        tile_mode_index: u3,
        _3: u4 = 0,
        allow_exp_clear: bool,
        _4: u1 = 0,
        tile_stencil_disable: bool,
        _5: u2 = 0,
    },
    z_read_base: u32,
    stencil_read_base: u32,
    z_write_base: u32,
    stencil_write_base: u32,
    depth_size: packed struct(u32) {
        pitch_tile_max: u11,
        height_tile_max: u11,
        _: u10 = 0,
    },
    depth_slice: packed struct(u32) {
        slice_tile: u22,
        _: u10 = 0,
    },
    depth_view: packed struct(u32) {
        slice_start: u11,
        _: u2 = 0,
        slice_max: u11,
        _2: u8 = 0,
    },
    htile_data_base: u32,
    htile_surface: packed struct(u32) {
        linear: bool,
        _: u16 = 0,
        tc_compatible: bool,
        _2: u14 = 0,
    },
    depth_info: packed struct(u32) {
        linear: bool,
        _: u16 = 0,
        tc_compatible: bool,
        _2: u14 = 0,
    },
    size: packed struct(u32) {
        width: u14,
        _: u2 = 0,
        height: u14,
        _2: u2 = 0,
    },

    // TODO: implement swizzle mask
    pub fn getZReadAddress(self: DepthRenderTarget) u56 {
        return @as(u56, self.z_read_base) << 8;
    }
    pub fn getZReadAddressAs(self: DepthRenderTarget, comptime T: type) ?[*]T {
        const addr = self.getZReadAddress();
        if (addr == 0) return null;
        return @ptrFromInt(addr);
    }
    // TODO: implement swizzle mask
    pub fn setZReadAddress(self: *DepthRenderTarget, address: *anyopaque) error{InvalidAddress}!void {
        const addr_u64: u64 = @intFromPtr(address);
        if ((addr_u64 & 0xffffff00000000ff) != 0) return error.InvalidAddress;
        self.z_read_base = @truncate(addr_u64 >> 8);
    }

    // TODO: implement swizzle mask
    pub fn getZWriteAddress(self: DepthRenderTarget) u56 {
        return @as(u56, self.z_write_base) << 8;
    }
    pub fn getZWriteAddressAs(self: DepthRenderTarget, comptime T: type) ?[*]T {
        const addr = self.getZWriteAddress();
        if (addr == 0) return null;
        return @ptrFromInt(addr);
    }
    // TODO: implement swizzle mask
    pub fn setZWriteAddress(self: *DepthRenderTarget, address: *anyopaque) error{InvalidAddress}!void {
        const addr_u64: u64 = @intFromPtr(address);
        if ((addr_u64 & 0xffffff00000000ff) != 0) return error.InvalidAddress;
        self.z_write_base = @truncate(addr_u64 >> 8);
    }

    pub fn getPaddedWidth(self: DepthRenderTarget) u16 {
        return (@as(u16, @intCast(self.depth_size.pitch_tile_max)) + 1) * 8;
    }
    pub fn getPaddedHeight(self: DepthRenderTarget) u16 {
        return (@as(u16, @intCast(self.depth_size.height_tile_max)) + 1) * 8;
    }

    pub const CreateInfo = struct {
        z_format: ZFormat,
        stencil_format: StencilFormat,

        width: u32,
        height: u32,
        pitch: u32,

        num_slices: u32,
        num_fragments: u32,

        tile_mode_hint: TileMode,
        min_gpu_mode: GpuMode,
        flags: u32 = 0, // FIXME
    };
    const CreateInfoInternal = extern struct {
        width: u32,
        height: u32,
        pitch: u32,
        num_slices: u32,

        // z_format: ZFormat,
        z_format: u32, // TODO: fix type
        // stencil_format: StencilFormat,
        stencil_format: u32, // TODO: fix type

        tile_mode_hint: u32, // FIXME
        min_gpu_mode: u32, // FIXME

        num_fragments: u32, // really well position field here, totally not awkward

        flags: u32 = 0, // FIXME
    };
    extern fn gnmCreateDepthRenderTarget(drt: *DepthRenderTarget, createinfo: *const CreateInfoInternal) c_int;
    pub fn create(ci: CreateInfo) error{Unknown}!DepthRenderTarget {
        var drt: DepthRenderTarget = .init;
        const result = gnmCreateDepthRenderTarget(&drt, &.{
            .width = ci.width,
            .height = ci.height,
            .pitch = ci.pitch,
            .num_slices = ci.num_slices,
            .z_format = @backingInt(ci.z_format),
            .stencil_format = @backingInt(ci.stencil_format),
            .tile_mode_hint = @backingInt(ci.tile_mode_hint),
            .min_gpu_mode = @backingInt(ci.min_gpu_mode),
            .num_fragments = ci.num_fragments,
            .flags = ci.flags,
        });
        if (result != 0) {
            std.debug.print("gnmCreateDepthRenderTarget failed with {s}\n", .{gnmStrError(result)});
            return error.Unknown;
        }
        return drt;
    }

    pub const SizeInfo = struct {
        length: u64,
        alignment: u32,

        pub const empty: SizeInfo = .{
            .length = 0,
            .alignment = 0,
        };
    };
    extern fn gnmDrtCalcByteSize(
        outsize: *u64,
        outalign: *u32,
        drt: *const DepthRenderTarget,
    ) c_int;
    pub fn calcByteSize(self: DepthRenderTarget) error{Unknown}!SizeInfo {
        var info: SizeInfo = .empty;
        const result = gnmDrtCalcByteSize(&info.length, &info.alignment, &self);
        if (result != 0) {
            std.debug.print("gnmDrtCalcByteSize failed with {s}\n", .{gnmStrError(result)});
            return error.Unknown;
        }
        return info;
    }
};

pub const ImageFormat = enum(u6) {
    invalid = 0,
    @"8" = 1,
    @"16" = 2,
    @"8_8" = 3,
    @"32" = 4,
    @"16_16" = 5,
    @"10_11_11" = 6,
    @"11_11_10" = 7,
    @"10_10_10_2" = 8,
    @"2_10_10_10" = 9,
    @"8_8_8_8" = 10,
    @"32_32" = 11,
    @"16_16_16_16" = 12,
    @"32_32_32" = 13,
    @"32_32_32_32" = 14,
    @"5_6_5" = 16,
    @"1_5_5_5" = 17,
    @"5_5_5_1" = 18,
    @"4_4_4_4" = 19,
    @"8_24" = 20,
    @"24_8" = 21,
    x24_8_32 = 22,
    gb_gr = 32,
    bg_rg = 33,
    @"5_9_9_9" = 34,
    bc1 = 35,
    bc2 = 36,
    bc3 = 37,
    bc4 = 38,
    bc5 = 39,
    bc6 = 40,
    bc7 = 41,
    fmask8_s2_f1 = 44,
    fmask8_s4_f1 = 45,
    fmask8_s8_f1 = 46,
    fmask8_s2_f2 = 47,
    fmask8_s4_f2 = 48,
    fmask8_s4_f4 = 49,
    fmask16_s16_f1 = 50,
    fmask16_s8_f2 = 51,
    fmask32_s16_f2 = 52,
    fmask32_s8_f4 = 53,
    fmask32_s8_f8 = 54,
    fmask64_s16_f4 = 55,
    fmask64_s16_f8 = 56,
    @"4_4" = 57,
    @"6_5_5" = 58,
    @"1" = 59,
    @"1_reversed" = 60,

    pub fn getBitsPerElement(format: ImageFormat) u8 {
        return switch (format) {
            .invalid => 0,
            .@"8" => 8,
            .@"16", .@"8_8" => 16,
            .@"32", .@"16_16", .@"10_11_11", .@"11_11_10", .@"10_10_10_2", .@"2_10_10_10", .@"8_8_8_8" => 32,
            .@"32_32", .@"16_16_16_16" => 64,
            .@"32_32_32" => 96,
            .@"32_32_32_32" => 128,
            .@"5_6_5", .@"1_5_5_5", .@"5_5_5_1", .@"4_4_4_4" => 16,
            .@"8_24", .@"24_8" => 32,
            .x24_8_32 => 64,
            .gb_gr, .bg_rg => 16,
            .@"5_9_9_9" => 32,
            .bc1 => 4,
            .bc2, .bc3 => 8,
            .bc4 => 4,
            .bc5, .bc6, .bc7 => 8,
            .fmask8_s2_f1, .fmask8_s4_f1, .fmask8_s8_f1, .fmask8_s2_f2, .fmask8_s4_f2, .fmask8_s4_f4 => 8,
            .fmask16_s16_f1, .fmask16_s8_f2 => 16,
            .fmask32_s16_f2, .fmask32_s8_f4, .fmask32_s8_f8 => 32,
            .fmask64_s16_f4, .fmask64_s16_f8 => 64,
            .@"4_4" => 8,
            .@"6_5_5" => 16,
            .@"1", .@"1_reversed" => 1,
        };
    }

    pub fn isBlockCompressed(format: ImageFormat) bool {
        return switch (format) {
            .bc1, .bc2, .bc3, .bc4, .bc5, .bc6, .bc7 => true,
            else => false,
        };
    }

    pub fn toBuffer(format: ImageFormat) error{InvalidFormat}!BufferFormat {
        const format_int: u8 = @backingInt(format);
        if (format_int > @backingInt(BufferFormat.@"32_32_32_32")) return error.InvalidFormat;
        return @fromBackingInt(@intCast(format_int));
    }

    pub fn toRenderTarget(format: ImageFormat) error{InvalidFormat}!RenderTargetFormat {
        const format_int: u8 = @backingInt(format);
        if (format_int > @backingInt(RenderTargetFormat.x24_8_32)) return error.InvalidFormat;
        return @fromBackingInt(@intCast(format_int));
    }
};

pub const ImgNumFormat = enum(u4) {
    unorm = 0,
    snorm = 1,
    uscaled = 2,
    sscaled = 3,
    uint = 4,
    sint = 5,
    snorm_ogl = 6,
    float = 7,
    srgb = 9,
    ubnorm = 10,
    ubnorm_ogl = 11,
    ubint = 12,
    ubscaled = 13,

    pub fn toBuffer(format: ImgNumFormat) error{InvalidFormat}!BufNumFormat {
        const format_int: u8 = @backingInt(format);
        if (format_int > @backingInt(BufferFormat.@"32_32_32_32")) return error.InvalidFormat;
        return @fromBackingInt(@intCast(format_int));
    }

    pub fn toRenderTarget(format: ImageFormat) error{InvalidFormat}!RenderTargetFormat {
        const format_int: u8 = @backingInt(format);
        if (format_int > @backingInt(RenderTargetFormat.x24_8_32)) return error.InvalidFormat;
        return @fromBackingInt(@intCast(format_int));
    }
};

pub const TextureType = enum(u4) {
    invalid = 0,
    @"1d" = 8,
    @"2d" = 9,
    @"3d" = 10,
    cubemap = 11,
    @"1d_array" = 12,
    @"2d_array" = 13,
    @"2d_msaa" = 14,
    @"2d_array_msaa" = 15,
};

pub const Texture = extern struct {
    pub const MtypePart1 = enum(u2) {
        non_coherent_non_volatile = 0,
        non_coherent = 1,
        cache_coherent = 2,
        uncached = 3,
    };
    pub const MtypePart2 = enum(u1) {
        read_write = 0,
        read_only = 1,
    };

    pub const init: Texture = .{
        .reg0 = .{
            .base_address = 0,
        },
        .reg1 = .{
            .base_address_hi = 0,
            .mtype_l2 = .{ .gpu_coherent = false, .system_coherent = false },
            .minlod = 0,
            .data_format = .invalid,
            .num_format = .unorm,
            .mtype_b0 = .non_coherent_non_volatile,
        },
        .reg2 = .{
            .width = 0,
            .height = 0,
            .perf_mod = 0,
            .interlaced = false,
        },
        .reg3 = .{
            .dst_sel_x = .constant_0,
            .dst_sel_y = .constant_0,
            .dst_sel_z = .constant_0,
            .dst_sel_w = .constant_0,
            .base_level = 0,
            .last_level = 0,
            .tile_mode = .depth_2d_thin_64,
            .pow_2_pad = false,
            .mtype_b2 = .read_write,
            .atc = false,
            .type = .@"1d",
        },
        .reg4 = .{
            .depth = 0,
            .pitch = 0,
        },
        .reg5 = .{
            .base_array = 0,
            .last_array = 0,
        },
        .reg6 = .{
            .min_lod_warn = 0,
            .counter_bank_id = 0,
            .lod_hdw_cnt_en = false,
            .compression_en = false,
            .alpha_is_on_msb = false,
            .color_transform = false,
            .alt_tile_mode = false,
        },
        .reg7 = .{
            .metadata_addr = 0,
        },
    };

    reg0: packed struct(u32) {
        // 256 byte aligned, also used for fmask-ptr.
        base_address: u32,
    },
    reg1: packed struct(u32) {
        // NOTE: in the CI ISA, the 32-40 bits of this resource are also for the
        // base address, but they seem to have a different purpose according to
        // reverse engineered
        // NOTE: 6 high bits of baseaddress are unused
        base_address_hi: u6, // 0
        // mtype for L2
        mtype_l2: MemoryTypeL2, // 6
        minlod: u12, // 8
        // surface format
        data_format: ImageFormat, // 20
        // channel type
        num_format: ImgNumFormat, // 26
        // memory type, controls cache behavior
        // if enabled, uses L1 cache LRU
        mtype_b0: MtypePart1, // 30
    },
    reg2: packed struct(u32) {
        width: u14,
        height: u14,
        perf_mod: u3,
        interlaced: bool,
    },
    reg3: packed struct(u32) {
        // channel X to W
        dst_sel_x: Channel,
        dst_sel_y: Channel,
        dst_sel_z: Channel,
        dst_sel_w: Channel,
        // base mip level
        base_level: u4,
        // last mip level, or number of fragments/samples for MSAA
        last_level: u4,
        // tile mode
        tile_mode: TileMode,
        // memory footprint is padded to pow2 dimensions
        pow_2_pad: bool,
        // if enabled, texture is read only
        mtype_b2: MtypePart2,
        atc: bool,
        type: TextureType,
    },
    reg4: packed struct(u32) {
        depth: u13,
        pitch: u14,
        _: u5 = 0,
    },
    reg5: packed struct(u32) {
        base_array: u13,
        last_array: u13,
        _: u6 = 0,
    },
    reg6: packed struct(u32) {
        min_lod_warn: u12,
        counter_bank_id: u8,
        lod_hdw_cnt_en: bool,
        // gfx8/NEO only attributes
        compression_en: bool,
        alpha_is_on_msb: bool,
        color_transform: bool,
        // NEO only attribute,
        // reverse engineered and not in public registers
        // TODO: test it on real hardware
        alt_tile_mode: bool,
        _: u7 = 0,
    },
    reg7: packed struct(u32) {
        metadata_addr: u32,
    },

    pub const CreateInfo = struct {
        format: DataFormat,
        type: TextureType,

        width: u32,
        height: u32,
        depth: u32,
        pitch: u32,

        num_mips: u32,
        num_slices: u32,
        num_fragments: u32,

        tile_mode_hint: TileMode,
        min_gpu_mode: GpuMode,
    };
    const CreateInfoInternal = extern struct {
        format: u32, // FIXME type
        type: u32, // FIXME type

        width: u32,
        height: u32,
        depth: u32,
        pitch: u32,

        num_mips: u32,
        num_slices: u32,
        num_fragments: u32,

        tile_mode_hint: u32, // FIXME type
        min_gpu_mode: u32, // FIXME typ

    };
    extern fn gnmCreateTexture(rt: *Texture, createinfo: *const CreateInfoInternal) c_int;
    pub fn create(ci: CreateInfo) error{ InvalidFormat, Unknown }!Texture {
        var rt: Texture = .init;
        const result = gnmCreateTexture(&rt, &.{
            .format = @bitCast(ci.format),
            .type = @backingInt(ci.type),
            .width = ci.width,
            .height = ci.height,
            .depth = ci.depth,
            .pitch = ci.pitch,
            .num_mips = ci.num_mips,
            .num_slices = ci.num_slices,
            .num_fragments = ci.num_fragments,
            .tile_mode_hint = @backingInt(ci.tile_mode_hint),
            .min_gpu_mode = @backingInt(ci.min_gpu_mode),
        });
        if (result != 0) {
            std.debug.print("gnmCreateTexture failed with {s}\n", .{gnmStrError(result)});
            return error.Unknown;
        }
        return rt;
    }

    pub fn getBaseAddress(self: Texture) u56 {
        return @as(u56, self.reg0.base_address) << 8;
    }
    pub fn getBaseAddressAs(self: Texture, comptime T: type) [*]T {
        return @ptrFromInt(self.getBaseAddress());
    }

    pub fn setBaseAddress(self: *Texture, address: u56) void {
        assert(mem.isAligned(address, 256));
        self.reg0.base_address = @truncate(address >> 8);
    }

    pub fn getWidth(self: Texture) u16 {
        return @as(u16, @intCast(self.reg2.width)) + 1;
    }
    pub fn getHeight(self: Texture) u16 {
        return @as(u16, @intCast(self.reg2.height)) + 1;
    }
    pub fn getDepth(self: Texture) u16 {
        return @as(u16, @intCast(self.reg4.depth)) + 1;
    }

    pub fn setMemoryType(self: *Texture, options: GeneralMemoryType) void {
        self.reg1.mtype_b0 = switch (options.l1) {
            .non_coherent => .non_coherent,
            .cache_coherent => .cache_coherent,
            .uncached => .uncached,
            else => .non_coherent_non_volatile,
        };
        self.reg1.mtype_l2 = options.l2;
        self.reg3.mtype_b2 = if (options.l1 == .read_only) .read_only else .read_write;
    }

    pub const SizeInfo = struct {
        length: u64,
        alignment: u32,

        pub const empty: SizeInfo = .{
            .length = 0,
            .alignment = 0,
        };
    };
    extern fn gnmTexCalcByteSize(
        out_size: *u64,
        out_align: *u32,
        tex: *const Texture,
    ) c_int;
    pub fn calcByteSize(self: Texture) error{Unknown}!SizeInfo {
        var info: SizeInfo = .empty;
        const result = gnmTexCalcByteSize(&info.length, &info.alignment, &self);
        if (result != 0) return error.Unknown;
        return info;
    }
};

pub const EmbeddedShaderVertex = enum(i32) {
    fullscreen = 0,
};

pub const EmbeddedShaderPixel = enum(i32) {
    null = 0,
    null_rg32 = 1,
};

comptime {
    assert(@sizeOf(Buffer) == 0x10);
    assert(@sizeOf(DepthRenderTarget) == 0x34);
    assert(@sizeOf(RenderTarget) == 0x40);
    assert(@sizeOf(Texture) == 0x20);
}

pub const FloatMode = enum(u8) {
    fp_32_round_towards_zero = 3,
    fp_16_64_round_towards_zero = 12,
    fp_32_denorms = 48,
    fp_16_64_denorms = 192,
    _,
};

pub const CbBlendControl = packed struct(u32) {
    color_src_blend: BlendOp = .zero,
    color_comb_fcn: CombFunc = .dst_plus_src,
    color_dest_blend: BlendOp = .zero,
    _: u3 = 0,
    alpha_src_blend: BlendOp = .zero,
    alpha_comb_fcn: CombFunc = .dst_plus_src,
    alpha_dest_blend: BlendOp = .zero,
    separate_alpha_blend: bool = false,
    enable: bool = false,
    disable_rop_3: bool = false,
};

pub const CbShaderMask = packed struct(u32) {
    target0_enable: EnableMask = .off,
    target1_enable: EnableMask = .off,
    target2_enable: EnableMask = .off,
    target3_enable: EnableMask = .off,
    target4_enable: EnableMask = .off,
    target5_enable: EnableMask = .off,
    target6_enable: EnableMask = .off,
    target7_enable: EnableMask = .off,

    pub const EnableMask = packed struct(u4) {
        pub const off: EnableMask = .{
            .r = false,
            .g = false,
            .b = false,
            .a = false,
        };

        pub const on: EnableMask = .{
            .r = true,
            .g = true,
            .b = true,
            .a = true,
        };
        r: bool,
        g: bool,
        b: bool,
        a: bool,
    };
};

pub const CbTargetMask = packed struct(u32) {
    target0_enable: EnableMask = .off,
    target1_enable: EnableMask = .off,
    target2_enable: EnableMask = .off,
    target3_enable: EnableMask = .off,
    target4_enable: EnableMask = .off,
    target5_enable: EnableMask = .off,
    target6_enable: EnableMask = .off,
    target7_enable: EnableMask = .off,

    pub const EnableMask = packed struct(u4) {
        pub const off: EnableMask = .{
            .r = false,
            .g = false,
            .b = false,
            .a = false,
        };

        pub const on: EnableMask = .{
            .r = true,
            .g = true,
            .b = true,
            .a = true,
        };
        r: bool,
        g: bool,
        b: bool,
        a: bool,
    };
};

pub const DbDepthControl = packed struct(u32) {
    stencil_enable: bool = false,
    z_enable: bool = false,
    z_write_enable: bool = false,
    depth_bounds_enable: bool = false,
    z_func: DepthCompare = .never,
    backface_enable: bool = false,
    stencil_func: DepthCompare = .never,
    _: u9 = 0,
    stencil_func_backface: DepthCompare = .never,
    _2: u7 = 0,
    enable_color_writes_on_depth_fail: bool = false,
    disable_color_writes_on_depth_pass: bool = false,
};

pub const DbRenderControl = packed struct(u32) {
    depth_clear_enable: bool = false,
    stencil_clear_enable: bool = false,
    depth_copy: bool = false,
    stencil_copy: bool = false,
    resummarize_enable: bool = false,
    stencil_compress_disable: bool = false,
    depth_compress_disable: bool = false,
    copy_centroid: bool = false,
    copy_sample: u4 = 0,
    decompress_enable: bool = false,
    _: u19 = 0,
};

pub const DbShaderControl = packed struct(u32) {
    z_export_enable: bool,
    stencil_test_val_export_enable: bool,
    stencil_op_val_export_enable: bool,
    _: u1 = 0,
    z_order: ZOrder,
    kill_enable: bool,
    coverage_to_mask_enable: bool,
    mask_export_enable: bool,
    exec_on_hier_fail: bool,
    exec_on_noop: bool,
    alpha_to_mask_disable: bool,
    depth_before_shader: bool,
    conservative_z_export: ConservativeZExport,
    _2: u17 = 0,

    pub const empty: DbShaderControl = .{
        .z_export_enable = false,
        .stencil_test_val_export_enable = false,
        .stencil_op_val_export_enable = false,
        .z_order = .late_z,
        .kill_enable = false,
        .coverage_to_mask_enable = false,
        .mask_export_enable = false,
        .exec_on_hier_fail = false,
        .exec_on_noop = false,
        .alpha_to_mask_disable = false,
        .depth_before_shader = false,
        .conservative_z_export = .export_any_z,
    };
};

pub const DrawIndirectArgs = extern struct {
    vertex_count: u32 = 0,
    instance_count: u32 = 0,
    first_vertex: u32 = 0,
    first_instance: u32 = 0,
};

pub const DrawIndexIndirectArgs = extern struct {
    index_count: u32 = 0,
    instance_count: u32 = 0,
    first_inde: u32 = 0,
    vertex_offset: u32 = 0,
    first_instance: u32 = 0,
};

pub const PaClVsOutCntl = packed struct(u32) {
    clip_dist_ena_0: bool = false,
    clip_dist_ena_1: bool = false,
    clip_dist_ena_2: bool = false,
    clip_dist_ena_3: bool = false,
    clip_dist_ena_4: bool = false,
    clip_dist_ena_5: bool = false,
    clip_dist_ena_6: bool = false,
    clip_dist_ena_7: bool = false,
    cull_dist_ena_0: bool = false,
    cull_dist_ena_1: bool = false,
    cull_dist_ena_2: bool = false,
    cull_dist_ena_3: bool = false,
    cull_dist_ena_4: bool = false,
    cull_dist_ena_5: bool = false,
    cull_dist_ena_6: bool = false,
    cull_dist_ena_7: bool = false,
    use_vtx_point_size: bool = false,
    use_vtx_edge_flag: bool = false,
    use_vtx_render_target_indx: bool = false,
    use_vtx_viewport_indx: bool = false,
    use_vtx_kill_flag: bool = false,
    vs_out_misc_vec_ena: bool = false,
    vs_out_ccdist0_vec_ena: bool = false,
    vs_out_ccdist1_vec_ena: bool = false,
    vs_out_misc_side_bus_ena: bool = false,
    use_vtx_gs_cut_flag: bool = false,
    use_vtx_line_width: bool = false,
    _: u5 = 0,
};

pub const PaClVPort = extern struct {
    x_scale: f32 = 0.0,
    x_offset: f32 = 0.0,
    y_scale: f32 = 0.0,
    y_offset: f32 = 0.0,
    z_scale: f32 = 0.0,
    z_offset: f32 = 0.0,
};

pub const PaClVteCntl = packed struct(u32) {
    vport_x_scale_ena: bool = false,
    vport_x_offset_ena: bool = false,
    vport_y_scale_ena: bool = false,
    vport_y_offset_ena: bool = false,
    vport_z_scale_ena: bool = false,
    vport_z_offset_ena: bool = false,
    _: u2 = 0,
    vtx_xy_fmt: bool = false,
    vtx_z_fmt: bool = false,
    vtx_w0_fmt: bool = false,
    perfcounter_ref: bool = false,
    _2: u20 = 0,
};

pub const PaScScreenScissorTL = packed struct(u32) {
    tl_x: i16 = 0,
    tl_y: i16 = 0,
};

pub const PaScScreenScissorBR = packed struct(u32) {
    br_x: i16 = 0,
    br_y: i16 = 0,
};

pub const PaScVPort = extern struct {
    z_min: f32 = 0.0,
    z_max: f32 = 0.0,
};

pub const PaSuHardwareScreenOffset = packed struct(u32) {
    hw_screen_offset_x: u9 = 0,
    _: u7 = 0,
    hw_screen_offset_y: u9 = 0,
    _2: u7 = 0,
};

pub const PaSuScModeCntl = packed struct(u32) {
    cull_front: bool = false,
    cull_back: bool = false,
    face: FaceOrientation = .ccw,
    poly_mode: PolyMode = .disable,
    polymode_front_ptype: FillMode = .points,
    polymode_back_ptype: FillMode = .points,
    poly_offset_front_enable: bool = false,
    poly_offset_back_enable: bool = false,
    poly_offset_para_enable: bool = false,
    _: u2 = 0,
    vtx_window_offset_enable: bool = false,
    _2: u2 = 0,
    provoking_vtx_last: bool = false,
    persp_corr_dis: bool = false,
    multi_prim_ib_ena: bool = false,
    _3: u10 = 0,
};

pub const PsInputCntl = packed struct(u32) {
    offset: u6 = 0,
    _: u2 = 0,
    default_val: u2 = 0,
    flat_shade: bool = false,
    _2: u2 = 0,
    cyl_wrap: u4 = 0,
    pt_sprite_tex: bool = false,
    dup: bool = false,
    fp16_interp_mode: bool = false,
    use_default_attr1: bool = false,
    default_val_attr1: u2 = 0,
    pt_sprite_tex_attr1: bool = false,
    attr0_valid: bool = false,
    attr1_valid: bool = false,
    _3: u6 = 0,
};

pub const SpiBarycCntl = packed struct(u32) {
    persp_center_cntl: bool,
    _: u3 = 0,
    persp_centroid_cntl: bool,
    _2: u3 = 0,
    linear_center_cntl: bool,
    _3: u3 = 0,
    linear_centroid_cntl: bool,
    _4: u3 = 0,
    pos_float_location: u2,
    _5: u2 = 0,
    pos_float_ulc: bool,
    _6: u3 = 0,
    front_face_all_bits: bool,
    _7: u7 = 0,

    pub const empty: SpiBarycCntl = .{
        .persp_center_cntl = false,
        .persp_centroid_cntl = false,
        .linear_center_cntl = false,
        .linear_centroid_cntl = false,
        .pos_float_location = 0,
        .pos_float_ulc = false,
        .front_face_all_bits = false,
    };
};

pub const SpiPsInputEna = packed struct(u32) {
    persp_sample_ena: bool = false,
    persp_center_ena: bool = false,
    persp_centroid_ena: bool = false,
    persp_pull_model_ena: bool = false,
    linear_sample_ena: bool = false,
    linear_center_ena: bool = false,
    linear_centroid_ena: bool = false,
    line_stipple_tex_ena: bool = false,
    pos_x_float_ena: bool = false,
    pos_y_float_ena: bool = false,
    pos_z_float_ena: bool = false,
    pos_w_float_ena: bool = false,
    front_face_ena: bool = false,
    ancillary_ena: bool = false,
    sample_coverage_ena: bool = false,
    pos_fixed_pt_ena: bool = false,
    _: u16 = 0,
};

pub const SpiPsInputAddr = SpiPsInputCntl;

pub const SpiPsInputCntl = packed struct(u32) {
    offset: u6,
    _: u2 = 0,
    default_val: PixelDefaultValue,
    flat_shade: bool,
    _2: u2 = 0,
    cyl_wrap: u4,
    pt_sprite_tex: bool,
    dup: bool,
    // NEO/VI only fields
    fp16_interp_mode: bool,
    use_default_attr1: bool,
    default_val_attr1: PixelDefaultValue,
    pt_sprite_tex_attr1: bool,
    attr0_valid: bool,
    attr1_valid: bool,
    _3: u6 = 0,

    pub const empty: SpiPsInputCntl = .{
        .offset = 0,
        .default_val = .@"0_0_0_0",
        .flat_shade = false,
        .cyl_wrap = 0,
        .pt_sprite_tex = false,
        .dup = false,
        .fp16_interp_mode = false,
        .use_default_attr1 = false,
        .default_val_attr1 = .@"0_0_0_0",
        .pt_sprite_tex_attr1 = false,
        .attr0_valid = false,
        .attr1_valid = false,
    };
};

pub const SpiPsInControl = packed struct(u32) {
    num_interp: u6,
    param_gen: bool,
    _: u7 = 0,
    bc_optimize_disable: bool,
    _2: u17 = 0,

    pub const empty: SpiPsInControl = .{
        .num_interp = 0,
        .param_gen = false,
        .bc_optimize_disable = false,
    };
};

pub const SpiShaderPgmRsrc1Ps = packed struct(u32) {
    vgprs: u6,
    sgprs: u4,
    priority: u2,
    float_mode: FloatMode,
    priv: bool,
    dx10_clamp: bool,
    debug_mode: bool,
    ieee_mode: bool,
    cu_group_disable: bool,
    cache_ctl: u3 = 0,
    cdbg_user: bool,
    _: u3 = 0,

    pub const empty: SpiShaderPgmRsrc1Ps = .{
        .vgprs = 0,
        .sgprs = 0,
        .priority = 0,
        .float_mode = @fromBackingInt(0),
        .priv = false,
        .dx10_clamp = false,
        .debug_mode = false,
        .ieee_mode = false,
        .cu_group_disable = false,
        .cache_ctl = 0,
        .cdbg_user = false,
    };
};

pub const SpiShaderPgmRsrc2Ps = packed struct(u32) {
    pub const ExceptionEnable = packed struct(u9) {
        invalid: bool = false,
        input_denormal: bool = false,
        divide_by_zero: bool = false,
        overflow: bool = false,
        underflow: bool = false,
        inexact: bool = false,
        int_divide_by_zero: bool = false,
        address_watch: bool = false,
        memory_violation: bool = false,
    };

    scratch_en: bool,
    user_sgpr: u5,
    trap_present: bool,
    wave_cnt_en: bool,
    extra_lds_size: u8,
    excp_en: ExceptionEnable,
    _: u7 = 0,

    pub const empty: SpiShaderPgmRsrc2Ps = .{
        .scratch_en = false,
        .user_sgpr = 0,
        .trap_present = false,
        .wave_cnt_en = false,
        .extra_lds_size = 0,
        .excp_en = .{},
    };
};

pub const SpiShaderPgmRsrc1Vs = packed struct(u32) {
    vgprs: u6,
    sgprs: u4,
    priority: u2,
    float_mode: FloatMode,
    priv: bool,
    dx10_clamp: bool,
    debug_mode: bool,
    ieee_mode: bool,
    vgpr_comp_cnt: u2,
    cu_group_enable: bool,
    cache_ctl: u3,
    cdbg_user: bool,
    _: u1 = 0,

    pub const empty: SpiShaderPgmRsrc1Vs = .{
        .vgprs = 0,
        .sgprs = 0,
        .priority = 0,
        .float_mode = @fromBackingInt(0),
        .priv = false,
        .dx10_clamp = false,
        .debug_mode = false,
        .ieee_mode = false,
        .vgpr_comp_cnt = 0,
        .cu_group_enable = false,
        .cache_ctl = 0,
        .cdbg_user = false,
    };
};

pub const SpiShaderPgmRsrc2Vs = packed struct(u32) {
    pub const ExceptionEnable = packed struct(u9) {
        invalid: bool = false,
        input_denormal: bool = false,
        divide_by_zero: bool = false,
        overflow: bool = false,
        underflow: bool = false,
        inexact: bool = false,
        int_divide_by_zero: bool = false,
        address_watch: bool = false,
        memory_violation: bool = false,
    };

    scratch_en: bool,
    user_sgpr: u5,
    trap_present: bool,
    oc_lds_en: bool,
    so_base0_en: bool,
    so_base1_en: bool,
    so_base2_en: bool,
    so_base3_en: bool,
    so_en: bool,
    excp_en: ExceptionEnable,
    _: u2 = 0,
    dispatch_draw_en: bool,
    _2: u7 = 0,

    pub const empty: SpiShaderPgmRsrc2Vs = .{
        .scratch_en = false,
        .user_sgpr = 0,
        .trap_present = false,
        .oc_lds_en = false,
        .so_base0_en = false,
        .so_base1_en = false,
        .so_base2_en = false,
        .so_base3_en = false,
        .so_en = false,
        .excp_en = .{},
        .dispatch_draw_en = false,
    };
};

pub const SpiShaderFormat = enum(u4) {
    none = 0,
    @"1comp" = 1,
    @"2comp" = 2,
    @"4compress" = 3,
    @"4comp" = 4,
};

pub const SpiShaderExFormat = enum(u4) {
    zero = 0,
    @"32_r" = 1,
    @"32_gr" = 2,
    @"32_ar" = 3,
    fp16_abgr = 4,
    unorm16_abgr = 5,
    snorm16_abgr = 6,
    uint16_abgr = 7,
    sint16_abgr = 8,
    @"32_abgr" = 9,
};

pub const SpiShaderColFormat = packed struct(u32) {
    col0_export_format: SpiShaderExFormat = .zero,
    col1_export_format: SpiShaderExFormat = .zero,
    col2_export_format: SpiShaderExFormat = .zero,
    col3_export_format: SpiShaderExFormat = .zero,
    col4_export_format: SpiShaderExFormat = .zero,
    col5_export_format: SpiShaderExFormat = .zero,
    col6_export_format: SpiShaderExFormat = .zero,
    col7_export_format: SpiShaderExFormat = .zero,
};

pub const SpiShaderPosFormat = packed struct(u32) {
    pos0_export_format: SpiShaderFormat = .none,
    pos1_export_format: SpiShaderFormat = .none,
    pos2_export_format: SpiShaderFormat = .none,
    pos3_export_format: SpiShaderFormat = .none,
    _: u16 = 0,
};

pub const SpiShaderZFormat = packed struct(u32) {
    z_export_format: SpiShaderExFormat,
    _: u28 = 0,

    pub const empty: SpiShaderZFormat = .{
        .z_export_format = .zero,
    };
};

pub const SpiVsOutConfig = packed struct(u32) {
    _: u1 = 0,
    vs_export_count: u5,
    vs_half_pack: bool,
    _2: u25 = 0,

    pub const empty: SpiVsOutConfig = .{
        .vs_export_count = 0,
        .vs_half_pack = false,
    };
};

pub const VgtDrawInitiator = packed struct(u32) {
    source_select: u2 = 0,
    major_mode: u2 = 0,
    sprite_en_r6xx: bool = false,
    not_eop: bool = false,
    use_opaque: bool = false,
    _: u25 = 0,
};

pub const VgtEventType = enum(u6) {
    reserved_0x00 = 0x00000000,
    sample_streamoutstats1 = 0x00000001,
    sample_streamoutstats2 = 0x00000002,
    sample_streamoutstats3 = 0x00000003,
    cache_flush_ts = 0x00000004,
    context_done = 0x00000005,
    cache_flush = 0x00000006,
    cs_partial_flush = 0x00000007,
    vgt_streamout_sync = 0x00000008,
    reserved_0x09 = 0x00000009,
    vgt_streamout_reset = 0x0000000a,
    end_of_pipe_incr_de = 0x0000000b,
    end_of_pipe_ib_end = 0x0000000c,
    rst_pix_cnt = 0x0000000d,
    reserved_0x0e = 0x0000000e,
    vs_partial_flush = 0x0000000f,
    ps_partial_flush = 0x00000010,
    flush_hs_output = 0x00000011,
    flush_ls_output = 0x00000012,
    reserved_0x13 = 0x00000013,
    cache_flush_and_inv_ts_event = 0x00000014,
    zpass_done = 0x00000015,
    cache_flush_and_inv_event = 0x00000016,
    perfcounter_start = 0x00000017,
    perfcounter_stop = 0x00000018,
    pipelinestat_start = 0x00000019,
    pipelinestat_stop = 0x0000001a,
    perfcounter_sample = 0x0000001b,
    flush_es_output = 0x0000001c,
    flush_gs_output = 0x0000001d,
    sample_pipelinestat = 0x0000001e,
    so_vgtstreamout_flush = 0x0000001f,
    sample_streamoutstats = 0x00000020,
    reset_vtx_cnt = 0x00000021,
    block_context_done = 0x00000022,
    cs_context_done = 0x00000023,
    vgt_flush = 0x00000024,
    tgid_rollover = 0x00000025,
    sq_non_event = 0x00000026,
    sc_send_db_vpz = 0x00000027,
    bottom_of_pipe_ts = 0x00000028,
    flush_sx_ts = 0x00000029,
    db_cache_flush_and_inv = 0x0000002a,
    flush_and_inv_db_data_ts = 0x0000002b,
    flush_and_inv_db_meta = 0x0000002c,
    flush_and_inv_cb_data_ts = 0x0000002d,
    flush_and_inv_cb_meta = 0x0000002e,
    cs_done = 0x0000002f,
    ps_done = 0x00000030,
    flush_and_inv_cb_pixel_data = 0x00000031,
    sx_cb_rat_ack_request = 0x00000032,
    thread_trace_start = 0x00000033,
    thread_trace_stop = 0x00000034,
    thread_trace_marker = 0x00000035,
    thread_trace_flush = 0x00000036,
    thread_trace_finish = 0x00000037,
    pixel_pipe_stat_control = 0x00000038,
    pixel_pipe_stat_dump = 0x00000039,
    pixel_pipe_stat_reset = 0x0000003a,
    context_suspend = 0x0000003b,
    offchip_hs_dealloc = 0x0000003c,
};

/// Generic abstraction of textures, render targets and buffers formats.
/// Formats are stored in texture specific formats since they emcompass all possible formats.
// TODO: get rid of paddings if and when everything is ported to Zig
pub const DataFormat = packed struct(u32) {
    surface: ImageFormat,
    _: u2 = 0,
    channel: ImgNumFormat,
    channel_x: Channel,
    channel_y: Channel,
    channel_z: Channel,
    channel_w: Channel,
    _2: u8 = 0,

    pub const r8g8b8a8_srgb: DataFormat = .{
        .surface = .@"8_8_8_8",
        .channel = .srgb,
        .channel_x = .x,
        .channel_y = .y,
        .channel_z = .z,
        .channel_w = .w,
    };
    pub const a8r8g8b8_srgb: DataFormat = .{
        .surface = .@"8_8_8_8",
        .channel = .srgb,
        .channel_x = .y,
        .channel_y = .z,
        .channel_z = .w,
        .channel_w = .x,
    };
    pub const a8b8g8r8_srgb: DataFormat = .{
        .surface = .@"8_8_8_8",
        .channel = .srgb,
        .channel_x = .w,
        .channel_y = .z,
        .channel_z = .y,
        .channel_w = .x,
    };
    pub const r16g16b16a16_float: DataFormat = .{
        .surface = .@"16_16_16_16",
        .channel = .float,
        .channel_x = .x,
        .channel_y = .y,
        .channel_z = .z,
        .channel_w = .w,
    };
    pub const a16b16g16r16_float: DataFormat = .{
        .surface = .@"16_16_16_16",
        .channel = .float,
        .channel_x = .w,
        .channel_y = .z,
        .channel_z = .y,
        .channel_w = .x,
    };
    pub const r32_uint: DataFormat = .{
        .surface = .@"32",
        .channel = .uint,
        .channel_x = .x,
        .channel_y = .constant_0,
        .channel_z = .constant_0,
        .channel_w = .constant_1,
    };
    pub const r32g32_float: DataFormat = .{
        .surface = .@"32_32",
        .channel = .float,
        .channel_x = .x,
        .channel_y = .y,
        .channel_z = .constant_0,
        .channel_w = .constant_1,
    };
    pub const r32g32b32_float: DataFormat = .{
        .surface = .@"32_32_32",
        .channel = .float,
        .channel_x = .x,
        .channel_y = .y,
        .channel_z = .z,
        .channel_w = .constant_1,
    };
    pub const r32g32b32a32_float: DataFormat = .{
        .surface = .@"32_32_32_32",
        .channel = .float,
        .channel_x = .x,
        .channel_y = .y,
        .channel_z = .z,
        .channel_w = .w,
    };
    pub const a2b10g10r10_float: DataFormat = .{
        .surface = .@"2_10_10_10",
        .channel = .float,
        .channel_x = .w,
        .channel_y = .z,
        .channel_z = .y,
        .channel_w = .x,
    };
    pub const a2b10g10r10_srgb: DataFormat = .{
        .surface = .@"2_10_10_10",
        .channel = .srgb,
        .channel_x = .w,
        .channel_y = .z,
        .channel_z = .y,
        .channel_w = .x,
    };

    pub const z_u16: DataFormat = .{
        .surface = .@"16",
        .channel = .unorm,
        .channel_x = .x,
        .channel_y = .constant_0,
        .channel_z = .constant_0,
        .channel_w = .constant_1,
    };
    pub const z_f32: DataFormat = .{
        .surface = .@"32",
        .channel = .float,
        .channel_x = .x,
        .channel_y = .constant_0,
        .channel_z = .constant_0,
        .channel_w = .constant_1,
    };
};

//
// GNM shader structures, not used directly by the GPU
//
// TODO: improve field names
pub const ShaderFileHeader = extern struct {
    pub const MAGIC: u32 = 0x72646853; // Shdr

    pub const Type = enum(u8) {
        vertex = 1,
        pixel = 2,
        geometry = 3,
        compute = 4,
        @"export" = 5,
        local = 6,
        hull = 7,
    };

    pub const TargetGpuMode = packed struct(u8) {
        base: bool = false,
        neo: bool = false,
        _: u6 = 0,
    };

    magic: u32 align(1) = ShaderFileHeader.MAGIC,
    version_major: u16,
    version_minor: u16,
    type: Type,
    shader_header_len_dwords: u8,
    has_shader_aux_data: u8,
    target_gpu_modes: TargetGpuMode,
    _: u32 = 0,
};
pub const InputUsageSlot = packed struct(u32) {
    pub const UsageType = enum(u8) {
        imm_resource = 0x0,
        imm_sampler = 0x1,
        imm_const_buffer = 0x2,
        imm_vertex_buffer = 0x3,
        imm_rw_resource = 0x4,
        imm_alu_float_const = 0x5,
        imm_alu_bool32_const = 0x6,
        imm_gds_counter_range = 0x7,
        imm_gds_memory_range = 0x8,
        imm_gws_base = 0x9,
        imm_shader_resource_table = 0xa,

        sub_ptr_fetch_shader = 0x12,
        ptr_resource_table = 0x13,
        ptr_internal_resource_table = 0x14,
        ptr_sampler_table = 0x15,
        ptr_const_buffer_table = 0x16,
        ptr_vertex_buffer_table = 0x17,
        ptr_so_buffer_table = 0x18,
        ptr_rw_resource_table = 0x19,
        ptr_internal_global_table = 0x1a,
        ptr_extended_user_data = 0x1b,
        ptr_indirect_resource_table = 0x1c,
        ptr_indirect_internal_resource_table = 0x1d,
        ptr_indirect_rw_resource_table = 0x1e,

        pub fn getNumRegisters(self: UsageType, using_large_resource: bool) u8 {
            return switch (self) {
                .imm_resource,
                .imm_rw_resource,
                .imm_shader_resource_table,
                => if (using_large_resource) 8 else 4,
                .imm_sampler,
                .imm_const_buffer,
                .imm_vertex_buffer,
                => 4,
                .imm_alu_float_const,
                .imm_alu_bool32_const,
                .imm_gds_counter_range,
                .imm_gds_memory_range,
                .imm_gws_base,
                => 1,
                .sub_ptr_fetch_shader,
                .ptr_resource_table,
                .ptr_internal_resource_table,
                .ptr_sampler_table,
                .ptr_const_buffer_table,
                .ptr_vertex_buffer_table,
                .ptr_so_buffer_table,
                .ptr_rw_resource_table,
                .ptr_internal_global_table,
                .ptr_extended_user_data,
                .ptr_indirect_resource_table,
                .ptr_indirect_internal_resource_table,
                .ptr_indirect_rw_resource_table,
                => 2,
            };
        }
    };

    pub const ResourceType = enum(u1) {
        buffer_or_pointer = 0,
        texture = 1,
    };

    usage_type: UsageType,
    api_slot: u8,
    start_register: u8,
    register_info: packed union {
        default: packed struct(u8) {
            using_large_resource: bool = false,
            resource_type: ResourceType = .buffer_or_pointer,
            _: u2 = 0,
            chunk_mask: u4 = 0,
        },
        shader_resource_table: packed struct(u8) {
            num_register_dwords_minus_one: u8,
        },
    },
};
pub const ShaderCommonData = packed struct(u64) {
    shader_len: u23,
    _: u1 = 0,
    num_input_usage_slots: u8,
    constant_buffer_len_dqwords: u16,
    scratch_size: u16,
};
pub const VsStageRegisters = extern struct {
    spi_shader_pgm_lo_vs: u32 align(1),
    spi_shader_pgm_hi_vs: u32,

    spi_shader_pgm_rsrc1_vs: SpiShaderPgmRsrc1Vs,
    spi_shader_pgm_rsrc2_vs: SpiShaderPgmRsrc2Vs,

    spi_vs_out_config: SpiVsOutConfig,
    spi_shader_pos_format: SpiShaderPosFormat,
    pa_cl_vs_out_cntl: PaClVsOutCntl,

    pub fn patchAddress(self: *VsStageRegisters, address: u56) void {
        self.spi_shader_pgm_lo_vs = @truncate(address >> 8);
        self.spi_shader_pgm_hi_vs = @truncate(address >> 40);
    }
};
pub const VsShader = extern struct {
    registers: VsStageRegisters,

    num_input_semantics: u8 align(1),
    num_export_semantics: u8,
    gs_mode_or_num_input_semantics_cs: u8,
    fetch_control: u8,
};
pub const PsStageRegisters = extern struct {
    spi_shader_pgm_lo_ps: u32 align(1),
    spi_shader_pgm_hi_ps: u32,

    spi_shader_pgm_rsrc1_ps: SpiShaderPgmRsrc1Ps,
    spi_shader_pgm_rsrc2_ps: SpiShaderPgmRsrc2Ps,

    spi_shader_z_format: SpiShaderZFormat,
    spi_shader_col_format: SpiShaderColFormat,

    spi_ps_input_ena: SpiPsInputEna,
    spi_ps_input_addr: SpiPsInputAddr,

    spi_ps_in_control: SpiPsInControl,
    spi_baryc_cntl: SpiBarycCntl,

    db_shader_control: DbShaderControl,
    cb_shader_mask: CbShaderMask,

    pub fn patchAddress(self: *PsStageRegisters, address: u56) void {
        self.spi_shader_pgm_lo_ps = @truncate(address >> 8);
        self.spi_shader_pgm_hi_ps = @truncate(address >> 40);
    }
};
pub const PsShader = extern struct {
    registers: PsStageRegisters,
    num_input_semantics: u8 align(1),
    _: [3]u8 = @splat(0),
};

pub const ComputePgmRsrc1 = packed struct(u32) {
    vgprs: u6,
    sgprs: u4,
    priority: u2,
    float_mode: FloatMode,
    priv: bool,
    dx10_clamp: bool,
    debug_mode: bool,
    ieee_mode: bool,
    bulky: bool,
    cdbg_user: bool,
    _: u6 = 0,
};

pub const ComputePgmRsrc2 = packed struct(u32) {
    pub const ExceptionEnable = packed struct(u7) {
        invalid: bool = false,
        input_denormal: bool = false,
        divide_by_zero: bool = false,
        overflow: bool = false,
        underflow: bool = false,
        inexact: bool = false,
        int_divide_by_zero: bool = false,
    };

    scratch_en: bool,
    user_sgpr: u5,
    trap_present: bool,
    tgid_x_en: bool,
    tgid_y_en: bool,
    tgid_z_en: bool,
    tg_size_en: bool,
    tidig_comp_cnt: u2,
    excp_en_msb: u2,
    lds_size: u9,
    excp_en: ExceptionEnable,
    _: u1 = 0,
};

pub const ComputeNumThread = packed struct(u32) {
    num_thread_full: u16,
    num_thread_partial: u16,
};

pub const CsStageRegisters = extern struct {
    compute_pgm_lo: u32,
    compute_pgm_hi: u32,

    compute_pgm_rsrc1: ComputePgmRsrc1,
    compute_pgm_rsrc2: ComputePgmRsrc2,

    compute_num_thread_x: ComputeNumThread,
    compute_num_thread_y: ComputeNumThread,
    compute_num_thread_z: ComputeNumThread,

    pub fn patchAddress(self: *CsStageRegisters, address: u56) void {
        self.compute_pgm_lo = @truncate(address >> 8);
        self.compute_pgm_hi = @truncate(address >> 40);
    }
};
pub const CsShader = extern struct {
    registers: CsStageRegisters,

    per_version: packed union(u8) {
        old: packed struct(u8) {
            ordered_append_mode: u8,
        },
        new: packed struct(u8) {
            ordered_append_mode: u2,
            num_input_semantics: u6,
        },
    },
    _2: u8 = 0,
    version: u8,
    _3: u8 = 0,
};

pub const ComputeDispatchInitiator = packed struct(u32) {
    pub const OrderedAppendMode = enum(u1) {
        index_per_wavefront = 0,
        index_per_thread_group = 1,
    };

    compute_shader_en: bool = false,
    partial_tg_en: bool = false,
    force_start_at_000: bool = false,
    ordered_append_enbl: bool = false,
    ordered_append_mode: OrderedAppendMode = .index_per_wavefront,
    use_thread_dimensions: bool = false,
    order_mode: bool = false,
    dispatch_cache_cntl: u3 = 0,
    scalar_l1_inv_vol: bool = false,
    vector_l1_inv_vol: bool = false,
    data_atc: bool = false,
    _: u1 = 0,
    restore: bool = false,
    _2: u17 = 0,
};

//
// GNM shader structures,
// not used directly by the GPU
//
// TODO: improve field names
pub const ShaderBinaryInfo = extern struct {
    pub const MAGIC = [7]u8{ 'O', 'r', 'b', 'S', 'h', 'd', 'r' };
    pub const CURRENT_VERSION = 7;

    pub const Type = enum(u4) {
        ps = 0,
        vs_vs = 1,
        vs_es = 2,
        vs_ls = 3,
        cs = 4,
        gs = 5,
        gs_vs = 6,
        hs = 7,
        ds_vs = 8,
        ds_es = 9,
    };

    magic: [7]u8 = MAGIC,
    version: u8 = CURRENT_VERSION,

    info: packed struct(u32) {
        is_pssl_or_cg: bool,
        is_source_cached: bool,
        type: Type,
        _: u2 = 0,
        length: u24,
    },

    chunk_usage_base_offset_dwords: u8,
    num_input_usage_slots: u8,

    srt: packed struct(u8) {
        has_shader_resource_tables: bool = false,
        is_srt_used_info_valid: bool = false,
        has_extended_usage_info: bool = false,
        source_hash_type: u2 = 0,
        _: u3 = 0,
    },

    footer_version: u8,
    association_hash: [2]u32,
    // CRC32 of whole shader until this field
    crc32: u32,
};

comptime {
    assert(@sizeOf(ShaderFileHeader) == 0x10);
    assert(@sizeOf(InputUsageSlot) == 0x4);
    assert(@sizeOf(ShaderCommonData) == 0x8);
    assert(@sizeOf(VsStageRegisters) == 0x1c);
    assert(@sizeOf(VsShader) == 0x20);
    assert(@sizeOf(PsStageRegisters) == 0x30);
    assert(@sizeOf(PsShader) == 0x34);
    assert(@sizeOf(CsStageRegisters) == 0x1c);
    assert(@sizeOf(CsShader) == 0x20);
    assert(@sizeOf(ShaderBinaryInfo) == 0x1c);
}

pub const MessageSeverity = enum(c_int) {
    warn = 0,
    err = 1,
};

pub extern fn gnmStrError(err: c_int) [*:0]const u8;
pub extern fn gnmSetMessageHandler(
    handlerfunc: *const fn (
        severity: MessageSeverity,
        message: [*:0]const u8,
        userdata: ?*void,
    ) callconv(.c) void,
    userdata: ?*void,
) void;

//
// fetch shader
// TODO: move to its own file
// TODO: implement it in zeeg
//
pub const FetchShaderCreateInfo = struct {
    vs_registers: VsStageRegisters,
    flags: Flags,

    input_usages: []const InputUsageSlot,
    vertex_inputs: []const VertexInputSemantic,
    remap_table: []const u32,
    instance_data: []const InstancingMode,

    vertex_base_user_sgpr: ?u4,
    instance_base_user_sgpr: ?u4,

    pub const Flags = enum(c_int) {
        none = 0,
        shift_overstep_0 = 1,
    };
    pub const InstancingMode = enum(c_int) {
        vertex_index = 0,
        instance_id = 1,
        instance_id_overstep_rate_0 = 2,
        instance_id_overstep_rate_1 = 3,
    };
};

pub const FetchShader = struct {
    code: []u8,
    sgprs: u4,
    vgpr_comp_cnt: u2,

    pub fn patchVertexShader(self: FetchShader, registers: *VsStageRegisters) void {
        registers.spi_shader_pgm_rsrc1_vs.sgprs = self.sgprs;
        registers.spi_shader_pgm_rsrc1_vs.vgpr_comp_cnt = self.vgpr_comp_cnt;
    }
};

pub const FetchShaderError = error{
    UnknownLength,
    GnmError,
} || mem.Allocator.Error;

pub fn createFetchShader(
    gpu_alloc: mem.Allocator,
    create_info: FetchShaderCreateInfo,
) FetchShaderError!FetchShader {
    const ci = FetchShaderCreateInfoInternal{
        .vs_registers = &create_info.vs_registers,
        .flags = create_info.flags,
        .input_usages = if (create_info.input_usages.len > 0) create_info.input_usages.ptr else null,
        .num_input_usages = @truncate(create_info.input_usages.len),
        .vertex_inputs = if (create_info.vertex_inputs.len > 0) create_info.vertex_inputs.ptr else null,
        .num_vertex_inputs = @truncate(create_info.vertex_inputs.len),
        .remap_table = if (create_info.remap_table.len > 0) create_info.remap_table.ptr else null,
        .num_remap_table_entries = @truncate(create_info.remap_table.len),
        .instance_data = if (create_info.instance_data.len > 0) create_info.instance_data.ptr else null,
        .num_instance_data_entries = @truncate(create_info.instance_data.len),
        .vertex_base_user_sgpr = if (create_info.vertex_base_user_sgpr) |sgpr| sgpr else 0,
        .instance_base_user_sgpr = if (create_info.instance_base_user_sgpr) |sgpr| sgpr else 0,
    };

    var byte_len: u32 = 0;
    var res = gnmFetchShaderCalcSize(&byte_len, &ci);
    if (res != 0) return error.UnknownLength;

    const memory = try gpu_alloc.alignedAlloc(u8, .fromByteUnits(ALIGNMENT_BUFFER_BYTES), byte_len);
    errdefer gpu_alloc.free(memory);

    var results: FetchShaderResults = undefined;
    res = gnmCreateFetchShader(memory.ptr, byte_len, &ci, &results);
    if (res != 0) {
        return error.GnmError;
    }

    return .{
        .sgprs = @truncate(results.sgprs),
        .vgpr_comp_cnt = @truncate(results.vgpr_comp_cnt),
        .code = memory,
    };
}

const FetchShaderCreateInfoInternal = extern struct {
    vs_registers: *const VsStageRegisters,
    flags: FetchShaderCreateInfo.Flags = .none,

    input_usages: ?[*]const InputUsageSlot,
    num_input_usages: u32,

    vertex_inputs: ?[*]const VertexInputSemantic,
    num_vertex_inputs: u32,

    remap_table: ?[*]const u32,
    num_remap_table_entries: u32,

    instance_data: ?[*]const FetchShaderCreateInfo.InstancingMode,
    num_instance_data_entries: u32,

    vertex_base_user_sgpr: u8,
    instance_base_user_sgpr: u8,
};
const FetchShaderResults = extern struct {
    sgprs: u32,
    vgpr_comp_cnt: u32,
};
extern fn gnmFetchShaderCalcSize(
    out_length: *u32,
    create_info: *const FetchShaderCreateInfoInternal,
) c_int;
extern fn gnmCreateFetchShader(
    out_data: *anyopaque,
    out_data_len: u32,
    create_info: *const FetchShaderCreateInfoInternal,
    results: *FetchShaderResults,
) c_int;

pub const GnmPlatParams = extern struct {
    gpu_mode: c_uint,
    get_buffer_label_address: ?*const fn (video_handle: i32, out_addr: *u64) callconv(.c) i32,
};
extern fn gnmPlatInit(params: *const GnmPlatParams) callconv(.c) void;
pub fn platInit(params: GnmPlatParams) void {
    gnmPlatInit(&params);
}

comptime {
    // force compilation
    _ = &@import("c_compat.zig");
}

const testing = std.testing;

test "gnm" {
    _ = &DrawCommandBuffer;
    _ = &psb;
    _ = &pm4;
    _ = &pm4.Reader;
    _ = &pm4.Writer;

    var count: u32 = 0;
    try testing.expect(runtests_fetchsh(&count));
    try testing.expect(runtests_gcn(&count));
    try testing.expect(runtests_gpuaddr(&count));
    try testing.expect(runtests_gnf(&count));
}

test "fnf" {
    var count: u32 = 0;
    try testing.expect(runtests_bmp(&count));
    try testing.expect(runtests_ktx(&count));
    try testing.expect(runtests_png(&count));
}

extern "C" fn runtests_fetchsh(passed_tests: *u32) bool;
extern "C" fn runtests_gcn(passed_tests: *u32) bool;
extern "C" fn runtests_gnf(passed_tests: *u32) bool;
extern "C" fn runtests_gpuaddr(passed_tests: *u32) bool;

extern "C" fn runtests_bmp(passed_tests: *u32) bool;
extern "C" fn runtests_ktx(passed_tests: *u32) bool;
extern "C" fn runtests_png(passed_tests: *u32) bool;
