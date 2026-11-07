import Foundation

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
