import 'dart:convert';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/foundation.dart';

class EncryptionService {
  static final EncryptionService _instance = EncryptionService._internal();
  factory EncryptionService() => _instance;
  EncryptionService._internal();

  final _storage = const FlutterSecureStorage();
  final _keyExchangeAlgorithm = X25519();
  final _cipher = Chacha20.poly1305Aead();
  
  SimpleKeyPair? _myKeyPair;
  String? _myPublicKeyBase64;

  // Initialize keys: load from storage or generate new ones
  Future<void> init() async {
    // Try to read private key from secure storage
    String? privateKeyBase64 = await _storage.read(key: 'private_key');
    String? publicKeyBase64 = await _storage.read(key: 'public_key');

    if (privateKeyBase64 != null && publicKeyBase64 != null) {
      // Reconstruct key pair
      final privateKeyBytes = base64Decode(privateKeyBase64);
      final publicKeyBytes = base64Decode(publicKeyBase64);
      
      _myKeyPair = SimpleKeyPairData(
        privateKeyBytes,
        publicKey: SimplePublicKey(publicKeyBytes, type: KeyPairType.x25519),
        type: KeyPairType.x25519,
      );
      _myPublicKeyBase64 = publicKeyBase64;
      debugPrint("🔐 EncryptionService: Keys Loaded (Valid)");
    } else {
      // Generate new key pair
      final keyPair = await _keyExchangeAlgorithm.newKeyPair();
      final privateKeyBytes = await keyPair.extractPrivateKeyBytes();
      final publicKey = await keyPair.extractPublicKey();
      final publicKeyBytes = publicKey.bytes;

      // Save to storage
      await _storage.write(key: 'private_key', value: base64Encode(privateKeyBytes));
      await _storage.write(key: 'public_key', value: base64Encode(publicKeyBytes));

      _myKeyPair = keyPair;
      _myPublicKeyBase64 = base64Encode(publicKeyBytes);
      debugPrint("🔐 EncryptionService: New Keys Generated");
    }
  }

  String? get myPublicKey => _myPublicKeyBase64;

  // Encrypt message for a receiver
  Future<String> encryptMessage(String plaintext, String receiverPublicKeyBase64) async {
    if (_myKeyPair == null) await init();

    debugPrint("🔒 Encrypting message: '$plaintext'");

    // 1. Parse receiver public key
    final receiverPublicKeyBytes = base64Decode(receiverPublicKeyBase64);
    final receiverPublicKey = SimplePublicKey(receiverPublicKeyBytes, type: KeyPairType.x25519);

    // 2. Derive shared secret
    final sharedSecretKey = await _keyExchangeAlgorithm.sharedSecretKey(
      keyPair: _myKeyPair!,
      remotePublicKey: receiverPublicKey,
    );

    // 3. Encrypt
    final secretKey = await sharedSecretKey.extractBytes();
    
    final algorithm = Chacha20.poly1305Aead();
    final secretBox = await algorithm.encrypt(
      utf8.encode(plaintext),
      secretKey: SecretKey(secretKey),
    );

    // 4. Return as single string
    final combined = secretBox.concatenation(); 
    final cipherText = base64Encode(combined);
    debugPrint("   -> CipherText: ${cipherText.substring(0, 10)}...");
    return cipherText;
  }

  // Decrypt message from a sender
  Future<String> decryptMessage(String encryptedContent, String senderPublicKeyBase64) async {
    if (_myKeyPair == null) await init();

    try {
      // 1. Parse sender public key (or receiver public key if I am the sender, logic is symmetric)
      final senderPublicKeyBytes = base64Decode(senderPublicKeyBase64);
      final senderPublicKey = SimplePublicKey(senderPublicKeyBytes, type: KeyPairType.x25519);

      // 2. Derive shared secret (same as encryption side)
      final sharedSecretKey = await _keyExchangeAlgorithm.sharedSecretKey(
        keyPair: _myKeyPair!,
        remotePublicKey: senderPublicKey,
      );
      final secretKeyBytes = await sharedSecretKey.extractBytes();

      // 3. Parse encrypted content
      final combined = base64Decode(encryptedContent);
      final secretBox = SecretBox.fromConcatenation(
        combined,
        nonceLength: 12,
        macLength: 16,
      );

      // 4. Decrypt
      final algorithm = Chacha20.poly1305Aead();
      final clearTextBytes = await algorithm.decrypt(
        secretBox,
        secretKey: SecretKey(secretKeyBytes),
      );
      
      final clearText = utf8.decode(clearTextBytes);
      return clearText;

    } catch (e) {
      if (e.toString().contains("SecretBoxAuthenticationError") || e.toString().contains("MAC")) {
         // This typically happens when keys are rotated but old messages remain.
         // checking for 'plaintext' fallback first:
         // If it's just a plain string (not base64), it might be legacy or system message.
         // But for now, returning a safe placeholder is better than crashing or spamming logs.
         // debugPrint("⚠️ Decryption Warning: Old key interaction.");
         return "🔒 Encrypted Message (Keys Rotated)";
      }
      
      // Graceful Fallback: If decryption fails (e.g. it's plaintext), return original
      return encryptedContent;
    }
  }

