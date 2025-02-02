const std = @import("std");
const r = @import("root.zig");

pub fn main() !void {
    const me = try r.Wallet.init();
    const alloc = std.heap.page_allocator;
    var validators = [_]r.Validator{.{ .addr = "0.0.0.0", .public_key = me.encodedPublicKey() }};
    var blockchain = r.Blockchain.init(alloc, &validators);
    var server = r.Network.init(alloc, &blockchain);
    try server.start_server(r.Network.MAINNET_PORT);
}

const REP = 15;
fn find_address() !void {
    for (0..REP) |reps| {
        for (1..1_000_000) |i| {
            const seed = r.Wallet.getRandomSeed();
            const wallet = try r.Wallet.initFromSeed(seed);
            const addr = wallet.encodedPublicKey();
            std.debug.print("{d}-{d}) {s}\n", .{ REP - reps, i, addr });
            if (is_good_wallet(addr, @as(i32, @intCast(REP - reps)), "NFEE", false)) {
                std.debug.print(" {s}\n", .{wallet.encodedPrivateKey()});
                std.debug.print(" FOUND WITH SEED: {s}\n", .{seed});
                return;
            }
        }
    }
}

fn is_good_wallet(address: [r.Wallet.AddressLength]u8, required_reps: i32, input: []const u8, lower_contains: bool) bool {
    return is_contain(address, input, lower_contains) or good_symillar_symbols(address, required_reps);
}

/// Looking for required input on start
fn starts_with(row: [r.Wallet.AddressLength]u8, input: []const u8, lower: bool) bool {
    var lowered: [r.Wallet.AddressLength]u8 = row;
    if (lower) {
        for (0..r.Wallet.AddressLength) |i| {
            lowered[i] = std.ascii.toLower(row[i]);
        }
    }

    const is_good = std.mem.eql(u8, lowered[0..input.len], input);
    if (is_good) {
        std.debug.print("{s}\n", .{highlight_occasion(lowered, input).?});
    }
    return is_good;
}

/// Looking for required input
fn is_contain(row: [r.Wallet.AddressLength]u8, input: []const u8, lower: bool) bool {
    var lowered: [r.Wallet.AddressLength]u8 = row;
    if (lower) {
        for (0..r.Wallet.AddressLength) |i| {
            lowered[i] = std.ascii.toLower(row[i]);
        }
    }

    const is_good = std.mem.indexOf(u8, &lowered, input) != null;
    if (is_good) {
        std.debug.print("{s}\n", .{highlight_occasion(lowered, input).?});
    }
    return is_good;
}

/// Looking for simmilar symbols in row
/// like `Ns0jdps777777asjxpfl`
fn good_symillar_symbols(address: [r.Wallet.AddressLength]u8, required_reps: i32) bool {
    var symb: u8 = address[0];
    var reps: i32 = 1;
    for (address) |c| {
        if (c == symb) {
            reps += 1;
        } else {
            reps = 1;
            symb = c;
        }

        if (reps == required_reps) {
            const all = std.heap.page_allocator;
            const rusize: usize = @intCast(reps);
            const val: []u8 = all.alloc(u8, rusize) catch {
                std.process.exit(1);
            };
            defer all.free(val);
            for (0..rusize) |i| {
                val[i] = symb;
            }

            std.debug.print("{?s}\n", .{highlight_occasion(address, val)});
            return true;
        }
    }
    return false;
}

fn highlight_occasion(row: [r.Wallet.AddressLength]u8, input: []const u8) ?[r.Wallet.AddressLength + 2]u8 {
    const start_idx = std.mem.indexOf(u8, &row, input);
    if (start_idx) |idx| {
        var buf: [r.Wallet.AddressLength + 2]u8 = undefined;

        // Copy the parts of `row` to `buf`
        @memcpy(buf[0..idx], row[0..idx]);
        buf[idx] = '_'; // Add the first underscore
        @memcpy(buf[idx + 1 .. idx + 1 + input.len], input);
        buf[idx + 1 + input.len] = '_'; // Add the second underscore
        @memcpy(buf[idx + 2 + input.len ..], row[idx + input.len ..]);

        return buf;
    }
    return null;
}

test "highlight" {
    const addr = "NEEmdW7CHnt2xFiG5vg4tqSJaerxofH8mxTQf5cntXdeV".*;
    const highlighted = highlight_occasion(addr, "FiG");
    const expected = "NEEmdW7CHnt2x_FiG_5vg4tqSJaerxofH8mxTQf5cntXdeV";
    try std.testing.expectEqualSlices(u8, expected, &highlighted.?);
}

test "highlight2" {
    const addr = "NCQsvLHhx6R2mWe6xaqEjeibcQTV6f65nufitdWwmQxLf".*;
    const highlighted = highlight_occasion(addr, "NCQ");
    const expected = "_NCQ_svLHhx6R2mWe6xaqEjeibcQTV6f65nufitdWwmQxLf";
    try std.testing.expectEqualSlices(u8, expected, &highlighted.?);
}

test "simmilar" {
    const text = "NCGAKSOEJ777DIAIIOSJDAKSJDL)XPKALXOFJWL++_I(A".*;
    const is_sim = good_symillar_symbols(text, 3);
    try std.testing.expectEqual(true, is_sim);
}
