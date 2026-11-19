#ifndef _PM4_DECODER_H_
#define _PM4_DECODER_H_

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

typedef enum {
	// not errors
	PM4_ERR_OK = 0,
	PM4_ERR_END_OF_CODE,

	// errors
	PM4_ERR_BUFFER_TOO_SMALL,
	PM4_ERR_PKT_TOO_SMALL,
	PM4_ERR_INVALID_ARG,
	PM4_ERR_INVALID_TYPE,
	PM4_ERR_INTERNAL_ERROR,
	PM4_ERR_OVERFLOW,
	PM4_ERR_UNINITIALIZED_CONTEXT,
} Pm4Error;

typedef enum {
	PM4_TYPE_0 = 0,	 // FIXME draw indexed, or is it setting registers?
	PM4_TYPE_2 = 2,	 // nop packet
	PM4_TYPE_3 = 3,	 // extended packet
} Pm4PacketType;

typedef enum {
	PM4_SH_GRAPHICS = 0,
	PM4_SH_COMPUTE = 1,
} Pm4ShaderType;

typedef struct {
	Pm4PacketType type;
	uint32_t count;
	uint32_t dword_offset;

	union {
		struct {
			uint32_t base_index;
		} pkt0;
		struct {
			// TODO: move opcodes to an enum?
			uint32_t opcode;
			Pm4ShaderType shader_type;
			bool predicate;
		} pkt3;
	};
} Pm4Packet;

typedef struct {
	const uint32_t* buffer;
	uint32_t max_dwords;
	uint32_t cur_dwords;
} Pm4Decoder;

static inline Pm4Decoder pm4DecoderInit(
    const uint32_t* cmd_buffer, uint32_t cmd_dwords
) {
	return (Pm4Decoder){
	    .buffer = cmd_buffer,
	    .max_dwords = cmd_dwords,
	    .cur_dwords = 0,
	};
}

static inline void pm4DecoderReset(Pm4Decoder* decoder) {
	decoder->cur_dwords = 0;
}

Pm4Error pm4DecodePacket(
    Pm4Decoder* ctx, Pm4Packet* outpkt, uint32_t* data_buffer,
    uint32_t num_data_buffer_dwords
);
Pm4Error pm4FormatPacket(
    const Pm4Decoder* ctx, const Pm4Packet* pkt, char* outbuf, size_t outbuflen
);

#endif	// _PM4_DECODER_H_
