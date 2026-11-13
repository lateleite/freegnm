#ifndef _GPU_ADDRESS_H_
#define _GPU_ADDRESS_H_

#include "gnm/types.h"
#include "gnm/rendertarget.h"
#include "gnm/texture.h"

#include "error.h"
#include "types.h"

//
// Element/Utility
//
typedef struct {
	GnmArrayMode array_mode;
	GnmNumBanks banks;
	GnmBankWidth bank_width;
	GnmBankHeight bank_height;
	GnmMacroTileAspect macro_aspect_ratio;
	GnmTileSplit tile_split;
	GnmPipeConfig pipe_config;
} GpaTileInfo;

GpaError gpaGetTileInfo(
    GpaTileInfo* outinfo, GnmTileMode tilemode, uint32_t bpp, uint32_t numfrags,
    GnmGpuMode gpumode
);
GpaError gpaComputeBaseSwizzle(
    uint32_t* outswizzle, GnmTileMode tilemode, uint32_t surfindex,
    uint32_t bpp, uint32_t numfrags, GnmGpuMode gpumode
);

//
// GNM and GPUAddr converters
//
typedef struct {
	GnmTextureType type;
	GnmDataFormat fmt;

	uint32_t width;
	uint32_t height;
	uint32_t pitch;
	uint32_t depth;

	uint32_t num_frags;
	uint32_t num_mips;
	uint32_t num_slices;

	GnmTileMode tile_mode;
	GnmGpuMode min_gpu_mode;

	bool power_of_2_pad;
} GpaTextureInfo;

static inline GpaTextureInfo gpaFromGnmTexture(const GnmTexture* tex) {
	return (GpaTextureInfo){
	    .type = tex->type,
	    .fmt = gnmTexGetFormat(tex),
	    .width = gnmTexGetWidth(tex),
	    .height = gnmTexGetHeight(tex),
	    .pitch = gnmTexGetPitch(tex),
	    .depth = gnmTexGetDepth(tex),
	    .num_frags = gnmTexGetNumFragments(tex),
	    .num_mips = gnmTexGetNumMips(tex),
	    .num_slices = gnmTexGetNumArraySlices(tex),
	    .tile_mode = tex->tiling_index,
	    .min_gpu_mode = tex->alt_tile_mode ? GNM_GPU_NEO : GNM_GPU_BASE,
	    .power_of_2_pad = tex->power_of_2_pad,
	};
}

static inline GpaTextureInfo gpaFromGnmRenderTarget(const GnmRenderTarget* rt) {
	return (GpaTextureInfo){
	    .type = GNM_TEXTURE_2D,
	    .fmt = gnmRtGetFormat(rt),
	    .width = gnmRtGetPitch(rt),
	    .height = gnmRtGetSliceSize(rt),
	    .pitch = gnmRtGetPitch(rt),
	    .depth = 1,
	    .num_frags = gnmRtGetNumFragments(rt),
	    .num_mips = 1,
	    .num_slices = 1,
	    .tile_mode = rt->attrib.tile_mode_index,
	    .min_gpu_mode = rt->info.alt_tile_mode ? GNM_GPU_NEO : GNM_GPU_BASE,
	    .power_of_2_pad = false,
	};
}

//
// Surface
//

// General surface
typedef struct {
	uint32_t color_target : 1;
	uint32_t depth_target : 1;
	uint32_t stencil_target : 1;
	uint32_t texture : 1;
	uint32_t cube : 1;
	uint32_t cube_as_array : 1;
	uint32_t volume : 1;
	uint32_t fmask : 1;
	uint32_t overlay : 1;
	uint32_t display : 1;
	uint32_t prt : 1;
	uint32_t power_of_2_pad : 1;
	uint32_t tc_compatible : 1;
	uint32_t _unused : 19;
} GpaSurfaceFlags;
_Static_assert(sizeof(GpaSurfaceFlags) == 0x4, "");

typedef struct {
	GnmTileMode tile_mode;
	GnmImageFormat image_format;
	GnmGpuMode min_gpu_mode;

	uint32_t linear_width;
	uint32_t linear_height;
	uint32_t linear_depth;
	uint32_t base_tiled_pitch;

	uint32_t num_frags_per_pixel;
	uint32_t bits_per_frag;

	uint32_t mip_level;
	uint32_t array_slice;

	GpaSurfaceFlags flags;
} GpaSurfaceDescription;

typedef struct {
	uint32_t pitch;
	uint32_t height;
	uint32_t depth;
	uint64_t surface_byte_size;
	uint32_t base_align;
	uint32_t pitch_align;
	uint32_t height_align;
	uint32_t depth_align;
	uint32_t bpp;

	uint32_t block_width;
	uint32_t block_height;

	GnmTileMode tile_mode;
	GpaTileInfo tile_info;

	struct {
		uint32_t tc_compatible : 1;
		uint32_t _unused : 31;
	};
} GpaSurfaceInfo;

GpaError gpaComputeSurfaceInfo(
    GpaSurfaceInfo* out, const GpaSurfaceDescription* desc
);

typedef struct {
	uint32_t pitch;
	uint32_t height;
	uint32_t num_slices;
	uint32_t num_frags;
	uint32_t bpp;

	GnmArrayMode array_mode;
	GnmNumBanks banks;
	GnmPipeConfig pipe_config;

	GnmGpuMode min_gpu_mode;

	struct {
		uint32_t tc_compatible : 1;
		uint32_t _reserved : 31;
	} flags;
} GpaHtileDescription;

