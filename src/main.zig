// src/main.zig - Main library entry point
const std = @import("std");

pub const Template = @import("template.zig").Template;

// Re-export commonly used types
pub const Allocator = std.mem.Allocator;

// Library version
pub const version = "0.1.0";

test {
    std.testing.refAllDecls(@This());
}