  // --- SYMMETRIC ENCRYPTION (FOR GROUPS) ---

  // Generate a random 256-bit (32-byte) key for a new group
  Future<String> generateSymmetricKey() async {
    final key = await _cipher.newSecretKey(); // Generate random key async
    return base64Encode(await key.extractBytes());
  }
  
  // Encrypt with a specific Symmetric Key (Group Key)
  Future<String> encryptSymmetric(String plaintext, String keyBase64) async {
    final keyBytes = base64Decode(keyBase64);
    final secretKey = SecretKey(keyBytes);
    
    final secretBox = await _cipher.encrypt(
      utf8.encode(plaintext),
      secretKey: secretKey,
    );
    
    final combined = secretBox.concatenation();
    return base64Encode(combined);
  }

  // Decrypt with a specific Symmetric Key (Group Key)
  Future<String> decryptSymmetric(String encryptedContent, String keyBase64) async {
    try {
      final keyBytes = base64Decode(keyBase64);
      final secretKey = SecretKey(keyBytes);
      
      final combined = base64Decode(encryptedContent);
      final secretBox = SecretBox.fromConcatenation(
        combined,
        nonceLength: 12,
        macLength: 16,
      );

      final clearTextBytes = await _cipher.decrypt(
        secretBox,
        secretKey: secretKey,
      );
      
      return utf8.decode(clearTextBytes);
    } catch (e) {
      if (e.toString().contains("SecretBoxAuthenticationError")) {
          return "🔒 Encrypted Group Message (Key Rotated)";
      }
      // Graceful Fallback for Groups too
      return encryptedContent;
    }
  }

  // --- KEY DISTRIBUTION (EPHEMERAL) ---
  
  // Encrypt the Group Key for a specific user using an Ephemeral Key Pair
  // This allows the receiver to decrypt it without knowing who sent it (Admin).
  // Format: [EphemeralPublicKey (32)] + [Nonce (12)] + [MAC (16)] + [Ciphertext]
  Future<String> encryptKeyForMember(String keyPayload, String memberPublicKeyBase64) async {
    // 1. Generate Ephemeral Key Pair
    final ephemeralKeyPair = await _keyExchangeAlgorithm.newKeyPair();
    final ephemeralPublicKey = await ephemeralKeyPair.extractPublicKey();
    
    // 2. Parse Member Public Key
    final memberKeyBytes = base64Decode(memberPublicKeyBase64);
    final memberPublicKey = SimplePublicKey(memberKeyBytes, type: KeyPairType.x25519);
    
    // 3. Derive Secret
    final sharedSecret = await _keyExchangeAlgorithm.sharedSecretKey(
      keyPair: ephemeralKeyPair,
      remotePublicKey: memberPublicKey,
    );
    final secretKeyBytes = await sharedSecret.extractBytes();
    
    // 4. Encrypt
    final algorithm = Chacha20.poly1305Aead();
    final secretBox = await algorithm.encrypt(
      utf8.encode(keyPayload),
      secretKey: SecretKey(secretKeyBytes),
    );
    
    // 5. Pack: EphemeralPub (32) + Encrypted Payload
    final combined = [
      ...ephemeralPublicKey.bytes,
      ...secretBox.concatenation(),
    ];
    
    return base64Encode(combined);
  }

  // Decrypt the Group Key
  Future<String> decryptKey(String encryptedBlobBase64) async {
    if (_myKeyPair == null) await init();
    
    try {
      final combined = base64Decode(encryptedBlobBase64);
      
      // Extract Ephemeral Public Key (First 32 bytes for X25519)
      if (combined.length < 32 + 12 + 16) throw Exception("Invalid blob length");
      
      final ephemeralBytes = combined.sublist(0, 32);
      final cipherTextCombined = combined.sublist(32);
      
      final ephemeralPublicKey = SimplePublicKey(ephemeralBytes, type: KeyPairType.x25519);
      
      // Derive secret using MY private key + Ephemeral Public Key
      final sharedSecret = await _keyExchangeAlgorithm.sharedSecretKey(
        keyPair: _myKeyPair!,
        remotePublicKey: ephemeralPublicKey,
      );
      final secretKeyBytes = await sharedSecret.extractBytes();
      
      // Decrypt
      final secretBox = SecretBox.fromConcatenation(
        cipherTextCombined,
        nonceLength: 12,
        macLength: 16,
      );
      
      final algorithm = Chacha20.poly1305Aead();
      final clearTextBytes = await algorithm.decrypt(
        secretBox,
        secretKey: SecretKey(secretKeyBytes),
      );
      
      return utf8.decode(clearTextBytes);

    } catch (e) {
      debugPrint("❌ Key Decryption Failed: $e");
      return "";
    }
  }
}
