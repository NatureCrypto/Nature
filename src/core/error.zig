pub const NatureError = error{
    BadDecimal,
    TooLongSymbolName,
    TooLongMemo,
    InsufficientBalance,
    InsufficientNatureBalance, // Used for fee
    LedgerTransactionIndexOutOfBounds,
};
