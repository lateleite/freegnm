#include "gnm/depthrendertarget.h"

#include "gnm/gpuaddr/error.h"
#include "gnm/gpuaddr/gpuaddr.h"
#include "gnm/platform.h"

#include "u/utility.h"

static GnmError inithtile(
    GnmDepthRenderTarget* drt, const GnmDepthRenderTargetCreateInfoFlags flags,
    uint32_t numslices
) {
	const GnmGpuMode mingpumode = gnmDrtGetMinGpuMode(drt);

	if (gnmGpuMode() == GNM_GPU_NEO && mingpumode == GNM_GPU_BASE) {
		return GNM_ERROR_INVALID_STATE;
	}

	drt->z_info.tile_surface_enable = true;

	const GpaHtileDescription hdesc = {
	    .pitch = gnmDrtGetPaddedWidth(drt),
	    .height = gnmDrtGetPaddedHeight(drt),
	    .num_slices = numslices,
	    .num_frags = gnmDrtGetNumFragments(drt),
	    .bpp = 32,
	    .array_mode = drt->depth_info.array_mode,
	    .banks = drt->depth_info.num_banks,
	    .pipe_config = drt->depth_info.pipe_config,

	    .min_gpu_mode = mingpumode,
	    .flags = {
		.tc_compatible = mingpumode == GNM_GPU_NEO,
	    },
	};
	GpaHtileInfo hinfo = {0};
	GpaError gerr = gpaComputeHtileInfo(&hinfo, &hdesc);
	if (gerr != GPA_ERR_OK) {
		return GNM_ERROR_INTERNAL_FAILURE;
	}

	const uint32_t numfrags = gnmDrtGetNumFragments(drt);

	if (flags.enable_texture_without_decompress &&
	    gnmDrtGetMinGpuMode(drt) == GNM_GPU_NEO && numfrags == 1) {
		const GnmTileMode tilemode = drt->z_info.tile_mode_index;
		if (tilemode == GNM_TM_THIN_1D_THIN) {
			return GNM_ERROR_UNSUPPORTED;
		}

		drt->htile_surface.tc_compatible = true;

		const GnmZFormat zfmt = drt->z_info.format;

		uint16_t unk = 0;
		if (zfmt == GNM_Z_16) {
			unk = 1;
		} else {
			if (numfrags != 1) {
				unk = (numfrags < 8) | 2;
			} else {
				unk = 5;
			}
		}

		drt->z_info._unused3 = unk;
	}

	return GNM_ERROR_OK;
}

