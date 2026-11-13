#include "gnm/rendertarget.h"

#include <stdlib.h>

#include "gnm/gpuaddr/gpuaddr.h"
#include "gnm/platform.h"

static bool init_rt_cmask(GnmRenderTarget* rt, uint32_t numslices) {
	const GnmDataFormat datafmt = gnmRtGetFormat(rt);
	const uint32_t bitsperelem = gnmGetBitsPerElement(datafmt.surfacefmt);
	const GnmGpuMode mingpumode =
	    rt->info.alt_tile_mode ? GNM_GPU_NEO : GNM_GPU_BASE;
	const GnmTileMode tm = rt->attrib.tile_mode_index;

	rt->info.compression = 1;

	const GpaCmaskDescription cdesc = {
	    .pitch = gnmRtGetPitch(rt),
	    .height = gnmRtGetSliceSize(rt),
	    .num_slices = numslices,
	    .num_frags = gnmRtGetNumFragments(rt),
	    .bpp = bitsperelem,
	    .tile_mode = tm,

	    .min_gpu_mode = mingpumode,
	    .flags = {
		.tc_compatible = mingpumode == GNM_GPU_NEO,
	    },
	};
	GpaCmaskInfo cinfo = {0};
	GpaError err = gpaComputeCmaskInfo(&cinfo, &cdesc );
	if (err != GPA_ERR_OK) {
		return false;
	}

	rt->cmask_slice.tile_max = (cinfo.cmask_byte_size / numslices) / 128 - 1;

	return true;
}

static bool init_rt_fmask(GnmRenderTarget* rt) {
	if (!rt->info.compression) {
		return false;
	}

	const GnmGpuMode curgpumode = gnmGpuMode();
	if (curgpumode == GNM_GPU_NEO && !rt->info.alt_tile_mode) {
		return false;
	}

	const GnmTileMode tm = rt->attrib.tile_mode_index;
	const bool isthin =
	    tm >= GNM_TM_THIN_1D_THIN && tm <= GNM_TM_THIN_3D_THIN_PRT;

	GnmTileMode fmask_tilemode = GNM_TM_THIN_2D_THIN;
	if (isthin == GNM_SURF_THIN_MICRO_TILING) {
		fmask_tilemode = rt->attrib.tile_mode_index;
	}
	rt->attrib.fmask_tile_mode_index = fmask_tilemode;

	rt->info.is_normalized = 1;  // TODO: is this member named correctly?

	const GnmGpuMode mingpumode =
	    rt->info.alt_tile_mode ? GNM_GPU_NEO : GNM_GPU_BASE;

	rt->info.compression = 1;

	const GpaFmaskDescription fparams = {
	    .tile_mode = fmask_tilemode,
	    .min_gpu_mode = mingpumode,
	    .pitch = gnmRtGetPitch(rt),
	    .height = gnmRtGetSliceSize(rt),
	    .num_slices = gnmRtGetNumSlices(rt),
	    .num_frags = gnmRtGetNumFragments(rt),
	};
	GpaFmaskInfo finfo = {0};
	GpaError err = gpaComputeFmaskInfo(&finfo, &fparams);
	if (err != GPA_ERR_OK) {
		return false;
	}

	// setFmaskPitchDiv8Minus1
	rt->pitch.fmask_tile_max = (finfo.pitch / 8) - 1;
	// setFmaskSliceNumTilesMinus1
	rt->fmask_slice.tile_max = ((finfo.pitch * finfo.height) / 64) - 1;

	return true;
}

