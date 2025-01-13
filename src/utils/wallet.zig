const std = @import("std");
const utils = @import("utils.zig");

pub const Wallet = struct {
    seed: ?[utils.Crypto.SeedLength]u8,
    publicKey: [utils.Crypto.PublicKeyLength]u8,
    privateKey: [utils.Crypto.PrivateKeyLength]u8,

    pub const AddressPrefix = "N";
    /// "N" + base57 encoded PublicKeyBytes (44) == 45
    pub const AddressLength = AddressPrefix.len + utils.Base57.base57Length(utils.Crypto.PublicKeyLength);
    /// base 57 encoded PrivateKeyBytes (88)
    pub const EncodedPrivateKeyLength = utils.Base57.base57Length(utils.Crypto.PrivateKeyLength);

    /// Return random seed in hex encoded
    pub fn getRandomSeed() [utils.Crypto.SeedLength]u8 {
        const AllowedChars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
        var buf: [utils.Crypto.SeedLength]u8 = undefined;

        inline for (&buf) |*c| {
            const rand_idx = std.crypto.random.int(u8) % AllowedChars.len;
            c.* = AllowedChars[rand_idx];
        }
        return buf;
    }

    pub fn init() !Wallet {
        const keyPair = try utils.Crypto.generateKeyPair(null);
        return Wallet.initFromKeyPair(keyPair, null);
    }

    pub fn initFromSeed(seed: [utils.Crypto.SeedLength]u8) !Wallet {
        const keyPair = try utils.Crypto.generateKeyPair(seed);
        return Wallet.initFromKeyPair(keyPair, seed);
    }

    pub fn initFromPrivateKey(privateKey: [utils.Crypto.PrivateKeyLength]u8) !Wallet {
        const keyPair = try utils.Crypto.generateKeyPairFromSecret(privateKey);
        return Wallet.initFromKeyPair(keyPair, null);
    }

    pub fn initFromKeyPair(keyPair: utils.Crypto.Ed25519.KeyPair, seed: ?[utils.Crypto.SeedLength]u8) !Wallet {
        const pubKey = keyPair.public_key.toBytes();
        const privKey = keyPair.secret_key.toBytes();
        return Wallet{ .seed = seed, .publicKey = pubKey, .privateKey = privKey };
    }

    pub fn encodedPublicKey(self: Wallet) [AddressLength]u8 {
        var result: [AddressLength]u8 = undefined;

        _ = utils.Crypto.base57FromBytes(
            AddressLength,
            &self.publicKey,
            &result,
        );
        return result;
    }

    pub fn encodedPrivateKey(self: Wallet) [EncodedPrivateKeyLength]u8 {
        var buf: [EncodedPrivateKeyLength]u8 = undefined;

        _ = utils.Crypto.base57FromBytes(
            EncodedPrivateKeyLength,
            &self.privateKey,
            &buf,
        );
        return buf;
    }
};

test "same wallet for same seed" {
    const seed: [utils.Crypto.SeedLength]u8 = "00000000000000000000000000000000".*;
    const expectedPublic = "N4vzuHP5tZAY6De3a6EuknX8HdZTWUosDeyrPvwtLMAzr";
    const expectedPrivate = "5PMLJPbWsYYu8g1QzUVvKv1gxyWBFD68hpkU3oSZBw6JCHhM9ayHAwzeWr1vbWD1jVMkXZeebjm4RiGbaUS2juP7";

    const wallet = try Wallet.initFromSeed(seed);

    try std.testing.expectEqualSlices(u8, expectedPublic, &wallet.encodedPublicKey());
    try std.testing.expectEqualSlices(u8, expectedPrivate, &wallet.encodedPrivateKey());
}

test "same wallet for same seed2" {
    const seed: [utils.Crypto.SeedLength]u8 = "10000000000000000000000000000000".*;
    const expectedPublic = "N78xsfyupaQq64TZLEtFHezmEUnqW5ZzJt5GYsgiirBET";
    const expectedPrivate = "5UYHigMVQWDsBpd9KehkGTfnh4qb1LRQ7yGUUUpppKUvpY6yoeYuPoaSAzhMyF4SfREva6cWtcMkkdSXb34URAmj";

    const wallet = try Wallet.initFromSeed(seed);

    try std.testing.expectEqualSlices(u8, expectedPublic, &wallet.encodedPublicKey());
    try std.testing.expectEqualSlices(u8, expectedPrivate, &wallet.encodedPrivateKey());
}

test "wallet from private should equal 10 times" {
    for (0..10) |_| {
        const wallet = try Wallet.init();
        var encodedPriv: [utils.Wallet.EncodedPrivateKeyLength]u8 = wallet.encodedPrivateKey();
        var backDecoded: [utils.Crypto.PrivateKeyLength]u8 = undefined;

        _ = try utils.Crypto.bytesFromBase57(utils.Crypto.PrivateKeyLength, &encodedPriv, &backDecoded);
        const wallet2 = try Wallet.initFromPrivateKey(backDecoded);

        try std.testing.expectEqualSlices(u8, &wallet.publicKey, &wallet2.publicKey);
        try std.testing.expectEqualSlices(u8, &wallet.privateKey, &wallet2.privateKey);
    }
}
