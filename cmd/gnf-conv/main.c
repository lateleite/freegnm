#include <getopt.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include <gnm/fnf/fnf.h>

#include "u/fs.h"
#include "u/utility.h"
#include "version.h"

typedef enum {
	OUT_FORMAT_INVALID = 0,
	OUT_FORMAT_BMP = 1,
	OUT_FORMAT_PNG = 2,
	OUT_FORMAT_KTX = 3,
} OutFormat;

static inline OutFormat findfmt(const char* str) {
	if (!strcmp(str, "bmp")) {
		return OUT_FORMAT_BMP;
	} else if (!strcmp(str, "png")) {
		return OUT_FORMAT_PNG;
	} else if (!strcmp(str, "ktx")) {
		return OUT_FORMAT_KTX;
	}
	return OUT_FORMAT_INVALID;
}

static inline bool parsestrtoint(int* outValue, const char* str, int base) {
	char* end = NULL;
	int res = strtol(str, &end, base);
	if (*end != 0) {
		return false;
	}
	*outValue = res;
	return true;
}

static bool loadgnftexture(
    GnmTexture* outtexture, void** outtexbuf, size_t* outtexbufsize,
    const void* filebuf, size_t filesize, uint32_t texindex, bool decomp
) {
	size_t texsize = 0;
	void* texbuf = NULL;
	GnmTexture texture = {0};
	FnfError ferr = fnfGnfLoad(
	    &texture, &texbuf, &texsize, filebuf, filesize, texindex
	);
	if (ferr != FNF_ERR_OK) {
		printf(
		    "Failed to load texture %u with: %s\n", texindex,
		    fnfStrError(ferr)
		);
		free(texbuf);
		return false;
	}

	GpaTextureInfo texinfo = gpaFromGnmTexture(&texture);

	if (texture.tiling_index != GNM_TM_DISPLAY_LINEAR_GENERAL) {
		const size_t detilebufsize = texsize;
		void* detilebuf = malloc(detilebufsize);
		assert(detilebuf);

		GpaError gerr = gpaTileTextureAll(
		    texbuf, texsize, detilebuf, detilebufsize, &texinfo,
		    GNM_TM_DISPLAY_LINEAR_GENERAL
		);
		free(texbuf);
		if (gerr != GPA_ERR_OK) {
			printf(
			    "Failed to detile texture surface with: %s\n",
			    gpaStrError(gerr)
			);
			free(detilebuf);
			return false;
		}

		texture.tiling_index = GNM_TM_DISPLAY_LINEAR_GENERAL;
		texinfo.tile_mode = texture.tiling_index;
		texbuf = detilebuf;
		texsize = detilebufsize;
	}

	const GnmDataFormat fmt = gnmTexGetFormat(&texture);
	if (decomp && gnmIsBlockCompressed(fmt.surfacefmt)) {
		size_t decbufsize = 0;
		GpaError gerr = gpaGetDecompressedSize(&decbufsize, &texinfo);
		if (gerr != GPA_ERR_OK) {
			printf(
			    "Failed to get decompressed size %u with: %s\n",
			    texindex, gpaStrError(gerr)
			);
			free(texbuf);
			return false;
		}

		void* decbuf = malloc(decbufsize);
		GnmDataFormat decfmt = GNM_FMT_INVALID;
		gerr = gpaDecompressTexture(
		    decbuf, decbufsize, texbuf, texsize, &texinfo, &decfmt
		);
		if (gerr != GPA_ERR_OK) {
			printf(
			    "Failed to decompress texture %u with: %s\n",
			    texindex, gpaStrError(gerr)
			);
			free(texbuf);
			free(decbuf);
			return false;
		}

		gnmTexSetFormat(&texture, decfmt);

		free(texbuf);
		texbuf = decbuf;
		texsize = decbufsize;
	}

	*outtexture = texture;
	*outtexbuf = texbuf;
	*outtexbufsize = texsize;
	return true;
}

typedef struct {
	const char* outpath;
	OutFormat outformat;
	int texindex;
	int mip;
	int face;
} OutArgs;