GnmError gnmCreateDepthRenderTarget(
    GnmDepthRenderTarget* drt, const GnmDepthRenderTargetCreateInfo* ci
) {
	if (!drt || !ci) {
		return GNM_ERROR_INVALID_ARGS;
	}

	if (ci->z_format == GNM_Z_INVALID &&
	    ci->stencil_format == GNM_STENCIL_INVALID) {
		return GNM_ERROR_INVALID_ARGS;
	}
	if (ci->width < 1 || ci->width > 16384) {
		return GNM_ERROR_INVALID_ARGS;
	}
	if (ci->height < 1 || ci->height > 16384) {
		return GNM_ERROR_INVALID_ARGS;
	}
	if (gnmGpuMode() == GNM_GPU_NEO && ci->min_gpu_mode == GNM_GPU_BASE &&
	    ci->flags.enable_htile_acceleration) {
		return GNM_ERROR_UNSUPPORTED;
	}
	if (ci->num_fragments != 1 &&
	    ci->flags.enable_texture_without_decompress) {
		return GNM_ERROR_UNSUPPORTED;
	}

	*drt = (GnmDepthRenderTarget){0};

	drt->depth_view.slice_start = 0;
	drt->depth_view.slice_max = ci->num_slices - 1;

	gnmDrtSetNumFragments(drt, ci->num_fragments);
	drt->z_info.z_range_precision = true;

	GnmTileMode actualtilemode =
	    (ci->min_gpu_mode == GNM_GPU_NEO &&
	     ci->flags.enable_htile_acceleration &&
	     ci->flags.enable_texture_without_decompress)
		? GNM_TM_DEPTH_2D_THIN_1K
		: ci->tile_mode_hint;
	uint32_t actualpitch = ci->width;
	uint32_t actualheight = ci->height;
	if (ci->z_format != GNM_Z_INVALID) {
		const GnmDataFormat zdf = gnmDfInitFromZ(ci->z_format);
		const uint32_t numtexels = gnmDfGetTexelsPerElement(zdf);
		const uint32_t numtotalbits = gnmDfGetTotalBitsPerElement(zdf);

		const GpaSurfaceDescription desc = {
		    .tile_mode = actualtilemode,
		    .image_format = zdf.surfacefmt,
		    .min_gpu_mode = ci->min_gpu_mode,

		    .linear_width = actualpitch,
		    .linear_height = actualheight,
		    .linear_depth = 1,
		    .base_tiled_pitch = ci->pitch,

		    .num_frags_per_pixel = ci->num_fragments,
		    .bits_per_frag = numtotalbits / numtexels,

		    .mip_level = 0,
		    .array_slice = 0,
		    .flags = {
			.depth_target = 1,
			.tc_compatible = ci->min_gpu_mode == GNM_GPU_NEO,
		    },
		};
		GpaSurfaceInfo surfinfo = {0};
		GpaError err = gpaComputeSurfaceInfo(&surfinfo, &desc);
		if (err != GPA_ERR_OK) {
			return GNM_ERROR_INTERNAL_FAILURE;
		}

		actualtilemode = surfinfo.tile_mode;
		actualpitch = umax(actualpitch, surfinfo.pitch);
		actualheight = umax(actualheight, surfinfo.height);
	}
	if (ci->stencil_format != GNM_STENCIL_INVALID) {
		const GnmDataFormat sdf = gnmDfInitFromStencil(
		    ci->stencil_format, GNM_IMG_NUM_FORMAT_UINT
		);
		const uint32_t numtexels = gnmDfGetTexelsPerElement(sdf);
		const uint32_t numtotalbits = gnmDfGetTotalBitsPerElement(sdf);

		const GpaSurfaceDescription desc = {
		    .tile_mode = actualtilemode,
		    .image_format = sdf.surfacefmt,
		    .min_gpu_mode = ci->min_gpu_mode,

		    .linear_width = actualpitch,
		    .linear_height = actualheight,
		    .linear_depth = 1,
		    .base_tiled_pitch = ci->pitch,

		    .num_frags_per_pixel = ci->num_fragments,
		    .bits_per_frag = numtotalbits / numtexels,

		    .mip_level = 0,
		    .array_slice = 0,
		    .flags = {
			.stencil_target = 1,
			.tc_compatible = ci->min_gpu_mode == GNM_GPU_NEO,
		    },
		};
		GpaSurfaceInfo surfinfo = {0};
		GpaError err = gpaComputeSurfaceInfo(&surfinfo, &desc);
		if (err != GPA_ERR_OK) {
			return GNM_ERROR_INTERNAL_FAILURE;
		}

		actualtilemode = surfinfo.tile_mode;
		actualpitch = umax(actualpitch, surfinfo.pitch);
		actualheight = umax(actualheight, surfinfo.height);
	}

	drt->z_info.format = ci->z_format;
	drt->stencil_info.format = ci->stencil_format;
	drt->stencil_info.tile_stencil_disable = true;

	gnmDrtSetWidth(drt, ci->width);
	gnmDrtSetHeight(drt, ci->height);

	GnmError gerr = gnmDrtSetPaddedWidth(drt, actualpitch);
	if (gerr != GNM_ERROR_OK) {
		return GNM_ERROR_INTERNAL_FAILURE;
	}
	gerr = gnmDrtSetPaddedHeight(drt, actualheight);
	if (gerr != GNM_ERROR_OK) {
		return GNM_ERROR_INTERNAL_FAILURE;
	}
	gnmDrtSetSliceSize(drt, actualpitch, actualheight);

	drt->depth_info.pipe_config = ci->min_gpu_mode == GNM_GPU_NEO
					  ? GNM_ADDR_SURF_P16_32x32_8x16
					  : GNM_ADDR_SURF_P8_32x32_8x16;

	gerr = gnmDrtSetTileMode(drt, actualtilemode);
	if (gerr != GNM_ERROR_OK) {
		return gerr;
	}

	if (ci->flags.enable_htile_acceleration) {
		gerr = inithtile(drt, ci->flags, ci->num_slices);
		if (gerr != GNM_ERROR_OK) {
			return gerr;
		}
	}

	return GNM_ERROR_OK;
}

