const std = @import("std");

/// Represents an item in the queue.
///
/// @param T The type of the item stored in the queue.
fn QueueItem(comptime T: type) type {
    return struct {
        item: T,
        next: ?*QueueItem(T),

        /// Initializes a new QueueItem.
        ///
        /// Allocates memory for the QueueItem using the provided allocator.
        ///
        /// @param item The item to store in the queue.
        /// @param allocator The memory allocator.
        /// @return A pointer to the newly created QueueItem.
        pub fn init(item: T, allocator: std.mem.Allocator) *QueueItem(T) {
            const newItem = allocator.create(QueueItem(T)) catch {
                @panic("Failed to allocate QueueItem!");
            };
            newItem.* = QueueItem(T){ .item = item, .next = null };
            return newItem;
        }

        /// Deinitializes the QueueItem.
        ///
        /// Frees the memory allocated for the QueueItem using the provided allocator.
        ///
        /// @param allocator The memory allocator.
        pub fn deinit(self: *QueueItem(T), allocator: std.mem.Allocator) void {
            allocator.destroy(self);
        }
    };
}

pub fn Queue(comptime T: type) type {
    return struct {
        head: ?*QueueItem(T),
        tail: ?*QueueItem(T),
        len: usize,
        allocator: std.mem.Allocator,

        const Self = @This();

        pub fn init(allocator: std.mem.Allocator) Self {
            return Self{ .head = null, .tail = null, .len = 0, .allocator = allocator };
        }

        /// Adds an item to the end of the queue.
        ///
        /// Allocates a new QueueItem and appends it to the queue.
        ///
        /// @param self The Queue instance.
        /// @param item The item to add to the queue.
        pub fn add(self: *Self, item: T) void {
            const newItem = QueueItem(T).init(item, self.allocator);

            if (self.tail) |tail_item| {
                tail_item.next = newItem;
            } else {
                self.head = newItem;
            }
            self.tail = newItem;
            self.len += 1;
        }

        /// Retrieves and removes the head item from the queue.
        ///
        /// @param self The Queue instance.
        /// @return The item if the queue is not empty, otherwise null.
        pub fn get(self: *Self) ?T {
            if (self.head) |head_item| {
                self.head = head_item.next;
                if (self.head == null) {
                    self.tail = null;
                }
                defer head_item.deinit(self.allocator);
                self.len -= 1;
                return head_item.item;
            } else {
                return null;
            }
        }

        /// Deinitializes the Queue and frees all allocated QueueItems.
        ///
        /// @param self The Queue instance.
        pub fn deinit(self: *Self) void {
            var current = self.head;
            while (current) |item| {
                const next = item.next;
                item.deinit(self.allocator);
                current = next;
            }
            self.head = null;
            self.tail = null;
            self.len = 0;
        }
    };
}

test "Blank queue" {
    var queue = Queue(i32).init(std.testing.allocator);
    defer queue.deinit();
    try std.testing.expectEqual(null, queue.get());
}

test "add and get" {
    var queue = Queue(i32).init(std.testing.allocator);
    defer queue.deinit();
    queue.add(1);
    queue.add(2);
    queue.add(3);
    queue.add(4); // SHOULDN'T BE LEAK
    try std.testing.expectEqual(1, queue.get());
    try std.testing.expectEqual(2, queue.get());
    try std.testing.expectEqual(3, queue.get());
}

const testStruct = struct {
    a: usize,
    b: usize,
};

test "struct queue" {
    var queue = Queue(testStruct).init(std.testing.allocator);
    defer queue.deinit();
    queue.add(.{ .a = 1, .b = 1 });
    queue.add(.{ .a = 2, .b = 2 });
    queue.add(.{ .a = 3, .b = 3 });

    for (1..4) |i| {
        const obj = queue.get();
        try std.testing.expectEqual(i, obj.?.a);
        try std.testing.expectEqual(i, obj.?.b);
    }

    try std.testing.expectEqual(null, queue.get());
}
