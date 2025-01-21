const std = @import("std");
const crypto = std.crypto;
const utils = @import("../utils/utils.zig");
const core = @import("../core/core.zig");

pub const Transaction = struct {
    uuid: [utils.UUID.Length]u8, // UUID of transaction
    sender: [utils.Wallet.AddressLength]u8, // Public key sender (256 bits)
    recipient: [utils.Wallet.AddressLength]u8, // Public key receiver (256 bits)
    amount: u128, // Amount in NAT. 1.2 NATURE = 1_200_000 NAT
    fee: u64, // Amount in NAT
    currency_symbol: [CurrencySymbolLen]u8, // Symbol of token that being sent (eg. NATURE)
    timestamp: i128, // Timestamp of transaction
    memo: ?[MemoMaxSize]u8,
    signature: ?[utils.Crypto.SignatureLength]u8 = null, // Ed25519 signature
    hash: ?[utils.Crypto.Base57HashLength]u8 = null,
    previous_hash: ?[utils.Crypto.Base57HashLength]u8 = null,

    pub const CurrencySymbolLen = 8;
    pub const NATValue = 1_000_000;
    pub const MemoMaxSize = 128;
    pub const FeePercent = 0.0001; // aka 0.01%
    pub const MinFeeInNAT = 0.01 * NATValue;

    /// Init transaction by user
    /// sender - base57 encoded address
    /// sender_private_key - base57 encoded secret privateKey
    /// recepient - base57 encoded address
    /// amount - in NATs
    /// currency_symbol - symbol of currency that being sent (eg. `NATURE`)
    /// previous_hash - hash of previous transaction
    pub fn initByUser(
        sender: [utils.Wallet.AddressLength]u8,
        sender_private_key: [utils.Wallet.EncodedPrivateKeyLength]u8,
        recipient: [utils.Wallet.AddressLength]u8,
        amount: f64,
        currency_symbol: []const u8,
        memo: ?[]const u8,
        previous_hash: ?[utils.Crypto.Base57HashLength]u8,
    ) !Transaction {
        var goodCurrencySymbol: [CurrencySymbolLen]u8 = undefined;
        if (currency_symbol.len > CurrencySymbolLen) {
            return core.NatureError.TooLongSymbolName;
        }
        @memcpy(goodCurrencySymbol[0..currency_symbol.len], currency_symbol[0..currency_symbol.len]);

        var goodMemo: ?[MemoMaxSize]u8 = undefined;
        if (memo) |m| {
            if (m.len > MemoMaxSize) {
                std.log.err("Provided memo size: {d} (max avaliable: {d})", .{ m.len, MemoMaxSize });
                return core.NatureError.TooLongMemo;
            } else {
                @memcpy(goodMemo.?[0..m.len], m[0..m.len]);
            }
        } else {
            goodMemo = null;
        }

        const natAmount = try calcualteNat(amount);

        var transaction = Transaction{
            .uuid = utils.UUID.get(),
            .sender = sender,
            .recipient = recipient,
            .amount = natAmount,
            .fee = calculateFee(amount),
            .currency_symbol = goodCurrencySymbol,
            .timestamp = std.time.nanoTimestamp(),
            .memo = goodMemo,
            .previous_hash = previous_hash,
        };
        // TODO: change allocator
        transaction.hash = try transaction.getHash(std.heap.page_allocator);
        try transaction.sign(sender_private_key);

        return transaction;
    }

    pub fn serialize(self: Transaction, allocator: std.mem.Allocator) ![]u8 {
        var buffer = std.ArrayList(u8).init(allocator);
        defer buffer.deinit();

        try std.json.stringify(self, .{ .emit_null_optional_fields = false }, buffer.writer());

        return try buffer.toOwnedSlice();
    }

    pub fn from_object(object: std.json.ObjectMap) !Transaction {
        _ = object;
        return core.NatureError.NotImplemented;
    }

    pub fn getHash(self: Transaction, allocator: std.mem.Allocator) ![utils.Crypto.Base57HashLength]u8 {
        const json = try self.serialize(allocator);
        defer allocator.free(json);
        const hash_bytes = utils.Crypto.hash(json);

        var hashb57: [utils.Crypto.Base57HashLength]u8 = undefined;
        _ = utils.Crypto.base57FromBytes(utils.Crypto.Base57HashLength, &hash_bytes, &hashb57);
        return hashb57;
    }

    pub fn verifySignature(self: *Transaction) !bool {
        const tmpSignatureHandler = self.signature;
        self.signature = null;
        defer self.signature = tmpSignatureHandler;
        errdefer self.signature = tmpSignatureHandler;

        const allocator = std.heap.page_allocator;
        const data = try self.serialize(allocator);
        defer allocator.free(data);

        const isGood = utils.Crypto.verifySign(&tmpSignatureHandler.?, data, self.sender);
        return isGood;
    }

    pub fn sign(self: *Transaction, privateKey: [utils.Wallet.EncodedPrivateKeyLength]u8) !void {
        const allocator = std.heap.page_allocator;
        const json = try self.serialize(allocator);
        defer allocator.free(json);

        self.signature = try utils.Crypto.sign(json, privateKey);
    }

    pub fn calcualteNat(amount: f64) !u128 {
        // true if not more then 6 symbols after comma
        const isGoodDecimal = ((amount * NATValue) - (std.math.floor(amount * NATValue))) == 0;
        if (!isGoodDecimal) {
            return core.NatureError.BadDecimal;
        } else {
            // Math floor doesnt change amount. It needed for int casting
            const natVal: u128 = @intFromFloat(amount * NATValue);
            return natVal;
        }
    }

    pub fn calculateFee(amount: f64) u64 {
        const percentage_fee: u64 = @intFromFloat(amount * FeePercent * NATValue);
        return if (percentage_fee > MinFeeInNAT) percentage_fee else MinFeeInNAT;
    }
};

fn printWallet(id: i32, wallet: utils.Wallet) void {
    const pubK = wallet.encodedPublicKey();
    const privK = wallet.encodedPrivateKey();
    std.debug.print("Wallet #{d}:\n > PUBB: {s}\n > PRIV: {s}\n", .{ id, pubK, privK });
}

fn printTransaction(t: Transaction) void {
    const amount_in_currency: f64 = @as(f64, @floatFromInt(t.amount)) / @as(f64, @floatFromInt(Transaction.NATValue));
    std.debug.print("Transaction {s}\n {s} -> {s}\n {d} NAT ({d} {s})\n Memo: {?s}\n Time: {d}\n Hash: {?s}\n Sign: {?s}\n", .{
        t.uuid,
        t.sender,
        t.recipient,
        t.amount,
        amount_in_currency,
        t.currency_symbol,
        t.memo,
        t.timestamp,
        t.hash,
        t.signature,
    });
}

test "Base transaction" {
    const wallet1 = try utils.Wallet.init();
    printWallet(1, wallet1);
    const wallet2 = try utils.Wallet.init();
    printWallet(2, wallet2);

    var t = try Transaction.initByUser(
        wallet1.encodedPublicKey(),
        wallet1.encodedPrivateKey(),
        wallet2.encodedPublicKey(),
        14.887777,
        "NATURE",
        "Transaction created successful!!",
        null,
    );
    printTransaction(t);
    const isGood = try t.verifySignature();
    std.debug.print("Is good sign? {}\n", .{isGood});
    try std.testing.expectEqual(true, isGood);

    std.debug.print("Size of basic transaction: {d}\n", .{@sizeOf(Transaction)});
}
