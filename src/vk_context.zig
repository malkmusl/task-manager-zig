const std = @import("std");
const c = @import("bindings.zig").c;

pub const VulkanContext = struct {
    instance: c.VkInstance,
    physical_device: c.VkPhysicalDevice,
    device: c.VkDevice,
    graphics_queue: c.VkQueue,
    graphics_queue_index: u32,
    
    pub fn init() !VulkanContext {
        var app_info = c.VkApplicationInfo{
            .sType = c.VK_STRUCTURE_TYPE_APPLICATION_INFO,
            .pApplicationName = "Zig Vulkan",
            .applicationVersion = c.VK_MAKE_VERSION(1, 0, 0),
            .pEngineName = "No Engine",
            .engineVersion = c.VK_MAKE_VERSION(1, 0, 0),
            .apiVersion = c.VK_API_VERSION_1_3,
            .pNext = null,
        };
        
        var ext_count: u32 = 0;
        const exts = c.glfwGetRequiredInstanceExtensions(&ext_count);
        if (exts == null) return error.ExtensionQueryFailed;
        
        const inst_info = c.VkInstanceCreateInfo{
            .sType = c.VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO,
            .pApplicationInfo = &app_info,
            .enabledLayerCount = 0,
            .enabledExtensionCount = ext_count,
            .ppEnabledExtensionNames = exts,
            .ppEnabledLayerNames = null,
            .pNext = null,
            .flags = 0,
        };
        
        var instance: c.VkInstance = undefined;
        if (c.vkCreateInstance(&inst_info, null, &instance) != c.VK_SUCCESS)
            return error.InstanceCreationFailed;
        
        var dev_count: u32 = 0;
        _ = c.vkEnumeratePhysicalDevices(instance, &dev_count, null);
        if (dev_count == 0) return error.NoDevicesFound;
        
        var gpa = std.heap.page_allocator;
        const phys_devs = try gpa.alloc(c.VkPhysicalDevice, dev_count);
        defer gpa.free(phys_devs);
        _ = c.vkEnumeratePhysicalDevices(instance, &dev_count, phys_devs.ptr);
        
        const physical_device = phys_devs[0];
        
        // Check if swapchain extension is supported
        var ext_prop_count: u32 = 0;
        _ = c.vkEnumerateDeviceExtensionProperties(physical_device, null, &ext_prop_count, null);
        const ext_props = try gpa.alloc(c.VkExtensionProperties, ext_prop_count);
        defer gpa.free(ext_props);
        _ = c.vkEnumerateDeviceExtensionProperties(physical_device, null, &ext_prop_count, ext_props.ptr);
        
        var swapchain_supported = false;
        for (ext_props) |ext_prop| {
            if (std.mem.eql(u8, std.mem.sliceTo(&ext_prop.extensionName, 0), c.VK_KHR_SWAPCHAIN_EXTENSION_NAME)) {
                swapchain_supported = true;
                break;
            }
        }
        
        if (!swapchain_supported) {
            return error.SwapchainNotSupported;
        }
        
        var q_count: u32 = 0;
        c.vkGetPhysicalDeviceQueueFamilyProperties(physical_device, &q_count, null);
        const q_props = try gpa.alloc(c.VkQueueFamilyProperties, q_count);
        defer gpa.free(q_props);
        c.vkGetPhysicalDeviceQueueFamilyProperties(physical_device, &q_count, q_props.ptr);
        
        var graphics_queue_index: u32 = 0;
        for (q_props, 0..) |q, i| {
            if ((q.queueFlags & c.VK_QUEUE_GRAPHICS_BIT) != 0) {
                graphics_queue_index = @intCast(i);
                break;
            }
        }
        
        const priority: f32 = 1.0;
        const queue_info = c.VkDeviceQueueCreateInfo{
            .sType = c.VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO,
            .queueFamilyIndex = graphics_queue_index,
            .queueCount = 1,
            .pQueuePriorities = &priority,
            .pNext = null,
            .flags = 0,
        };
        
        // Enable required device extensions
        const device_extensions = [_][*:0]const u8{
            c.VK_KHR_SWAPCHAIN_EXTENSION_NAME,
        };
        
        const dev_info = c.VkDeviceCreateInfo{
            .sType = c.VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO,
            .queueCreateInfoCount = 1,
            .pQueueCreateInfos = &queue_info,
            .pEnabledFeatures = null,
            .enabledLayerCount = 0,
            .enabledExtensionCount = device_extensions.len,
            .ppEnabledExtensionNames = &device_extensions[0],
            .ppEnabledLayerNames = null,
            .pNext = null,
            .flags = 0,
        };
        
        var device: c.VkDevice = undefined;
        if (c.vkCreateDevice(physical_device, &dev_info, null, &device) != c.VK_SUCCESS)
            return error.DeviceCreationFailed;
        
        var graphics_queue: c.VkQueue = undefined;
        c.vkGetDeviceQueue(device, graphics_queue_index, 0, &graphics_queue);
        
        return VulkanContext{
            .instance = instance,
            .physical_device = physical_device,
            .device = device,
            .graphics_queue = graphics_queue,
            .graphics_queue_index = graphics_queue_index,
        };
    }
    
    pub fn deinit(self: *VulkanContext) void {
        c.vkDestroyDevice(self.device, null);
        c.vkDestroyInstance(self.instance, null);
    }
};
