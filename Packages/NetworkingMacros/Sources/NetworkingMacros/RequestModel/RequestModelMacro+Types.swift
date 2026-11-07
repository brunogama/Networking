import SwiftSyntax
import SwiftSyntaxBuilder

extension RequestModelMacro {
  static func headerValuesType(for properties: [RequestModelProperty]) -> StructDeclSyntax {
    StructDeclSyntax(
      modifiers: RequestModelSyntaxFactory.privateModifiers,
      name: .identifier("RequestModelHeaderValues"),
      inheritanceClause: inheritance("Sendable"),
      memberBlock: memberBlock(for: properties)
    )
  }

  static func payloadType(for properties: [RequestModelProperty]) -> StructDeclSyntax {
    StructDeclSyntax(
      modifiers: RequestModelSyntaxFactory.privateModifiers,
      name: .identifier("RequestModelPayload"),
      inheritanceClause: inheritance("Encodable", "Sendable"),
      memberBlock: MemberBlockSyntax(
        members: MemberBlockItemListSyntax {
          for property in properties {
            RequestModelSyntaxFactory.storedProperty(name: property.name, type: property.type)
          }
          codingKeys(for: properties)
        }
      )
    )
  }

  static func memberBlock(for properties: [RequestModelProperty]) -> MemberBlockSyntax {
    MemberBlockSyntax(
      members: MemberBlockItemListSyntax {
        for property in properties {
          RequestModelSyntaxFactory.storedProperty(name: property.name, type: property.type)
        }
      }
    )
  }

  static func codingKeys(for properties: [RequestModelProperty]) -> EnumDeclSyntax {
    EnumDeclSyntax(
      modifiers: RequestModelSyntaxFactory.privateModifiers,
      name: .identifier("CodingKeys"),
      inheritanceClause: inheritance("String", "CodingKey"),
      memberBlock: MemberBlockSyntax(
        members: MemberBlockItemListSyntax {
          for property in properties {
            codingKey(for: property)
          }
        }
      )
    )
  }

  static func codingKey(for property: RequestModelProperty) -> EnumCaseDeclSyntax {
    EnumCaseDeclSyntax(
      elements: EnumCaseElementListSyntax {
        EnumCaseElementSyntax(
          name: property.name,
          rawValue: InitializerClauseSyntax(
            value: StringLiteralExprSyntax(content: property.key)
          )
        )
      }
    )
  }

  static func inheritance(_ names: String...) -> InheritanceClauseSyntax {
    InheritanceClauseSyntax(
      inheritedTypes: InheritedTypeListSyntax {
        for name in names {
          InheritedTypeSyntax(type: RequestModelSyntaxFactory.namedType(name))
        }
      }
    )
  }
}
