const std = @import("std");
const utils = @import("utils.zig");

pub const Crypto = struct {
    pub const Ed25519 = std.crypto.sign.Ed25519;
    pub const SeedLength = Ed25519.KeyPair.seed_length;
    pub const PublicKeyLength = Ed25519.PublicKey.encoded_length;
    pub const PrivateKeyLength = Ed25519.SecretKey.encoded_length;
    pub const SignatureLength = utils.Base57.base57Length(Ed25519.Signature.encoded_length);

    pub const Blake3 = std.crypto.hash.Blake3;
    pub const Base57HashLength = utils.Base57.base57Length(Blake3.digest_length);

    /// Returns Blake3 hash of `data` in raw bytes
    pub fn hash(data: []const u8) [Blake3.digest_length]u8 {
        var buf: [Blake3.digest_length]u8 = undefined;
        Blake3.hash(data, &buf, .{});
        return buf;
    }

    /// Sign data with Ed25519 secret aka private key and encode it with base57
    pub fn sign(data: []const u8, privateKey: [utils.Wallet.EncodedPrivateKeyLength]u8) ![SignatureLength]u8 {
        var secret: [PrivateKeyLength]u8 = undefined;
        _ = try bytesFromBase57(PrivateKeyLength, &privateKey, &secret);

        const keyPair = try generateKeyPairFromSecret(secret);
        const signature = try keyPair.sign(data, null);

        var b52SignBuf: [SignatureLength]u8 = undefined;
        _ = base57FromBytes(SignatureLength, &signature.toBytes(), &b52SignBuf);
        return b52SignBuf;
    }

    /// Verify data with Ed25519 public key
    pub fn verifySign(
        signature: []const u8,
        data: []const u8,
        senderPublicKey: [utils.Wallet.AddressLength]u8,
    ) !bool {
        var publicKey: [PublicKeyLength]u8 = undefined;
        _ = try bytesFromBase57(PublicKeyLength, &senderPublicKey, &publicKey);

        var bytesSignature: [Ed25519.Signature.encoded_length]u8 = undefined;
        _ = try bytesFromBase57(Ed25519.Signature.encoded_length, signature, &bytesSignature);

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

    /// Converts bytes to Base57 with fixed padding
    pub fn base57FromBytes(
        comptime expected_len: comptime_int,
        bytes: []const u8,
        b57dest: *[expected_len]u8,
    ) usize {
        const encoder = utils.Base57.Encoder{};

        // Temporary buffer to hold the encoded Base57 string
        var temp_b57: [expected_len]u8 = undefined;

        // Perform Base57 encoding
        const encoded_length = encoder.encode(bytes, &temp_b57);

        if (std.mem.indexOf(u8, &temp_b57, &[_]u8{@as(u8, 170)})) |idx| {
            // std.log.debug("Before double N: {s} ({c} {any}, {c} {any})\n", .{
            //     temp_b57,
            //     temp_b57[temp_b57.len - 2],
            //     temp_b57[temp_b57.len - 2],
            //     temp_b57[temp_b57.len - 1],
            //     temp_b57[temp_b57.len - 1],
            // });

            // Calculate the number of padding characters needed
            const padding_length = expected_len - encoded_length;

            // Fill the beginning of b57dest with '1's for padding
            for (0..padding_length) |padded_index| {
                b57dest[padded_index] = 'N';
            }
            @memcpy(b57dest[padding_length..], temp_b57[0..idx]);
        } else {
            @memcpy(b57dest[0..], temp_b57[0..]);
        }

        // Return the total length (always expected_len)
        return expected_len;
    }

    /// Converts a fixed-length Base57 encoded string to bytes
    pub fn bytesFromBase57(
        comptime expected_len: comptime_int,
        base57: []const u8,
        bytesdest: *[expected_len]u8,
    ) !usize {
        const decoder = utils.Base57.Decoder{};

        // Count the number of leading 'N's which represent padding
        var padding_count: usize = 0;
        // Max padding is 2 (Usual padding + default N)
        while (base57[padding_count] == 'N' and padding_count < 2) {
            padding_count += 1;
        }

        _ = try decoder.decode(base57[padding_count..], bytesdest);

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

test "to and from base57 1000 times with random data" {
    for (0..1000) |_| {
        const keypair = try Crypto.generateKeyPair(utils.Wallet.getRandomSeed());
        const publicBytes = keypair.public_key.bytes;
        var encodedPublic: [utils.Base57.base57Length(Crypto.PublicKeyLength)]u8 = undefined;
        var backDecoded: [Crypto.PublicKeyLength]u8 = undefined;

        _ = Crypto.base57FromBytes(encodedPublic.len, &publicBytes, &encodedPublic);
        _ = try Crypto.bytesFromBase57(backDecoded.len, &encodedPublic, &backDecoded);

        try std.testing.expectEqualSlices(u8, &publicBytes, &backDecoded);
    }
}
