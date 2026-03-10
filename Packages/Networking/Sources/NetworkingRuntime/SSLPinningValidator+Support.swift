import Foundation

#if canImport(CommonCrypto)
import CommonCrypto
#endif

#if canImport(Security)
import Security

extension SSLPinningValidator {
  func getServerCertificateChain(serverTrust: SecTrust) -> [SecCertificate]? {
    guard let certificateChain = SecTrustCopyCertificateChain(serverTrust) else {
      return nil
    }

    var certificates: [SecCertificate] = []
    let count = CFArrayGetCount(certificateChain)

    for index in 0..<count {
      guard let certificate = CFArrayGetValueAtIndex(certificateChain, index) else {
        continue
      }

      let certificateRef = Unmanaged<SecCertificate>.fromOpaque(certificate).takeUnretainedValue()
      certificates.append(certificateRef)
    }

    return certificates.isEmpty ? nil : certificates
  }

  func writeToStandardError(_ message: String) {
    FileHandle.standardError.write(Data("\(message)\n".utf8))
  }

  func sha256Hash(of certificate: SecCertificate) -> String {
    let certificateData = SecCertificateCopyData(certificate) as Data
    return sha256Hash(of: certificateData)
  }

  func sha256Hash(of publicKey: SecKey) -> String {
    guard let subjectPublicKeyInfo = subjectPublicKeyInfo(for: publicKey) else {
      return ""
    }

    return sha256Hash(of: subjectPublicKeyInfo)
  }

  private func sha256Hash(of data: Data) -> String {
    var digest = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
    data.withUnsafeBytes { buffer in
      guard let baseAddress = buffer.baseAddress else {
        return
      }

      CC_SHA256(baseAddress, CC_LONG(buffer.count), &digest)
    }

    return digest.map { String(format: "%02x", $0) }.joined()
  }

  private func subjectPublicKeyInfo(for publicKey: SecKey) -> Data? {
    guard
      let attributes = SecKeyCopyAttributes(publicKey) as? [CFString: Any],
      let keyType = attributes[kSecAttrKeyType] as? String,
      let keySizeInBits = attributes[kSecAttrKeySizeInBits] as? Int,
      let publicKeyData = SecKeyCopyExternalRepresentation(publicKey, nil) as Data?
    else {
      return nil
    }

    let algorithmIdentifier: Data
    if keyType == (kSecAttrKeyTypeRSA as String) {
      algorithmIdentifier = asn1Sequence(
        asn1ObjectIdentifier([0x2A, 0x86, 0x48, 0x86, 0xF7, 0x0D, 0x01, 0x01, 0x01])
          + asn1Null()
      )
    } else if keyType == (kSecAttrKeyTypeECSECPrimeRandom as String) {
      guard let curveIdentifier = ecCurveIdentifier(for: keySizeInBits) else {
        return nil
      }
      algorithmIdentifier = asn1Sequence(
        asn1ObjectIdentifier([0x2A, 0x86, 0x48, 0xCE, 0x3D, 0x02, 0x01])
          + curveIdentifier
      )
    } else {
      return nil
    }

    return asn1Sequence(algorithmIdentifier + asn1BitString(publicKeyData))
  }

  private func ecCurveIdentifier(for keySizeInBits: Int) -> Data? {
    switch keySizeInBits {
    case 256:
      return asn1ObjectIdentifier([0x2A, 0x86, 0x48, 0xCE, 0x3D, 0x03, 0x01, 0x07])
    case 384:
      return asn1ObjectIdentifier([0x2B, 0x81, 0x04, 0x00, 0x22])
    case 521:
      return asn1ObjectIdentifier([0x2B, 0x81, 0x04, 0x00, 0x23])
    default:
      return nil
    }
  }

  private func asn1Sequence(_ value: Data) -> Data {
    Data([0x30]) + asn1Length(value.count) + value
  }

  private func asn1BitString(_ value: Data) -> Data {
    Data([0x03]) + asn1Length(value.count + 1) + Data([0x00]) + value
  }

  private func asn1Null() -> Data {
    Data([0x05, 0x00])
  }

  private func asn1ObjectIdentifier(_ bytes: [UInt8]) -> Data {
    Data([0x06]) + asn1Length(bytes.count) + Data(bytes)
  }

  private func asn1Length(_ length: Int) -> Data {
    guard length >= 0x80 else {
      return Data([UInt8(length)])
    }

    var value = length
    var bytes: [UInt8] = []
    while value > 0 {
      bytes.insert(UInt8(value & 0xFF), at: 0)
      value >>= 8
    }

    return Data([0x80 | UInt8(bytes.count)]) + Data(bytes)
  }
}

#endif
