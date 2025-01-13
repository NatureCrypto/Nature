const std = @import("std");
const utils = @import("utils.zig");

pub const Wallet = struct {
    seed: ?[utils.Crypto.SeedLength]u8,
    publicKey: [utils.Crypto.PublicKeyLength]u8,
    privateKey: [utils.Crypto.PrivateKeyLength]u8,

    pub const AddressPrefix = "N";
    /// "N" + base58 encoded PublicKeyBytes (44) == 45
    pub const AddressLength = AddressPrefix.len + utils.Base58.base58Length(utils.Crypto.PublicKeyLength);
    /// base 58 encoded PrivateKeyBytes (88)
    pub const EncodedPrivateKeyLength = utils.Base58.base58Length(utils.Crypto.PrivateKeyLength);

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

        _ = utils.Crypto.base58FromBytes(
            AddressLength,
            &self.publicKey,
            &result,
        );
        return result;
    }

    pub fn encodedPrivateKey(self: Wallet) [EncodedPrivateKeyLength]u8 {
        var buf: [EncodedPrivateKeyLength]u8 = undefined;

        _ = utils.Crypto.base58FromBytes(
            EncodedPrivateKeyLength,
            &self.privateKey,
            &buf,
        );
        return buf;
    }
};

test "same wallet for same seed" {
    const seed: [utils.Crypto.SeedLength]u8 = "00000000000000000000000000000000".*;
    const expectedPublic = "N2ru5PcgeQzxF7QZYwQgDkG2K13PRqyigVw99zMYg8eML";
    const expectedPrivate = "Nxt19s1sp2UZCGhy9rNyb1FtxdKiDGZZPNFnc1KiM9jYWrhBV5GXfwMPDTt4nD22tDuETgzJ63oLoUnuFUEHHT6E";

    const wallet = try Wallet.initFromSeed(seed);
    try std.testing.expectEqualSlices(u8, expectedPublic, &wallet.encodedPublicKey());
    try std.testing.expectEqualSlices(u8, expectedPrivate, &wallet.encodedPrivateKey());
}

test "same wallet for same seed2" {
    const seed: [utils.Crypto.SeedLength]u8 = "10000000000000000000000000000000".*;
    const expectedPublic = "N3uaH3jadsesYW94PVXWx6yYkb7jbeymVmspZj9vBwfeY";
    const expectedPrivate = "Nz3G4s6EBRNiKL8jcwUwX3AFwu3XpmWwDMRTGouKcefGnp1RLNwBDdKLmiHciUUha5cj2oXmcKXaWgCceuqQFZnx";

    const wallet = try Wallet.initFromSeed(seed);
    try std.testing.expectEqualSlices(u8, expectedPublic, &wallet.encodedPublicKey());
    try std.testing.expectEqualSlices(u8, expectedPrivate, &wallet.encodedPrivateKey());
}

test "wallet from private should equal 10 times" {
    for (0..10) |_| {
        const wallet = try Wallet.init();
        var encodedPriv: [utils.Wallet.EncodedPrivateKeyLength]u8 = wallet.encodedPrivateKey();
        var backDecoded: [utils.Crypto.PrivateKeyLength]u8 = undefined;

        _ = try utils.Crypto.bytesFromBase58(utils.Crypto.PrivateKeyLength, &encodedPriv, &backDecoded);
        const wallet2 = try Wallet.initFromPrivateKey(backDecoded);

        try std.testing.expectEqualSlices(u8, &wallet.publicKey, &wallet2.publicKey);
        try std.testing.expectEqualSlices(u8, &wallet.privateKey, &wallet2.privateKey);
    }
}
