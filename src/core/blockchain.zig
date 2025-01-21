const std = @import("std");

const types = @import("../types/types.zig");
const Transaction = types.Transaction;
const TransactionPool = types.TransactionPool;

const core = @import("core.zig");
const Ledger = core.Ledger;

const network = @import("../network/network.zig");
const Network = network.Network;
const Validator = network.Validator;
const Consensus = network.Consensus;

pub const Blockchain = struct {
    allocator: std.mem.Allocator,

    // Components of the blockchain
    transaction_pool: TransactionPool,
    ledger: Ledger,
    consensus: Consensus,

    // Initializer
    pub fn init(allocator: std.mem.Allocator, validators: []Validator) Blockchain {
        // Initialize Transaction Pool
        var tx_pool = TransactionPool.init(allocator);

        // Initialize Ledger
        var ledger = Ledger.init(allocator);

        // Initialize Consensus
        const consensus = Consensus.init(validators, &tx_pool, &ledger, allocator) catch {
            @panic("Failed to init consensus");
        };

        return Blockchain{
            .allocator = allocator,
            .transaction_pool = tx_pool,
            .ledger = ledger,
            .consensus = consensus,
        };
    }

    /// Function to add a transaction to the pool
    pub fn add_transaction(self: *Blockchain, tx: Transaction) !void {
        try self.transaction_pool.add_transaction(tx);
        // Broadcast the transaction to peers
        try self.network.broadcast_transaction(tx); // TODO: Fix this
    }

    /// Function to validate transaction
    pub fn validate_transaction(self: *Blockchain, tx: Transaction) bool {
        const static_values_check = tx.verifySignature() and tx.currency_symbol.len <= Transaction.CurrencySymbolLen and tx.memo <= Transaction.MemoMaxSize;
        const balances_check = bal: {
            // TODO: Implement easy to call balance check logic from ledger and call here
            _ = self.ledger;
            break :bal false;
        };
        return static_values_check and balances_check;
    }

    /// Function to process transactions from the pool
    pub fn process_transactions(self: *Blockchain) !void {
        const txs = self.transaction_pool.get_transactions();
        for (txs, 0..) |tx, idx| {
            // Validate transaction
            if (try tx.verifySignature()) |isValid| {
                if (isValid) {
                    // Add to ledger
                    try self.ledger.apply_transaction(tx);

                    // Remove from pool
                    try self.transaction_pool.remove_transaction(idx);

                    std.log.info("Transaction {s} applied to ledger.\n", .{tx.hash});
                } else {
                    std.log.err("Invalid signature for transaction {s}.\n", .{tx.hash});
                }
            } else |err| {
                std.log.err("Error verifying signature for transaction {s}: {}\n", .{ tx.hash, err });
            }
        }
    }

    /// Function to run the consensus mechanism
    pub fn run_consensus(self: *Blockchain) !void {
        // Example: Propose transactions from the pool
        const txs = self.transaction_pool.get_transactions();
        for (txs) |tx| {
            try self.consensus.propose_transaction(tx);
            // After proposing, validate and apply transaction
            try self.ledger.apply_transaction(tx);
            // Remove from pool
            // (Ensure thread-safety and avoid index issues)
        }
    }
};
