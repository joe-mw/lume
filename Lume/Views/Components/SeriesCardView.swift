//
//  SeriesCardView.swift
//  Lume
//
//  Card view for displaying a series cover and title
//

import SwiftUI

struct SeriesCardView: View {
    let series: Series

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Cover
            AsyncImage(url: URL(string: series.cover ?? "")) { phase in
                switch phase {
                case .empty:
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .overlay {
                            ProgressView()
                        }
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                case .failure:
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .overlay {
                            Image(systemName: "tv")
                                .foregroundStyle(.secondary)
                                .font(.largeTitle)
                        }
                @unknown default:
                    EmptyView()
                }
            }
            .frame(width: 120, height: 180)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .shadow(radius: 2)

            // Title
            Text(series.name)
                .font(.caption)
                .lineLimit(2)
                .frame(width: 120, alignment: .leading)
        }
    }
}

#Preview {
    SeriesCardView(
        series: Series(
            id: "preview",
            seriesId: 1,
            name: "Sample Series"
        )
    )
}
