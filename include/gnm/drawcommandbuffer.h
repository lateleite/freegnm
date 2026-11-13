#ifndef _GNM_DRAWCOMMANDBUFFER_H_
#define _GNM_DRAWCOMMANDBUFFER_H_

#include "buffer.h"
#include "commandbuffer.h"
#include "controls.h"
#include "depthrendertarget.h"
#include "sampler.h"
#include "shader.h"
#include "texture.h"

typedef struct {
	float dmin;
	float dmax;
	float scale[3];
	float offset[3];
} GnmSetViewportInfo;

void gnmDrawCmdInitDefaultHardwareState(GnmCommandBuffer* cmd);

void gnmDrawCmdDrawIndex(
    GnmCommandBuffer* cmd, uint32_t indexcount, const void* indexaddr
);
void gnmDrawCmdDrawIndex2(
    GnmCommandBuffer* cmd, uint32_t indexcount, const void* indexaddr,
    GnmDrawModifier modifier
);
void gnmDrawCmdDrawIndexAuto(GnmCommandBuffer* cmd, uint32_t indexcount);
void gnmDrawCmdDrawIndexAuto2(
    GnmCommandBuffer* cmd, uint32_t indexcount, GnmDrawModifier modifier
);
void gnmDrawCmdDrawIndexIndirect(
    GnmCommandBuffer* cmd, uint32_t dataoffset, GnmShaderStage stage,
    uint8_t vertexoffusgpr, uint8_t instanceoffusgpr
);
void gnmDrawCmdDrawIndexIndirect2(
    GnmCommandBuffer* cmd, uint32_t dataoffset, GnmShaderStage stage,
    uint8_t vertexoffusgpr, uint8_t instanceoffusgpr, GnmDrawModifier mod
);
void gnmDrawCmdDrawIndirect(
    GnmCommandBuffer* cmd, uint32_t dataoffset, GnmShaderStage stage,
    uint8_t vertexoffusgpr, uint8_t instanceoffusgpr
);
void gnmDrawCmdDrawIndirect2(
    GnmCommandBuffer* cmd, uint32_t dataoffset, GnmShaderStage stage,
    uint8_t vertexoffusgpr, uint8_t instanceoffusgpr, GnmDrawModifier mod
);

void gnmDrawCmdSetDepthClearValue(GnmCommandBuffer* cmd, float clearvalue);
void gnmDrawCmdSetDepthRenderTarget(
    GnmCommandBuffer* cmd, const GnmDepthRenderTarget* depthtarget
);
void gnmDrawCmdSetGuardBands(
    GnmCommandBuffer* cmd, float horzclip, float vertclip, float horzdiscard,
    float vertdiscard
);
void gnmDrawCmdSetHwScreenOffset(
    GnmCommandBuffer* cmd, uint32_t offsetx, uint32_t offsety
);
void gnmDrawCmdSetIndexBuffer(GnmCommandBuffer* cmd, const void* buffer);
void gnmDrawCmdSetIndexCount(GnmCommandBuffer* cmd, uint32_t count);
void gnmDrawCmdSetIndexSize(
    GnmCommandBuffer* cmd, GnmIndexSize indexsize, GnmCachePolicy cachepol
);
void gnmDrawCmdSetIndirectArgs(
    GnmCommandBuffer* cmd, const GnmDrawIndirectArgs* args
);
void gnmDrawCmdSetIndexedIndirectArgs(
    GnmCommandBuffer* cmd, const GnmDrawIndexedIndirectArgs* args
);
void gnmDrawCmdSetInstanceStepRate(
    GnmCommandBuffer* cmd, uint32_t rate0, uint32_t rate1
);
void gnmDrawCmdSetNumInstances(GnmCommandBuffer* cmd, uint32_t count);
void gnmDrawCmdSetPrimitiveType(
    GnmCommandBuffer* cmd, GnmPrimitiveType primType
);
void gnmDrawCmdSetRenderTarget(
    GnmCommandBuffer* cmd, uint32_t rtslot, const GnmRenderTarget* rt
);
void gnmDrawCmdSetRenderTargetMask(GnmCommandBuffer* cmd, uint32_t mask);
void gnmDrawCmdSetScreenScissor(
    GnmCommandBuffer* cmd, int32_t left, int32_t top, int32_t right,
    int32_t bottom
);
void gnmDrawCmdSetViewport(
    GnmCommandBuffer* cmd, uint32_t viewportid, const GnmSetViewportInfo* vpinfo
);

void gnmDrawCmdSetPsShader(
    GnmCommandBuffer* cmd, const GnmPsStageRegisters* regs
);
void gnmDrawCmdSetEmbeddedPsShader(
    GnmCommandBuffer* cmd, GnmEmbeddedPsShader shaderid
);
void gnmDrawCmdSetVsShader(
    GnmCommandBuffer* cmd, const GnmVsStageRegisters* regs,
    uint32_t shadermodifier
);
void gnmDrawCmdSetEmbeddedVsShader(
    GnmCommandBuffer* cmd, GnmEmbeddedVsShader shaderid, uint32_t shadermodifier
);

void gnmDrawCmdSetPsInputUsage(
    GnmCommandBuffer* cmd, const GnmVertexExportSemantic* vstable,
    uint32_t numvstableitems, const GnmPixelInputSemantic* pstable,
    uint32_t numpstableitems
);

void gnmDrawCmdSetVsharpUserData(
    GnmCommandBuffer* cmd, GnmShaderStage stage, uint32_t startuserdataslot,
    const GnmBuffer* buf
);
void gnmDrawCmdSetTsharpUserData(
    GnmCommandBuffer* cmd, GnmShaderStage stage, uint32_t startuserdataslot,
    const GnmTexture* tex
);
void gnmDrawCmdSetSsharpUserData(
    GnmCommandBuffer* cmd, GnmShaderStage stage, uint32_t startuserdataslot,
    const GnmSampler* sampler
);
void gnmDrawCmdSetPointerUserData(
    GnmCommandBuffer* cmd, GnmShaderStage stage, uint32_t startuserdataslot,
    void* ptr
);

void gnmDrawCmdSetBlendControl(
    GnmCommandBuffer* cmd, uint32_t rtindex, const GnmBlendControl* ctrl
);
void gnmDrawCmdSetDepthStencilControl(
    GnmCommandBuffer* cmd, const GnmDepthStencilControl* ctrl
);
void gnmDrawCmdSetDbRenderControl(
    GnmCommandBuffer* cmd, const GnmDbRenderControl* ctrl
);
void gnmDrawCmdSetPrimitiveSetup(
    GnmCommandBuffer* cmd, const GnmPrimitiveSetup* ctrl
);
void gnmDrawCmdSetViewportTransformControl(
    GnmCommandBuffer* cmd, const GnmViewportTransformControl* ctrl
);

void gnmDrawCmdEventWriteEop(
    GnmCommandBuffer* cmd, GnmEventType evtype, uint64_t gpuaddr,
    GnmEventDataSel datasel, uint64_t immvalue
);
void gnmDrawCmdWaitGraphicsWrite(
    GnmCommandBuffer* cmd, GnmWaitGraphicsTargetMask mask
);
void gnmDrawCmdWaitOnAddress(
    GnmCommandBuffer* cmd, GnmWaitOperation op, uint64_t gpuaddr,
    uint32_t refval, uint32_t mask
);
void gnmDrawCmdWaitUntilSafeForRendering(
    GnmCommandBuffer* cmd, int32_t videohandle, uint32_t displaybufidx
);

#endif	// _GNM_DRAWCOMMANDBUFFER_H_