GnmError gnmDrtCalcByteSize(
    uint64_t* outsize, uint32_t* outalignment, const GnmDepthRenderTarget* drt
) {
	if (!drt) {
		return GNM_ERROR_INVALID_ARGS;
	}

	const GnmDataFormat dfmt = gnmDfInitFromZ(drt->z_info.format);
	const GnmGpuMode mingpumode = gnmDrtGetMinGpuMode(drt);
	const uint32_t numtexels = gnmDfGetTexelsPerElement(dfmt);
	const uint32_t numtotalbits = gnmDfGetTotalBitsPerElement(dfmt);

	const GpaSurfaceDescription desc = {
	    .tile_mode = drt->z_info.tile_mode_index,
	    .image_format = dfmt.surfacefmt,
	    .min_gpu_mode = mingpumode,

	    .linear_width = gnmDrtGetPaddedWidth(drt),
	    .linear_height = gnmDrtGetPaddedHeight(drt),
	    .linear_depth = 1,
	    .base_tiled_pitch = gnmDrtGetPaddedWidth(drt),

	    .num_frags_per_pixel = gnmDrtGetNumFragments(drt),
	    .bits_per_frag = numtotalbits / numtexels,

	    .mip_level = 0,
	    .array_slice = 0,
	    .flags = {
		.depth_target = 1,
	    },
	};
	GpaSurfaceInfo surfinfo = {0};
	GpaError err = gpaComputeSurfaceInfo(&surfinfo, &desc);
	if (err != GPA_ERR_OK) {
		gnmWriteMsgf(
		    GNM_MSGSEV_WARN,
		    "Drt: failed to compute surface info with %s",
		    gpaStrError(err)
		);
		return GNM_ERROR_INTERNAL_FAILURE;
	}

	const uint32_t numslices = gnmDrtGetNumSlices(drt);
	const uint64_t totalsurfsize = surfinfo.surface_byte_size * (numslices);
	if (outsize) {
		*outsize = totalsurfsize;
	}
	if (outalignment) {
		*outalignment = surfinfo.base_align;
	}
	return GNM_ERROR_OK;
}

GnmError gnmDrtSetTileMode(GnmDepthRenderTarget* drt, GnmTileMode mode) {
	if (!drt || mode > GNM_TM_DEPTH_2D_THIN_PRT_1K) {
		return GNM_ERROR_INVALID_ARGS;
	}
	if (drt->depth_info.pipe_config < GNM_ADDR_SURF_P8_32x32_8x16 ||
	    drt->depth_info.pipe_config > GNM_ADDR_SURF_P16_32x32_8x16) {
		return GNM_ERROR_INVALID_STATE;
	}

	const GnmGpuMode gpumode = gnmDrtGetMinGpuMode(drt);
	const GnmDataFormat fmt = gnmDfInitFromZ(drt->z_info.format);
	const uint32_t bitsperelem = gnmGetBitsPerElement(fmt.surfacefmt);
	const uint32_t numsamples = gnmDrtGetNumFragments(drt);

	GpaTileInfo tileinfo = {0};
	GpaError err =
	    gpaGetTileInfo(&tileinfo, mode, bitsperelem, numsamples, gpumode);
	if (err != GPA_ERR_OK) {
		return GNM_ERROR_INTERNAL_FAILURE;
	}

	drt->z_info.tile_mode_index = mode;
	drt->z_info.tile_split = tileinfo.tile_split;

	drt->stencil_info.tile_mode_index = mode;
	drt->stencil_info.tile_split = tileinfo.tile_split;

	drt->depth_info.array_mode = tileinfo.array_mode;
	drt->depth_info.pipe_config = tileinfo.pipe_config;
	drt->depth_info.bank_width = tileinfo.bank_width;
	drt->depth_info.bank_height = tileinfo.bank_height;
	drt->depth_info.macro_tile_aspect = tileinfo.macro_aspect_ratio;
	drt->depth_info.num_banks = tileinfo.banks;
	return GNM_ERROR_OK;
}