GnmError gnmCreateRenderTarget(
    GnmRenderTarget* rt, const GnmRenderTargetCreateInfo* ci
) {
	if (!rt) {
		gnmWriteMsg(GNM_MSGSEV_ERR, "rt is null");
		return GNM_ERROR_INVALID_ARGS;
	}
	if (!ci) {
		gnmWriteMsg(GNM_MSGSEV_ERR, "spec is null");
		return GNM_ERROR_INVALID_ARGS;
	}
	if ((uint32_t)ci->num_samples < (uint32_t)ci->num_fragments) {
		gnmWriteMsg(
		    GNM_MSGSEV_ERR,
		    "numSamples must be equal or larger than numFragments"
		);
		return GNM_ERROR_INVALID_ARGS;
	}
	if (ci->color_fmt.surfacefmt > GNM_IMG_DATA_FORMAT_X24_8_32) {
		gnmWriteMsgf(
		    GNM_MSGSEV_ERR, "colorfmt 0x08%x is invalid", ci->color_fmt
		);
		return GNM_ERROR_INVALID_ARGS;
	}
	if (ci->color_fmt.surfacefmt == GNM_IMG_DATA_FORMAT_10_10_10_2 ||
	    ci->color_fmt.surfacefmt == GNM_IMG_DATA_FORMAT_2_10_10_10) {
		if (ci->color_fmt.chantype == GNM_IMG_NUM_FORMAT_SRGB) {
			gnmWriteMsgf(
			    GNM_MSGSEV_ERR, "color_fmt 0x08%x is invalid",
			    ci->color_fmt
			);
			return GNM_ERROR_INVALID_ARGS;
		}
	} else if (
	    ci->color_fmt.surfacefmt == GNM_IMG_DATA_FORMAT_32_32_32 ||
	    ci->color_fmt.surfacefmt == 15
	) {
		// TODO: what surface format is value 15?
		gnmWriteMsgf(
		    GNM_MSGSEV_ERR,
		    "colorfmt 0x08%x is invalid format 32_32_32 or 15",
		    ci->color_fmt
		);
		return GNM_ERROR_INVALID_ARGS;
	}

	GnmSurfaceNumber rtchantype = 0;
	if (!gnmDfGetRtChannelType(ci->color_fmt, &rtchantype)) {
		gnmWriteMsgf(
		    GNM_MSGSEV_ERR, "colorfmt 0x08%x has invalid channel type",
		    ci->color_fmt
		);
		return GNM_ERROR_INVALID_ARGS;
	}

	GnmSurfaceSwap rtchorder = 0;
	if (!gnmDfGetRtChannelOrder(ci->color_fmt, &rtchorder)) {
		gnmWriteMsgf(
		    GNM_MSGSEV_ERR, "colorfmt 0x08%x has invalid channel order",
		    ci->color_fmt
		);
		return GNM_ERROR_INVALID_ARGS;
	}

	if (ci->width - 1 > 16383) {
		gnmWriteMsg(
		    GNM_MSGSEV_ERR, "width must be between 1 and 16384"
		);
		return GNM_ERROR_INVALID_ARGS;
	}
	if (ci->height - 1 > 16383) {
		gnmWriteMsg(
		    GNM_MSGSEV_ERR, "height must be between 1 and 16384"
		);
		return GNM_ERROR_INVALID_ARGS;
	}
	if (ci->pitch > 16384) {
		gnmWriteMsg(
		    GNM_MSGSEV_ERR, "pitch must be between 0 and 16384"
		);
		return GNM_ERROR_INVALID_ARGS;
	}

	const GnmGpuMode curgpumode = gnmGpuMode();
	if (curgpumode == GNM_GPU_NEO && ci->min_gpu_mode == GNM_GPU_BASE) {
		if (ci->flags.enable_cmask_fastclear) {
			gnmWriteMsg(
			    GNM_MSGSEV_ERR,
			    "In NEO mode, enable_cmask_fastclear must be 0 if "
			    "mingpumode is BASE"
			);
			return GNM_ERROR_INVALID_ARGS;
		} else if (ci->flags.enable_fmask_compression) {
			gnmWriteMsg(
			    GNM_MSGSEV_ERR,
			    "In NEO mode, enable_fmask_compression must be 0 "
			    "if mingpumode is BASE"
			);
			return GNM_ERROR_INVALID_ARGS;
		} else if (ci->flags.enable_dcc_compression) {
			gnmWriteMsg(
			    GNM_MSGSEV_ERR,
			    "In NEO mode, enable_dcc_compression must be 0 if "
			    "mingpumode is BASE"
			);
			return GNM_ERROR_INVALID_ARGS;
		}
	}

	if (ci->min_gpu_mode == GNM_GPU_NEO) {
		rt->dcc_control.min_compressed_blocksize = 1;
	}

	const GnmTileMode tm = rt->attrib.tile_mode_index;
	const bool isthick =
	    tm >= GNM_TM_THICK_1D_THICK && tm <= GNM_TM_THICK_3D_XTHICK;

	uint32_t actualw = ci->width;
	uint32_t actualh = ci->height;
	uint32_t actualdepth = 1;
	if (ci->flags.enable_cmask_fastclear) {
		actualw = (actualw + 7) & (-8);
		actualh = (actualh + 7) & (-8);
	}
	if (isthick) {
		actualdepth = ci->num_slices;
	}

	const uint32_t numtexels = gnmDfGetTexelsPerElement(ci->color_fmt);
	const uint32_t numtotalbits = gnmDfGetTotalBitsPerElement(ci->color_fmt);

	GpaSurfaceInfo surfinfo = {0};
	const GpaSurfaceDescription desc = {
	    .tile_mode = ci->color_tile_mode_hint,
	    .image_format = ci->color_fmt.surfacefmt,
	    .min_gpu_mode = ci->min_gpu_mode,

	    .linear_width = actualw,
	    .linear_height = actualh,
	    .linear_depth = actualdepth,
	    .base_tiled_pitch = ci->pitch,

	    .num_frags_per_pixel = 1 << ci->num_fragments,
	    .bits_per_frag = numtotalbits / numtexels,

	    .mip_level = 0,
	    .array_slice = 0,
	    .flags = {
		.fmask = isthick,
		.tc_compatible = curgpumode == GNM_GPU_NEO,
	    },
	};
	GpaError err = gpaComputeSurfaceInfo(&surfinfo, &desc);
	if (err != GPA_ERR_OK) {
		gnmWriteMsgf(
		    GNM_MSGSEV_ERR, "gpa_computesurfaceinfo failed with: %s",
		    gpaStrError(err)
		);
		return GNM_ERROR_INTERNAL_FAILURE;
	}

	// setpitchdiv8minus1
	rt->pitch.tile_max = surfinfo.pitch / 8 - 1;
	// setFmaskPitchDiv8Minus1
	rt->pitch.fmask_tile_max = surfinfo.pitch / 8 - 1;

	// setSliceSizeDiv64Minus1
	rt->slice.tile_max = (surfinfo.pitch * surfinfo.height) / 64 - 1;

	// setarrayview
	rt->view.slice_start = 0;
	rt->view.slice_max = ci->num_slices - 1;

	// setdataformat
	rt->info.format = ci->color_fmt.surfacefmt;
	rt->info.channel_type = rtchantype;
	rt->info.channel_order = rtchorder;
	rt->info.is_normalized = rtchantype == GNM_NUMBER_UNORM ||
				 rtchantype == GNM_NUMBER_SNORM ||
				 rtchantype == GNM_NUMBER_SRGB;
	rt->info.is_int =
	    rtchantype == GNM_NUMBER_UINT || rtchantype == GNM_NUMBER_SINT;
	rt->info.is_scaled = rtchantype == GNM_NUMBER_UINT ||
			     rtchantype == GNM_NUMBER_SINT ||
			     rtchantype == GNM_NUMBER_FLOAT;
	// setUseAltTileMode
	rt->info.alt_tile_mode = ci->min_gpu_mode == GNM_GPU_NEO;

	// setnumsamples
	rt->attrib.num_samples = ci->num_samples >> 1;
	// setnumfragments
	rt->attrib.num_fragments = ci->num_fragments >> 1;
	// setTileMode
	rt->attrib.tile_mode_index = surfinfo.tile_mode;
	// setFmaskTileMode
	rt->attrib.fmask_tile_mode_index = surfinfo.tile_mode;

	// setWidth
	rt->size.width = ci->width;
	// setHeight
	rt->size.height = ci->height;

	if (ci->flags.enable_cmask_fastclear) {
		if (!init_rt_cmask(rt, ci->num_slices)) {
			gnmWriteMsg(GNM_MSGSEV_ERR, "init_rt_cmask failed");
			return GNM_ERROR_INTERNAL_FAILURE;
		}
	}
	if (ci->flags.enable_fmask_compression && ci->num_samples > 0) {
		if (!init_rt_fmask(rt)) {
			gnmWriteMsg(GNM_MSGSEV_ERR, "init_rt_fmask failed");
			return GNM_ERROR_INTERNAL_FAILURE;
		}
	}

	if (curgpumode == GNM_GPU_NEO && ci->flags.enable_dcc_compression) {
		// setDccCompressionEnable
		rt->info.dcc_enable = 1;

		const uint32_t bitsperelem =
		    gnmGetBitsPerElement(ci->color_fmt.surfacefmt);

		uint8_t maxuncompbs = 2 - (bitsperelem == 16);
		uint8_t maxcompbs = 0;
		if (bitsperelem == 8) {
			maxuncompbs = 0;
		}
		if (!ci->flags.enable_colortexture_without_decompress) {
			maxcompbs = maxuncompbs;
		}

		// setDccMaxUncompressedBlockSize
		rt->dcc_control.max_uncompressed_blocksize = maxuncompbs;
		// setDccMaxCompressedBlockSize
		rt->dcc_control.max_compressed_blocksize = maxcompbs;
		// setDccForceIndependentBlocks
		rt->dcc_control.independent_64b_blocks =
		    ci->flags.enable_colortexture_without_decompress;
	}

	return GNM_ERROR_OK;
}

