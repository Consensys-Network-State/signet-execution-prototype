local json = require("json")
local base64 = require(".base64")
local crypto = require(".crypto.init")
local Array = require(".crypto.util.array")
local bignum = require(".bint")(1024) -- 4096 AO's own big int lib
local _0n, _1n, _2n, _3n, _4n, _5n, _6n, _7n = bignum(0), bignum(1), bignum(2), bignum(3), bignum(4), bignum(5), bignum(6), bignum(7)
local _11n, _22n, _23n, _27n, _44n, _88n = bignum(11), bignum(22), bignum(23), bignum(27), bignum(44), bignum(88)
local eip712 = require('.eip712')

local DEBUG = false

-- A library for working with JWTs secured with ES256K signatures
-- More or less a direct lua port of the 'did-jwt' npm package and its dependency on '@noble/curves/secp256k1'
-- The only external dependencies are AO's own json, bigint and crypto libraries.

-- TODO: clean up the mess in this file into a coherent set of submodules

local function hex_to_bignum(hex_string)
  if hex_string:sub(1, 2) == "0x" then
    return bignum(hex_string)
  else
    return bignum("0x"..hex_string)
  end
end

local function check_expected(value, value_label, expected, expect_bignum)
  local expected_value = expected
  if expect_bignum then
    expected_value = bignum(expected)
  end
  if not DEBUG then
    return
  end
  if value ~= expected_value then
    print(value_label .. " does not match: " .. tostring(value))
  else
    print(value_label.." MATCHES!")
  end
end

-- Define the secp256k1 curve parameters
local secp256k1 = {
  p = bignum("0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEFFFFFC2F"), -- Prime modulus
  a = bignum(0), -- Curve coefficient a
  b = bignum(7), -- Curve coefficient b
  Gx = bignum("0x79BE667EF9DCBBAC55A06295CE870B07029BFCDB2DCE28D959F2815B16F81798"), -- Base point x
  Gy = bignum("0x483ADA7726A3C4655DA4FBFC0E1108A8FD17B448A68554199C47D08FFB10D4B8"), -- Base point y
  n = bignum("0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141") -- Order of the group
}
local ORDER = secp256k1.p
local BYTES = 32 -- bytes per coordinate value
local COMPRESSED_POINT_BYTES = 1 + BYTES -- recovery byte, x-coord 
local UNCOMPRESSED_POINT_BYTES = 1 + BYTES * 2 -- recovery byte, x-coord , y-coord
local COMPRESSED_POINT_HEX_CHARS = 2 * COMPRESSED_POINT_BYTES
local UNCOMPRESSED_POINT_HEX_CHARS = 2 * UNCOMPRESSED_POINT_BYTES

local function mod(a, b)
  local result = a % b;
  if result >= _0n then
    return result
  else
    return b + result;
  end
end

-- Inverses number over modulo
local function modinv(number, modulo)
  if number == _0n or modulo <= _0n then
    error("invert: expected positive integers, got n="..tostring(number).." mod="..tostring(modulo))
  end
  -- Euclidean GCD https://brilliant.org/wiki/extended-euclidean-algorithm/
  -- Fermat's little theorem "CT-like" version inv(n) = n^(m-2) mod m is 30x slower.
  local a = mod(number, modulo);
  local b = modulo;
  local x, y, u, v = _0n, _1n, _1n, _0n;
  while a ~= _0n do
    local q = b // a;
    local r = b % a;
    local m = x - u * q;
    local n = y - v * q;
    b, a, x, y, u, v = a, r, u, v, m, n;
  end
  local gcd = b;
  if gcd ~= _1n then
    error("invert: does not exist")
  end
  return mod(x, modulo);
end

local function pow2(x, power, modulo)
  local res = x;
  while power > _0n do
    res = res * res;
    res = res % modulo;
    power = power - 1
  end
  return res;
end

local Fp = {}
function Fp.sqrt(y)
  local P = secp256k1.p
  local b2 = (y * y * y) % P; -- x^3, 11
  local b3 = (b2 * b2 * y) % P; -- x^7
  local b6 = (pow2(b3, _3n, P) * b3) % P;
  local b9 = (pow2(b6, _3n, P) * b3) % P;
  local b11 = (pow2(b9, _2n, P) * b2) % P;
  local b22 = (pow2(b11, _11n, P) * b11) % P;
  local b44 = (pow2(b22, _22n, P) * b22) % P;
  local b88 = (pow2(b44, _44n, P) * b44) % P;
  local b176 = (pow2(b88, _88n, P) * b88) % P;
  local b220 = (pow2(b176, _44n, P) * b44) % P;
  local b223 = (pow2(b220, _3n, P) * b3) % P;
  local t1 = (pow2(b223, _23n, P) * b22) % P;
  local t2 = (pow2(t1, _6n, P) * b2) % P;
  local root = pow2(t2, _2n, P);
  if (not Fp.eql(Fp.sqr(root), y)) then
    error('Cannot find square root')
  end
  return root;
