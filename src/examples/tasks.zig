const std = @import("std");

// =====================================================
// Task Functions
// =====================================================

pub fn task1() void {
    std.debug.print("  -> Hello from task1!\n", .{});
}

pub fn task2() void {
    std.debug.print("  -> Computing 1+1={}\n", .{2});
}

pub fn task3() void {
    std.debug.print("  -> Execute shell `{s}` commands!\n", .{"ls -l"});
}

pub fn task4() void {
    std.debug.print("  -> Downloading file: example.zip\n", .{});
}

pub fn task5() void {
    std.debug.print("  -> Parsing JSON config: {{\"server\": \"localhost\"}}\n", .{});
}

pub fn task6() void {
    std.debug.print("  -> Database query: `SELECT * FROM users;`\n", .{});
}

pub fn task7() void {
    std.debug.print("  -> HTTP GET request to 'api.example.com'\n", .{});
}

pub fn task8() void {
    std.debug.print("  -> Image processing: resize 1920x1080 -> 640x480\n", .{});
}

pub fn task9() void {
    std.debug.print("  -> Compressing data with gzip algorithm\n", .{});
}

pub fn task10() void {
    std.debug.print("  -> Sending email notification to admin\n", .{});
}

pub fn task11() void {
    std.debug.print("  -> Encrypting file with AES-256\n", .{});
}

pub fn task12() void {
    std.debug.print("  -> Cleaning up temporary cache files\n", .{});
}

pub fn task13() void {
    std.debug.print("  -> Establishing secure WebSocket connection\n", .{});
}

pub fn task14() void {
    std.debug.print("  -> Rendering Markdown to HTML\n", .{});
}

pub fn task15() void {
    std.debug.print("  -> Logging system metrics to Prometheus\n", .{});
}

pub fn task16() void {
    std.debug.print("  -> K8s: Tainting node 'worker-3' as unschedulable\n", .{});
}

pub fn task17() void {
    std.debug.print("  -> Vite: Triggering hot module replacement for App.vue\n", .{});
}

pub fn task18() void {
    std.debug.print("  -> React: Performing virtual DOM diff and re-render\n", .{});
}

pub fn task19() void {
    std.debug.print("  -> Docker: Building multi-stage image for backend service\n", .{});
}

pub fn task20() void {
    std.debug.print("  -> CI/CD: Running e2e tests on staging cluster\n", .{});
}

// Task function array for round-robin assignment to goroutines
pub const TASK_FUNCTIONS = [_]fn () void{
    task1,  task2,  task3,  task4,  task5,
    task6,  task7,  task8,  task9,  task10,
    task11, task12, task13, task14, task15,
    task16, task17, task18, task19, task20,
};
