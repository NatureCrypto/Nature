const std = @import("std");
const expectEqualSlices = std.testing.expectEqualSlices;
const Alphabet = @import("alphabet.zig").Alphabet;

/// `Base57Encoder` is a structure for encoding byte slices into Base57 format.
pub const Encoder = struct {
    const Self = @This();

    /// Contains the Base57 alphabet used for encoding.
    ///
    /// This should be initialized with a valid Base57 character set.
    alpha: Alphabet = Alphabet.init(.{}) catch unreachable,

    pub fn encode(self: *const Self, source: []const u8, dest: []u8) usize {
        // Index in the destination slice where the next Base57 character will be written.
        var index: usize = 0;
        // Count of leading zeros in the input data.
        var zero_counter: usize = 0;

        // Count leading zeros in the input source.
        //
        // This loop increments `zero_counter` as long as leading bytes are zero.
        while (zero_counter < source.len and source[zero_counter] == 0) {
            zero_counter += 1;
        }

        // Process the remaining bytes after leading zeros have been handled.
        for (source[zero_counter..]) |val| {
            // Initialize carry with the current byte value.
            var carry: usize = @intCast(val);

            // Encode carry into Base57 digits, modifying the `dest` slice.
            // This loop processes the carry and updates the destination slice accordingly.
            for (dest[0..index]) |*byte| {
                // Add carry to current byte value (multiplied by 256).
                carry += @as(usize, byte.*) << 8;
                // Store the Base57 digit in the destination.
                byte.* = @truncate(carry % @as(usize, 57));
                // Reduce carry for the next iteration.
                carry /= 57;
            }

            // Process any remaining carry and add to the `dest` slice.
            while (carry > 0) {
                // Store the Base57 digit.
                dest[index] = @truncate(carry % 57);
                // Reduce carry for the next iteration.
                carry /= 57;
                // Move to the next position in the destination slice.
                index += 1;
            }
        }

        // Calculate the index where the encoded result ends.
        const dest_index = index + zero_counter;

        // Fill in the leading '1's for the leading zeros in the encoded result.
        // This loop places the correct number of '1' characters at the beginning of `dest`.
        for (dest[index..dest_index]) |*d| {
            d.* = self.alpha.encode[0];
        }

        // Map the Base57 digit values to their corresponding characters using the `alpha` alphabet.
        for (dest[0..index]) |*val| {
            // Convert digit values to Base57 characters.
            val.* = self.alpha.encode[val.*];
        }

        // Reverse the `dest` slice to produce the final encoded result.
        std.mem.reverse(u8, dest[0..dest_index]);
        return dest_index;
    }

    /// Pass an `allocator` & `source` bytes buffer. `encodeAlloc` will allocate a buffer
    /// to write into. It may also realloc as needed. Returned value is base57 encoded string.
    pub fn encodeAlloc(self: *const Self, allocator: std.mem.Allocator, source: []const u8) ![]u8 {
        var dest = try allocator.alloc(u8, source.len * 2);

        const size = self.encode(source, dest);
        if (dest.len != size) {
            dest = try allocator.realloc(dest, size);
        }

        return dest;
    }

    pub fn encodeCheckAlloc(encoder: *const Encoder, allocator: std.mem.Allocator, data: []const u8) ![]u8 {
        var hasher = std.crypto.hash.sha2.Sha256.init(.{});
        hasher.update(data);
        var checksum = hasher.finalResult();

        hasher = std.crypto.hash.sha2.Sha256.init(.{});
        hasher.update(&checksum);
        checksum = hasher.finalResult();

        var encoding_data = try allocator.alloc(u8, data.len + 4);
        defer allocator.free(encoding_data);

        @memcpy(encoding_data[0..data.len], data);
        @memcpy(encoding_data[data.len..], checksum[0..4]);

        return try encoder.encodeAlloc(allocator, encoding_data);
    }
};
