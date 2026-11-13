#ifndef _GNM_RENDERTARGET_H_
#define _GNM_RENDERTARGET_H_

#include "dataformat.h"
#include "error.h"

#include "gpuaddr/types.h"

typedef struct {
	uint32_t enable_cmask_fastclear : 1;
	uint32_t enable_fmask_compression : 1;
	uint32_t enable_colortexture_without_decompress : 1;
	uint32_t enable_fmasktexture_without_decompress : 1;
	uint32_t enable_dcc_compression : 1;
	uint32_t _unused : 27;
} GnmRenderTargetCreateInfoFlags;

typedef struct {
	GnmDataFormat color_fmt;

	uint32_t width;
	uint32_t height;
	uint32_t pitch;
	uint32_t num_slices;

	uint32_t num_samples;
	uint32_t num_fragments;

	GnmTileMode color_tile_mode_hint;
	GnmGpuMode min_gpu_mode;
	GnmRenderTargetCreateInfoFlags flags;
} GnmRenderTargetCreateInfo;

typedef struct {
	uint32_t base_base256b;	 // register 0

	union {
		struct {
			uint32_t tile_max : 11;
			uint32_t _unused : 9;
			uint32_t fmask_tile_max : 11;
			uint32_t _unused2 : 1;
		};
		uint32_t asuint;
	} pitch;  // register 1

	union {
		struct {
			uint32_t tile_max : 22;
			uint32_t _unused : 10;
		};
		uint32_t asuint;
	} slice;  // register 2

	union {
		struct {
			uint32_t slice_start : 11;
			uint32_t _unused : 2;
			uint32_t slice_max : 11;
			uint32_t _unused2 : 8;
		};
		uint32_t asuint;
	} view;	 // register 3

	union {
		struct {
			uint32_t _unused : 2;  // 0

			uint32_t format : 5;  // 3

			uint32_t _unused2 : 1;	// 7

			GnmSurfaceNumber channel_type : 3;  // 8
			GnmSurfaceSwap channel_order : 2;   // 11
			uint32_t fast_clear : 1;	   // 13
			uint32_t compression : 1;	   // 14
			uint32_t is_normalized : 1;	   // 15
			uint32_t is_int : 1;		   // 16

			uint32_t _unused3 : 1;	// 17

			uint32_t is_scaled : 1;	       // 18
			uint32_t cmask_is_linear : 1;  // 19

			uint32_t _unused4 : 6;	// 20

			uint32_t fmask_compression_mode : 2;  // 26
			uint32_t dcc_enable : 1;	      // 28
			uint32_t cmask_addr_type : 2;	      // 29
			uint32_t alt_tile_mode : 1;	      // 31
		};
		uint32_t asuint;
	} info;	 // register 4

	union {
		struct {
			GnmTileMode tile_mode_index : 5;
			GnmTileMode fmask_tile_mode_index : 5;
			uint32_t _unused : 2;
			uint32_t num_samples : 3;
			uint32_t num_fragments : 2;
			uint32_t force_dst_alpha_1 : 1;
			uint32_t _unused2 : 14;
		};
		uint32_t asuint;
	} attrib;  // register 5

	union {
		struct {
			uint32_t overwrite_combine_disabler : 1;
			uint32_t _unused : 1;
			uint32_t max_uncompressed_blocksize : 2;
			uint32_t min_compressed_blocksize : 1;
			uint32_t max_compressed_blocksize : 2;
			uint32_t color_transform : 2;
			uint32_t independent_64b_blocks : 1;
			uint32_t _unused5 : 22;
		};
		uint32_t asuint;
	} dcc_control;	// register 6

	uint32_t cmask_base256b;  // register 7
	union {
		struct {
			uint32_t tile_max : 14;
			uint32_t _unused : 18;
		};
		uint32_t asuint;
	} cmask_slice;	// register 8

	uint32_t fmask_base256b;  // register 9
	union {
		struct {
			uint32_t tile_max : 22;
			uint32_t _unused : 10;
		};
		uint32_t asuint;
	} fmask_slice;	// register 10

	uint32_t clear_word0;  // register 11
	uint32_t clear_word1;  // register 12

	uint32_t dccbase_base256b;  // register 13

	uint32_t _unusedreg;  // register 14

	union {
		struct {
			uint16_t width;
			uint16_t height;
		};
		uint32_t asuint;
	} size;	 // (not a GPU register) register 15
} GnmRenderTarget;
_Static_assert(sizeof(GnmRenderTarget) == 0x40, "");

static inline void* gnmRtGetBaseAddr(const GnmRenderTarget* rt) {
	return (void*)((uintptr_t)rt->base_base256b << 8);
}
static inline void gnmRtSetBaseAddr(GnmRenderTarget* rt, void* baseaddr) {
	rt->base_base256b = ((uintptr_t)baseaddr >> 8);
}

static inline uint32_t gnmRtGetPitch(const GnmRenderTarget* rt) {
	return (rt->pitch.tile_max + 1) * 8;
}
static inline uint32_t gnmRtGetSliceSize(const GnmRenderTarget* rt) {
	return (rt->slice.tile_max + 1) * 64 / gnmRtGetPitch(rt);
}
static inline uint32_t gnmRtGetNumSlices(const GnmRenderTarget* rt) {
	return rt->view.slice_max + 1;
}

static inline uint8_t gnmRtGetNumSamples(const GnmRenderTarget* rt) {
	return 1 << rt->attrib.num_samples;
}
static inline uint8_t gnmRtGetNumFragments(const GnmRenderTarget* rt) {
	return 1 << rt->attrib.num_fragments;
}

GnmError gnmCreateRenderTarget(
    GnmRenderTarget* rt, const GnmRenderTargetCreateInfo* createinfo
);

GnmDataFormat gnmRtGetFormat(const GnmRenderTarget* rt);

GnmError gnmRtCalcByteSize(
    uint64_t* outsize, uint32_t* outalign, const GnmRenderTarget* rt
);

#endif	// _GNM_RENDERTARGET_H_
