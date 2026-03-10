// swiftlint:disable file_length
import Foundation
#if canImport(CoreFoundation)
import CoreFoundation
#endif

package extension String {
  init?<Tag>(data: BoundaryData<Tag>, encoding: Encoding) {
    self.init(data: data.rawValue, encoding: encoding)
  }
}

public extension HTTPTextEncoding {
  static let utf8 = Self(rawValue: "utf-8")
  static let utf16 = Self(rawValue: "utf-16")
  static let utf16BigEndian = Self(rawValue: "utf-16be")
  static let utf16LittleEndian = Self(rawValue: "utf-16le")
  static let utf32 = Self(rawValue: "utf-32")
  static let ascii = Self(rawValue: "us-ascii")
  static let isoLatin1 = Self(rawValue: "iso-8859-1")
}

package extension BoundaryString where Tag == HTTPTextEncodingTag {
  var foundationEncoding: String.Encoding? {
    let normalizedName = lowercased().replacingOccurrences(of: "_", with: "-")

    switch normalizedName {
    case "utf8", "utf-8":
      return String.Encoding.utf8
    case "utf16", "utf-16":
      return String.Encoding.utf16
    case "utf16be", "utf-16be":
      return String.Encoding.utf16BigEndian
    case "utf16le", "utf-16le":
      return String.Encoding.utf16LittleEndian
    case "utf32", "utf-32":
      return String.Encoding.utf32
    case "utf32be", "utf-32be":
      return String.Encoding.utf32BigEndian
    case "utf32le", "utf-32le":
      return String.Encoding.utf32LittleEndian
    case "ascii", "us-ascii":
      return String.Encoding.ascii
    case "iso-8859-1", "latin1", "iso-latin-1":
      return String.Encoding.isoLatin1
    default:
      #if canImport(CoreFoundation)
      let cfEncoding = CFStringConvertIANACharSetNameToEncoding(rawValue as CFString)
      guard cfEncoding != kCFStringEncodingInvalidId else {
        return nil
      }
      return String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(cfEncoding))
      #else
      return nil
      #endif
    }
  }
}

package extension URL {
  init?<Tag>(string: BoundaryString<Tag>) {
    self.init(string: string.rawValue)
  }
}

package extension URLRequest {
  init<Tag>(url: BoundaryURL<Tag>) {
    self.init(url: url.rawValue)
  }
}

package extension URLComponents {
  init?<Tag>(url: BoundaryURL<Tag>, resolvingAgainstBaseURL: Bool) {
    self.init(url: url.rawValue, resolvingAgainstBaseURL: resolvingAgainstBaseURL)
  }
}

package extension JSONDecoder {
  func decode<T: Decodable, Tag>(_ type: T.Type, from data: BoundaryData<Tag>) throws -> T {
    try decode(type, from: data.rawValue)
  }
}

package extension Set where Element == Int {
  func contains<Tag>(_ member: BoundaryInt<Tag>) -> Bool {
    contains(member.rawValue)
  }
}
