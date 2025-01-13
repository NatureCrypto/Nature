const std = @import("std");

pub const ALPHABET: [57]u8 = [57]u8{
    '1', '2', '3', '4', '5', '6', '7', '8',
    '9', 'A', 'B', 'C', 'D', 'E', 'F', 'G',
    'H', 'J', 'K', 'L', 'M', 'P', 'Q', 'R',
    'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z',
    'a', 'b', 'c', 'd', 'e', 'f', 'g', 'h',
    'i', 'j', 'k', 'm', 'n', 'o', 'p', 'q',
    'r', 's', 't', 'u', 'v', 'w', 'x', 'y',
    'z',
};

pub const Alphabet = struct {
    encode: [57]u8,
    decode: [128]u8,

    const Options = struct { alphabet: [57]u8 = ALPHABET };

    const Self = @This();

    pub const DEFAULT = Self.init(.{}) catch unreachable;

    /// Initialize an Alpabet set with options
    pub fn init(options: Options) !Self {
        var encode = [_]u8{0x00} ** 57;
        var decode = [_]u8{0xFF} ** 128;

        for (options.alphabet, 0..) |b, i| {
            if (b >= 128) {
                return error.NonAsciiChar;
            }
            if (decode[b] != 0xFF) {
                return error.DuplicateCharacter;
            }

            encode[i] = b;
            decode[b] = @intCast(i);
        }

        return .{
            .encode = encode,
            .decode = decode,
        };
    }
};