GnmError gnmRtCalcByteSize(
    uint64_t* outsize, uint32_t* outalign, const GnmRenderTarget* rt
) {
	const GnmTileMode tm = rt->attrib.tile_mode_index;
	const bool isdisplay =
	    tm == GNM_TM_DISPLAY_LINEAR_GENERAL ||
	    tm == GNM_TM_DISPLAY_LINEAR_ALIGNED ||
	    tm == GNM_TM_DISPLAY_1D_THIN || tm == GNM_TM_DISPLAY_2D_THIN ||
	    tm == GNM_TM_DISPLAY_THIN_PRT || tm == GNM_TM_DISPLAY_2D_THIN_PRT;

	const GnmDataFormat datafmt = gnmRtGetFormat(rt);
	const uint32_t numtexels = gnmDfGetTexelsPerElement(datafmt);
	const uint32_t numtotalbits = gnmDfGetTotalBitsPerElement(datafmt);

	const GnmGpuMode mingpumode =
	    rt->info.alt_tile_mode ? GNM_GPU_NEO : GNM_GPU_BASE;

	GpaSurfaceDescription desc = {
	    .tile_mode = rt->attrib.tile_mode_index,
	    .image_format = datafmt.surfacefmt,
	    .min_gpu_mode = mingpumode,

	    .linear_width = gnmRtGetPitch(rt),
	    .linear_height = gnmRtGetSliceSize(rt),
	    .linear_depth = 1,
	    .base_tiled_pitch = (rt->pitch.tile_max + 1) * 8,

	    .num_frags_per_pixel = gnmRtGetNumFragments(rt),
	    .bits_per_frag = numtotalbits / numtexels,

	    .mip_level = 0,
	    .array_slice = 0,
	    .flags = {
		.display = isdisplay,
	    },
	};
	if (mingpumode == GNM_GPU_NEO) {
		if (rt->info.dcc_enable &&
		    (!rt->dcc_control.independent_64b_blocks ||
		     rt->dcc_control.max_uncompressed_blocksize >
			 GNM_DCC_MBS_64)) {
			desc.flags.tc_compatible = false;
		}
	}

	GpaSurfaceInfo surfinfo = {0};
	GpaError err = gpaComputeSurfaceInfo(&surfinfo, &desc);
	if (err != GPA_ERR_OK) {
		return GNM_ERROR_INTERNAL_FAILURE;
	}

	const uint64_t slicesize =
	    surfinfo.surface_byte_size * (rt->view.slice_max + 1);

	if (outsize) {
		*outsize = slicesize;
	}
	if (outalign) {
		*outalign = surfinfo.base_align;
	}
	return GNM_ERROR_OK;
}

