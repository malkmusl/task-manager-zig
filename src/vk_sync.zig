
const c = @import("bindings.zig").c;
pub const SyncObjects = struct {
    image_available: c.VkSemaphore,
    render_finished: c.VkSemaphore,
    in_flight_fence: c.VkFence,

    pub fn init(device: c.VkDevice) !SyncObjects {
        const sem_info = c.VkSemaphoreCreateInfo{
            .sType = c.VK_STRUCTURE_TYPE_SEMAPHORE_CREATE_INFO,
            .flags = 0,
            .pNext = null,
        };

        const fence_info = c.VkFenceCreateInfo{
            .sType = c.VK_STRUCTURE_TYPE_FENCE_CREATE_INFO,
            .flags = c.VK_FENCE_CREATE_SIGNALED_BIT,
            .pNext = null,
        };

        var image_available: c.VkSemaphore = undefined;
        _ = c.vkCreateSemaphore(device, &sem_info, null, &image_available);

        var render_finished: c.VkSemaphore = undefined;
        _ = c.vkCreateSemaphore(device, &sem_info, null, &render_finished);

        var in_flight_fence: c.VkFence = undefined;
        _ = c.vkCreateFence(device, &fence_info, null, &in_flight_fence);

        return SyncObjects{
            .image_available = image_available,
            .render_finished = render_finished,
            .in_flight_fence = in_flight_fence,
        };
    }

    pub fn deinit(self: *SyncObjects, device: c.VkDevice) void {
        c.vkDestroyFence(device, self.in_flight_fence, null);
        c.vkDestroySemaphore(device, self.render_finished, null);
        c.vkDestroySemaphore(device, self.image_available, null);
    }
};

