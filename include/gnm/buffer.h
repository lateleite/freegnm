#ifndef _GNM_BUFFER_H_
#define _GNM_BUFFER_H_

#include "dataformat.h"
#include "error.h"
#include "types.h"

//
// buffer resource
//
typedef struct {
	// register 0
	// 256 byte aligned, also use for fmask-ptr.
	uint32_t baseaddress;

	// register 1
	uint32_t baseaddresshi : 12;  // 0
	// mtype for scalar L1, or KCache
	// 0x0 - LRU cache
	// 0x3 - Cache is bypassed
	uint32_t mtype_l1s : 2;	 // 12
	// mtype for L2
	// values for this:
	// 0x0 - no coherency
	// 0x1 - GPU coherent
	// 0x2 - System coherent
	// 0x3 - Both GPU and System coherent
	uint32_t mtype_l2 : 2;	// 14
	// byte stride
	uint32_t stride : 14;  // 16
	// buffer access. optionally swizzle texture cache TC L1 cache banks
	uint32_t cacheswizzle : 1;  // 30
	// is swizzle enabled
	uint32_t swizzleen : 1;	 // 31

	// register 2
	// in units of stride
	uint32_t numrecords;

	// register 3
	// channel X to W
	GnmChannel dstselx : 3;	 // 0
	GnmChannel dstsely : 3;	 // 3
	GnmChannel dstselz : 3;	 // 6
	GnmChannel dstselw : 3;	 // 9
	// numeric data type
	GnmBufNumFormat numformat : 3;	// 12
	// number and size of each field
	GnmBufferFormat dataformat : 4;	 // 15
	// 2, 4, 8 or 16 bytes. used for swizzled buffer addressing
	uint32_t elementsize : 2;  // 19
	// 8, 16, 32 or 64. used for swizzled buffer addressing
	uint32_t indexstride : 2;  // 21
	// add thread ID to the index for address calculation
	uint32_t addtiden : 1;	// 23
	// if 0: resource is in GPUVM memory space;
	// if 1: resource is in ATC memory space
	uint32_t atc : 1;  // 24
	// buffer addresses are hashed for better cache performance
	uint32_t hashen : 1;  // 25
	// is buffer is a heap?
	// it's out of range if offset is 0 or >= than numrecords
	uint32_t heap : 1;  // 26
	// memory type for L1, controls cache behavior
	uint32_t mtype : 3;  // 27
	// if type == 0 then it's a buffer.
	// overlaps with the upper 2 bits of texture's 4 bit type
	uint32_t type : 2;  // 30
} GnmBuffer;
_Static_assert(sizeof(GnmBuffer) == 0x10, "");

static inline void* gnmBufGetBaseAddress(const GnmBuffer* buf) {
	return (void*)((uintptr_t)buf->baseaddress |
		       ((uintptr_t)buf->baseaddresshi << 32));
}

static inline void gnmBufSetBaseAddress(GnmBuffer* buf, void* baseaddr) {
	if ((uintptr_t)baseaddr & 3) {
		gnmWriteMsg(
		    GNM_MSGSEV_ERR,
		    "gnmBuf: baseaddr must be aligned to 4 bytes"
		);
		return;
	}
	buf->baseaddress = (uintptr_t)baseaddr & 0xffffffff;
	buf->baseaddresshi = ((uintptr_t)baseaddr >> 32) & 0xfff;
}

static inline GnmDataFormat gnmBufGetFormat(const GnmBuffer* buf) {
	return (GnmDataFormat){
	    .surfacefmt = (GnmImageFormat)buf->dataformat,
	    .chantype = (GnmImgNumFormat)buf->numformat,
	    .chanx = buf->dstselx,
	    .chany = buf->dstsely,
	    .chanz = buf->dstselz,
	    .chanw = buf->dstselw,
	};
}

static inline void gnmBufSetFormat(GnmBuffer* buf, GnmDataFormat fmt) {
	if (fmt.chantype < (int)GNM_BUF_NUM_FORMAT_UNORM ||
	    fmt.chantype > (int)GNM_BUF_NUM_FORMAT_FLOAT ||
	    fmt.surfacefmt <= (int)GNM_BUF_DATA_FORMAT_INVALID ||
	    fmt.surfacefmt > (int)GNM_BUF_DATA_FORMAT_32_32_32_32) {
		gnmWriteMsg(
		    GNM_MSGSEV_ERR, "Buffer: data format is unsupported"
		);
		return;
	}
	buf->numformat = (GnmBufNumFormat)fmt.chantype;
	buf->dataformat = (GnmBufferFormat)fmt.surfacefmt;
	buf->dstselx = fmt.chanx;
	buf->dstsely = fmt.chany;
	buf->dstselz = fmt.chanz;
	buf->dstselw = fmt.chanw;
}

static inline void gnmBufSetMemoryType(
    GnmBuffer* buf, GnmMemoryType memtype, bool l1cachebypass, bool kcachebypass
) {
	buf->mtype = (!l1cachebypass ? 0x0 : 0x3) | ((memtype >> 2) & 0x4);
	buf->mtype_l1s = (!kcachebypass ? 0x0 : 0x3) | ((memtype >> 5) & 0x3);
	buf->mtype_l2 = memtype & 0x3;
}

static inline GnmBuffer gnmCreateConstBuffer(
    void* baseaddr, uint32_t bytesize
) {
	GnmBuffer res = {0};
	gnmBufSetBaseAddress(&res, baseaddr);
	res.stride = 16;
	res.numrecords = (bytesize + 15) / 16;
	gnmBufSetFormat(&res, GNM_FMT_R32G32B32A32_FLOAT);
	gnmBufSetMemoryType(&res, GNM_MEMORY_READONLY, false, false);
	return res;
}

static inline GnmBuffer gnmCreateVertexBuffer(
    void* baseaddr, GnmDataFormat fmt, uint32_t stride, uint32_t numelements
) {
	const uint32_t elementbytesize = gnmGetBitsPerElement(fmt.surfacefmt) / 8;
	const uint32_t minalignment =
	    (elementbytesize > 4 ? elementbytesize : 4) - 1;
	if ((uintptr_t)baseaddr & minalignment) {
		gnmWriteMsgf(
		    GNM_MSGSEV_ERR, "gnmBuf: baseaddr %p must be aligned to %u. Element byte size is %u",
		    baseaddr,
		    minalignment + 1,
		    elementbytesize
		);
	}

	if (stride == 0 && numelements != elementbytesize) {
		gnmWriteMsgf(
		    GNM_MSGSEV_ERR,
		    "gnmBuf: if stride is 0, numelements (%u) must be format's "
		    "size (%u)",
		    numelements, elementbytesize
		);
	}

	GnmBuffer res = {0};
	gnmBufSetBaseAddress(&res, baseaddr);
	res.stride = stride;
	res.numrecords = numelements;
	gnmBufSetFormat(&res, fmt);
	gnmBufSetMemoryType(&res, GNM_MEMORY_READONLY, false, false);
	return res;
}

#endif	// _GNM_BUFFER_H_
