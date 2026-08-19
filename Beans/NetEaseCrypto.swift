import Foundation
import Security

enum NetEaseCrypto {
    private static let fixedKey = Data("0CoJUm6Qyw8W8jud".utf8)
    private static let fixedIV = Data("0102030405060708".utf8)
    private static let eapiKey = Data("e82ckenh8dichen8".utf8)

    // MARK: - AES-128-CBC

    private static func aesCBCEncrypt(_ input: Data, key: Data) -> Data? {
        var outBytes = [UInt8](repeating: 0, count: input.count + kCCBlockSizeAES128)
        var outLen: size_t = 0
        let status = key.withUnsafeBytes { keyBytes in
            fixedIV.withUnsafeBytes { ivBytes in
                input.withUnsafeBytes { dataBytes in
                    CCCrypt(
                        CCOperation(kCCEncrypt),
                        CCAlgorithm(kCCAlgorithmAES),
                        CCOptions(kCCOptionPKCS7Padding),
                        keyBytes.baseAddress, key.count,
                        ivBytes.baseAddress,
                        dataBytes.baseAddress, input.count,
                        &outBytes, outBytes.count,
                        &outLen
                    )
                }
            }
        }
        guard status == kCCSuccess else { return nil }
        return Data(outBytes.prefix(outLen))
    }

    // MARK: - RSA PKCS1 (网易云固定 1024 位公钥)

    private static func rsaEncrypt(_ input: Data) -> Data? {
        guard let secKey = rsaPublicKey() else { return nil }
        var error: Unmanaged<CFError>?
        guard let encrypted = SecKeyCreateEncryptedData(secKey, .rsaEncryptionPKCS1, input as CFData, &error) as Data? else {
            return nil
        }
        return encrypted
    }

    private static func rsaPublicKey() -> SecKey? {
        let der = rsaPublicKeyDER()
        let attributes: [CFString: Any] = [
            kSecAttrKeyType: kSecAttrKeyTypeRSA,
            kSecAttrKeyClass: kSecAttrKeyClassPublic,
        ]
        return SecKeyCreateWithData(der as CFData, attributes as CFDictionary, nil)
    }

    private static func rsaPublicKeyDER() -> Data {
        let modulusHex = "00e0b509f6259df8642dbc35662901477df22677ec152b5ff68ace615bb7b725152b3ab17a876aea8a5aa76d2e417629ec4ee341f56135fccf695280104e0312ecbda92557c93870114af6c9d05c4f7f0c3685b7a46bee255932575cce10b424d813cfe4875d3e82047b97ddef52741d546b8e289dc6935b3ece0462db0a22b8e7"
        let modulus = Data(hexString: modulusHex)
        let exponent = Data([0x01, 0x00, 0x01])
        let rsaPub = derSequence(derInteger(modulus) + derInteger(exponent))
        let bitString = Data([0x03]) + derLength(rsaPub.count + 1) + Data([0x00]) + rsaPub
        let oid = Data([0x06, 0x09, 0x2a, 0x86, 0x48, 0x86, 0xf7, 0x0d, 0x01, 0x01, 0x01])
        let algorithm = derSequence(oid + Data([0x05, 0x00]))
        return derSequence(algorithm + bitString)
    }

    private static func derLength(_ len: Int) -> Data {
        if len < 0x80 { return Data([UInt8(len)]) }
        var bytes: [UInt8] = []
        var value = len
        while value > 0 {
            bytes.insert(UInt8(value & 0xff), at: 0)
            value >>= 8
        }
        return Data([UInt8(0x80 | bytes.count)]) + Data(bytes)
    }

    private static func derInteger(_ value: Data) -> Data {
        var data = value
        if let first = data.first, first & 0x80 != 0 {
            data = Data([0x00]) + data
        }
        return Data([0x02]) + derLength(data.count) + data
    }

    private static func derSequence(_ content: Data) -> Data {
        Data([0x30]) + derLength(content.count) + content
    }

    // MARK: - weapi / eapi

    static func weapi(_ payload: [String: Any]) -> [String: String] {
        let text = jsonString(payload)
        guard let first = aesCBCEncrypt(Data(text.utf8), key: fixedKey) else { return [:] }
        let secretKey = random16()
        guard let second = aesCBCEncrypt(Data(first.base64EncodedString().utf8), key: Data(secretKey.utf8)),
              let encSecKey = rsaEncrypt(Data(secretKey.utf8)) else { return [:] }
        return [
            "params": second.base64EncodedString(),
            "encSecKey": hexString(encSecKey),
        ]
    }

    static func eapi(_ payload: [String: Any], path: String) -> [String: String] {
        let text = jsonString(payload)
        let message = "nobody\(path)use\(text)md5forencrypt"
        let digest = Data(message.utf8).md5Hex()
        guard let paramsData = aesCBCEncrypt(Data(digest.utf8), key: eapiKey),
              let encSecKey = rsaEncrypt(eapiKey) else { return [:] }
        return [
            "params": "\(path)-36cd479b6b5-\(hexString(paramsData))",
            "encSecKey": hexString(encSecKey),
        ]
    }

    private static func hexString(_ data: Data) -> String {
        data.map { String(format: "%02x", $0) }.joined()
    }

    private static func random16() -> String {
        let chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        return String((0..<16).compactMap { _ in chars.randomElement() ?? "a" })
    }

    private static func jsonString(_ payload: [String: Any]) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: payload) else { return "{}" }
        return String(data: data, encoding: .utf8) ?? "{}"
    }
}

extension Data {
    init(hexString: String) {
        var bytes: [UInt8] = []
        var index = hexString.startIndex
        while index < hexString.endIndex {
            let next = hexString.index(index, offsetBy: 2)
            if let byte = UInt8(hexString[index..<next], radix: 16) {
                bytes.append(byte)
            }
            index = next
        }
        self.init(bytes)
    }

    func md5Hex() -> String {
        var digest = [UInt8](repeating: 0, count: Int(CC_MD5_DIGEST_LENGTH))
        _ = withUnsafeBytes { CC_MD5($0.baseAddress, CC_LONG(count), &digest) }
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}