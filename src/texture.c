#include "gnm/texture.h"

#include "gnm/gpuaddr/gpuaddr.h"
#include "gnm/platform.h"

#include "gpuaddr/gpuaddr_private.h"

static inline GpaError tex_calcswizzlemask(
    uint32_t* outmask, const GnmTexture* tex
) {
	const GnmGpuMode gpumode = gnmGpuMode();
	const GnmTileMode tm = tex->tiling_index;
	const GnmDataFormat fmt = gnmTexGetFormat(tex);
	const uint32_t bitsperelem = gnmGetBitsPerElement(fmt.surfacefmt);
	const uint8_t numfrags = gnmTexGetNumFragments(tex);

	return gpaComputeBaseSwizzle(
	    outmask, tm, 0, bitsperelem, numfrags, gpumode
	);
}

GnmError gnmCreateTexture(GnmTexture* tex, const GnmTextureCreateInfo* ci) {
	if (!tex) {
		gnmWriteMsg(GNM_MSGSEV_ERR, "CreateTexture: tex can't be null");
	}
	if (!ci) {
		gnmWriteMsg(
		    GNM_MSGSEV_ERR, "CreateTexture: createinfo can't be null"
		);
	}

	if (!ci->num_mip_levels) {
		gnmWriteMsg(
		    GNM_MSGSEV_ERR, "nummiplevels must be greater than 0"
		);
		return GNM_ERROR_INVALID_ARGS;
	}

	uint32_t largestdim = ci->width;
	if (largestdim < ci->height) {
		largestdim = ci->height;
	}
	if (largestdim < ci->depth) {
		largestdim = ci->depth;
	}

	if (ci->format.chantype != GNM_IMG_NUM_FORMAT_FLOAT &&
	    (ci->format.surfacefmt == GNM_IMG_DATA_FORMAT_10_11_11 ||
	     ci->format.surfacefmt == GNM_IMG_DATA_FORMAT_11_11_10)) {
		gnmWriteMsgf(
		    GNM_MSGSEV_ERR, "format 0x%x cannot be used as a texture",
		    ci->format.asuint
		);
		return GNM_ERROR_INVALID_ARGS;
	}

	tex->power_of_2_pad = ci->num_mip_levels > 1;
	tex->mtype2 = 1;
	tex->type = ci->texture_type;

	switch (ci->texture_type) {
	case GNM_TEXTURE_1D:
	case GNM_TEXTURE_1D_ARRAY:
		if (ci->height != 1) {
			gnmWriteMsg(
			    GNM_MSGSEV_ERR,
			    "height must be 1 if texturetype is 1D"
			);
			return GNM_ERROR_INVALID_ARGS;
		}
		if (ci->depth != 1) {
			gnmWriteMsg(
			    GNM_MSGSEV_ERR,
			    "depth must be 1 if texturetype is 1D"
			);
			return GNM_ERROR_INVALID_ARGS;
		}
		if (ci->num_fragments != 1) {
			gnmWriteMsg(
			    GNM_MSGSEV_ERR,
			    "numfragments must be 1 if texturetype is 1D"
			);
			return GNM_ERROR_INVALID_ARGS;
		}
		break;
	case GNM_TEXTURE_2D:
	case GNM_TEXTURE_2D_ARRAY:
		if (ci->depth != 1) {
			gnmWriteMsg(
			    GNM_MSGSEV_ERR,
			    "depth must be 1 if texturetype is 2D"
			);
			return GNM_ERROR_INVALID_ARGS;
		}
		if (ci->num_fragments > 1) {
			gnmWriteMsg(
			    GNM_MSGSEV_ERR,
			    "if numfragments is larger than 1, texturetype "
			    "must be 2D MSAA"
			);
			return GNM_ERROR_INVALID_ARGS;
		}
		break;
	case GNM_TEXTURE_3D:
		if (ci->num_slices != 1) {
			gnmWriteMsg(
			    GNM_MSGSEV_ERR,
			    "numslices must be 1 if texturetype is 2D"
			);
			return GNM_ERROR_INVALID_ARGS;
		}
		if (ci->num_fragments != 1) {
			gnmWriteMsg(
			    GNM_MSGSEV_ERR,
			    "numfragments must be 1 if texturetype is 2D"
			);
			return GNM_ERROR_INVALID_ARGS;
		}
		break;
	case GNM_TEXTURE_2D_MSAA:
	case GNM_TEXTURE_2D_ARRAY_MSAA:
		if (ci->num_fragments <= 1) {
			gnmWriteMsg(
			    GNM_MSGSEV_ERR,
			    "numfragments must be larger than "
			    "1 if texturetype is 2D MSAA"
			);
			return GNM_ERROR_INVALID_ARGS;
		}
		break;
	case GNM_TEXTURE_CUBEMAP:
		// TODO?
		break;
	default:
		gnmWriteMsgf(
		    GNM_MSGSEV_ERR, "Unknown texturetype %u", ci->texture_type
		);
		return GNM_ERROR_INTERNAL_FAILURE;
	}

	const uint32_t totalbitsperelem =
	    gnmDfGetTotalBitsPerElement(ci->format);
	const uint32_t texelsperelem = gnmDfGetTexelsPerElement(ci->format);

	const GpaSurfaceDescription desc = {
	    .tile_mode = ci->tile_mode_hint,
	    .image_format = ci->format.surfacefmt,
	    .min_gpu_mode = ci->min_gpu_mode,

	    .linear_width = ci->width,
	    .linear_height = ci->height,
	    .linear_depth = ci->depth,
	    .base_tiled_pitch = ci->pitch,

	    .num_frags_per_pixel = 1 << ci->num_fragments,
	    .bits_per_frag = totalbitsperelem / texelsperelem,

	    .mip_level = 0,
	    .array_slice = 0,
	    .flags = {
		.cube = ci->texture_type == GNM_TEXTURE_CUBEMAP,
		.volume = ci->texture_type == GNM_TEXTURE_3D,
		.power_of_2_pad = ci->num_mip_levels > 1,
		.tc_compatible = ci->min_gpu_mode == GNM_GPU_NEO,
	    },
	};

	GpaSurfaceInfo surfinfo = {0};
	GpaError err = gpaComputeSurfaceInfo(&surfinfo, &desc);
	if (err != GPA_ERR_OK) {
		gnmWriteMsgf(
		    GNM_MSGSEV_ERR, "Failed to compute surface info with %s",
		    gpaStrError(err)
		);
		return GNM_ERROR_INTERNAL_FAILURE;
	}

	gnmTexSetWidth(tex, ci->width);
	gnmTexSetHeight(tex, ci->height);
	gnmTexSetPitch(tex, surfinfo.pitch);

	gnmTexSetFormat(tex, ci->format);

	const uint32_t realdepth =
	    ci->texture_type == GNM_TEXTURE_3D ? ci->depth : ci->num_slices;
	gnmTexSetDepth(tex, realdepth);

	// setArrayView
	const uint32_t numslices = ci->texture_type == GNM_TEXTURE_CUBEMAP
				       ? ci->num_slices * 6
				       : ci->num_slices;
	tex->base_array = 0;
	tex->last_array = numslices;

	// setMipLevelRange
	tex->base_level = 0;
	tex->last_level = ci->num_mip_levels - 1;
	// setMinLodClamp
	// setNumFragments
	tex->min_lod = 0;
	// NOTE: this is only valid for 2D (Array) MSAA textures
	if (ci->num_fragments > 1) {
		tex->last_level = ci->num_fragments >> 1;
	}
	// setTileMode
	tex->tiling_index = surfinfo.tile_mode;
	// setUseAltTileMode
	tex->alt_tile_mode = ci->min_gpu_mode == GNM_GPU_NEO;
	// setSamplerModulationFactor
	tex->perf_mod = GNM_PERFMOD_MAX;

	return GNM_ERROR_OK;
}

