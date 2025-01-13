//
// Rewrited base58 to base57 w/o 'N' symbol
//

pub const Encoder = @import("encode.zig").Encoder;
pub const Decoder = @import("decode.zig").Decoder;
pub const Alphabet = @import("alphabet.zig").Alphabet;

pub inline fn base57Length(bytes_len: comptime_int) comptime_int {
    const math = @import("std").math;
    return math.floor(bytes_len * math.log(comptime_float, 10, 256) / math.log(comptime_float, 10, 57) + 1);
}
