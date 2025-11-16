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
        var nodes: std.ArrayList(Node) = .empty;
        errdefer nodes.deinit(allocator);

        var i: usize = 0;
        var text_buffer: std.ArrayList(u8) = .empty;
        defer text_buffer.deinit(allocator);

        while (i < template_str.len) {
            if (i + 1 < template_str.len and
                template_str[i] == '{' and
                template_str[i + 1] == '{')
            {
                // Flush any accumulated text
                if (text_buffer.items.len > 0) {
                    const text_data = try allocator.dupe(u8, text_buffer.items);
                    try nodes.append(allocator, Node{ .action = .text, .data = text_data });
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

                    try nodes.append(allocator, Node{
                        .action = Node.Action.pipeline,
                        .data = pipeline_data,
                    });
                    i = i + end_offset + 2;
                }
            }
            try text_buffer.append(allocator, template_str[i]);
            i += 1;
        }

        // Flush any remaining text
        if (text_buffer.items.len > 0) {
            const text_data = try allocator.dupe(u8, text_buffer.items);
            try nodes.append(allocator, Node{ .action = .text, .data = text_data });
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
        self.nodes.deinit(self.allocator);
    }

    pub fn render(self: *Template, allocator: std.mem.Allocator, context: std.StringHashMap([]const u8)) ![]u8 {
        var result: std.ArrayList(u8) = .empty;
        errdefer result.deinit(allocator);

        for (self.nodes.items) |node| {
            switch (node.action) {
                .text => try result.appendSlice(allocator, node.data),
                .pipeline => {
                    const key = std.mem.trim(u8, node.data, &[_]u8{'.'});
                    if (context.get(key)) |value| {
                        try result.appendSlice(allocator, value);
                    }
                },
            }
        }

        return result.toOwnedSlice(allocator);
    }

    pub fn renderWithFunction(self: *Template, allocator: std.mem.Allocator, context: fn ([]const u8) []const u8) ![]u8 {
        var result: std.ArrayList(u8) = .empty;
        errdefer result.deinit(allocator);

        for (self.nodes.items) |node| {
            switch (node.action) {
                .text => try result.appendSlice(allocator, node.data),
                .pipeline => {
                    const key = std.mem.trim(u8, node.data, &[_]u8{'.'});
                    const val = context(key);
                    try result.appendSlice(allocator, val);
                },
            }
        }

        return result.toOwnedSlice(allocator);
    }
};

test "simple" {
    const allocator = std.testing.allocator;

    // Create a template with a simple variable
    const template_str = "Hello {{.name}}!";
    var template = try Template.init(allocator, template_str);
    defer template.deinit();

    // Create context data
    var context = std.StringHashMap([]const u8).init(allocator);
    defer context.deinit();
    try context.put("name", "World");

    // Render the template
    const result = try template.render(allocator, context);
    defer allocator.free(result);

    // Check the result
    try std.testing.expectEqualStrings("Hello World!", result);
}

test "multiple variables" {
    const allocator = std.testing.allocator;

    const template_str = "{{.greeting}} {{.name}}! You have {{.count}} messages.";
    var template = try Template.init(allocator, template_str);
    defer template.deinit();

    var context = std.StringHashMap([]const u8).init(allocator);
    defer context.deinit();
    try context.put("greeting", "Hi");
    try context.put("name", "Alice");
    try context.put("count", "3");

    const result = try template.render(allocator, context);
    defer allocator.free(result);

    try std.testing.expectEqualStrings("Hi Alice! You have 3 messages.", result);
}

test "template with missing variable" {
    const allocator = std.testing.allocator;

    const template_str = "Hello {{.name}}! Your age is {{.age}}.";
    var template = try Template.init(allocator, template_str);
    defer template.deinit();

    var context = std.StringHashMap([]const u8).init(allocator);
    defer context.deinit();
    try context.put("name", "Alice");
    // Note: 'age' is missing from context

    const result = try template.render(allocator, context);
    defer allocator.free(result);

    // Should render with empty string for missing variable
    try std.testing.expectEqualStrings("Hello Alice! Your age is .", result);
}

test "template with malformed syntax" {
    const allocator = std.testing.allocator;

    const template_str = "Hello {{.name! Missing closing braces";
    var template = try Template.init(allocator, template_str);
    defer template.deinit();

    var context = std.StringHashMap([]const u8).init(allocator);
    defer context.deinit();
    try context.put("name", "World");

    const result = try template.render(allocator, context);
    defer allocator.free(result);

    // Should treat malformed {{ as literal text
    try std.testing.expectEqualStrings("Hello {{.name! Missing closing braces", result);
}

test "empty template" {
    const allocator = std.testing.allocator;

    const template_str = "";
    var template = try Template.init(allocator, template_str);
    defer template.deinit();

    var context = std.StringHashMap([]const u8).init(allocator);
    defer context.deinit();

    const result = try template.render(allocator, context);
    defer allocator.free(result);

    try std.testing.expectEqualStrings("", result);
}

test "template with only text" {
    const allocator = std.testing.allocator;

    const template_str = "Just plain text, no variables";
    var template = try Template.init(allocator, template_str);
    defer template.deinit();

    var context = std.StringHashMap([]const u8).init(allocator);
    defer context.deinit();

    const result = try template.render(allocator, context);
    defer allocator.free(result);

    try std.testing.expectEqualStrings("Just plain text, no variables", result);
}

test "with function" {
    const allocator = std.testing.allocator;

    const template_str = "Hello {{.name}}!";
    var template = try Template.init(allocator, template_str);
    defer template.deinit();

    const context_handler = struct {
        pub fn call(key: []const u8) []const u8 {
            _ = key;
            return "world";
        }
    }.call;

    const result = try template.renderWithFunction(allocator, context_handler);
    defer allocator.free(result);

    try std.testing.expectEqualStrings("Hello world!", result);
}
