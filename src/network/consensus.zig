const std = @import("std");
const types = @import("../types/types.zig");
const Transaction = types.Transaction;
const TransactionPool = types.TransactionPool;
const core = @import("../core/core.zig");
const Ledger = core.Ledger;
const Wallet = @import("../utils/wallet.zig").Wallet;

pub const Validator = struct {
    public_key: [Wallet.AddressLength]u8, // Public key of the validator
    addr: []const u8, // 15 len max
};

pub const Consensus = struct {
    validators: std.ArrayList(Validator),
    current_index: usize,
    transaction_pool: *TransactionPool, // Reference to the blockchain's transaction pool
    ledger: *Ledger, // Reference to the blockchain's ledger

    pub fn init(validators: []Validator, tx_pool: *TransactionPool, ledger: *Ledger, allocator: std.mem.Allocator) !Consensus {
        var validator_list = std.ArrayList(Validator).init(allocator);
        try validator_list.appendSlice(validators);
        return Consensus{
            .validators = validator_list,
            .current_index = 0,
            .transaction_pool = tx_pool,
            .ledger = ledger,
        };
    }

    /// Function to propose and validate a transaction
    pub fn propose_transaction(self: *Consensus) !void {
        if (self.validators.len == 0) return error.NoValidators;

        // Select the current validator
        const validator = self.validators.items[self.current_index];

        std.log.info("Validator {s} is proposing a transaction.\n", .{validator.public_key});

        // Select a transaction from the pool
        const tx_opt = self.transaction_pool.pool.items[0];
        if (tx_opt == null) {
            std.log.info("No transactions to propose.\n", .{});
            return;
        }
        const tx = tx_opt.?;

        // Validate the transaction
        if (!try tx.verifySignature()) {
            std.log.info("Invalid transaction signature. Removing from pool.\n", .{});
            try self.transaction_pool.remove_transaction(0);
            return;
        }

        // Apply the transaction to the ledger
        try self.ledger.apply_transaction(tx);

        std.log.info("Transaction {s} applied by validator {s}.\n", .{ tx.hash, validator.name });

        // Remove the transaction from the pool
        try self.transaction_pool.remove_transaction(0);

        // Move to the next validator
        self.current_index = (self.current_index + 1) % self.validators.len;
    }

    /// Function to add a new validator
    pub fn add_validator(self: *Consensus, validator: Validator) !void {
        try self.validators.append(validator);
    }

    /// Function to remove a validator by index
    pub fn remove_validator(self: *Consensus, index: usize) !void {
        if (index >= self.validators.len) return error.InvalidValidatorIndex;
        try self.validators.remove(index);
    }
};