static bool savetexturetofile(
    const void* texbuffer, size_t texbuffersize, const GnmTexture* texture,
    const GpaSurfaceIndex* surfindex, const char* outpath, OutFormat outfmt
) {
	void* filebuf = NULL;
	size_t filebufsize = 0;
	FnfError ferr = FNF_ERR_OK;

	// now write to the file buffer
	switch (outfmt) {
	case OUT_FORMAT_BMP:
		ferr = fnfBmpStore(
		    &filebuf, &filebufsize, texbuffer, texbuffersize, texture,
		    surfindex
		);
		if (ferr != FNF_ERR_OK) {
			printf(
			    "Failed to build out BMP image with: %s\n",
			    fnfStrError(ferr)
			);
			return false;
		}
		break;
	case OUT_FORMAT_PNG:
		ferr = fnfPngStore(
		    &filebuf, &filebufsize, texbuffer, texbuffersize, texture,
		    surfindex
		);
		if (ferr != FNF_ERR_OK) {
			printf(
			    "Failed to build out PNG image with: %s\n",
			    fnfStrError(ferr)
			);
			return false;
		}
		break;
	case OUT_FORMAT_KTX:
		ferr = fnfKtxStore(
		    &filebuf, &filebufsize, texbuffer, texbuffersize, texture
		);
		if (ferr != FNF_ERR_OK) {
			printf(
			    "Failed to build out KTX image with: %s\n",
			    fnfStrError(ferr)
			);
			return false;
		}
		break;
	default:
		puts("Unexpected out file type found when saving texture");
		abort();
	}

	int res = writefile(outpath, filebuf, filebufsize);
	if (res != 0) {
		printf("Failed to write file %s with %i\n", outpath, res);
	}

	free(filebuf);
	return res == 0;
}

static inline void printhelp(void) {
	printf(
	    "gnfconv %s\n"
	    "A GNF PS4 formatted texture files converter.\n"
	    "Usage: gnfconv [options] in-file out-file\n"
	    "Options:\n"
	    "  -t\tThe file type to convert to. Default is png. Types "
	    "available: [bmp, png, ktx]\n"
	    "  -i\tIndex of the texture to be extracted. Default is 0.\n"
	    "  -m\tTexture mip level to extract. Default is 0.\n"
	    "  -f\tTexture face index to extract. Default is 0.\n"
	    "  -d\tDecompress block-compressed texture. Default is off.\n"
	    "  -h\tShows this help message.\n"
	    "  -v\tShow this program's version.\n",
	    VERSION_STR
	);
}

static inline void printversion(void) {
	puts(VERSION_STR);
}

int main(int argc, char* argv[]) {
	OutFormat outformat = OUT_FORMAT_PNG;
	int faceindex = 0;
	int mipindex = 0;
	int texindex = 0;
	bool decompress = false;

	int c = -1;
	while ((c = getopt(argc, argv, "df:hi:m:t:v")) != -1) {
		switch (c) {
		case 'd':
			decompress = true;
			break;
		case 'f':
			if (!parsestrtoint(&faceindex, optarg, 10)) {
				fatalf("Invalid face index %s", optarg);
			}
			break;
		case 'h':
			printhelp();
			return EXIT_SUCCESS;
		case 'i':
			if (!parsestrtoint(&texindex, optarg, 10)) {
				fatalf("Invalid texture index %s", optarg);
			}
			break;
		case 'm':
			if (!parsestrtoint(&mipindex, optarg, 10)) {
				fatalf("Invalid mip index %s", optarg);
			}
			break;
		case 't':
			outformat = findfmt(optarg);
			if (outformat == OUT_FORMAT_INVALID) {
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
	bool loadres = loadgnftexture(
	    &texture, &texbuf, &texbufsize, filebuf, filesize, texindex,
	    decompress
	);

	free(filebuf);
	if (!loadres) {
		return EXIT_FAILURE;
	}

	int exitStatus = EXIT_SUCCESS;
	switch (outformat) {
	case OUT_FORMAT_KTX:
		if (!savetexturetofile(
			texbuf, texbufsize, &texture, NULL, outpath,
			OUT_FORMAT_KTX
		    )) {
			fatalf("Failed to convert texture to %s", outpath);
		}
		break;
	case OUT_FORMAT_BMP:
	case OUT_FORMAT_PNG: {
		const GpaSurfaceIndex surfindex = {
		    .arrayindex = 0,
		    .depth = 0,
		    .face = faceindex,
		    .fragment = 0,
		    .mip = 0,
		    .sample = 0,
		};
		if (!savetexturetofile(
			texbuf, texbufsize, &texture, &surfindex, outpath,
			outformat
		    )) {
			fatalf("Failed to convert texture to %s", outpath);
		}
		break;
	}
	default:
		abort();
	}

	printf("Saved texture to %s\n", outpath);

	free(texbuf);
	return exitStatus;
}
