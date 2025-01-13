const std = @import("std");
const utils = @import("utils.zig");

pub const Crypto = struct {
    pub const Ed25519 = std.crypto.sign.Ed25519;
    pub const SeedLength = Ed25519.KeyPair.seed_length;
    pub const PublicKeyLength = Ed25519.PublicKey.encoded_length;
    pub const PrivateKeyLength = Ed25519.SecretKey.encoded_length;
    pub const SignatureLength = utils.Base58.base58Length(Ed25519.Signature.encoded_length);

    pub const Blake3 = std.crypto.hash.Blake3;
    pub const Base58HashLength = utils.Base58.base58Length(Blake3.digest_length);

    /// Returns Blake3 hash of `data` in raw bytes
    pub fn hash(data: []const u8) [Blake3.digest_length]u8 {
        var buf: [Blake3.digest_length]u8 = undefined;
        Blake3.hash(data, &buf, .{});
        return buf;
    }

    /// Sign data with Ed25519 secret aka private key and encode it with base58
    pub fn sign(data: []const u8, privateKey: [utils.Wallet.EncodedPrivateKeyLength]u8) ![SignatureLength]u8 {
        var secret: [PrivateKeyLength]u8 = undefined;
        _ = try bytesFromBase58(PrivateKeyLength, &privateKey, &secret);

        const keyPair = try generateKeyPairFromSecret(secret);
        const signature = try keyPair.sign(data, null);

        var b52SignBuf: [SignatureLength]u8 = undefined;
        _ = base58FromBytes(SignatureLength, &signature.toBytes(), &b52SignBuf);
        return b52SignBuf;
    }

    /// Verify data with Ed25519 public key
    pub fn verifySign(
        signature: []const u8,
        data: []const u8,
        senderPublicKey: [utils.Wallet.AddressLength]u8,
    ) !bool {
        var publicKey: [PublicKeyLength]u8 = undefined;
        _ = try bytesFromBase58(PublicKeyLength, &senderPublicKey, &publicKey);

        var bytesSignature: [Ed25519.Signature.encoded_length]u8 = undefined;
        _ = try bytesFromBase58(Ed25519.Signature.encoded_length, signature, &bytesSignature);

        const publicKeyObject = try Ed25519.PublicKey.fromBytes(publicKey);
        const signatureObject = Ed25519.Signature.fromBytes(bytesSignature);

        signatureObject.verify(data, publicKeyObject) catch |e| {
            switch (e) {
                std.crypto.errors.SignatureVerificationError.SignatureVerificationFailed => return false,
                else => return e,
            }
        };
        return true;
    }

    /// Converts bytes to Base58 with fixed padding
    pub fn base58FromBytes(
        comptime expected_len: comptime_int,
        bytes: []const u8,
        b58dest: *[expected_len]u8,
    ) usize {
        const encoder = utils.Base58.Encoder{};

        // Temporary buffer to hold the encoded Base58 string
        var temp_b58: [expected_len]u8 = undefined;

        // Perform Base58 encoding
        const encoded_length = encoder.encode(bytes, &temp_b58);

        if (std.mem.indexOf(u8, &temp_b58, &[_]u8{@as(u8, 170)})) |idx| {
            // std.log.debug("Before double N: {s} ({c} {any}, {c} {any})\n", .{
            //     temp_b58,
            //     temp_b58[temp_b58.len - 2],
            //     temp_b58[temp_b58.len - 2],
            //     temp_b58[temp_b58.len - 1],
            //     temp_b58[temp_b58.len - 1],
            // });

            // Calculate the number of padding characters needed
            const padding_length = expected_len - encoded_length;

            // Fill the beginning of b58dest with '1's for padding
            for (0..padding_length) |padded_index| {
                b58dest[padded_index] = 'N';
            }
            @memcpy(b58dest[padding_length..], temp_b58[0..idx]);
        } else {
            @memcpy(b58dest[0..], temp_b58[0..]);
        }

        // Return the total length (always expected_len)
        return expected_len;
    }

    /// Converts a fixed-length Base58 encoded string to bytes
    pub fn bytesFromBase58(
        comptime expected_len: comptime_int,
        base58: []const u8,
        bytesdest: *[expected_len]u8,
    ) !usize {
        const decoder = utils.Base58.Decoder{};

        // Count the number of leading 'N's which represent padding
        var padding_count: usize = 0;
        // Max padding is 2 (Usual padding + default N)
        while (base58[padding_count] == 'N' and padding_count < 2) {
            padding_count += 1;
        }

        _ = try decoder.decode(base58[padding_count..], bytesdest);

        // Return the number of bytes written (always bytesdest.len)
        return bytesdest.len;
    }

    /// Return Ed25519 KeyPair using seed or `std.crypto.random.bytes(&seed)`
    pub fn generateKeyPair(seed: ?[SeedLength]u8) !Ed25519.KeyPair {
        if (seed) |ss| {
            return Ed25519.KeyPair.generateDeterministic(ss);
        } else {
            return Ed25519.KeyPair.generate();
        }
    }

    /// Return Ed25519 KeyPair using secret aka privateKey
    pub fn generateKeyPairFromSecret(secret: [PrivateKeyLength]u8) !Ed25519.KeyPair {
        const secretKey = try Ed25519.SecretKey.fromBytes(secret);
        return Ed25519.KeyPair.fromSecretKey(secretKey);
    }
};

test "to and from base58 10 times with random data" {
    for (0..1000) |_| {
        const keypair = try Crypto.generateKeyPair(utils.Wallet.getRandomSeed());
        const publicBytes = keypair.public_key.bytes;
        var encodedPublic: [utils.Base58.base58Length(Crypto.PublicKeyLength)]u8 = undefined;
        var backDecoded: [Crypto.PublicKeyLength]u8 = undefined;

        _ = Crypto.base58FromBytes(encodedPublic.len, &publicBytes, &encodedPublic);
        _ = try Crypto.bytesFromBase58(backDecoded.len, &encodedPublic, &backDecoded);

        std.debug.print("\n-----\n{s}\n{any}\n{any}\n-----\n", .{ encodedPublic, publicBytes, backDecoded });

        try std.testing.expectEqualSlices(u8, &publicBytes, &backDecoded);
    }
}
