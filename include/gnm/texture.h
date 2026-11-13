#ifndef _GNM_TEXTURE_H_
#define _GNM_TEXTURE_H_

#include "dataformat.h"
#include "error.h"
#include "types.h"

#include "gpuaddr/types.h"

typedef struct {
	GnmDataFormat format;
	GnmTextureType texture_type;
	uint32_t width;
	uint32_t height;
	uint32_t depth;
	uint32_t pitch;

	uint32_t num_mip_levels;
	uint32_t num_slices;
	uint32_t num_fragments;

	GnmTileMode tile_mode_hint;
	GnmGpuMode min_gpu_mode;
} GnmTextureCreateInfo;

//
// texture resource
//
typedef struct {
	// register 0
	// 256 byte aligned, also use for fmask-ptr.
	uint32_t base_address;

	// register 1
	// NOTE: in the CI ISA, the 32-40 bits of this resource are also for the
	// base address, but they seem to have a different purpose according to
	// reverse engineered GNM.
	// NOTE: 6 high bits of baseaddress are unused
	uint32_t base_address_hi : 6;
	// values for this:
	// 0x0 - no coherency
	// 0x1 - GPU coherent
	// 0x2 - System coherent
	// 0x3 - Both GPU and System coherent
	uint32_t mtype_l2 : 2;
	uint32_t min_lod : 12;
	// surface format
	GnmImageFormat data_format : 6;
	// channel type
	GnmImgNumFormat num_format : 4;
	// memory type, controls cache behavior
	// if enabled, uses L1 cache LRU
	uint32_t mtype0 : 2;

	// register 2
	uint32_t width : 14;
	uint32_t height : 14;
	uint32_t perf_mod : 3;
	uint32_t interlaced : 1;

	// register 3
	// channel X to W
	GnmChannel dst_sel_x : 3;	 // 0
	GnmChannel dst_sel_y : 3;	 // 3
	GnmChannel dst_sel_z : 3;	 // 6
	GnmChannel dst_sel_w : 3;	 // 9
	// base mip level
	uint32_t base_level : 4;	 // 12
	// last mip level, or number of fragments/samples for MSAA
	uint32_t last_level : 4;	 // 16
	// tile mode
	GnmTileMode tiling_index : 5;  // 20
	// memory footpring is padded to pow2 dimensions
	uint32_t power_of_2_pad : 1;  // 25
	// if enabled, texture is read only
	uint32_t mtype2 : 1;	  // 26
	uint32_t atc : 1;	  // 27
	GnmTextureType type : 4;  // 28

	// register 4
	uint32_t depth : 13;
	uint32_t pitch : 14;
	uint32_t _unused : 5;

	// register 5
	uint32_t base_array : 13;
	uint32_t last_array : 13;
	uint32_t _unused2 : 6;

	// register 6
	uint32_t min_lod_warn : 12;    // 0
	uint32_t counter_bank_id : 8;  // 12
	uint32_t lod_hdw_cnt_en : 1;    // 20
	// gfx8 only attributes
	uint32_t compression_en : 1;   // 21
	uint32_t alpha_is_on_msb : 1;    // 22
	uint32_t color_transform : 1;  // 23
	// NEO only attribute,
	// reverse engineered and not in public registers
	// TODO: test it on real hardware
	uint32_t alt_tile_mode : 1;  // 24
	uint32_t _unused3 : 7;	   // 25

	// register 7
	uint32_t metadata_addr;
} GnmTexture;
_Static_assert(sizeof(GnmTexture) == 0x20, "");

static inline void* gnmTexGetBaseAddress(const GnmTexture* tex) {
	return (void*)((uintptr_t)tex->base_address << 8);
}
void gnmTexSetBaseAddress(GnmTexture* tex, void* baseaddr);

static inline GnmDataFormat gnmTexGetFormat(const GnmTexture* tex) {
	return (GnmDataFormat){
	    .surfacefmt = tex->data_format,
	    .chantype = tex->num_format,
	    .chanx = tex->dst_sel_x,
	    .chany = tex->dst_sel_y,
	    .chanz = tex->dst_sel_z,
	    .chanw = tex->dst_sel_w,
	};
}
static inline void gnmTexSetFormat(GnmTexture* tex, GnmDataFormat df) {
	tex->data_format = df.surfacefmt;
	tex->num_format = df.chantype;
	tex->dst_sel_x = df.chanx;
	tex->dst_sel_y = df.chany;
	tex->dst_sel_z = df.chanz;
	tex->dst_sel_w = df.chanw;
}

static inline uint32_t gnmTexGetWidth(const GnmTexture* tex) {
	return tex->width + 1;
}
static inline void gnmTexSetWidth(GnmTexture* tex, uint32_t width) {
	tex->width = width - 1;
}
static inline uint32_t gnmTexGetHeight(const GnmTexture* tex) {
	return tex->height + 1;
}
static inline void gnmTexSetHeight(GnmTexture* tex, uint32_t height) {
	tex->height = height - 1;
}
static inline uint32_t gnmTexGetDepth(const GnmTexture* tex) {
	return tex->depth + 1;
}
static inline void gnmTexSetDepth(GnmTexture* tex, uint32_t depth) {
	tex->depth = depth - 1;
}
static inline uint32_t gnmTexGetPitch(const GnmTexture* tex) {
	return tex->pitch + 1;
}
static inline void gnmTexSetPitch(GnmTexture* tex, uint32_t pitch) {
	tex->pitch = pitch - 1;
}

static inline uint32_t gnmTexGetBaseMipLevel(const GnmTexture* tex) {
	if (tex->type == GNM_TEXTURE_2D_MSAA ||
	    tex->type == GNM_TEXTURE_2D_ARRAY_MSAA) {
		return 0;
	}
	return tex->base_level;
}
static inline uint32_t gnmTexGetLastMipLevel(const GnmTexture* tex) {
	if (tex->type == GNM_TEXTURE_2D_MSAA ||
	    tex->type == GNM_TEXTURE_2D_ARRAY_MSAA) {
		return 0;
	}
	return tex->last_level;
}
static inline uint32_t gnmTexGetNumMips(const GnmTexture* tex) {
	return gnmTexGetLastMipLevel(tex) + 1;
}
static inline uint32_t gnmTexGetNumFaces(const GnmTexture* tex) {
	return tex->type == GNM_TEXTURE_CUBEMAP ? 6 : 1;
}
static inline uint32_t gnmTexGetTotalArraySlices(const GnmTexture* tex) {
	return tex->type == GNM_TEXTURE_3D ? 1 : gnmTexGetDepth(tex);
}
uint32_t gnmTexGetNumArraySlices(const GnmTexture* tex);

static inline uint8_t gnmTexGetNumFragments(const GnmTexture* tex) {
	if (tex->type == GNM_TEXTURE_2D_MSAA ||
	    tex->type == GNM_TEXTURE_2D_ARRAY_MSAA) {
		return 1 << tex->last_level;
	}
	return 1;
}

static inline void gnmTexSetMemoryType(
    GnmTexture* tex, GnmMemoryType memtype, bool l1cachebypass
) {
	tex->mtype_l2 = memtype & 0x3;
	tex->mtype0 = !l1cachebypass;
	tex->mtype2 = (memtype & GNM_MEMORY_READONLY) == GNM_MEMORY_READONLY;
}

GnmError gnmCreateTexture(
    GnmTexture* tex, const GnmTextureCreateInfo* createinfo
);

GnmError gnmTexCalcByteSize(
    uint64_t* outsize, uint32_t* outalignment, const GnmTexture* tex
);

#endif	// _GNM_TEXTURE_H_
