//
//  StoresHomeView.swift
//  Riftbound Companiokay
//
//  "Stores" segment of the Events tab. Phase 0: store search + map.
//  Phase 1 adds favorites ("My local stores") and a calendar of favorite
//  stores' events.
//

import SwiftUI

struct StoresHomeView: View {
    var body: some View {
        StoreSearchView(embedded: true)
    }
}
