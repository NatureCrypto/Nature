const std = @import("std");
const Transaction = @import("transaction.zig").Transaction;
const utils = @import("../utils/utils.zig");

pub const CurrencySymbolLen = 8;

// Composite key combining account address and currency symbol
pub const AccountCurrency = struct {
    address: [utils.Crypto.PublicKeyLength]u8,
    currency: [Transaction.CurrencySymbolLen]u8,
};
