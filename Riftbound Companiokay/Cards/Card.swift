//
//  Card.swift
//  Riftbound Companiokay
//

import Foundation

// nonisolated because RiftcodexCardRepository decodes these off the main actor.
// Under the project's default-MainActor isolation a plain model's Codable
// conformance is MainActor-isolated and cannot be used from there.

nonisolated struct Card: Identifiable, Codable, Hashable, Sendable {
    let id: String
    let name: String
    let riftboundId: String?
    let collectorNumber: Int?
    let attributes: CardAttributes?
    let classification: CardClassification?
    let text: CardText?
    let set: CardSet?
    let media: CardMedia?
    let tags: [String]?
    let orientation: String?
    let metadata: CardMetadata?

    enum CodingKeys: String, CodingKey {
        case id, name
        case riftboundId     = "riftbound_id"
        case collectorNumber = "collector_number"
        case attributes, classification, text, set, media, tags, orientation, metadata
    }
}

nonisolated struct CardAttributes: Codable, Hashable, Sendable {
    let energy: Int?
    let might: Int?
    let power: Int?
}

nonisolated struct CardClassification: Codable, Hashable, Sendable {
    let type: String?
    let supertype: String?
    let rarity: String?
    let domain: [String]?
}

nonisolated struct CardText: Codable, Hashable, Sendable {
    let rich: String?
    let plain: String?
    let flavour: String?
}

nonisolated struct CardSet: Codable, Hashable, Sendable {
    let setId: String?
    let label: String?

    enum CodingKeys: String, CodingKey {
        case setId = "set_id"
        case label
    }
}

nonisolated struct CardMedia: Codable, Hashable, Sendable {
    let imageUrl: String?
    let artist: String?
    let accessibilityText: String?

    enum CodingKeys: String, CodingKey {
        case imageUrl          = "image_url"
        case artist
        case accessibilityText = "accessibility_text"
    }

    var imageURL: URL? {
        guard let raw = imageUrl else { return nil }
        return URL(string: raw)
    }
}

nonisolated struct CardMetadata: Codable, Hashable, Sendable {
    let cleanName: String?
    let updatedOn: String?
    let alternateArt: Bool?
    let overnumbered: Bool?
    let signature: Bool?

    enum CodingKeys: String, CodingKey {
        case cleanName    = "clean_name"
        case updatedOn    = "updated_on"
        case alternateArt = "alternate_art"
        case overnumbered
        case signature
    }
}

// Pagination wrapper returned by the Riftcodex API list endpoints
nonisolated struct CardPage: Codable, Sendable {
    let total: Int
    let page: Int
    let size: Int
    let items: [Card]
}
