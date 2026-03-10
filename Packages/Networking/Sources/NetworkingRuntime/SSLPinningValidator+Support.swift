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
    let certificateData = SecCertificateCopyData(certificate)
    let data = CFDataGetBytePtr(certificateData)!
    let length = CFDataGetLength(certificateData)

    var digest = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
    CC_SHA256(data, CC_LONG(length), &digest)

    return digest.map { String(format: "%02x", $0) }.joined()
  }

  func sha256Hash(of publicKey: SecKey) -> String {
    guard let publicKeyData = SecKeyCopyExternalRepresentation(publicKey, nil) else {
      return ""
    }

    let data = CFDataGetBytePtr(publicKeyData)!
    let length = CFDataGetLength(publicKeyData)

    var digest = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
    CC_SHA256(data, CC_LONG(length), &digest)

    return digest.map { String(format: "%02x", $0) }.joined()
  }
}

#endif
