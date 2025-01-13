const std = @import("std");
const Transaction = @import("../types/transaction.zig").Transaction;
const Blockchain = @import("../core/blockchain.zig").Blockchain;

const consensus = @import("consensus.zig");
pub const Consensus = consensus.Consensus;
pub const Validator = consensus.Validator;

pub const Network = struct {
    allocator: std.mem.Allocator,
    peers: std.ArrayList(std.net.Stream),
    server: ?std.net.Server,

    pub fn init(allocator: std.mem.Allocator) Network {
        const peer_list = std.ArrayList(std.net.Stream).init(allocator);

        return Network{
            .allocator = allocator,
            .peers = peer_list,
            .server = null,
        };
    }

    /// Start listening for incoming connections
    pub fn start_server(self: *Network, port: u16) !void {
        const address = try std.net.Address.parseIp4("0.0.0.0", port);
        self.server = try std.net.StreamServer.listen(address, .{});
        std.debug.print("Server listening on port {d}\n", .{port});

        // Start accepting connections asynchronously
        const accept_handle = try std.Thread.spawn(.{}, Network.accept_connections, self);
        accept_handle.detach();
    }

    /// Function to accept incoming connections
    pub fn accept_connections(thread: *std.Thread, network_ptr: *Network) void {
        _ = thread;
        while (true) {
            const stream = try network_ptr.server.?.accept() catch |err| {
                std.debug.print("Error accepting connection: {}\n", .{err});
                continue;
            };
            std.debug.print("Accepted new connection.\n", .{});
            try network_ptr.peers.append(stream);

            // Handle the connection in a new thread
            const handle = try std.Thread.spawn(.{}, Network.handle_peer, network_ptr);
            handle.detach();
        }
    }

    /// Function to handle communication with a peer
    pub fn handle_peer(thread: *std.Thread, network_ptr: *Network) !void {
        // Placeholder for handling messages
        // Implement reading from the stream and processing messages
        _ = thread;
        _ = network_ptr;
    }

    /// Connect to a peer
    pub fn connect_to_peer(self: *Network, address: []const u8, port: u16) !void {
        const addr = try std.net.Address.parseIp4(address, port);
        const stream = try std.net.Stream.connect(addr, .{});
        try self.peers.append(stream);
        std.log.info("Connected to peer {s}:{d}\n", .{ address, port });

        // Handle the connection in a new thread
        const handle = try std.Thread.spawn(.{}, Network.handle_peer, self);
        handle.detach();
    }

    /// Broadcast a transaction to all peers
    pub fn broadcast_transaction(self: *Network, tx: Transaction) !void {
        const tx_bytes = try tx.serialize(self.allocator);
        for (self.peers) |peer| {
            try peer.writer().writeAll(tx_bytes);
        }
        std.log.info("Broadcasted transaction {s} to peers.\n", .{tx.hash});
    }

    /// Placeholder: Function to receive and handle transactions from peers
    pub fn receive_transactions(self: *Network, blockchain: *Blockchain) void {
        // Implement message parsing and transaction handling
        _ = self;
        _ = blockchain;
    }
};