end
function Fp.sqr(num)
  return mod(num * num, ORDER)
end
function Fp.neg(num)
  return mod(-num, ORDER)
end
function Fp.mod(a, b)
  return mod(a, b)
end
function Fp.add(lhs, rhs)
  return Fp.mod(lhs + rhs, ORDER)
end
function Fp.sub(lhs, rhs) 
  return Fp.mod(lhs - rhs, ORDER)
end
function Fp.mul(lhs, rhs)
  return Fp.mod(lhs * rhs, ORDER)
end
function Fp.eql(lhs, rhs)
  return lhs == rhs
end
function Fp.is0(num)
  return num == _0n
end
function Fp.inv(num)
  return modinv(num, ORDER)
end

-- Converts Projective point to affine (x, y) coordinates.
-- (x, y, z) ∋ (x=x/z, y=y/z)
local function toAffine(p)
  local ZERO = { x = _0n, y = _1n, z = _0n }; -- this is intentionally (0, 1, 0)
  local function point_equals(this, other)
    local X1, Y1, Z1 = this.x, this.y, this.z;
    local X2, Y2, Z2 = other.x, other.y, other.z;
    local U1 = Fp.eql(Fp.mul(X1, Z2), Fp.mul(X2, Z1));
    local U2 = Fp.eql(Fp.mul(Y1, Z2), Fp.mul(Y2, Z1));
    return U1 and U2;
  end
  local x, y, z = p.x, p.y, p.z
  -- Fast-path for normalized points
  if Fp.eql(z, _0n) then
    return { x = x, y = y }
  end
  local is0 = point_equals(p, ZERO)
  -- If invZ was 0, we return zero point. However we still want to execute
  -- all operations, so we replace invZ with a random number, 1.
  local iz;
  if is0 then
    iz = _1n
  else
    iz = Fp.inv(z)
  end
  local ax = Fp.mul(x, iz);
  local ay = Fp.mul(y, iz);
  local zz = Fp.mul(z, iz);
  if is0 then
    return { x = _0n, y = _0n, z = _1n }
  end
  if not Fp.eql(zz, _1n) then
    error('invZ was invalid');
  end

  return { x = ax, y = ay, z = _1n };
end

-- Renes-Costello-Batina exception-free doubling formula.
-- There is 30% faster Jacobian formula, but it is not complete.
-- https://eprint.iacr.org/2015/1060, algorithm 3
-- Cost: 8M + 3S + 3*a + 2*b3 + 15add.
local function point_double(point)
  local a, b = secp256k1.a, secp256k1.b;
  local b3 = Fp.mul(b, _3n);
  local X1, Y1, Z1 = point.x, point.y, point.z;
  local X3, Y3, Z3 = _0n, _0n, _0n;
  local t0 = Fp.mul(X1, X1); -- step 1
  local t1 = Fp.mul(Y1, Y1);
  local t2 = Fp.mul(Z1, Z1);
  local t3 = Fp.mul(X1, Y1);
  t3 = Fp.add(t3, t3); -- step 5
  Z3 = Fp.mul(X1, Z1);
  Z3 = Fp.add(Z3, Z3);
  X3 = Fp.mul(a, Z3);
  Y3 = Fp.mul(b3, t2);
  Y3 = Fp.add(X3, Y3); -- step 10
  X3 = Fp.sub(t1, Y3);
  Y3 = Fp.add(t1, Y3);
  Y3 = Fp.mul(X3, Y3);
  X3 = Fp.mul(t3, X3);
  Z3 = Fp.mul(b3, Z3); -- step 15
  t2 = Fp.mul(a, t2);
  t3 = Fp.sub(t0, t2);
  t3 = Fp.mul(a, t3);
  t3 = Fp.add(t3, Z3);
  Z3 = Fp.add(t0, t0); -- step 20
  t0 = Fp.add(Z3, t0);
  t0 = Fp.add(t0, t2);
  t0 = Fp.mul(t0, t3);
  Y3 = Fp.add(Y3, t0);
  t2 = Fp.mul(Y1, Z1); -- step 25
  t2 = Fp.add(t2, t2);
  t0 = Fp.mul(t2, t3);
  X3 = Fp.sub(X3, t0);
  Z3 = Fp.mul(t2, t1);
  Z3 = Fp.add(Z3, Z3); -- step 30
  Z3 = Fp.add(Z3, Z3);
  return { x = X3, y = Y3, z = Z3 };