GnmDataFormat gnmRtGetFormat(const GnmRenderTarget* rt) {
	GnmImgNumFormat chantype = 0;
	switch (rt->info.channel_type) {
	case GNM_NUMBER_UNORM:
		chantype = GNM_IMG_NUM_FORMAT_UNORM;
		break;
	case GNM_NUMBER_SNORM:
		chantype = GNM_IMG_NUM_FORMAT_SNORM;
		break;
	case GNM_NUMBER_UINT:
		chantype = GNM_IMG_NUM_FORMAT_UINT;
		break;
	case GNM_NUMBER_SINT:
		chantype = GNM_IMG_NUM_FORMAT_SINT;
		break;
	case GNM_NUMBER_SRGB:
		chantype = GNM_IMG_NUM_FORMAT_SRGB;
		break;
	case GNM_NUMBER_FLOAT:
		chantype = GNM_IMG_NUM_FORMAT_FLOAT;
		break;
	default:
		abort();
	}

	GnmDataFormat res = {
	    .surfacefmt = (GnmImageFormat)rt->info.format,
	    .chantype = chantype,
	};

	const uint32_t numcomps = gnmDfGetNumComponents(res);
	if (numcomps > 4) {
		abort();
	}

	switch (rt->info.channel_order) {
	case GNM_SWAP_STD:
		if (numcomps == 1) {
			res.chanx = GNM_CHAN_X;
			res.chany = GNM_CHAN_CONSTANT0;
			res.chanz = GNM_CHAN_CONSTANT0;
			res.chanw = GNM_CHAN_CONSTANT0;
		} else if (numcomps == 2) {
			res.chanx = GNM_CHAN_X;
			res.chany = GNM_CHAN_Y;
			res.chanz = GNM_CHAN_CONSTANT0;
			res.chanw = GNM_CHAN_CONSTANT0;
		} else if (numcomps == 3) {
			res.chanx = GNM_CHAN_X;
			res.chany = GNM_CHAN_Y;
			res.chanz = GNM_CHAN_Z;
			res.chanw = GNM_CHAN_CONSTANT0;
		} else if (numcomps == 4) {
			res.chanx = GNM_CHAN_X;
			res.chany = GNM_CHAN_Y;
			res.chanz = GNM_CHAN_Z;
			res.chanw = GNM_CHAN_W;
		}
		break;
	case GNM_SWAP_ALT:
		if (numcomps == 1) {
			res.chanx = GNM_CHAN_CONSTANT0;
			res.chany = GNM_CHAN_Y;
			res.chanz = GNM_CHAN_CONSTANT0;
			res.chanw = GNM_CHAN_CONSTANT0;
		} else if (numcomps == 2) {
			res.chanx = GNM_CHAN_X;
			res.chany = GNM_CHAN_CONSTANT0;
			res.chanz = GNM_CHAN_CONSTANT0;
			res.chanw = GNM_CHAN_Y;
		} else if (numcomps == 3) {
			res.chanx = GNM_CHAN_X;
			res.chany = GNM_CHAN_Y;
			res.chanz = GNM_CHAN_CONSTANT0;
			res.chanw = GNM_CHAN_Z;
		} else if (numcomps == 4) {
			res.chanx = GNM_CHAN_Z;
			res.chany = GNM_CHAN_Y;
			res.chanz = GNM_CHAN_X;
			res.chanw = GNM_CHAN_W;
		}
		break;
	case GNM_SWAP_STD_REV:
		if (numcomps == 1) {
			res.chanx = GNM_CHAN_CONSTANT0;
			res.chany = GNM_CHAN_CONSTANT0;
			res.chanz = GNM_CHAN_X;
			res.chanw = GNM_CHAN_CONSTANT0;
		} else if (numcomps == 2) {
			res.chanx = GNM_CHAN_Y;
			res.chany = GNM_CHAN_X;
			res.chanz = GNM_CHAN_CONSTANT0;
			res.chanw = GNM_CHAN_CONSTANT0;
		} else if (numcomps == 3) {
			res.chanx = GNM_CHAN_Z;
			res.chany = GNM_CHAN_Y;
			res.chanz = GNM_CHAN_X;
			res.chanw = GNM_CHAN_CONSTANT0;
		} else if (numcomps == 4) {
			res.chanx = GNM_CHAN_W;
			res.chany = GNM_CHAN_Z;
			res.chanz = GNM_CHAN_Y;
			res.chanw = GNM_CHAN_X;
		}
		break;
	case GNM_SWAP_ALT_REV:
		if (numcomps == 1) {
			res.chanx = GNM_CHAN_CONSTANT0;
			res.chany = GNM_CHAN_CONSTANT0;
			res.chanz = GNM_CHAN_CONSTANT0;
			res.chanw = GNM_CHAN_X;
		} else if (numcomps == 2) {
			res.chanx = GNM_CHAN_Y;
			res.chany = GNM_CHAN_CONSTANT0;
			res.chanz = GNM_CHAN_CONSTANT0;
			res.chanw = GNM_CHAN_X;
		} else if (numcomps == 3) {
			res.chanx = GNM_CHAN_Z;
			res.chany = GNM_CHAN_Y;
			res.chanz = GNM_CHAN_CONSTANT0;
			res.chanw = GNM_CHAN_X;
		} else if (numcomps == 4) {
			res.chanx = GNM_CHAN_Y;
			res.chany = GNM_CHAN_Z;
			res.chanz = GNM_CHAN_W;
			res.chanw = GNM_CHAN_X;
		}
		break;
	default:
		abort();
	}

	return res;
}
