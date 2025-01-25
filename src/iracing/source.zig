const std = @import("std");
const win = std.os.windows;
const windows = @import("windows.zig");

// Source describes the source for data from sim
pub const Source = struct {
    memory: ?MemorySource = null,
    file: ?FileSource = null,

    pub fn fromMemory(path: []const u8) !Source {
        const source = try MemorySource.init(path);
        return Source{ .memory = source };
    }

    pub fn fromFile(path: []const u8) !Source {
        const source = try FileSource.init(path);
        return Source{ .file = source };
    }

    pub fn read(self: Source, offset: usize, buffer: []u8) !void {
        if (self.memory) |memory| {
            memory.read(offset, buffer);
        }
        if (self.file) |file| {
            try file.read(offset, buffer);
        }
    }

    pub fn deinit(self: Source) !void {
        if (self.memory) |memory| {
            try memory.deinit();
        }
        if (self.file) |file| {
            file.deinit();
        }
    }
};

const MemorySource = struct {
    handle: win.HANDLE,
    location: *anyopaque,

    fn init(path: []const u8) !MemorySource {
        const handle_name = try win.sliceToPrefixedFileW(null, path);
        const handle = try windows.openFileMappingW(windows.FILE_MAP_READ, 0, handle_name.span().ptr);
        const location = try windows.mapViewOfFile(handle, windows.FILE_MAP_READ, 0, 0, 0);

        return MemorySource{
            .handle = handle,
            .location = location,
        };
    }

    fn read(self: MemorySource, offset: usize, buffer: []u8) void {
        const memory = @as([*]u8, @ptrCast(@alignCast(self.location)))[offset .. offset + buffer.len];
        @memcpy(buffer, memory);
    }

    fn deinit(self: MemorySource) !void {
        try windows.unmapViewOfFile(self.location);
        win.CloseHandle(self.handle);
    }
};

const FileSource = struct {
    file: std.fs.File,

    fn init(path: []const u8) !FileSource {
        const file = try std.fs.cwd().openFile(path, .{});
        return FileSource{ .file = file };
    }

    fn read(self: FileSource, offset: usize, buffer: []u8) !void {
        try self.file.seekTo(offset);
        _ = try self.file.read(buffer);
    }

    fn deinit(self: FileSource) void {
        self.file.close();
    }
};
