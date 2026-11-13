#include "gnm/fnf/fnf.h"

#include <stdlib.h>
#include <string.h>

#define UKTX_IMPLEMENTATION
#include "u/ktx.h"

// TODO: handle swizzle
// TODO: handle more formats
FnfError fnfKtxLoad(
    GnmTexture* out_tex, void** outbuf, size_t* outbuflen, const void* inbuf,
    size_t inbuflen
) {
	if (!out_tex || !outbuf || !outbuflen || !inbuf || !inbuflen) {
		return FNF_ERR_INVALID_ARG;
	}

	UKtxMemBuffer mem = {
	    .data = inbuf,
	    .len = inbuflen,
	};
	UKtxContext ctx = uktx_openmem(&mem);
	UKtx info = {0};
	UKtxError err = uktx_read(&ctx, &info);
	if (err != UKTX_ERR_OK) {
		return FNF_ERR_INTERNAL_ERROR;
	}

	GnmTextureType textype = GNM_TEXTURE_1D;
	if (info.pixelheight > 0) {
		textype = GNM_TEXTURE_2D;
		if (info.pixeldepth > 1) {
			textype = GNM_TEXTURE_3D;
		} else if (info.numfaces == 6) {
			textype = GNM_TEXTURE_CUBEMAP;
		}
	}

	GnmDataFormat fmt = GNM_FMT_INVALID;
	switch (info.intfmt) {
	case UKTX_IFMT_RGBA8:
		fmt = GNM_FMT_R8G8B8A8_UNORM;
		break;
	case UKTX_IFMT_SRGB8_ALPHA8:
		fmt = GNM_FMT_R8G8B8A8_SRGB;
		break;
	case UKTX_IFMT_RGBA16:
		fmt = GNM_FMT_R16G16B16A16_UNORM;
		break;
	case UKTX_IFMT_RGBA16F:
		fmt = GNM_FMT_R16G16B16A16_FLOAT;
		break;
	case UKTX_IFMT_RGBA32F:
		fmt = GNM_FMT_R32G32B32A32_FLOAT;
		break;
	case UKTX_IFMT_COMPRESSED_RGBA_S3TC_DXT1:
		fmt = GNM_FMT_BC1_UNORM;
		break;
	case UKTX_IFMT_COMPRESSED_SRGB_ALPHA_S3TC_DXT1:
		fmt = GNM_FMT_BC1_SRGB;
		break;
	case UKTX_IFMT_COMPRESSED_RGBA_S3TC_DXT5:
		fmt = GNM_FMT_BC3_UNORM;
		break;
	case UKTX_IFMT_COMPRESSED_RGB_BPTC_SIGNED_FLOAT:
		fmt = GNM_FMT_BC6_UNORM;
		break;
	case UKTX_IFMT_COMPRESSED_RGBA_BPTC_UNORM:
		fmt = GNM_FMT_BC7_UNORM;
		break;
	case UKTX_IFMT_COMPRESSED_SRGB_ALPHA_BPTC_UNORM:
		fmt = GNM_FMT_BC7_SRGB;
		break;
	case UKTX_IFMT_NONE:
		return FNF_ERR_INVALID_TEXTURE;
	default:
		return FNF_ERR_UNSUPPORTED;
	}

	const GnmTextureCreateInfo ci = {
	    .texture_type = textype,
	    .width = info.pixelwidth,
	    .height = info.pixelheight > 0 ? info.pixelheight : 1,
	    .depth = info.pixeldepth > 0 ? info.pixeldepth : 1,
	    .pitch = info.pixelwidth,

	    .num_mip_levels = info.numlevels > 0 ? info.numlevels : 1,
	    .num_slices = info.numarrayelems > 0 ? info.numarrayelems : 1,

	    .format = fmt,
	    .tile_mode_hint = GNM_TM_DISPLAY_LINEAR_GENERAL,
	    .min_gpu_mode = GNM_GPU_BASE,
	    .num_fragments = 1,
	};
	GnmError gnmerr = gnmCreateTexture(out_tex, &ci);
	if (gnmerr != GNM_ERROR_OK) {
		// TODO: better error handling?
		return FNF_ERR_INTERNAL_ERROR;
	}

	uint64_t texlen = 0;
	gnmerr = gnmTexCalcByteSize(&texlen, NULL, out_tex);
	if (gnmerr != GNM_ERROR_OK) {
		// TODO: better error handling?
		return FNF_ERR_INTERNAL_ERROR;
	}

	uint8_t* texdata = malloc(texlen);
	if (!texdata) {
		return FNF_ERR_OOM;
	}

	memset(texdata, 0, texlen);

	const GpaTextureInfo texinfo = gpaFromGnmTexture(out_tex);
	for (uint32_t m = 0; m < ci.num_mip_levels; m += 1) {
		for (uint32_t s = 0; s < ci.num_slices; s += 1) {
			for (uint32_t f = 0; f < info.numfaces; f += 1) {
				uint64_t offset = 0;
				uint64_t size = 0;
				GpaError gerr = gpaComputeSurfaceSizeOffset(
				    &size, &offset, &texinfo, m, s + f
				);
				if (gerr != GPA_ERR_OK) {
					free(texdata);
					return FNF_ERR_UNSUPPORTED;
				}

				if (offset + size > texlen) {
					free(texdata);
					return FNF_ERR_OVERFLOW;
				}

				err = uktx_loadimage(
				    &ctx, &info, &texdata[offset], size, m, s, f
				);
				if (err != UKTX_ERR_OK) {
					free(texdata);
					return FNF_ERR_INTERNAL_ERROR;
				}
			}
		};
	}

	*outbuf = texdata;
	*outbuflen = texlen;
	return FNF_ERR_OK;
}

