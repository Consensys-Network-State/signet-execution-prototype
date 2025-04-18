local secp256k1 = require("secp256k1")

-- Test signature verification success case
local result = secp256k1.verify_signature(
  'hello', -- message
  '3045022100a71d86190354d64e5b3eb2bd656313422cdf7def69bf3669cdbfd09a9162c96e0220713b81f3440bff0b639d2f29b2c48494b812fa89b754b7b6cdc9eaa8027cf369', -- signature
  '02477ce3b986ab14d123d6c4167b085f4d08c1569963a0201b2ffc7d9d6086d2f3') -- pub key
print("verify_signature valid case success: " .. tostring(result == true))

-- Test signature verification failure case
local int_result = secp256k1.verify_signature(
  'bai', -- message
  '3045022100a71d86190354d64e5b3eb2bd656313422cdf7def69bf3669cdbfd09a9162c96e0220713b81f3440bff0b639d2f29b2c48494b812fa89b754b7b6cdc9eaa8027cf369', -- signature
  '02477ce3b986ab14d123d6c4167b085f4d08c1569963a0201b2ffc7d9d6086d2f3') -- pub key
print("verify_signature invalid case success: " .. tostring(int_result == false))

-- Test signature verification success case
local result = secp256k1.recover_public_key(
  '7b2c6055e7ef2ff5251cf924920e6556c8a8f011711b39e61689f12e940158c933177f026e9509d49d3a1686c7ba763591e1ccb37f97ce9d535a54b6a9e623331c', -- signature
  'a136086b9f2049db56fd0cd937c6d496b5f732f20ec89599e48a6225362a225c') -- message hash
local matchingPubKey = result == '047249530c6a738ff8d59e4a948b10a91feb4209339f75f8132b09fa66eb08b82a420c722ebbc04758f2517a68fcd4f1a8c5873407de4fb03942f706d466e2797d'
print("recover_public_key success: " .. tostring(matchingPubKey))