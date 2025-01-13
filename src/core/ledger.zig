const std = @import("std");
const types = @import("../types/types.zig");
const Transaction = types.Transaction;
const AccountCurrency = types.AccountCurrency;
const utils = @import("../utils/utils.zig");

pub const Ledger = struct {
    allocator: std.mem.Allocator,
    accounts: std.AutoHashMap(AccountCurrency, u128),

    pub fn init(allocator: std.mem.Allocator) Ledger {
        const accounts_map = std.AutoHashMap(AccountCurrency, u128).init(allocator);

        return Ledger{
            .allocator = allocator,
            .accounts = accounts_map,
        };
    }

    /// Function to apply a transaction to the ledger
    pub fn apply_transaction(self: *Ledger, tx: Transaction) !void {
        const currency = tx.currency_symbol;
        const sender = tx.sender;
        const recipient = tx.recipient;
        const amount = tx.amount;
        const fee = @as(u128, tx.fee); // Convert fee to u128 for consistency

        // Define fee collector address (predefined or generated)
        const fee_collector_address: [utils.Wallet.AddressLength]u8 = self.get_fee_collector_address();

        // Create composite keys
        const sender_tx_currency_key = AccountCurrency{
            .address = sender,
            .currency = currency,
        };
        const sender_nature_key = AccountCurrency{
            .address = sender,
            .currency = get_fee_currency(),
        };
        const recipient_tx_currency_key = AccountCurrency{
            .address = recipient,
            .currency = currency,
        };
        const fee_collector_nature_key = AccountCurrency{
            .address = fee_collector_address,
            .currency = get_fee_currency(),
        };

        // Deduct amount from sender's transaction currency balance
        const sender_balance = self.get_balance(sender_tx_currency_key);
        if (sender_balance < amount) {
            return error.InsufficientBalance;
        }

        // Deduct fee from sender's NATURE balance
        const sender_nature_balance = self.get_balance(sender_nature_key);
        if (sender_nature_balance < fee) {
            return error.InsufficientNatureBalance;
        }

        // Update `currency` balance
        try self.update_balance(sender_tx_currency_key, sender_balance - amount);
        // Update `nature` balance
        try self.update_balance(sender_nature_key, sender_nature_balance - fee);

        // Add amount to recipient's transaction currency balance
        const recipient_balance = try self.get_balance(recipient_tx_currency_key);
        try self.update_balance(recipient_tx_currency_key, recipient_balance + amount);

        // Add fee to fee collector's NATURE balance
        const fee_collector_balance = try self.get_balance(fee_collector_nature_key);
        try self.update_balance(fee_collector_nature_key, fee_collector_balance + fee);
    }

    /// Function to get the balance of an account for a specific currency
    pub fn get_balance(self: *Ledger, key: AccountCurrency) u128 {
        const maybe_balance = self.accounts.get(key);
        return maybe_balance orelse 0;
    }

    /// Function to update the balance of an account for a specific currency
    pub fn update_balance(self: *Ledger, key: AccountCurrency, new_balance: u128) !void {
        try self.accounts.put(key, new_balance);
    }

    /// Function to retrieve the fee collector's address
    pub fn get_fee_collector_address(self: *Ledger) [utils.Wallet.AddressLength]u8 {
        // Define a static address for fee collection
        // Example: All zeros or a specific predefined public key
        _ = self;
        return [utils.Wallet.AddressLength]u8{0} ** utils.Wallet.AddressLength;
    }

    /// Returns `NATURE` inlined and filled to `Transaction.CurrencySymbolLen` size
    pub inline fn get_fee_currency() [Transaction.CurrencySymbolLen]u8 {
        var curr: [Transaction.CurrencySymbolLen]u8 = undefined;
        const nature_curr = "NATURE";
        @memcpy(curr[0..nature_curr.len], nature_curr[0..]);
        return curr;
    }
};
