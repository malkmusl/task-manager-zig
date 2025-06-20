const std = @import("std");
const c = @import("bindings.zig").c;
const VulkanContext = @import("vk_context.zig").VulkanContext;
const VulkanWindow = @import("vk_window.zig").VulkanWindow;
const SyncObjects = @import("vk_sync.zig").SyncObjects;
const RenderPass = @import("vk_renderpass.zig").RenderPass;

pub fn main() !void {
    std.debug.print("Starting application...\n", .{});
    
    // Initialize GLFW
    std.debug.print("Initializing GLFW...\n", .{});
    if (c.glfwInit() == 0) {
        std.debug.print("GLFW initialization failed!\n", .{});
        return error.GLFWInitFailed;
    }
    defer c.glfwTerminate();
    std.debug.print("GLFW initialized successfully.\n", .{});
    
    // Check Vulkan support
    std.debug.print("Checking Vulkan support...\n", .{});
    if (c.glfwVulkanSupported() == c.GLFW_FALSE) {
        std.debug.print("Vulkan not supported!\n", .{});
        return error.VulkanNotSupported;
    }
    std.debug.print("Vulkan is supported.\n", .{});
    
    // Vulkan context (instance + device) 
    std.debug.print("Initializing Vulkan context...\n", .{});
    var ctx = VulkanContext.init() catch |err| {
        std.debug.print("Vulkan context initialization failed: {}\n", .{err});
        return err;
    };
    defer ctx.deinit();
    std.debug.print("Vulkan context initialized successfully.\n", .{});
    
    // Sync objects
    std.debug.print("Creating sync objects...\n", .{});
    var sync = SyncObjects.init(ctx.device) catch |err| {
        std.debug.print("Sync objects creation failed: {}\n", .{err});
        return err;
    };
    defer sync.deinit(ctx.device);
    std.debug.print("Sync objects created successfully.\n", .{});
    
    // Since both windows use the same format, we can define it here
    const swapchain_format = c.VK_FORMAT_B8G8R8A8_SRGB;
    
    // Renderpass (shared between windows)
    std.debug.print("Creating render pass...\n", .{});
    var renderpass = RenderPass.init(ctx.device, swapchain_format) catch |err| {
        std.debug.print("Render pass creation failed: {}\n", .{err});
        return err;
    };
    defer renderpass.deinit(ctx.device);
    std.debug.print("Render pass created successfully.\n", .{});
    
    std.debug.print("Creating render pass 2...\n", .{});
    var renderpass_2 = RenderPass.init(ctx.device, swapchain_format) catch |err| {
        std.debug.print("Render pass 2 creation failed: {}\n", .{err});
        return err;
    };
    defer renderpass_2.deinit(ctx.device);
    std.debug.print("Render pass 2 created successfully.\n", .{});

    // Create first window
    std.debug.print("Creating window 1...\n", .{});
    var window1 = VulkanWindow.init(&ctx, &renderpass, 800, 600, "Window 1") catch |err| {
        std.debug.print("Window 1 creation failed: {}\n", .{err});
        return err;
    };
    defer window1.deinit(&ctx);
    std.debug.print("Window 1 created successfully.\n", .{});
    
    // Create second window
    // std.debug.print("Creating window 2...\n", .{});
    // var window2 = VulkanWindow.init(&ctx, &renderpass, 640, 480, "Window 2") catch |err| {
    //     std.debug.print("Window 2 creation failed: {}\n", .{err});
    //     return err;
    // };
    // defer window2.deinit(&ctx);
    // std.debug.print("Window 2 created successfully.\n", .{});
    
    std.debug.print("Vulkan Multiwindow ready. Starting main loop...\n", .{});
    
    // Main loop
    var frame_count: u32 = 0;
    // while (c.glfwWindowShouldClose(window1.handle) == 0 or c.glfwWindowShouldClose(window2.handle) == 0) {
    while (c.glfwWindowShouldClose(window1.handle) == 0) {
        c.glfwPollEvents();
        
        // Draw window 1
        if (c.glfwWindowShouldClose(window1.handle) == 0) {
            window1.drawFrame(&ctx, &renderpass, &sync) catch |err| {
                std.debug.print("Window 1 draw frame failed: {}\n", .{err});
                break;
            };
        }
        
        // Draw window 2  
        // if (c.glfwWindowShouldClose(window2.handle) == 0) {
        //     window2.drawFrame(&ctx, &renderpass, &sync) catch |err| {
        //         std.debug.print("Window 2 draw frame failed: {}\n", .{err});
        //         break;
        //     };
        // }
        
        frame_count += 1;
        if (frame_count % 60 == 0) {
            std.debug.print("Rendered {} frames\n", .{frame_count});
        }
    }
    
    // Wait for all operations to complete before cleanup
    std.debug.print("Waiting for device idle...\n", .{});
    _ = c.vkDeviceWaitIdle(ctx.device);
    std.debug.print("Exiting.\n", .{});
}