end

-- Renes-Costello-Batina exception-free addition formula.
-- There is 30% faster Jacobian formula, but it is not complete.
--  https://eprint.iacr.org/2015/1060, algorithm 1
-- Cost: 12M + 0S + 3*a + 3*b3 + 23add.
local function point_add(one, other)
  local X1, Y1, Z1 = one.x, one.y, one.z;
  local X2, Y2, Z2 = other.x, other.y, other.z;
  local X3, Y3, Z3 = _0n, _0n, _0n;
  local a = secp256k1.a;
  local b3 = Fp.mul(secp256k1.b, _3n);
  local t0 = Fp.mul(X1, X2); -- step 1
  local t1 = Fp.mul(Y1, Y2);
  local t2 = Fp.mul(Z1, Z2);
  local t3 = Fp.add(X1, Y1);
  local t4 = Fp.add(X2, Y2); -- step 5
  t3 = Fp.mul(t3, t4);
  t4 = Fp.add(t0, t1);
  t3 = Fp.sub(t3, t4);
  t4 = Fp.add(X1, Z1);
  local t5 = Fp.add(X2, Z2); -- step 10
  t4 = Fp.mul(t4, t5);
  t5 = Fp.add(t0, t2);
  t4 = Fp.sub(t4, t5);
  t5 = Fp.add(Y1, Z1);
  X3 = Fp.add(Y2, Z2); -- step 15
  t5 = Fp.mul(t5, X3);
  X3 = Fp.add(t1, t2);
  t5 = Fp.sub(t5, X3);
  Z3 = Fp.mul(a, t4);
  X3 = Fp.mul(b3, t2); -- step 20
  Z3 = Fp.add(X3, Z3);
  X3 = Fp.sub(t1, Z3);
  Z3 = Fp.add(t1, Z3);
  Y3 = Fp.mul(X3, Z3);
  t1 = Fp.add(t0, t0); -- step 25
  t1 = Fp.add(t1, t0);
  t2 = Fp.mul(a, t2);
  t4 = Fp.mul(b3, t4);
  t1 = Fp.add(t1, t2);
  t2 = Fp.sub(t0, t2); -- step 30
  t2 = Fp.mul(a, t2);
  t4 = Fp.add(t4, t2);
  t0 = Fp.mul(t1, t4);
  Y3 = Fp.add(Y3, t0);
  t0 = Fp.mul(t5, t4); -- step 35
  X3 = Fp.mul(t3, X3);
  X3 = Fp.sub(X3, t0);
  t0 = Fp.mul(t3, t1);
  Z3 = Fp.mul(t5, Z3);
  Z3 = Fp.add(Z3, t0); -- step 40
  return { x = X3, y = Y3, z = Z3 };
end

local function is_point_on_curve(point, curve)
  if point.infinity then return true end
  local x, y = point.x, point.y
  return mod(y^2, curve.p) == mod(x^3 + curve.a * x + curve.b, curve.p)
end

local function scalar_mult(k, P, curve)
  local R = { x = _0n, y = _1n, z = _0n, infinity = true }
  local Q = P

  local iterations = 0;
  while k > _0n do
      if k % _2n == _1n then
          R = point_add(R, Q, curve)
      end
      Q = point_double(Q, curve)
      
      k = k // _2n

      iterations = iterations + 1
      -- check if the intermediate point is still on the curve 
      -- assert(is_point_on_curve(R, curve), 'Intermediate point R not on curve')
  end

  return R
end

local function mult(k, P)
  return scalar_mult(k, P, secp256k1)
end

local function isBiggerThanHalfOrder(number)
  local HALF = ORDER >> _1n;
  return number > HALF;
end

local function normalizeS(s)
  local normS = mod(-s, ORDER); -- if lowS was passed, ensure s is always in the bottom half of N
  return normS
end

