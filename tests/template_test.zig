// tests/template_test.zig
const std = @import("std");
const testing = std.testing;
const wasmpl = @import("wasmpl");
const Template = wasmpl.Template;

// test "simple variable substitution" {
test "simple" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

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
    try testing.expectEqualStrings("Hello World!", result);
}

test "multiple variables" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

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

    try testing.expectEqualStrings("Hi Alice! You have 3 messages.", result);
}

test "template with missing variable" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

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
    try testing.expectEqualStrings("Hello Alice! Your age is .", result);
}

test "template with malformed syntax" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const template_str = "Hello {{.name! Missing closing braces";
    var template = try Template.init(allocator, template_str);
    defer template.deinit();

    var context = std.StringHashMap([]const u8).init(allocator);
    defer context.deinit();
    try context.put("name", "World");

    const result = try template.render(allocator, context);
    defer allocator.free(result);

    // Should treat malformed {{ as literal text
    try testing.expectEqualStrings("Hello {{.name! Missing closing braces", result);
}

test "empty template" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const template_str = "";
    var template = try Template.init(allocator, template_str);
    defer template.deinit();

    var context = std.StringHashMap([]const u8).init(allocator);
    defer context.deinit();

    const result = try template.render(allocator, context);
    defer allocator.free(result);

    try testing.expectEqualStrings("", result);
}

test "template with only text" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const template_str = "Just plain text, no variables";
    var template = try Template.init(allocator, template_str);
    defer template.deinit();

    var context = std.StringHashMap([]const u8).init(allocator);
    defer context.deinit();

    const result = try template.render(allocator, context);
    defer allocator.free(result);

    try testing.expectEqualStrings("Just plain text, no variables", result);
}
