
const c = @import("bindings.zig").c;


pub const RenderPass = struct {
    render_pass: c.VkRenderPass,

    pub fn init(device: c.VkDevice, format: c.VkFormat) !RenderPass {
        const color_attachment = c.VkAttachmentDescription{
            .format = format,
            .samples = c.VK_SAMPLE_COUNT_1_BIT,
            .loadOp = c.VK_ATTACHMENT_LOAD_OP_CLEAR,
            .storeOp = c.VK_ATTACHMENT_STORE_OP_STORE,
            .stencilLoadOp = c.VK_ATTACHMENT_LOAD_OP_DONT_CARE,
            .stencilStoreOp = c.VK_ATTACHMENT_STORE_OP_DONT_CARE,
            .initialLayout = c.VK_IMAGE_LAYOUT_UNDEFINED,
            .finalLayout = c.VK_IMAGE_LAYOUT_PRESENT_SRC_KHR,
            .flags = 0,
        };

        const color_attachment_ref = c.VkAttachmentReference{
            .attachment = 0,
            .layout = c.VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL,
        };

        const subpass = c.VkSubpassDescription{
            .pipelineBindPoint = c.VK_PIPELINE_BIND_POINT_GRAPHICS,
            .colorAttachmentCount = 1,
            .pColorAttachments = &color_attachment_ref,
            .flags = 0,
            .pInputAttachments = null,
            .pResolveAttachments = null,
            .pDepthStencilAttachment = null,
            .preserveAttachmentCount = 0,
            .pPreserveAttachments = null,
        };

        const rp_info = c.VkRenderPassCreateInfo{
            .sType = c.VK_STRUCTURE_TYPE_RENDER_PASS_CREATE_INFO,
            .attachmentCount = 1,
            .pAttachments = &color_attachment,
            .subpassCount = 1,
            .pSubpasses = &subpass,
            .dependencyCount = 0,
            .pDependencies = null,
            .pNext = null,
            .flags = 0,
        };

        var render_pass: c.VkRenderPass = undefined;
        if (c.vkCreateRenderPass(device, &rp_info, null, &render_pass) != c.VK_SUCCESS)
            return error.RenderPassCreationFailed;

        return RenderPass{ .render_pass = render_pass };
    }

    pub fn deinit(self: *RenderPass, device: c.VkDevice) void {
        c.vkDestroyRenderPass(device, self.render_pass, null);
    }
};