-- ECDSA signature generation
local function ecdsa_sign(msg_hash, private_key, curve)
  if not curve then 
    curve = secp256k1
  end
  -- TODO: in production, there must be a very specific way to derrive this 'randomness' seed param by combining
  --  the private key with the msg hash. Otherwise there's a huge RISK of having the private key being recovered
  --  from multiple signatures.
  local k = hex_to_bignum('8ac5f958ad2b9d30a7383849bc5524de170182ecbee58775db96a4fcf1faff00')

  check_expected(k, 'k', '62768962901804729095411658001965103353380613121348715616389293158909559373568')
  local ik = modinv(k, curve.n)
  check_expected(ik, 'ik', '1042947050345953731404813983511559908450000309234119092993542873992981932465')

  local q = scalar_mult(k, { x = curve.Gx, y = curve.Gy, z = _1n }, curve)
  local Q = toAffine(q)

  check_expected(Q.x, 'Q.x', '38110709613600030109776518978402043000890462180768063594596204542854315599514')
  check_expected(Q.y, 'Q.y', '39006713418887119964232258219336355675678076967459032963275003768461563482156')

  local r = mod(Q.x, curve.n)
  check_expected(r, 'r', '38110709613600030109776518978402043000890462180768063594596204542854315599514')
  if r == 0 then return nil end

  -- seems to be this in veramo libs:
  local d = private_key
  check_expected(d, "d", "40839181649111427193280201715559328232867928666774427659280915319722298741517")
  local m = mod(msg_hash, curve.n)
  check_expected(m, 'm', '31231729721240794170262228186871591290810344234421880292925025428487592902353')

  local s = mod(ik * mod(m + r * d, curve.n), curve.n)
  check_expected(s, 's', '4416970586591183196279786900594171332381664988321120228710568292826003118988')
  if s == 0 then return nil end

  local recovery = nil
  if q.x == r then
    recovery = _0n
  else
    recovery = _2n
  end
  recovery = recovery | (q.y & _1n) -- recovery bit (2 or 3, when q.x > n)

  local normS = s;
  if isBiggerThanHalfOrder(s) then -- ensure s is always in the bottom half of N
      normS = normalizeS(s);
      recovery = recovery ~ _1n; -- binary XOR
  end

  -- This run did not result in the need to normalize (recovery = 0)
  -- check_expected(s, 's_normalized', '47848231997904621696665724211347736151540736418345389854007245076377743760662')
  return { r = r, s = normS, recovery = recovery }
end

local function weierstrassEquation(x)
  local a, b = secp256k1.a, secp256k1.b
  local x2 = Fp.sqr(x)
  local x3 = Fp.mul(x2, x)
  local result = Fp.add(Fp.add(x3, Fp.mul(x, a)), b) -- x3 + a * x + b
  return result
end

