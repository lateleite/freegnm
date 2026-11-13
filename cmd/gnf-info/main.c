#include <getopt.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include <gnm/fnf/fnf.h>
#include <gnm/strings.h>

#include "u/fs.h"
#include "u/utility.h"
#include "version.h"

static inline bool parsestrtoint(int* outValue, const char* str, int base) {
	char* end = NULL;
	int res = strtol(str, &end, base);
	if (*end != 0) {
		return false;
	}
	*outValue = res;
	return true;
}

static inline void printhelp(void) {
	printf(
	    "gnf-info %s\n"
	    "Prints information about PS4 GNF textures.\n"
	    "Usage: gnf-info [options] file\n"
	    "Options:\n"
	    "  -i\tIndex of the texture to be used. Default is 0.\n"
	    "  -h\tShows this help message.\n"
	    "  -v\tShow this program's version.\n",
	    VERSION_STR
	);
}

static inline void printversion(void) {
	puts(VERSION_STR);
}

int main(int argc, char* argv[]) {
	int texindex = 0;

	int c = -1;
	while ((c = getopt(argc, argv, "hi:v")) != -1) {
		switch (c) {
		case 'h':
			printhelp();
			return EXIT_SUCCESS;
		case 'i':
			if (!parsestrtoint(&texindex, optarg, 10)) {
				fatalf("Invalid texture index %s", optarg);
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

	void* filebuf = NULL;
	size_t filesize = 0;
	int readres = readfile(inpath, &filebuf, &filesize);
	if (readres != 0) {
		fatalf(
		    "Failed to read file %s with: %s", inpath, strerror(readres)
		);
	}

	size_t texsize = 0;
	void* texbuf = NULL;
	GnmTexture tex = {0};
	FnfError ferr =
	    fnfGnfLoad(&tex, &texbuf, &texsize, filebuf, filesize, texindex);

	free(filebuf);

	if (ferr != FNF_ERR_OK) {
		fatalf("Failed to load texture with: %s", fnfStrError(ferr));
	}

	const uint32_t width = gnmTexGetWidth(&tex);
	const uint32_t height = gnmTexGetHeight(&tex);
	const uint32_t depth = gnmTexGetDepth(&tex);
	const uint32_t pitch = gnmTexGetPitch(&tex);
	const GnmDataFormat fmt = gnmTexGetFormat(&tex);
	const uint32_t numfaces = gnmTexGetNumFaces(&tex);
	const uint32_t numfrags = gnmTexGetNumFragments(&tex);
	const uint32_t num_mips = gnmTexGetNumMips(&tex);
	const uint32_t numslices = gnmTexGetTotalArraySlices(&tex);

	printf("Texture index %i:\n", texindex);
	printf("Type: %s\n", gnmStrTextureType(tex.type));
	printf(
	    "Format: surface %s channel type %s channels %s %s %s %s\n",
	    gnmStrSurfaceFormat(fmt.surfacefmt),
	    gnmStrTexChannelType(fmt.chantype), gnmStrTexChannel(fmt.chanx),
	    gnmStrTexChannel(fmt.chany), gnmStrTexChannel(fmt.chanz),
	    gnmStrTexChannel(fmt.chanw)
	);
	printf("Dimensions: %ux%ux%u\n", width, height, depth);
	printf("Pitch: %u\n", pitch);
	printf("Tiling mode: %s\n", gnmStrTileMode(tex.tiling_index));
	printf("Faces: %u\n", numfaces);
	printf("Fragments: %u\n", numfrags);
	printf("Mips: %u\n", num_mips);
	printf("Array slices: %u\n", numslices);
	printf("Power of 2 pad: %u\n", tex.power_of_2_pad);

	free(texbuf);
	return EXIT_SUCCESS;
}
