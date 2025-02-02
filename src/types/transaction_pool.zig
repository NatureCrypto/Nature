const std = @import("std");
const Transaction = @import("transaction.zig").Transaction;
const NatureError = @import("../core/core.zig").NatureError;

pub const TransactionPool = struct {
    pool: std.ArrayList(Transaction),

    pub fn init(allocator: std.mem.Allocator) TransactionPool {
        const pool_list = std.ArrayList(Transaction).init(allocator);

        return TransactionPool{
            .pool = pool_list,
        };
    }

    /// Add a transaction to the pool
    pub fn add_transaction(self: *TransactionPool, tx: Transaction) !void {
        self.pool.append(tx) catch {
            return NatureError.AddToTransactionPoolError;
        };
    }

    /// Remove a transaction from the pool by index
    pub fn remove_transaction(self: *TransactionPool, index: usize) !void {
        if (index >= self.pool.len) return NatureError.LedgerTransactionIndexOutOfBounds;
        _ = self.pool.orderedRemove(index);
    }

    /// Get all transactions
    pub fn get_transactions(self: *TransactionPool) []Transaction {
        return self.pool.toOwnedSlice();
    }

    /// Clear the pool
    pub fn clear(self: *TransactionPool) void {
        self.pool.clearAndFree();
    }
};
