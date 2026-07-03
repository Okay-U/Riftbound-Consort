//
//  Card.swift
//  Riftbound Companiokay
//

import Foundation

struct Card: Identifiable, Codable, Hashable, Sendable {
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

struct CardAttributes: Codable, Hashable, Sendable {
    let energy: Int?
    let might: Int?
    let power: Int?
}

struct CardClassification: Codable, Hashable, Sendable {
    let type: String?
    let supertype: String?
    let rarity: String?
    let domain: [String]?
}

struct CardText: Codable, Hashable, Sendable {
    let rich: String?
    let plain: String?
    let flavour: String?
}

struct CardSet: Codable, Hashable, Sendable {
    let setId: String?
    let label: String?

    enum CodingKeys: String, CodingKey {
        case setId = "set_id"
        case label
    }
}

struct CardMedia: Codable, Hashable, Sendable {
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

struct CardMetadata: Codable, Hashable, Sendable {
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
struct CardPage: Codable, Sendable {
    let total: Int
    let page: Int
    let size: Int
    let items: [Card]
}