-- TODO: actually expects a hex string for input, so the function name's a bit of a misnomer
local function point_from_bytes(point_hex)
  local head = point_hex:sub(1, 2)
  local tail = point_hex:sub(3)

  if #point_hex == COMPRESSED_POINT_HEX_CHARS and (head == '02' or head == '03') then
    local x = hex_to_bignum(tail)
    local y2 = weierstrassEquation(x)
    local y = Fp.sqrt(y2)
  
    if hex_to_bignum(head):isodd() ~= y:isodd() then
        y = Fp.neg(y);
    end
    return { x = x, y = y, z = _1n }
  elseif #point_hex == UNCOMPRESSED_POINT_HEX_CHARS and head == '04' then
    -- Split the binary string into r and s
    local xhex = tail:sub(1, UNCOMPRESSED_POINT_HEX_CHARS)
    local yhex = tail:sub(UNCOMPRESSED_POINT_HEX_CHARS + 1, -1)
    local x = hex_to_bignum(xhex)
    local y = hex_to_bignum(yhex)
    return { x = x, y = y, z = _1n }
  else
    error('Point of length '..#tail..' was invalid. Expected '..COMPRESSED_POINT_HEX_CHARS..' compressed hex chars or '..UNCOMPRESSED_POINT_HEX_CHARS..' uncompressed hex chars')
  end
end

local function point_to_bytes(point, isCompressed)
  local point_aff = toAffine(point)
  local x = point_aff.x:tobase(16)
  local y = point_aff.y:tobase(16)
  if isCompressed then
    local prefix = '03'
    if bignum.iseven(point_aff.y) then
      prefix = '02'
    end
    return Array.concat(
      Array.fromHex(prefix),
      Array.fromHex(x)
    )
  else
    return Array.concat(
      Array.concat(
        Array.fromHex('04'),
        Array.fromHex(x)
      ),
      Array.fromHex(y)
    )
  end
end

local function toEthereumAddress(pubkey)
  -- assumes pubkey is a binary string (not hex)
  local keccak_hash = crypto.digest.keccak256(pubkey).asHex()
  -- expect a5e5e23e454ccb57f2f43bcc2a6ffb5341f8c1ce123343162e3351f1b6286c43
  return '0x'..string.sub(keccak_hash, -40, -1); -- last 40 hex chars, aka 20 bytes
end

local function pubkey_point_to_eth_address(point)
  -- local pubkey_bytes = Array.concat(
  --   Array.fromString(bignum.tobe(point.x, true)),
  --   Array.fromString(bignum.tobe(point.y, true))
  -- )
  -- local pubkey_hex = string.lower(Array.toHex(pubkey_bytes))
    local pubkey_bytes = point_to_bytes(point)

  -- drop the leading prefix byte
  local bytes = Array.slice(pubkey_bytes, 2, -1)
  local eth_address = toEthereumAddress(Array.toString(bytes))
  return eth_address
end

-- ECDSA signature verification
local function ecdsa_verify(msg_hash, sig_point, expected_eth_address, curve)
  if not curve then 
    curve = secp256k1
  end

  local h = msg_hash
  check_expected(h, 'h', '67277960046661651858058833595783189530640197073074635471512071083734624216902')

  local r, s, recovery = sig_point.r, sig_point.s, sig_point.recovery
  check_expected(r, 'r', '38110709613600030109776518978402043000890462180768063594596204542854315599514')
  check_expected(s, 's', '43656985260422404571642319563636039110961248401828454594307383185354388597699')

  if r <= _0n or r >= curve.n or s <= _0n or s >= curve.n then
      return false
  end

  -- picking radj depends on the value of the recovery bit:
  -- const radj = rec === 2 || rec === 3 ? r + CURVE.n : r;
  local radj = r
  local prefix = '02'
  if recovery:isodd() then
    prefix = '03'
  end
  local compressed_point_hex = prefix .. radj:tobase(16)
  local recovered_point = point_from_bytes(compressed_point_hex)
  local y = recovered_point.y
  check_expected(y, 'y', '39006713418887119964232258219336355675678076967459032963275003768461563482156')

  local R = { x = radj, y = y, z = _1n }
  local ir = modinv(r, curve.n)
  check_expected(ir, 'ir', '92426821849398360072923626197728714965359031120538554784285269019594905870959')

  local u1 = mod(-h * ir, curve.n)
  check_expected(u1, 'u1', '52226219540562561224044854770834381067920804938578653902475353796949342563447')

  local u2 = mod(s * ir, curve.n)
  check_expected(u2, 'u2', '75799482499018543187976782755596787367828847218668085791439691350112698687473')

  local P1 = scalar_mult(u1, { x = curve.Gx, y = curve.Gy, z = _1n }, curve)
  P1 = toAffine(P1)
  check_expected(P1.x, 'P1.px', '18224593219427761846553776154322379274403491856283448395509886155933072898592')
  check_expected(P1.y, 'P1.py', '32758412604047267622792497902920496039143902939178264560283433285705399233802')
  check_expected(P1.z, 'P1.pz', '1')
  local P2 = scalar_mult(u2, R, curve)
  check_expected(P2.x, 'P2.px', '107434607317460829055117946277539365217257579366909853549751352711197197887495')
  check_expected(P2.y, 'P2.py', '115502456242595185753301092759155036583300811896008541460122096119304308542221')
  check_expected(P2.z, 'P2.pz', '68737293029069406741060789893283208570149301135127655889163710772471128575473')
  local Q = point_add(P1, P2, curve)
  check_expected(Q.x, 'Q.px', '103285944287998521933359616885035093317252272214179748358027751419711509814244')
  check_expected(Q.y, 'Q.py', '40517521241163205383828502365630888111254666846077829043939151866497239943622')
  check_expected(Q.z, 'Q.pz', '97449908929088944393563663315963736434258659649499845625191512109662501502398')

  local pubKeyAff = toAffine(Q)
  check_expected(pubKeyAff.x, 'pubKeyAff.px', '44945664365711695867597170205247250063533527663516513464614790907145334592491')
  check_expected(pubKeyAff.y, 'pubKeyAff.py', '51620294598338175616925375290099158439564501137858167897238406002843643051656')

  local eth_address = pubkey_point_to_eth_address(pubKeyAff)

  -- check_expected(eth_address, 'eth_address', '0x2a6ffb5341f8c1ce123343162e3351f1b6286c43')
  -- TODO: handle other forms of authority being passed in. Eg. a compressed/uncompressed public key.
  return eth_address == expected_eth_address
end

-- Helper functions for base64url decoding
local function base64_url_encode(data)
  local encoded = base64.encode(data)
  -- subbing out these chars with URL-safe ones
  encoded = encoded:gsub("+", "-")
  encoded = encoded:gsub("/", "_")
  return encoded
end

local function base64_url_decode(data)
  -- the contents in JWTs are base64 encoded, but also makde URL safe. This means substituting
  -- chars like + and / with - and _ respectively. We need to undo this before decoding the data.
  data = data:gsub("-", "+")
  data = data:gsub("_", "/")
  -- TODO: for some reason, there's an issue with using AO's base64 lib at runtime... opting to use a simpler implementation instead
  local res = base64.decode(data)
  return res
end

-- Parse JWT into header, payload, and signature
local function parse_jwt(jwt)
  local header_b64, payload_b64, signature_b64 = jwt:match("([^%.]+)%.([^%.]+)%.([^%.]+)")
  if not header_b64 or not payload_b64 or not signature_b64 then
      return nil, "Invalid JWT format"
  end
  local header = base64_url_decode(header_b64)
  local payload = base64_url_decode(payload_b64)
  local signature = base64_url_decode(signature_b64)
  return header, payload, signature, header_b64 .. "." .. payload_b64
end

local function decode_signature(signature)
  -- assumes we're getting a base64-decoded string as input

  -- TODO: this method is pretty much a specialized version of point_from_bytes(),
  --   assuming that the input is a 64 byte signature with no recovery bit.
  --   Should be able to utilize point_from_bytes() and not duplicate the logic.
  local bytes = {}
  if signature:sub(1, 2) == "0x" then
    bytes = Array.fromHex(signature:sub(3))
  else
    bytes = Array.fromString(signature)
  end

-- Ensure the signature is 64 bytes long (32 bytes for r, 32 bytes for s)
  if #bytes ~= 64 and #bytes ~= 65 then
      error("Invalid signature length: expected 64-65 bytes")
  end

  -- Split the binary string into r and s
  local rbytes = Array.slice(bytes, 1, 32)
  local sbytes = Array.slice(bytes, 33, 64)
  local v = nil
  -- if sig is 65 bytes, assuming that the last byte is the recovery param (EIP-712)
  if #bytes == 65 then
    local vbytes = Array.slice(bytes, 65)
    local vhex = Array.toHex(vbytes)
    v = hex_to_bignum(vhex)
    if v >= _27n then
      v = v - _27n
    end
  end
  local rhex = Array.toHex(rbytes)
  local shex = Array.toHex(sbytes)
  local r = hex_to_bignum(rhex)
  local s = hex_to_bignum(shex)
  return r, s, v
end

local function create_sig(msg_hex, priv_key_hex, curve)
  -- expecting input to be a hex string
  local hash = hex_to_bignum(msg_hex);
  local priv_key = hex_to_bignum(priv_key_hex)

  local sig = ecdsa_sign(hash, priv_key, curve)
  return sig
end

local function verify_sig(msg_hex, signature, expected_eth_address, curve)
  -- expecting input to be a hex string
  local msg_hash = hex_to_bignum(msg_hex);

  local r, s, recovery
  -- as a bit of a hack to support multiple test cases, supporing passing the signature 
  -- as both a hex string, and a r,s point. This makes it possible to use this function to
  -- directly verify the result of create_sig function.
  if signature.r and signature.s and signature.recovery then
      r, s, recovery = signature.r, signature.s, signature.recovery
  else
    r, s, recovery = decode_signature(signature);
  end
  local success = false
  local recovery_modes_to_try = {}
  if recovery then
    recovery_modes_to_try = { recovery }
  else
    recovery_modes_to_try = { _0n, _1n }
  end
  for rnum = 1, #recovery_modes_to_try do
    local recovery = recovery_modes_to_try[rnum]

    local normS = s;
    if isBiggerThanHalfOrder(s) then -- ensure s is always in the bottom half of N
        normS = normalizeS(s);
        recovery = recovery ~ _1n; -- binary XOR
    end
  
    success = ecdsa_verify(msg_hash, { r = r, s = normS, z = _1n, recovery = recovery }, expected_eth_address, curve)
    if success then
      break -- as soon as we have one successful verification, we're good
    end
  end

  return success
end

local function string_split(inputstr, sep)
  if sep == nil then
    sep = "%s"
  end
  local t = {}
  for str in string.gmatch(inputstr, "([^"..sep.."]+)") do
    table.insert(t, str)
  end
  return t
end

local function get_authority(issuer)
  -- TODO: handle other authority formats? Eg. public keys
  local pub_key_hex = nil
  local eth_address = nil
  if (issuer) then
    -- TODO: parse out the pub key
    local parts = string_split(issuer, ':')
    if (parts[1] == 'did') then
      if (parts[2] == 'ethr') then
        if #parts == 3 then
          -- mainnet ethr did
          pub_key_hex = parts[3]
        elseif #parts == 4 then
          -- a non-mainnet chain is specified
          pub_key_hex = parts[4]
        end
      -- did:pkh:eip155:1:0x1e8564A52fc67A68fEe78Fc6422F19c07cFae198
      elseif parts[2] == 'pkh' and parts[3] == 'eip155' and parts[4] == '1' then
        eth_address = parts[5]
      end
    end
    if pub_key_hex and string.sub(pub_key_hex, 1, 2) == '0x'  then
      pub_key_hex = string.sub(pub_key_hex, 3, -1)
    end

    if not eth_address and pub_key_hex then
      local pubkey_point = point_from_bytes(pub_key_hex)
      eth_address = pubkey_point_to_eth_address(pubkey_point)
    end
    return string.lower(eth_address or '')
  end
end

-- ECDSA signature verification for JWT
local function jwt_validate(jwt, curve)
  local header, payload, signature, signing_input = parse_jwt(jwt)

  if not header or not payload or not signature then
      return false, "Failed to parse JWT"
  end

  local json_header = json.decode(header)
  if (json_header.alg ~= "ES256K") then
    error('Only supporting ES256K signatures')
  end
  local json_payload = json.decode(payload)
  local owner_eth_address = get_authority(json_payload.iss)
  -- JWT convention is to sha256 encode the input before signing
  local msg_stream = crypto.utils.stream.fromString(signing_input);
  local msg_hash_hex = crypto.digest.sha2_256(msg_stream).asHex();

  local success = verify_sig(msg_hash_hex, signature, owner_eth_address, curve)
  return success, payload
end

local function vc_validate(vc)
  local vc_json = json.decode(vc)
  local owner_eth_address = get_authority(vc_json.issuer.id)
  local proof = vc_json.proof
  local proofValue = nil
  if proof.type == 'EthereumEip712Signature2021' then
    proofValue = proof.proofValue
  else
    error('Only supporting EthereumEip712Signature2021 proof type')
  end

  local eip712data = vc_json.proof.eip712
  local domain = eip712data.domain
  local types = eip712data.types
  local primaryType = eip712data.primaryType
  local domainSeparator = eip712.createDomainSeparator(domain)
  check_expected(domainSeparator, 'domainSeparator', 'aa4dcb7d1c0b8808696b50a6713af9ce211fd50be889233bc44ef8c2cb43fb8f')

  local message = Array.copy(vc_json)
  local proof_copy = Array.copy(vc_json.proof)
  proof_copy.proofValue = nil
  proof_copy.eip712 = nil
  proof_copy.eip712Domain = nil
  message.proof = proof_copy

  local structHash = eip712.hashStruct(primaryType, message, types)
  check_expected(structHash, 'structHash', '8546337130a3e9a6f11188353fc9dbde5cac02c39250e7263e9c4b858c116d71')

  local signingInput = eip712.getSigningInput(domainSeparator, structHash)
  check_expected(signingInput, 'signingInput', 'e8b95caf587909001e49eabda523a448693e02debd3776fc28272b3ffb7768b7')

  local success = verify_sig(signingInput, proofValue, owner_eth_address)

  return success
end

local es256k = {
  jwt_validate = jwt_validate,
  create_sig = create_sig,
  verify_sig = verify_sig,
  vc_validate = vc_validate,
  base64_url_decode = base64_url_decode,
  secp256k1 = secp256k1,
  Fp = Fp,
};

return es256k