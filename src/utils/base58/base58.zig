pub const Encoder = @import("encode.zig").Encoder;
pub const Decoder = @import("decode.zig").Decoder;
pub const Alphabet = @import("alphabet.zig").Alphabet;

pub inline fn base58Length(bytes_len: comptime_int) comptime_int {
    const math = @import("std").math;
    return math.floor(bytes_len * math.log(comptime_float, 10, 256) / math.log(comptime_float, 10, 58) + 1);
}

test {
    _ = @import("tests.zig");
}
