const std = @import("std");

// Indices in the UUID string representation for each byte.
const EncodedPos = [16]u8{ 0, 2, 4, 6, 9, 11, 14, 16, 19, 21, 24, 26, 28, 30, 32, 34 };
const Hex = "0123456789abcdef";

pub const UUID = struct {
    pub const Length = 36;
    pub fn get() [UUID.Length]u8 {
        // Generate 128 random bits
        var bytes: [16]u8 = undefined;
        std.crypto.random.bytes(&bytes);

        // Set the version field to 4 (UUID v4)
        bytes[6] = (bytes[6] & 0x0F) | 0x40; // set bits 12-15 to 0100 (v4)

        // Set the variant field to 10 (RFC4122)
        bytes[8] = (bytes[8] & 0x3F) | 0x80; // set bits 6-7 to 10

        return UUID.to_string(bytes);
    }

    fn to_string(bytes: [16]u8) [UUID.Length]u8 {
        var buf: [36]u8 = undefined;
        buf[8] = '-';
        buf[13] = '-';
        buf[18] = '-';
        buf[23] = '-';

        inline for (EncodedPos, 0..) |pos, i| {
            buf[pos + 0] = Hex[bytes[i] >> 4];
            buf[pos + 1] = Hex[bytes[i] & 0x0f];
        }
        return buf;
    }
};

test "UUID" {
    const uuid1 = UUID.get();
    const uuid2 = UUID.get();
    std.debug.print("UUID 1: {s}\nUUID 2: {s}\n", .{ uuid1, uuid2 });
    try std.testing.expect(!std.mem.eql(u8, &uuid1, &uuid2));
}
