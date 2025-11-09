//
//  RoadmapView.swift
//  Riftbound Companiokay
//
//  Created by Okay Kaan Ünal on 06.11.25.
//


import SwiftUI

struct RoadmapView: View {
    struct Item: Identifiable {
        let id = UUID()
        let when: String
        let title: String
        let detail: String?
        let icon: String
    }

    private let items: [Item] = [
        .init(when: "Nov 2025", title: "Release Simple Scoreboard App", detail: nil, icon: "sparkles"),
        .init(when: "Christmas 2025", title: "Implement user feedback", detail: nil, icon: "gift"),
        .init(when: "Q1 2026", title: "Maskot Update", detail: "Get ready for your little friend", icon: "pat.carrier.fill"),
        .init(when: "Q2 2026", title: "Card Database Update", detail: "Turning the Scoreboard App into a Companion App", icon: "square.3.layers.3d")
    ]

    var body: some View {
        List {
            ForEach(items) { item in
                HStack(spacing: 12) {
                    Image(systemName: item.icon)
                        .imageScale(.large)
                        .frame(width: 28, height: 28)
                        .foregroundStyle(.tint)
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(item.when)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Spacer()
                        }
                        Text(item.title)
                            .font(.headline)
                        if let d = item.detail {
                            Text(d).foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.vertical, 6)
            }
        }
        .navigationTitle("Roadmap")
    }
}
