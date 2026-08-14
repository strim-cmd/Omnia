import Foundation

/// The provider-owned wire shape is confined to Infrastructure.
internal struct ModelListResponse: Decodable, Sendable {
    let data: [ModelListItem]
}

internal struct ModelListItem: Decodable, Sendable {
    let id: String
}
