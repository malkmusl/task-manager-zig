const std = @import("std");
const VulkanContext = @import("vk_context.zig").VulkanContext;
const RenderPass = @import("vk_renderpass.zig").RenderPass;
const SyncObjects = @import("vk_sync.zig").SyncObjects;

const c = @cImport({
    @cDefine("GLFW_INCLUDE_VULKAN", "1");
    @cInclude("GLFW/glfw3.h");
});

pub const VulkanWindow = struct {
    handle: *c.GLFWwindow,
    surface: c.VkSurfaceKHR,
    swapchain: c.VkSwapchainKHR,
    swapchain_format: c.VkFormat,
    swapchain_extent: c.VkExtent2D,

    image_views: []c.VkImageView,
    framebuffers: []c.VkFramebuffer,
    command_pool: c.VkCommandPool,
    command_buffers: []c.VkCommandBuffer,
    image_count: u32,
    current_image_index: u32,

    pub fn init(ctx: *VulkanContext, rp: *RenderPass, width: u32, height: u32, title: [*:0]const u8) !VulkanWindow {
        c.glfwWindowHint(c.GLFW_CLIENT_API, c.GLFW_NO_API);
        const handle = c.glfwCreateWindow(@intCast(width), @intCast(height), title, null, null);
        if (handle == null) return error.WindowCreationFailed;

        c.glfwShowWindow(handle);

        var surface: c.VkSurfaceKHR = undefined;
        if (c.glfwCreateWindowSurface(ctx.instance, handle, null, &surface) != c.VK_SUCCESS)
            return error.SurfaceCreationFailed;

        var surface_supported: c.VkBool32 = undefined;
        _ = c.vkGetPhysicalDeviceSurfaceSupportKHR(ctx.physical_device, ctx.graphics_queue_index, surface, &surface_supported);
        if (surface_supported == c.VK_FALSE) {
            return error.SurfaceNotSupported;
        }

        var surface_caps: c.VkSurfaceCapabilitiesKHR = undefined;
        _ = c.vkGetPhysicalDeviceSurfaceCapabilitiesKHR(ctx.physical_device, surface, &surface_caps);

        const format = c.VK_FORMAT_B8G8R8A8_SRGB;

        const extent = if (surface_caps.currentExtent.width != 0xFFFFFFFF) 
            surface_caps.currentExtent 
        else 
            c.VkExtent2D{ .width = width, .height = height };

        const image_count = if (surface_caps.maxImageCount > 0 and surface_caps.minImageCount + 1 > surface_caps.maxImageCount)
            surface_caps.maxImageCount
        else
            surface_caps.minImageCount + 1;

        const sc_info = c.VkSwapchainCreateInfoKHR{
            .sType = c.VK_STRUCTURE_TYPE_SWAPCHAIN_CREATE_INFO_KHR,
            .surface = surface,
            .minImageCount = image_count,
            .imageFormat = format,
            .imageColorSpace = c.VK_COLOR_SPACE_SRGB_NONLINEAR_KHR,
            .imageExtent = extent,
            .imageArrayLayers = 1,
            .imageUsage = c.VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT,
            .imageSharingMode = c.VK_SHARING_MODE_EXCLUSIVE,
            .queueFamilyIndexCount = 0,
            .pQueueFamilyIndices = null,
            .preTransform = surface_caps.currentTransform,
            .compositeAlpha = c.VK_COMPOSITE_ALPHA_OPAQUE_BIT_KHR,
            .presentMode = c.VK_PRESENT_MODE_FIFO_KHR,
            .clipped = c.VK_TRUE,
            .oldSwapchain = null,
            .pNext = null,
            .flags = 0,
        };

        var swapchain: c.VkSwapchainKHR = undefined;
        if (c.vkCreateSwapchainKHR(ctx.device, &sc_info, null, &swapchain) != c.VK_SUCCESS)
            return error.SwapchainCreationFailed;

        var actual_image_count: u32 = 0;
        _ = c.vkGetSwapchainImagesKHR(ctx.device, swapchain, &actual_image_count, null);

        const images = try std.heap.page_allocator.alloc(c.VkImage, actual_image_count);
        defer std.heap.page_allocator.free(images);

        _ = c.vkGetSwapchainImagesKHR(ctx.device, swapchain, &actual_image_count, images.ptr);

        // Image Views + Framebuffers arrays
        const image_views = try std.heap.page_allocator.alloc(c.VkImageView, actual_image_count);
        const framebuffers = try std.heap.page_allocator.alloc(c.VkFramebuffer, actual_image_count);

        for (images[0..actual_image_count], 0..) |image, i| {
            const view_info = c.VkImageViewCreateInfo{
                .sType = c.VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO,
                .image = image,
                .viewType = c.VK_IMAGE_VIEW_TYPE_2D,
                .format = format,
                .components = .{
                    .r = c.VK_COMPONENT_SWIZZLE_IDENTITY,
                    .g = c.VK_COMPONENT_SWIZZLE_IDENTITY,
                    .b = c.VK_COMPONENT_SWIZZLE_IDENTITY,
                    .a = c.VK_COMPONENT_SWIZZLE_IDENTITY,
                },
                .subresourceRange = .{
                    .aspectMask = c.VK_IMAGE_ASPECT_COLOR_BIT,
                    .baseMipLevel = 0,
                    .levelCount = 1,
                    .baseArrayLayer = 0,
                    .layerCount = 1,
                },
                .flags = 0,
                .pNext = null,
            };

            if (c.vkCreateImageView(ctx.device, &view_info, null, &image_views[i]) != c.VK_SUCCESS)
                return error.ImageViewCreationFailed;

            const fb_info = c.VkFramebufferCreateInfo{
                .sType = c.VK_STRUCTURE_TYPE_FRAMEBUFFER_CREATE_INFO,
                .renderPass = rp.render_pass,
                .attachmentCount = 1,
                .pAttachments = &image_views[i],
                .width = extent.width,
                .height = extent.height,
                .layers = 1,
                .pNext = null,
                .flags = 0,
            };

            if (c.vkCreateFramebuffer(ctx.device, &fb_info, null, &framebuffers[i]) != c.VK_SUCCESS)
                return error.FramebufferCreationFailed;
        }

        const pool_info = c.VkCommandPoolCreateInfo{
            .sType = c.VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO,
            .queueFamilyIndex = ctx.graphics_queue_index,
            .flags = c.VK_COMMAND_POOL_CREATE_RESET_COMMAND_BUFFER_BIT,
            .pNext = null,
        };

        var command_pool: c.VkCommandPool = undefined;
        if (c.vkCreateCommandPool(ctx.device, &pool_info, null, &command_pool) != c.VK_SUCCESS)
            return error.CommandPoolCreationFailed;

        const command_buffers = try std.heap.page_allocator.alloc(c.VkCommandBuffer, actual_image_count);

        const alloc_info = c.VkCommandBufferAllocateInfo{
            .sType = c.VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO,
            .commandPool = command_pool,
            .level = c.VK_COMMAND_BUFFER_LEVEL_PRIMARY,
            .commandBufferCount = actual_image_count,
            .pNext = null,
        };

        if (c.vkAllocateCommandBuffers(ctx.device, &alloc_info, command_buffers.ptr) != c.VK_SUCCESS)
            return error.CommandBufferAllocationFailed;

        return VulkanWindow{
            .handle = handle,
            .surface = surface,
            .swapchain = swapchain,
            .swapchain_format = format,
            .swapchain_extent = extent,
            .image_views = image_views,
            .framebuffers = framebuffers,
            .command_pool = command_pool,
            .command_buffers = command_buffers,
            .image_count = actual_image_count,
            .current_image_index = 0,
        };
    }

    pub fn drawFrame(self: *VulkanWindow, ctx: *VulkanContext, rp: *RenderPass, sync: *SyncObjects) !void {
        _ = c.vkWaitForFences(ctx.device, 1, &sync.in_flight_fence, c.VK_TRUE, 1_000_000_000);
        _ = c.vkResetFences(ctx.device, 1, &sync.in_flight_fence);

        var image_index: u32 = undefined;
        const acquire_result = c.vkAcquireNextImageKHR(ctx.device, self.swapchain, 1_000_000_000, sync.image_available, null, &image_index);
        if (acquire_result != c.VK_SUCCESS) return error.ImageAcquireFailed;

        self.current_image_index = image_index;
        const command_buffer = self.command_buffers[image_index];

        const begin_info = c.VkCommandBufferBeginInfo{
            .sType = c.VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO,
            .flags = c.VK_COMMAND_BUFFER_USAGE_ONE_TIME_SUBMIT_BIT,
            .pNext = null,
            .pInheritanceInfo = null,
        };
        _ = c.vkBeginCommandBuffer(command_buffer, &begin_info);

        const clear_color = c.VkClearValue{ .color = .{ .float32 = .{ 0.0, 0.0, 0.0, 1.0 } } };

        const rp_begin = c.VkRenderPassBeginInfo{
            .sType = c.VK_STRUCTURE_TYPE_RENDER_PASS_BEGIN_INFO,
            .renderPass = rp.render_pass,
            .framebuffer = self.framebuffers[image_index],
            .renderArea = .{
                .offset = .{ .x = 0, .y = 0 },
                .extent = self.swapchain_extent,
            },
            .clearValueCount = 1,
            .pClearValues = &clear_color,
            .pNext = null,
        };

        c.vkCmdBeginRenderPass(command_buffer, &rp_begin, c.VK_SUBPASS_CONTENTS_INLINE);
        c.vkCmdEndRenderPass(command_buffer);
        _ = c.vkEndCommandBuffer(command_buffer);

        const wait_stages: u32 = @intCast(c.VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT);

        const submit_info = c.VkSubmitInfo{
            .sType = c.VK_STRUCTURE_TYPE_SUBMIT_INFO,
            .waitSemaphoreCount = 1,
            .pWaitSemaphores = &sync.image_available,
            .pWaitDstStageMask = &wait_stages,
            .commandBufferCount = 1,
            .pCommandBuffers = &command_buffer,
            .signalSemaphoreCount = 1,
            .pSignalSemaphores = &sync.render_finished,
            .pNext = null,
        };

        if (c.vkQueueSubmit(ctx.graphics_queue, 1, &submit_info, sync.in_flight_fence) != c.VK_SUCCESS)
            return error.QueueSubmitFailed;

        const present_info = c.VkPresentInfoKHR{
            .sType = c.VK_STRUCTURE_TYPE_PRESENT_INFO_KHR,
            .waitSemaphoreCount = 1,
            .pWaitSemaphores = &sync.render_finished,
            .swapchainCount = 1,
            .pSwapchains = &self.swapchain,
            .pImageIndices = &self.current_image_index,
            .pResults = null,
            .pNext = null,
        };

        const present_result = c.vkQueuePresentKHR(ctx.graphics_queue, &present_info);
        if (present_result != c.VK_SUCCESS) return error.PresentFailed;
    }
};