typedef struct {
	uint32_t pitch;
	uint32_t height;
	uint32_t base_align;
	uint32_t bpp;
	uint32_t macro_width;
	uint32_t macro_height;
	uint64_t htile_byte_size;
	uint64_t slice_byte_size;
} GpaHtileInfo;

GpaError gpaComputeHtileInfo(
    GpaHtileInfo* outinfo, const GpaHtileDescription* desc
);

typedef struct {
	uint32_t pitch;
	uint32_t height;
	uint32_t num_slices;
	uint32_t num_frags;
	uint32_t bpp;
	GnmTileMode tile_mode;

	GnmGpuMode min_gpu_mode;

	struct {
		uint32_t tc_compatible : 1;
		uint32_t _reserved : 31;
	} flags;
} GpaCmaskDescription;

typedef struct {
	uint32_t pitch;
	uint32_t height;
	uint32_t base_align;
	uint32_t bpp;
	uint32_t macro_width;
	uint32_t macro_height;
	uint32_t block_max;
	uint64_t cmask_byte_size;
	uint64_t slice_byte_size;
} GpaCmaskInfo;

GpaError gpaComputeCmaskInfo(
    GpaCmaskInfo* outinfo, const GpaCmaskDescription* desc
);

// FMask surface
typedef struct {
	GnmTileMode tile_mode;
	GnmGpuMode min_gpu_mode;

	uint32_t pitch;
	uint32_t height;
	uint32_t num_slices;
	uint32_t num_frags;
	uint32_t num_samples;
} GpaFmaskDescription;

typedef struct {
	uint32_t pitch;
	uint32_t height;

	uint32_t base_align;
	uint32_t pitch_align;
	uint32_t height_align;

	uint32_t bits_per_pixel;
	uint64_t fmask_byte_size;
	uint64_t slice_byte_size;
} GpaFmaskInfo;

GpaError gpaComputeFmaskInfo(
    GpaFmaskInfo* outinfo, const GpaFmaskDescription* desc
);

GpaError gpaComputeSurfaceTileMode(
    GnmTileMode* outtilemode, GnmGpuMode mingpumode, GnmArrayMode arraymode,
    GpaSurfaceFlags flags, GnmDataFormat surfacefmt, uint32_t numfragsperpixel,
    GnmMicroTileMode mtm
);

typedef struct {
	GnmGpuMode min_gpu_mode;
	GnmTileMode tile_mode;
	GpaTileInfo tile_info;

	uint32_t linear_width;
	uint32_t linear_height;
	uint32_t linear_depth;
	uint32_t padded_width;
	uint32_t padded_height;
	uint32_t padded_depth;

	uint32_t bits_per_element;
	uint32_t num_frags_per_pixel;

	uint32_t bank_swizzle_mask;
	uint32_t pipe_swizzle_mask;
} GpaSurfaceContext;

GpaError gpaInitSurfaceContext(
    GpaSurfaceContext* ctx, size_t surfsize, const GpaSurfaceDescription* tp
);
GpaError gpaComputeSurfaceCoord(
    uint64_t* outoffset, uint64_t* outbitoffset, const GpaSurfaceContext* ctx,
    uint32_t x, uint32_t y, uint32_t z, uint32_t fragindex
);
GpaError gpaComputeSurfaceSizeOffset(
    uint64_t* outsize, uint64_t* outoffset, const GpaTextureInfo* tex,
    uint32_t miplevel, uint32_t arrayslice
);

//
// Surface generation
//
typedef struct {
	GnmTileMode tile_mode;
	GpaSurfaceFlags flags;
} GpaSurfaceProperties;

GpaError gpaFindOptimalSurface(
    GpaSurfaceProperties* outprops, GpaSurfaceType surfacetype, uint32_t bpp,
    uint32_t numfrags, bool mipmapped, GnmGpuMode mingpumode
);

//
// Decompression
//
GpaError gpaGetDecompressedSize(
    uint64_t* outlen, const GpaTextureInfo* texinfo
);
GpaError gpaDecompressTexture(
    void* outbuf, uint64_t outlen, const void* inbuf, uint64_t inlen,
    const GpaTextureInfo* texinfo, GnmDataFormat* outfmt
);

//
// Tiler
//
typedef struct {
	uint32_t left;	 // -X
	uint32_t top;	 // -Y
	uint32_t front;	 // -Z

	uint32_t right;	  // +X
	uint32_t bottom;  // +Y
	uint32_t back;	  // +Z
} GpaSurfaceRegion;

GpaError gpaSurfaceDescInit(
    GpaSurfaceDescription* tp, const GpaTextureInfo* tex, uint32_t miplevel,
    uint32_t arrayslice
);

GpaError gpaTileSurface(
    void* outbuf, size_t outlen, const void* inbuf, size_t inlen,
    const GpaSurfaceDescription* srctp, const GpaSurfaceDescription* dst_tp
);
GpaError gpaTileSurfaceRegion(
    void* outbuf, size_t outlen, const void* inbuf, size_t inlen,
    const GpaSurfaceDescription* srctp, const GpaSurfaceDescription* dst_tp,
    const GpaSurfaceRegion* region
);
GpaError gpaTileTextureIndexed(
    const void* inbuf, size_t inlen, void* outbuf, size_t outlen,
    const GpaTextureInfo* texinfo, GnmTileMode newtiling, uint32_t mip,
    uint32_t slice
);
GpaError gpaTileTextureAll(
    const void* inbuf, size_t inlen, void* outbuf, size_t outlen,
    const GpaTextureInfo* texinfo, GnmTileMode newtiling
);

#endif	// _GPU_ADDRESS_H_
