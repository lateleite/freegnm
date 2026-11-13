#include <assert.h>
#include <getopt.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "gnm/fnf/fnf.h"

#include "u/fs.h"
#include "u/utility.h"
#include "version.h"

typedef enum {
	IN_FORMAT_INVALID = 0,
	IN_FORMAT_BMP,
	IN_FORMAT_PNG,
	IN_FORMAT_KTX,
} InFormat;

static inline InFormat findfmt(const char* str) {
	if (!strcmp(str, "bmp")) {
		return IN_FORMAT_BMP;
	} else if (!strcmp(str, "png")) {
		return IN_FORMAT_PNG;
	} else if (!strcmp(str, "ktx")) {
		return IN_FORMAT_KTX;
	}
	return IN_FORMAT_INVALID;
}

static void loadimage(
    void** outbuf, size_t* outbufsize, GnmTexture* outtexture,
    const void* indata, size_t indatasize, InFormat format
) {
	FnfError ferr = FNF_ERR_OK;

	switch (format) {
	case IN_FORMAT_BMP:
		ferr = fnfBmpLoad(
		    outtexture, outbuf, outbufsize, indata, indatasize
		);
		if (ferr != FNF_ERR_OK) {
			fatalf(
			    "Failed to load BMP image with: %s",
			    fnfStrError(ferr)
			);
		}
		break;
	case IN_FORMAT_PNG:
		ferr = fnfPngLoad(
		    outtexture, outbuf, outbufsize, indata, indatasize
		);
		if (ferr != FNF_ERR_OK) {
			fatalf(
			    "Failed to load PNG image with: %s",
			    fnfStrError(ferr)
			);
		}
		break;
	case IN_FORMAT_KTX:
		ferr = fnfKtxLoad(
		    outtexture, outbuf, outbufsize, indata, indatasize
		);
		if (ferr != FNF_ERR_OK) {
			fatalf(
			    "Failed to load KTX texture with: %s",
			    fnfStrError(ferr)
			);
		}
		break;
	default:
		fatal("Unknown format used");
	}
}

static void writegnf(
    const void* texbuf, uint64_t texbufsize, const GnmTexture* texture,
    const char* outpath, bool linear, bool nomips
) {
	GnmTexture out_tex = *texture;

	if (nomips) {
		// disable mips and recalculate buffer size
		out_tex.last_level = 0;
	}

	GnmTileMode targetmode = GNM_TM_DISPLAY_LINEAR_ALIGNED;

	if (!linear) {
		const uint32_t bpp =
		    gnmGetBitsPerElement(gnmTexGetFormat(texture).surfacefmt);
		const uint32_t numfrags = gnmTexGetNumFragments(texture);

		// TODO: get gpumode dynamically?
		GpaSurfaceProperties surfprops = {0};
		GpaError err = gpaFindOptimalSurface(
		    &surfprops, GPA_SURFACE_COLOR, bpp, numfrags, false,
		    GNM_GPU_BASE
		);
		if (err != GPA_ERR_OK) {
			fatalf(
			    "Failed to find optimal surface with %s",
			    gpaStrError(err)
			);
		}

		targetmode = surfprops.tile_mode;
	}

	const GpaTextureInfo texinfo = gpaFromGnmTexture(&out_tex);

	out_tex.tiling_index = targetmode;

	uint64_t newlen = 0;
	GnmError gerr = gnmTexCalcByteSize(&newlen, NULL, &out_tex);
	if (gerr != GNM_ERROR_OK) {
		fatalf(
		    "Failed to calc new texture size with %s", gnmStrError(gerr)
		);
	}

	uint8_t* outbuf = malloc(newlen);
	assert(outbuf);

	GpaError err = gpaTileTextureAll(
	    texbuf, texbufsize, outbuf, newlen, &texinfo, targetmode
	);
	if (err != GPA_ERR_OK) {
		fatalf("Failed to tile texture with %s", gpaStrError(err));
	}

	size_t gnfsize = 0;
	void* gnfbuf = NULL;
	FnfError ferr =
	    fnfGnfStore(&gnfbuf, &gnfsize, outbuf, newlen, &out_tex);
	if (ferr != FNF_ERR_OK) {
		fatalf("Failed to build GNF data with %s", fnfStrError(ferr));
	}

	free(outbuf);

	int writeres = writefile(outpath, gnfbuf, gnfsize);
	if (writeres != 0) {
		fatalf(
		    "Failed to write GNF to %s with %s", outpath,
		    strerror(writeres)
		);
	}

	free(gnfbuf);
}

static inline void printhelp(void) {
	printf(
	    "gnfmk version %s\n"
	    "A GNF textures container file creating tool.\n"
	    "Usage: mkgnf [options] in-file out-file\n"
	    "Options:\n"
	    "  -t\tThe file type to convert from. Types available: [bmp, ktx, "
	    "png]\n"
	    "  -l\tUse linear tiling.\n"
	    "  -n\tDon't use mip levels.\n"
	    "  -h\tShows this help message.\n"
	    "  -v\tShow this program's version.\n",
	    VERSION_STR
	);
}

static inline void printversion(void) {
	puts(VERSION_STR);
}

int main(int argc, char* argv[]) {
	InFormat informat = IN_FORMAT_INVALID;
	bool linear = false;
	bool nomips = false;

	int c = -1;
	while ((c = getopt(argc, argv, "hlnt:v")) != -1) {
		switch (c) {
		case 'h':
			printhelp();
			return EXIT_SUCCESS;
		case 'l':
			linear = true;
			break;
		case 'n':
			nomips = true;
			break;
		case 't':
			informat = findfmt(optarg);
			if (informat == IN_FORMAT_INVALID) {
				fatalf("Invalid format %s", optarg);
			}
			break;
		case 'v':
			printversion();
			return EXIT_SUCCESS;
		}
	}

	const char* inpath = argv[optind];
	if (!inpath) {
		fatal("Please specify an input file");
	}

	const char* outpath = argv[optind + 1];
	if (!outpath) {
		fatal("Please specify an output file");
	}

	if (informat == IN_FORMAT_INVALID) {
		fatal("Please specify an input format");
	}

	void* filebuf = NULL;
	size_t filesize = 0;
	int readres = readfile(inpath, &filebuf, &filesize);
	if (readres != 0) {
		fatalf(
		    "Failed to read file %s with: %s", inpath, strerror(readres)
		);
	}

	void* texbuf = NULL;
	size_t texbufsize = 0;
	GnmTexture texture = {0};
	loadimage(&texbuf, &texbufsize, &texture, filebuf, filesize, informat);

	free(filebuf);

	writegnf(texbuf, texbufsize, &texture, outpath, linear, nomips);
	printf("Wrote GNF to %s\n", outpath);

	free(texbuf);
	return EXIT_SUCCESS;
}
