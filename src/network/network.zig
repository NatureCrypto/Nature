const std = @import("std");
const Transaction = @import("../types/transaction.zig").Transaction;
const Blockchain = @import("../core/blockchain.zig").Blockchain;
const RPC = @import("rpc.zig").RPC;

const consensus = @import("consensus.zig");
pub const Consensus = consensus.Consensus;
pub const Validator = consensus.Validator;

pub const Network = struct {
    allocator: std.mem.Allocator,
    peers: std.ArrayList(std.net.Stream),
    server: ?std.net.Server,
    rpc: RPC,

    pub const MAINNET_PORT = 11097;
    pub const NATURE_NETWORK_VERSION = "0.0.1";

    pub fn init(allocator: std.mem.Allocator, blockchain: *Blockchain) Network {
        const peer_list = std.ArrayList(std.net.Stream).init(allocator);

        return Network{
            .allocator = allocator,
            .peers = peer_list,
            .server = null,
            .rpc = RPC.init(blockchain),
        };
    }

    /// Start the TCP server for JSON-RPC communication
    pub fn start_server(self: *Network, port: u16) !void {
        const address = try std.net.Address.parseIp4("0.0.0.0", port);
        self.server = try address.listen(.{});
        std.log.info("TCP Server listening on port {d}", .{port});

        // Start accepting connections asynchronously
        const accept_handle = try std.Thread.spawn(.{}, Network.accept_connections, .{self});
        accept_handle.join();
    }

    /// Function to accept incoming TCP connections
    pub fn accept_connections(network_ptr: *Network) !void {
        while (true) {
            const connection = network_ptr.server.?.accept() catch |err| {
                std.log.err("Error accepting connection: {}", .{err});
                continue;
            };
            std.log.info("Accepted new TCP connection.", .{});
            try network_ptr.peers.append(connection.stream);

            // Handle the connection in a new thread
            const handle = try std.Thread.spawn(.{}, Network.handle_peer, .{ network_ptr, connection.stream });
            handle.detach();
        }
    }

    /// Function to handle communication with a peer using JSON-RPC
    pub fn handle_peer(self: *Network, stream: std.net.Stream) !void {
        defer stream.close();

        var reader = stream.reader();

        // Read the incoming JSON-RPC request
        var buffer: [4096]u8 = undefined;
        const request_data = try reader.readUntilDelimiter(&buffer, '\n');
        std.log.debug("Received data: {s}", .{request_data});

        // Parse the JSON-RPC request
        var json_parsed = try std.json.parseFromSlice(std.json.Value, self.allocator, request_data, .{});
        defer json_parsed.deinit();

        var parsed = json_parsed.value.object;

        // Extract method and parameters
        const method = parsed.get("method").?.string;
        const params = parsed.get("params").?.object;
        const result = self.rpc.invokeRPCMethod(method, params);

        // Form response and stringify json it
        var response: Response = undefined;
        if (result) |val| {
            response = Response{ .success = true, .result = val };
        } else |err| {
            response = Response{ .success = false, .result = @errorName(err) };
        }

        var buf = std.ArrayList(u8).init(self.allocator);
        try std.json.stringify(response, .{}, buf.writer());
        const json_slice = try buf.toOwnedSlice();
        defer self.allocator.free(json_slice);

        try stream.writeAll(json_slice);
    }

    /// Connect to a peer via TCP
    pub fn connect_to_peer(self: *Network, address: []const u8, port: u16) !void {
        const addr = try std.net.Address.parseIp4(address, port);
        const stream = try std.net.tcpConnectToAddress(addr);
        try self.peers.append(stream);
        std.log.info("Connected to peer {s}:{d}", .{ address, port });

        // Handle the connection in a new thread
        const handle = try std.Thread.spawn(.{}, Network.handle_peer, .{ self, stream });
        handle.detach();
    }

    /// Broadcast a transaction to all peers via JSON-RPC
    pub fn broadcast_transaction(self: *Network, tx: Transaction) !void {
        // Serialize the transaction to JSON
        const tx_json = try tx.to_json(self.allocator);
        defer self.allocator.free(tx_json);

        // Construct the JSON-RPC request
        const rpc_request = try std.fmt.allocPrint(self.allocator, "{ \"jsonrpc\": \"2.0\", \"method\": \"validate_transaction\", \"params\": { \"transaction\": {s} }, \"id\": 1 }\n", .{tx_json});
        defer self.allocator.free(rpc_request);

        var successful_validations: usize = 0;
        const total_peers = self.peers.len;

        for (self.peers.items) |peer| {
            // Send the JSON-RPC request
            try peer.writer().writeAll(rpc_request);
            try peer.writer().writeAll(tx_json);

            // Read the JSON-RPC response
            var response_buffer: [4096]u8 = undefined;
            const bytes_read = try peer.reader().readAll(&response_buffer);
            const response_data = response_buffer[0..bytes_read];

            // Parse the JSON-RPC response
            var json_parser = std.json.Parser.init(response_data);
            const parsed = try json_parser.parse();
            defer json_parser.deinit();

            const result = try parsed.get("result").?.toString();
            if (std.mem.eql(u8, result, "valid")) {
                successful_validations += 1;
            } else {
                std.log.warn("Peer {s}:{d} rejected transaction {s}.", .{ peer.peer.address, peer.peer.port, tx.hash });
            }
        }

        // Determine if the transaction is approved by all peers
        if (successful_validations == total_peers) {
            try self.blockchain.add_transaction(tx);
            std.log.info("Transaction {s} committed to the ledger after unanimous validation.", .{tx.hash});
        } else {
            std.log.warn("Transaction {s} was rejected by one or more peers. Not committing.", .{tx.hash});
        }
    }
};

pub const Response = struct {
    success: bool,
    /// Json stringified response
    result: []const u8,
};
