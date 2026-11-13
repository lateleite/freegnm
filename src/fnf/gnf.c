#include "gnm/fnf/fnf.h"

#include <stdlib.h>
#include <string.h>

#include <gnm/gnf/gnf.h>
#include <gnm/gnf/validate.h>

static const uint32_t GNF_CONTENTS_PADDING_SIZE = 256;

FnfError fnfGnfLoad(
    GnmTexture* out_tex, void** outbuf, size_t* outbuflen, const void* inbuf,
    size_t inbuflen, uint32_t texindex
) {
	if (!out_tex || !outbuf || !outbuflen || !inbuf || !inbuflen) {
		return FNF_ERR_INVALID_ARG;
	}

	GnfError err = gnfValidate(inbuf, inbuflen);
	if (err != GNF_ERR_OK) {
		return FNF_ERR_INVALID_GNF;
	}

	const GnfHeader* header = (const GnfHeader*)inbuf;
	const GnfContents* contents =
	    (const GnfContents*)((const uint8_t*)inbuf + sizeof(GnfHeader));

	if (texindex >= contents->numtextures) {
		return FNF_ERR_INVALID_TEXTURE;
	}

	*out_tex = contents->textures[texindex];

	const uint32_t texoffset = gnfGetTextureOffset(header, texindex);
	const uint32_t texsize = gnfGetTextureSize(header, texindex);

	void* texbuf = malloc(texsize);
	if (!texbuf) {
		return FNF_ERR_OOM;
	}

	memcpy(texbuf, (const uint8_t*)inbuf + texoffset, texsize);

	*outbuf = texbuf;
	*outbuflen = texsize;
	return FNF_ERR_OK;
}

static inline int roundtopow2(const int value, const int multiple) {
	return (value + multiple - 1) & -multiple;
}

FnfError fnfGnfStore(
    void** outbuf, size_t* outbuflen, const void* inbuf, size_t inbuflen,
    const GnmTexture* tex
) {
	if (!outbuf || !outbuflen || !inbuf || !inbuflen || !tex) {
		return FNF_ERR_INVALID_ARG;
	}

	uint64_t texsize = 0;
	GnmError err = gnmTexCalcByteSize(&texsize, NULL, tex);
	if (err != GNM_ERROR_OK) {
		return FNF_ERR_INTERNAL_ERROR;
	}

	if (texsize > inbuflen) {
		return FNF_ERR_OVERFLOW;
	}

	const uint32_t numtextures = 1;
	const uint32_t userdatasize = 0;

	const uint32_t actualcontentsize = sizeof(GnfHeader) +
					   sizeof(GnfContents) +
					   (numtextures * sizeof(GnmTexture)) +
					   sizeof(GnfUserData) + userdatasize;
	const uint32_t paddedcontentsize =
	    roundtopow2(actualcontentsize, GNF_CONTENTS_PADDING_SIZE);
	const uint32_t totalsize = paddedcontentsize + texsize;

	void* gnfbuf = malloc(totalsize);
	if (!gnfbuf) {
		return FNF_ERR_OOM;
	}

	memset(gnfbuf, 0, totalsize);

	GnfHeader* header = gnfbuf;
	GnfContents* contents =
	    (GnfContents*)((uint8_t*)gnfbuf + sizeof(GnfHeader));
	GnfUserData* userdata =
	    (GnfUserData*)((uint8_t*)contents + sizeof(GnfContents) +
			   numtextures * sizeof(GnmTexture));

	header->magic = GNF_HEADER_MAGIC;
	header->contentssize = paddedcontentsize - sizeof(GnfHeader);

	contents->version = 2;
	contents->alignment = 8;
	contents->numtextures = numtextures;
	contents->streamsize = totalsize;
	contents->textures[0] = *tex;

	contents->textures[0].base_address = 0;
	contents->textures[0].metadata_addr = texsize;

	userdata->magic = GNF_USER_MAGIC;
	userdata->datasize = userdatasize;

	memcpy((uint8_t*)gnfbuf + paddedcontentsize, inbuf, texsize);

	*outbuf = gnfbuf;
	*outbuflen = totalsize;
	return FNF_ERR_OK;
}
