#ifndef _GPUADDRESS_TYPES_H_
#define _GPUADDRESS_TYPES_H_

#include <stdbool.h>
#include <stddef.h>

#include "gnm/dataformat.h"
#include "gnm/types.h"

typedef enum {
	GPA_SURFACE_COLORDISPLAY,
	GPA_SURFACE_COLOR,
	GPA_SURFACE_DEPTHSTENCIL,
	GPA_SURFACE_DEPTH,
	GPA_SURFACE_STENCIL,
	GPA_SURFACE_FMASK,
	GPA_SURFACE_TEXTUREFLAT,
	GPA_SURFACE_TEXTUREVOLUME,
	GPA_SURFACE_TEXTURECUBEMAP,
	GPA_SURFACE_RWTEXTUREFLAT,
	GPA_SURFACE_RWTEXTUREVOLUME,
	GPA_SURFACE_RWTEXTURECUBEMAP,
} GpaSurfaceType;

// TODO: move this to fnf
typedef struct {
	uint32_t arrayindex;
	uint32_t face;
	uint32_t mip;
	uint32_t depth;
	uint32_t fragment;
	uint32_t sample;
} GpaSurfaceIndex;

#endif	// _GPUADDRESS_TYPES_H_
