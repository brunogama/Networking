import Foundation

package extension String {
  init?<Tag>(data: BoundaryData<Tag>, encoding: Encoding) {
    self.init(data: data.rawValue, encoding: encoding)
  }
}

public extension HTTPTextEncoding {
  /// UTF-8 text encoding.
  static let utf8 = Self(rawValue: "utf-8")
  /// UTF-16 text encoding.
  static let utf16 = Self(rawValue: "utf-16")
  /// Big-endian UTF-16 text encoding.
  static let utf16BigEndian = Self(rawValue: "utf-16be")
  /// Little-endian UTF-16 text encoding.
  static let utf16LittleEndian = Self(rawValue: "utf-16le")
  /// UTF-32 text encoding.
  static let utf32 = Self(rawValue: "utf-32")
  /// US-ASCII text encoding.
  static let ascii = Self(rawValue: "us-ascii")
  /// ISO-8859-1 text encoding.
  static let isoLatin1 = Self(rawValue: "iso-8859-1")
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
