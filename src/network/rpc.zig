const std = @import("std");
const NatureError = @import("../core/error.zig").NatureError;
const Blockchain = @import("../core/blockchain.zig").Blockchain;
const Network = @import("network.zig").Network;
const Transaction = @import("../types/transaction.zig").Transaction;

pub const RPC = struct {
    blockchain: *Blockchain,
    network: *Network,

    const RPC_PARAM_TYPE = std.json.ObjectMap;
    const RPC_FUNCTION_TYPE = *const fn (blockchain: *Blockchain, network: *Network, params: RPC_PARAM_TYPE) NatureError![]const u8;
    const METHODS_MAP_TYPE = std.StaticStringMap(RPC_FUNCTION_TYPE);
    const KEY_VALUE_PAIR = struct { []const u8, RPC_FUNCTION_TYPE };

    pub const RPC_METHODS_MAP = METHODS_MAP_TYPE.initComptime([_]KEY_VALUE_PAIR{
        .{ "ping", &ping },
        .{ "version", &version },
        .{ "submit_transaction", &submit_transaction },
    });

    pub fn init(blockchain: *Blockchain, network: *Network) @This() {
        return @This(){ .blockchain = blockchain, .network = network };
    }

    pub fn invokeRPCMethod(self: @This(), method_name: []const u8, param: RPC_PARAM_TYPE) NatureError![]const u8 {
        const method = RPC_METHODS_MAP.get(method_name);
        if (method) |m| {
            return m(self.blockchain, self.network, param);
        } else {
            return NatureError.RPCMethodNotFound;
        }
    }

    fn ping(_: *Blockchain, _: *Network, _: RPC_PARAM_TYPE) NatureError![]const u8 {
        return "pong";
    }

    fn version(_: *Blockchain, _: *Network, _: RPC_PARAM_TYPE) NatureError![]const u8 {
        return Network.NATURE_NETWORK_VERSION;
    }

    fn submit_transaction(blockchain: *Blockchain, _: *Network, params: RPC_PARAM_TYPE) NatureError![]const u8 {
        // Extract the transaction object from parameters.
        const tx = try Transaction.from_object(params);

        // Validate the transaction.
        const is_valid = blockchain.validate_transaction(tx);
        if (is_valid) {
            // Add to the transaction pool.
            try blockchain.add_transaction(tx);

            // Respond with "valid".
            return "valid";
        } else {
            // Respond with "invalid".
            return "invalid";
        }
    }

    fn _stringify(comptime T: type, object: T, allocator: std.mem.Allocator) NatureError![]const u8 {
        var buf = std.ArrayList(u8).init(allocator);
        std.json.stringify(object, .{}, buf.writer()) catch |e| {
            std.log.err("Error on RPC._stringify.stringify: {any}", .{e});
            return NatureError.StringifyError;
        };
        const json_slice = buf.toOwnedSlice() catch |e| {
            std.log.err("Error on RPC._stringify.toOwnedSlice(): {any}", .{e});
            return NatureError.StringifyError;
        };
        return json_slice;
    }
};
