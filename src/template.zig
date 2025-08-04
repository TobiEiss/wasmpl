// src/template.zig
const std = @import("std");

const Node = struct {
    action: Action,
    data: []const u8,

    pub const Action = enum { text, pipeline };
};

pub const Template = struct {
    allocator: std.mem.Allocator,
    nodes: std.ArrayList(Node),

    pub fn init(allocator: std.mem.Allocator, template_str: []const u8) !Template {
        var nodes = std.ArrayList(Node).init(allocator);
        errdefer nodes.deinit();

        var i: usize = 0;
        var text_buffer = std.ArrayList(u8).init(allocator);
        defer text_buffer.deinit();

        while (i < template_str.len) {
            if (i + 1 < template_str.len and
                template_str[i] == '{' and
                template_str[i + 1] == '{')
            {
                // Flush any accumulated text
                if (text_buffer.items.len > 0) {
                    const text_data = try allocator.dupe(u8, text_buffer.items);
                    try nodes.append(Node{ .action = .text, .data = text_data });
                    text_buffer.clearRetainingCapacity();
                }

                if (std.mem.indexOf(u8, template_str[i..], "}}")) |end_offset| {
                    const pipeline_start = i + 2;
                    const pipeline_end = pipeline_start + end_offset - 2;
                    const pipeline = std.mem.trim(
                        u8,
                        template_str[pipeline_start..pipeline_end],
                        &[_]u8{ ' ', '\t', '\n' },
                    );
                    const pipeline_data = try allocator.dupe(u8, pipeline);

                    try nodes.append(Node{
                        .action = Node.Action.pipeline,
                        .data = pipeline_data,
                    });
                    i = i + end_offset + 2;
                }
            }
            try text_buffer.append(template_str[i]);
            i += 1;
        }

        // Flush any remaining text
        if (text_buffer.items.len > 0) {
            const text_data = try allocator.dupe(u8, text_buffer.items);
            try nodes.append(Node{ .action = .text, .data = text_data });
        }

        return Template{
            .allocator = allocator,
            .nodes = nodes,
        };
    }

    pub fn deinit(self: *Template) void {
        for (self.nodes.items) |node| {
            self.allocator.free(node.data);
        }
        self.nodes.deinit();
    }

    pub fn render(self: *Template, allocator: std.mem.Allocator, context: std.StringHashMap([]const u8)) ![]u8 {
        var result = std.ArrayList(u8).init(allocator);
        defer result.deinit();

        for (self.nodes.items) |node| {
            switch (node.action) {
                .text => try result.appendSlice(node.data),
                .pipeline => {
                    const key = std.mem.trim(u8, node.data, &[_]u8{'.'});
                    if (context.get(key)) |value| {
                        try result.appendSlice(value);
                    }
                },
            }
        }

        return result.toOwnedSlice();
    }
};