GnmError gnmTexCalcByteSize(
    uint64_t* outsize, uint32_t* outalignment, const GnmTexture* tex
) {
	if (!tex) {
		return GNM_ERROR_INVALID_ARGS;
	}

	const GpaTextureInfo texinfo = {
	    .type = tex->type,
	    .fmt = gnmTexGetFormat(tex),

	    .width = gnmTexGetWidth(tex),
	    .height = gnmTexGetHeight(tex),
	    .depth = gnmTexGetDepth(tex),
	    .pitch = gnmTexGetPitch(tex),

	    .num_frags = gnmTexGetNumFragments(tex),
	    .num_mips = gnmTexGetNumMips(tex),
	    .num_slices = gnmTexGetNumArraySlices(tex),

	    .tile_mode = tex->tiling_index,
	    .min_gpu_mode = tex->alt_tile_mode ? GNM_GPU_NEO : GNM_GPU_BASE,

	    .power_of_2_pad = tex->power_of_2_pad,
	};

	GpaSurfaceDescription tp = {0};
	GpaError err = gpaSurfaceDescInit(&tp, &texinfo, 0, 0);
	if (err != GPA_ERR_OK) {
		return GNM_ERROR_INVALID_STATE;
	}

	GpaSurfaceInfo surfinfo = {0};
	for (uint32_t i = 0; i < texinfo.num_mips; i += 1) {
		tp.linear_width = umax(texinfo.width >> i, 1);
		tp.linear_height = umax(texinfo.height >> i, 1);
		tp.linear_depth = umax(texinfo.depth >> i, 1);
		tp.mip_level = i;

		err = gpaComputeSurfaceInfo(&surfinfo, &tp);
		if (err != GPA_ERR_OK) {
			return GNM_ERROR_INTERNAL_FAILURE;
		}

		if (outsize) {
			*outsize += texinfo.num_slices * surfinfo.surface_byte_size;
		}
		if (outalignment) {
			*outalignment = umax(*outalignment, surfinfo.base_align);
		}

		if (tp.linear_width == 1 && tp.linear_height == 1 &&
		    tp.linear_depth == 1) {
			break;
		}
	}

	return GNM_ERROR_OK;
}

uint32_t gnmTexGetNumArraySlices(const GnmTexture* tex) {
	uint32_t numarrayslices = gnmTexGetTotalArraySlices(tex);
	if (tex->type == GNM_TEXTURE_CUBEMAP) {
		numarrayslices *= 6;
	} else if (tex->type == GNM_TEXTURE_3D) {
		numarrayslices = 1;
	}
	if (tex->power_of_2_pad) {
		numarrayslices = NextPow2(numarrayslices);
	}
	return numarrayslices;
}

void gnmTexSetBaseAddress(GnmTexture* tex, void* baseaddr) {
	if (((uintptr_t)baseaddr & 0xff) != 0) {
		gnmWriteMsg(
		    GNM_MSGSEV_ERR,
		    "gnmTex: base address must be 256 byte aligned"
		);
		return;
	}

	uintptr_t addr = (uintptr_t)baseaddr >> 8;

	uint32_t swizzlemask = 0;
	GpaError err = tex_calcswizzlemask(&swizzlemask, tex);
	if (err == GPA_ERR_OK) {
		addr = (addr & ~swizzlemask) | (tex->base_address & swizzlemask);
	} else {
		gnmWriteMsgf(
		    GNM_MSGSEV_WARN,
		    "Texture: failed to calculate swizzle mask with %s",
		    gpaStrError(err)
		);
	}

	tex->base_address = addr;
}