static inline GpaError getswizzlemask(
    uint32_t* outmask, const GnmDepthRenderTarget* drt
) {
	const GnmTileMode tm = drt->z_info.tile_mode_index;
	const GnmDataFormat dfmt = gnmDfInitFromZ(drt->z_info.format);
	const GnmGpuMode mingpumode = gnmDrtGetMinGpuMode(drt);
	const uint32_t bitsperelem = gnmGetBitsPerElement(dfmt.surfacefmt);
	const uint32_t numfrags = gnmDrtGetNumFragments(drt);

	return gpaComputeBaseSwizzle(
	    outmask, tm, 0, bitsperelem, numfrags, mingpumode
	);
}

void* gnmDrtGetZReadAddress(const GnmDepthRenderTarget* drt) {
	uint32_t addr256 = drt->z_read_base_256b;

	uint32_t swizzlemask = 0;
	GpaError err = getswizzlemask(&swizzlemask, drt);
	if (err == GPA_ERR_OK) {
		// remove the swizzle bits from the address
		addr256 &= ~swizzlemask;
	} else {
		gnmWriteMsgf(
		    GNM_MSGSEV_WARN, "Drt: failed to get swizzle mask with %s",
		    gpaStrError(err)
		);
	}

	return (void*)((uintptr_t)addr256 << 8);
}

GnmError gnmDrtSetZReadAddress(GnmDepthRenderTarget* drt, void* baseaddr) {
	if (!drt) {
		return GNM_ERROR_INVALID_ARGS;
	}
	if ((uintptr_t)baseaddr & 0xff) {
		return GNM_ERROR_INVALID_ALIGNMENT;
	}

	uint32_t newaddr = (uintptr_t)baseaddr >> 8;

	uint32_t swizzlemask = 0;
	GpaError err = getswizzlemask(&swizzlemask, drt);
	if (err == GPA_ERR_OK) {
		newaddr = (newaddr & ~swizzlemask) |
			  (drt->z_read_base_256b & swizzlemask);
	} else {
		gnmWriteMsgf(
		    GNM_MSGSEV_WARN, "Drt: failed to get swizzle mask with %s",
		    gpaStrError(err)
		);
	}

	drt->z_read_base_256b = newaddr;
	return GNM_ERROR_OK;
}

void* gnmDrtGetStencilReadAddress(const GnmDepthRenderTarget* drt) {
	uint32_t addr256 = drt->stencil_read_base_256b;

	uint32_t swizzlemask = 0;
	GpaError err = getswizzlemask(&swizzlemask, drt);
	if (err == GPA_ERR_OK) {
		// remove the swizzle bits from the address
		addr256 &= ~swizzlemask;
	} else {
		gnmWriteMsgf(
		    GNM_MSGSEV_WARN, "Drt: failed to get swizzle mask with %s",
		    gpaStrError(err)
		);
	}

	return (void*)((uintptr_t)addr256 << 8);
}

