/// An identity that cannot be mixed with identities from another domain.
public typealias Identifier<Domain, RawValue> = Tagged<Domain, RawValue>