typedef struct {
	char* data;
	size_t len;
	size_t off;
} WriterContext;

static void ktexwriter(const void* buf, size_t len, void* userdata) {
	WriterContext* ctx = userdata;

	const size_t newlen = ctx->off + len;
	if (newlen > ctx->len) {
		ctx->data = realloc(ctx->data, newlen);
		ctx->len = newlen;
	}

	memcpy(&ctx->data[ctx->off], buf, len);
	ctx->off = newlen;
}

// TODO: handle swizzle
FnfError fnfKtxStore(
    void** outbuf, size_t* outbuflen, const void* inbuf, size_t inbuflen,
    const GnmTexture* tex
) {
	if (!outbuf || !outbuflen || !inbuf || !inbuflen || !tex) {
		return FNF_ERR_INVALID_ARG;
	}

	const GnmDataFormat texfmt = gnmTexGetFormat(tex);
	const GnmTextureType textype = tex->type;

	// TODO: should the ktx library handle this somehow?
	UKtxType type = UKTX_TYPE_NONE;
	UKtxDataFormat dfmt = UKTX_DFMT_NONE;
	UKtxInternalFormat ifmt = UKTX_IFMT_NONE;
	UKtxBaseInternalFormat bifmt = UKTX_BIFMT_NONE;
	uint32_t typesize = 0;
	switch (texfmt.surfacefmt) {
	case GNM_IMG_DATA_FORMAT_8_8_8_8:
		type = UKTX_TYPE_UNSIGNED_BYTE;
		typesize = 1;
		dfmt = UKTX_DFMT_RGBA;
		bifmt = UKTX_BIFMT_RGBA;
		switch (texfmt.chantype) {
		case GNM_IMG_NUM_FORMAT_UNORM:
			ifmt = UKTX_IFMT_RGBA8;
			break;
		case GNM_IMG_NUM_FORMAT_SNORM:
			ifmt = UKTX_IFMT_RGBA8_SNORM;
			break;
		case GNM_IMG_NUM_FORMAT_SRGB:
			ifmt = UKTX_IFMT_SRGB8_ALPHA8;
			break;
		default:
			return FNF_ERR_UNSUPPORTED;
		}
		break;
	case GNM_IMG_DATA_FORMAT_16_16_16_16:
		type = UKTX_TYPE_UNSIGNED_SHORT;
		typesize = 2;
		dfmt = UKTX_DFMT_RGBA;
		bifmt = UKTX_BIFMT_RGBA;
		switch (texfmt.chantype) {
		case GNM_IMG_NUM_FORMAT_UNORM:
			ifmt = UKTX_IFMT_RGBA16;
			break;
		case GNM_IMG_NUM_FORMAT_SNORM:
			ifmt = UKTX_IFMT_RGBA16_SNORM;
			break;
		case GNM_IMG_NUM_FORMAT_FLOAT:
			ifmt = UKTX_IFMT_RGBA16F;
			break;
		default:
			return FNF_ERR_UNSUPPORTED;
		}
		break;
	case GNM_IMG_DATA_FORMAT_32_32_32_32:
		type = UKTX_TYPE_FLOAT;
		typesize = 4;
		dfmt = UKTX_DFMT_RGBA;
		bifmt = UKTX_BIFMT_RGBA;
		switch (texfmt.chantype) {
		case GNM_IMG_NUM_FORMAT_FLOAT:
			ifmt = UKTX_IFMT_RGBA32F;
			break;
		default:
			return FNF_ERR_UNSUPPORTED;
		}
		break;
	case GNM_IMG_DATA_FORMAT_BC1:
		typesize = 1;
		bifmt = UKTX_BIFMT_RGBA;
		switch (texfmt.chantype) {
		case GNM_IMG_NUM_FORMAT_UNORM:
			ifmt = UKTX_IFMT_COMPRESSED_RGBA_S3TC_DXT1;
			break;
		case GNM_IMG_NUM_FORMAT_SRGB:
			ifmt = UKTX_IFMT_COMPRESSED_SRGB_ALPHA_S3TC_DXT1;
			break;
		default:
			return FNF_ERR_UNSUPPORTED;
		}
		break;
	case GNM_IMG_DATA_FORMAT_BC3:
		typesize = 1;
		bifmt = UKTX_BIFMT_RGBA;
		switch (texfmt.chantype) {
		case GNM_IMG_NUM_FORMAT_UNORM:
			ifmt = UKTX_IFMT_COMPRESSED_RGBA_S3TC_DXT5;
			break;
		default:
			return FNF_ERR_UNSUPPORTED;
		}
		break;
	case GNM_IMG_DATA_FORMAT_BC6:
		typesize = 1;
		bifmt = UKTX_BIFMT_RGB;
		switch (texfmt.chantype) {
		case GNM_IMG_NUM_FORMAT_FLOAT:
			ifmt = UKTX_IFMT_COMPRESSED_RGB_BPTC_SIGNED_FLOAT;
			break;
		default:
			return FNF_ERR_UNSUPPORTED;
		}
		break;
	case GNM_IMG_DATA_FORMAT_BC7:
		typesize = 1;
		bifmt = UKTX_BIFMT_RGBA;
		switch (texfmt.chantype) {
		case GNM_IMG_NUM_FORMAT_UNORM:
			ifmt = UKTX_IFMT_COMPRESSED_RGBA_BPTC_UNORM;
			break;
		case GNM_IMG_NUM_FORMAT_SRGB:
			ifmt = UKTX_IFMT_COMPRESSED_SRGB_ALPHA_BPTC_UNORM;
			break;
		default:
			return FNF_ERR_UNSUPPORTED;
		}
		break;
	default:
		return FNF_ERR_UNSUPPORTED;
	}

	const uint32_t width = gnmTexGetWidth(tex);
	const uint32_t height = gnmTexGetHeight(tex);
	const uint32_t depth = gnmTexGetDepth(tex);

	const uint32_t numarrayslices = gnmTexGetTotalArraySlices(tex);
	const uint32_t nummips = gnmTexGetNumMips(tex);
	const uint32_t numfaces = gnmTexGetNumFaces(tex);

	if (nummips > UKTX_MAX_LEVELS) {
		return FNF_ERR_UNSUPPORTED;
	}

	UKtxWriteLevel mipmaps[UKTX_MAX_LEVELS] = {0};
	const GpaTextureInfo texinfo = gpaFromGnmTexture(tex);
	for (uint32_t m = 0; m < nummips; m += 1) {
		mipmaps[m].slices =
		    malloc(sizeof(UKtxWriteSlice) * numarrayslices);
		for (uint32_t s = 0; s < numarrayslices; s += 1) {
			for (uint32_t f = 0; f < numfaces; f += 1) {
				uint64_t offset = 0;
				uint64_t size = 0;
				GpaError gerr = gpaComputeSurfaceSizeOffset(
				    &size, &offset, &texinfo, m, s + f
				);
				if (gerr != GPA_ERR_OK) {
					return FNF_ERR_UNSUPPORTED;
				}

				mipmaps[m].slices[s].faces[f] = (UKtxWriteFace){
				    .data = (const uint8_t*)inbuf + offset,
				    .len = size,
				};
			};
		};
	}

	static const char* key = "KTXorientation";
	static const char* value = "S=r,T=d";
	const UKtxWriteKeyValue keyval = {
	    .key = key,
	    .keylen = strlen(key) + 1,
	    .val = value,
	    .val_len = strlen(value) + 1,
	};
	const UKtxWriteInfo info = {
	    .type = type,
	    .typesize = typesize,
	    .datafmt = dfmt,
	    .intfmt = ifmt,
	    .baseintfmt = bifmt,
	    .pixelwidth = width,
	    .pixelheight = height,
	    .pixeldepth = textype == GNM_TEXTURE_3D ? depth : 0,
	    .numlevels = nummips,
	    .numfaces = numfaces,
	    .numarrayelems = numarrayslices > 1 ? numarrayslices : 0,

	    .numkeyvals = 1,
	    .keyvals = &keyval,
	    .levels = mipmaps,
	};

	WriterContext ctx = {0};
	UKtxError err = uktx_write(ktexwriter, &ctx, &info);

	for (uint32_t m = 0; m < nummips; m += 1) {
		free(mipmaps[m].slices);
	}

	if (err != UKTX_ERR_OK) {
		if (ctx.data) {
			free(ctx.data);
		}
		return FNF_ERR_INTERNAL_ERROR;
	}

	*outbuf = ctx.data;
	*outbuflen = ctx.len;
	return FNF_ERR_OK;
}
