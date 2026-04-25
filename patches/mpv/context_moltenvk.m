/*
 * MoltenVK GPU context backend for mpv.
 *
 * Consumes a CAMetalLayer pointer passed through `--wid=<int64>` and builds a
 * Vulkan surface on top of it via `vkCreateMetalSurfaceEXT`. Resize is driven
 * entirely off `layer.drawableSize`, so a host UIKit/AppKit view-controller
 * only needs to keep the layer alive — mpv polls it every VOCTRL_CHECK_EVENTS
 * and resizes the swapchain in place (no Vulkan pipeline rebuild).
 *
 * This file is part of mpv.
 *
 * mpv is free software; you can redistribute it and/or modify it under the
 * terms of the GNU Lesser General Public License as published by the Free
 * Software Foundation; either version 2.1 of the License, or (at your option)
 * any later version.
 *
 * mpv is distributed in the hope that it will be useful, but WITHOUT ANY
 * WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
 * FOR A PARTICULAR PURPOSE. See the GNU Lesser General Public License for
 * more details.
 */

// mpv's `video/out/vulkan/common.h` only defines this when `HAVE_COCOA` is
// set (the macOS Cocoa+Vulkan path); on iOS without Cocoa it never fires, so
// `<vulkan/vulkan.h>` skips `<vulkan/vulkan_metal.h>` and we lose
// VkMetalSurfaceCreateInfoEXT et al. Define it here before any header pulls
// the Vulkan core in.
#define VK_USE_PLATFORM_METAL_EXT

#import <QuartzCore/CAMetalLayer.h>

#include "video/out/gpu/context.h"
#include "video/out/vo.h"
#include "options/options.h"

#include "common.h"
#include "context.h"
#include "utils.h"

struct priv {
    struct mpvk_ctx vk;
    CAMetalLayer *layer;
    CGSize last_size;
};

static void moltenvk_uninit(struct ra_ctx *ctx)
{
    struct priv *p = ctx->priv;
    ra_vk_ctx_uninit(ctx);
    mpvk_uninit(&p->vk);
    // We don't own the layer — the host provided it through `--wid`. Drop our
    // retained reference but leave the underlying CAMetalLayer alive.
    p->layer = nil;
}

static bool moltenvk_init(struct ra_ctx *ctx)
{
    struct priv *p = ctx->priv = talloc_zero(ctx, struct priv);
    struct mpvk_ctx *vk = &p->vk;
    int msgl = ctx->opts.probing ? MSGL_V : MSGL_ERR;

    int64_t wid = ctx->vo->opts->WinID;
    if (wid == 0 || wid == -1) {
        MP_MSG(ctx, msgl, "moltenvk: --wid not set; need a CAMetalLayer pointer.\n");
        goto fail;
    }

    // __bridge: the caller retains ownership; we keep a strong ObjC reference
    // to read drawableSize until uninit.
    p->layer = (__bridge CAMetalLayer *)(void *)(intptr_t)wid;
    if (![p->layer isKindOfClass:[CAMetalLayer class]]) {
        MP_MSG(ctx, msgl, "moltenvk: --wid does not point to a CAMetalLayer.\n");
        goto fail;
    }

    if (!mpvk_init(vk, ctx, VK_EXT_METAL_SURFACE_EXTENSION_NAME))
        goto fail;

    VkMetalSurfaceCreateInfoEXT surface_info = {
        .sType = VK_STRUCTURE_TYPE_METAL_SURFACE_CREATE_INFO_EXT,
        .pNext = NULL,
        .flags = 0,
        .pLayer = (__bridge const CAMetalLayer *)p->layer,
    };
    VkResult res = vkCreateMetalSurfaceEXT(vk->vkinst->instance, &surface_info,
                                           NULL, &vk->surface);
    if (res != VK_SUCCESS) {
        MP_MSG(ctx, msgl, "moltenvk: vkCreateMetalSurfaceEXT failed (%d)\n", res);
        goto fail;
    }

    struct ra_ctx_params params = {0};
    if (!ra_vk_ctx_init(ctx, vk, params, VK_PRESENT_MODE_FIFO_KHR))
        goto fail;

    p->last_size = p->layer.drawableSize;
    return true;
fail:
    moltenvk_uninit(ctx);
    return false;
}

static bool moltenvk_reconfig(struct ra_ctx *ctx)
{
    struct priv *p = ctx->priv;
    CGSize size = p->layer.drawableSize;
    // A zero-size layer means the host hasn't laid out yet — don't attempt to
    // resize or we'll flush a dead swapchain on every poll tick.
    if (size.width <= 0 || size.height <= 0)
        return true;
    p->last_size = size;
    return ra_vk_ctx_resize(ctx, (int)size.width, (int)size.height);
}

static int moltenvk_control(struct ra_ctx *ctx, int *events, int request,
                            void *arg)
{
    struct priv *p = ctx->priv;

    switch (request) {
    case VOCTRL_CHECK_EVENTS: {
        CGSize current = p->layer.drawableSize;
        if (current.width != p->last_size.width ||
            current.height != p->last_size.height) {
            // The layer resized out from under us — e.g. UIKit device rotation.
            // Set VO_EVENT_RESIZE so mpv's main loop calls back into
            // moltenvk_reconfig, which in turn calls ra_vk_ctx_resize. No
            // VkInstance / VkDevice / shader cache teardown happens.
            *events |= VO_EVENT_RESIZE;
        }
        return VO_TRUE;
    }
    default:
        return VO_NOTIMPL;
    }
}

const struct ra_ctx_fns ra_ctx_vulkan_moltenvk = {
    .type           = "vulkan",
    .name           = "moltenvk",
    .description    = "Vulkan on Metal via MoltenVK (iOS / macOS)",
    .reconfig       = moltenvk_reconfig,
    .control        = moltenvk_control,
    .init           = moltenvk_init,
    .uninit         = moltenvk_uninit,
};
