#include "gnm/fnf/fnf.h"

#include "deps/stb_image.h"
#include "deps/stb_image_write.h"

#include "u/utility.h"

#include "writer.h"

// TODO: get format from caller
// also handle other formats
FnfError fnfPngLoad(
    GnmTexture* out_tex, void** outbuf, size_t* outbuflen, const void* inbuf,
    size_t inbuflen
) {
	if (!out_tex || !outbuf || !outbuflen || !inbuf || !inbuflen) {
		return FNF_ERR_INVALID_ARG;
	}

	const GnmDataFormat desiredfmt = GNM_FMT_R8G8B8A8_SRGB;
	const uint32_t desiredchans = gnmDfGetNumComponents(desiredfmt);

	int x = 0;
	int y = 0;
	int numchans = 0;
	stbi_uc* buf = stbi_load_from_memory(
	    inbuf, inbuflen, &x, &y, &numchans, desiredchans
	);
	if (!buf) {
		return FNF_ERR_INTERNAL_ERROR;
	}

	const GnmTextureCreateInfo outtexspec = {
	    .texture_type = GNM_TEXTURE_2D,
	    .width = x,
	    .height = y,
	    .depth = 1,
	    .pitch = x,

	    .num_mip_levels = 1,
	    .num_slices = 1,

	    .format = desiredfmt,
	    .tile_mode_hint = GNM_TM_DISPLAY_LINEAR_GENERAL,
	    .min_gpu_mode = GNM_GPU_BASE,
	    .num_fragments = 1,
	};
	GnmError gnmerr = gnmCreateTexture(out_tex, &outtexspec);
	if (gnmerr != GNM_ERROR_OK) {
		// TODO: better error handling?
		return FNF_ERR_INTERNAL_ERROR;
	}

	*outbuf = buf;
	*outbuflen = x * y * numchans;
	return FNF_ERR_OK;
}

// TODO: use other SurfaceIndex fields such as array slice
// also support float formats?
FnfError fnfPngStore(
    void** outbuf, size_t* outbuflen, const void* inbuf, size_t inbuflen,
    const GnmTexture* texture, const GpaSurfaceIndex* surfidx
) {
	if (!outbuf || !outbuflen || !inbuf || !inbuflen || !texture ||
	    !surfidx) {
		return FNF_ERR_INVALID_ARG;
	}

	const GnmDataFormat fmt = gnmTexGetFormat(texture);
	const uint32_t width = umax(gnmTexGetWidth(texture) >> surfidx->mip, 1);
	const uint32_t height =
	    umax(gnmTexGetHeight(texture) >> surfidx->mip, 1);
	const uint32_t bytesperelem = gnmGetBitsPerElement(fmt.surfacefmt) / 8;
	const uint32_t numcomponents = gnmDfGetNumComponents(fmt);

	const size_t reqinsize = width * height * bytesperelem;
	if (reqinsize > inbuflen) {
		return FNF_ERR_OVERFLOW;
	}

	WriteStbContext ctx = {0};
	int err = stbi_write_png_to_func(
	    writestb, &ctx, width, height, numcomponents, inbuf, 0
	);
	if (err == 0 || !ctx.data) {
		freewriter(&ctx);
		return FNF_ERR_INTERNAL_ERROR;
	}

	*outbuf = ctx.data;
	*outbuflen = ctx.len;
	return FNF_ERR_OK;
}