GnmError gnmDrtSetStencilReadAddress(
    GnmDepthRenderTarget* drt, void* baseaddr
) {
	if (!drt) {
		return GNM_ERROR_INVALID_ARGS;
	}
	if ((uintptr_t)baseaddr & 0xff) {
		return GNM_ERROR_INVALID_ALIGNMENT;
	}

	uint32_t newaddr = (uintptr_t)baseaddr >> 8;

	uint32_t swizzlemask = 0;
	GpaError err = getswizzlemask(&swizzlemask, drt);
	if (err == GPA_ERR_OK) {
		newaddr = (newaddr & ~swizzlemask) |
			  (drt->stencil_read_base_256b & swizzlemask);
	} else {
		gnmWriteMsgf(
		    GNM_MSGSEV_WARN, "Drt: failed to get swizzle mask with %s",
		    gpaStrError(err)
		);
	}

	drt->stencil_read_base_256b = newaddr;
	return GNM_ERROR_OK;
}

void* gnmDrtGetZWriteAddress(const GnmDepthRenderTarget* drt) {
	uint32_t addr256 = drt->z_write_base_256b;

	uint32_t swizzlemask = 0;
	GpaError err = getswizzlemask(&swizzlemask, drt);
	if (err == GPA_ERR_OK) {
		// remove the swizzle bits from the address
		addr256 &= ~swizzlemask;
	} else {
		gnmWriteMsgf(
		    GNM_MSGSEV_WARN, "Drt: failed to get swizzle mask with %s",
		    gpaStrError(err)
		);
	}

	return (void*)((uintptr_t)addr256 << 8);
}

GnmError gnmDrtSetZWriteAddress(GnmDepthRenderTarget* drt, void* baseaddr) {
	if (!drt) {
		return GNM_ERROR_INVALID_ARGS;
	}
	if ((uintptr_t)baseaddr & 0xff) {
		return GNM_ERROR_INVALID_ALIGNMENT;
	}

	uint32_t newaddr = (uintptr_t)baseaddr >> 8;

	uint32_t swizzlemask = 0;
	GpaError err = getswizzlemask(&swizzlemask, drt);
	if (err == GPA_ERR_OK) {
		newaddr = (newaddr & ~swizzlemask) |
			  (drt->z_write_base_256b & swizzlemask);
	} else {
		gnmWriteMsgf(
		    GNM_MSGSEV_WARN, "Drt: failed to get swizzle mask with %s",
		    gpaStrError(err)
		);
	}

	drt->z_write_base_256b = newaddr;
	return GNM_ERROR_OK;
}

void* gnmDrtGetStencilWriteAddress(const GnmDepthRenderTarget* drt) {
	uint32_t addr256 = drt->stencil_write_base_256b;

	uint32_t swizzlemask = 0;
	GpaError err = getswizzlemask(&swizzlemask, drt);
	if (err == GPA_ERR_OK) {
		// remove the swizzle bits from the address
		addr256 &= ~swizzlemask;
	} else {
		gnmWriteMsgf(
		    GNM_MSGSEV_WARN, "Drt: failed to get swizzle mask with %s",
		    gpaStrError(err)
		);
	}

	return (void*)((uintptr_t)addr256 << 8);
}

GnmError gnmDrtSetStencilWriteAddress(
    GnmDepthRenderTarget* drt, void* baseaddr
) {
	if (!drt) {
		return GNM_ERROR_INVALID_ARGS;
	}
	if ((uintptr_t)baseaddr & 0xff) {
		return GNM_ERROR_INVALID_ALIGNMENT;
	}

	uint32_t newaddr = (uintptr_t)baseaddr >> 8;

	uint32_t swizzlemask = 0;
	GpaError err = getswizzlemask(&swizzlemask, drt);
	if (err == GPA_ERR_OK) {
		newaddr = (newaddr & ~swizzlemask) |
			  (drt->stencil_write_base_256b & swizzlemask);
	} else {
		gnmWriteMsgf(
		    GNM_MSGSEV_WARN, "Drt: failed to get swizzle mask with %s",
		    gpaStrError(err)
		);
	}

	drt->stencil_write_base_256b = newaddr;
	return GNM_ERROR_OK;
}
