//! Scheduler configuration module
//!
//! Provides instance-based APIs for determining the number of processors (P)
//! from the available CPU cores using various scaling strategies.
//! Also offers an optional global configuration instance for convenience.

const std = @import("std");
const builtin = @import("builtin");

// =====================================================
// Scheduler Configuration - Instance-based Design
// =====================================================

/// P:CPU ratio strategy.
pub const ScalingStrategy = enum {
    /// 1:1 - One processor per CPU core (default).
    OneToOne,

    /// 1:2 - Half processors compared to CPU cores.
    HalfProcessors,

    /// 1:4 - Quarter processors compared to CPU cores.
    QuarterProcessors,

    /// 2:1 - Double processors compared to CPU cores.
    DoubleProcessors,

    /// Custom - User defined ratio.
    Custom,

    /// Convert strategy to human readable string.
    pub fn toString(self: ScalingStrategy) []const u8 {
        return switch (self) {
            .OneToOne => "1:1 (P=CPU)",
            .HalfProcessors => "1:2 (P=CPU/2)",
            .QuarterProcessors => "1:4 (P=CPU/4)",
            .DoubleProcessors => "2:1 (P=CPU*2)",
            .Custom => "Custom Ratio",
        };
    }
};

/// Scheduler Configuration with instance state.
pub const SchedulerConfig = struct {
    const Self = @This();

    // =====================================================
    // Instance State
    // =====================================================

    /// Current scaling strategy for this instance.
    strategy: ScalingStrategy,

    /// Cached CPU core count (calculated once).
    cpu_cores: u32,

    /// Cached processor count (calculated once).
    processor_count: u32,

    // =====================================================
    // Configuration Constants
    // =====================================================

    /// Default scaling strategy.
    pub const DEFAULT_STRATEGY: ScalingStrategy = .OneToOne;

    /// Custom ratio settings.
    pub const CUSTOM_PROCESSOR_MULTIPLIER: f32 = 0.5;
    pub const CUSTOM_MIN_PROCESSORS: u32 = 1;
    pub const CUSTOM_MAX_PROCESSORS: u32 = 64;

    // =====================================================
    // Initialization
    // =====================================================

    /// Initialize scheduler config with specific strategy.
    pub fn init(strategy: ScalingStrategy) Self {
        const cpu_cores = getActualCpuCores();
        const processor_count = calculateProcessorCountForStrategy(cpu_cores, strategy);

        return Self{
            .strategy = strategy,
            .cpu_cores = cpu_cores,
            .processor_count = processor_count,
        };
    }

    /// Initialize scheduler config with default strategy.
    pub fn initDefault() Self {
        return init(DEFAULT_STRATEGY);
    }

    // =====================================================
    // Instance Methods
    // =====================================================

    /// Display configuration for this instance.
    pub fn displayConfig(self: *const Self) void {
        const platform = getPlatformInfo();

        std.debug.print("=== Scheduler Configuration ===\n", .{});
        std.debug.print("Platform: {s}\n", .{platform});
        std.debug.print("CPU Cores: {}\n", .{self.cpu_cores});
        std.debug.print("Strategy: {s}\n", .{self.strategy.toString()});
        std.debug.print("Processors: {} ({s})\n", .{ self.processor_count, self.getScalingDescription() });
        std.debug.print("===============================\n\n", .{});
    }

    /// Get processor count for this configuration.
    pub fn getProcessorCount(self: *const Self) u32 {
        return self.processor_count;
    }

    /// Get CPU core count for this configuration.
    pub fn getCpuCoreCount(self: *const Self) u32 {
        return self.cpu_cores;
    }

    /// Get strategy for this configuration.
    pub fn getStrategy(self: *const Self) ScalingStrategy {
        return self.strategy;
    }

    /// Get scaling description for this instance.
    fn getScalingDescription(self: *const Self) []const u8 {
        if (self.processor_count == self.cpu_cores) return "1:1 scaling";
        if (self.processor_count == self.cpu_cores / 2) return "1:2 scaling";
        if (self.processor_count == self.cpu_cores / 4) return "1:4 scaling";
        if (self.processor_count == self.cpu_cores * 2) return "2:1 scaling";
        return "custom scaling";
    }

    // =====================================================
    // Static Helper Functions
    // =====================================================

    /// Get actual CPU core count (hardware detection).
    fn getActualCpuCores() u32 {
        const count = std.Thread.getCpuCount() catch {
            const DEFAULT_CORES = 4;
            if (builtin.mode == .Debug) {
                std.debug.print("[sched] getCpuCount() failed, defaulting to {} cores\n", .{DEFAULT_CORES});
            }
            return DEFAULT_CORES;
        };
        return @as(u32, @intCast(count));
    }

    /// Calculate processor count for given strategy.
    fn calculateProcessorCountForStrategy(cpu_cores: u32, strategy: ScalingStrategy) u32 {
        const processor_count = switch (strategy) {
            .OneToOne => cpu_cores,
            .HalfProcessors => @max(1, cpu_cores / 2),
            .QuarterProcessors => @max(1, cpu_cores / 4),
            .DoubleProcessors => @min(64, cpu_cores * 2),
            .Custom => calculateCustomProcessorCount(cpu_cores),
        };

        return @max(1, processor_count);
    }

    /// Calculate custom processor count with bounds checking.
    fn calculateCustomProcessorCount(cpu_cores: u32) u32 {
        const raw_count = @as(u32, @intFromFloat(@as(f32, @floatFromInt(cpu_cores)) * CUSTOM_PROCESSOR_MULTIPLIER));
        return @max(CUSTOM_MIN_PROCESSORS, @min(CUSTOM_MAX_PROCESSORS, raw_count));
    }

    /// Get platform information string.
    fn getPlatformInfo() []const u8 {
        return switch (builtin.cpu.arch) {
            .aarch64 => switch (builtin.os.tag) {
                .macos => "Apple Silicon macOS",
                .linux => "ARM64 Linux",
                else => "ARM64 Unknown",
            },
            .x86_64 => switch (builtin.os.tag) {
                .macos => "Intel macOS",
                .linux => "x86_64 Linux",
                .windows => "x86_64 Windows",
                else => "x86_64 Unknown",
            },
            else => "Unknown Architecture",
        };
    }
};

// =====================================================
// Global Instance (for backward compatibility)
// =====================================================

/// Global default configuration instance.
var global_config: ?SchedulerConfig = null;

/// Initialize global configuration and return reference (supports chaining).
pub fn initGlobalConfig(strategy: ScalingStrategy) *SchedulerConfig {
    global_config = SchedulerConfig.init(strategy);
    return &global_config.?;
}

/// Get global configuration (lazy initialization with default strategy).
pub fn getGlobalConfig() *SchedulerConfig {
    if (global_config == null) {
        global_config = SchedulerConfig.initDefault();
    }
    return &global_config.?;
}

// =====================================================
// Convenience Functions (for backward compatibility)
// =====================================================

/// Get processor count from global config.
pub fn getProcessorCount() u32 {
    return getGlobalConfig().getProcessorCount();
}

/// Get CPU core count from global config.
pub fn getCpuCoreCount() u32 {
    return getGlobalConfig().getCpuCoreCount();
}
