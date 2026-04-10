//
//  LiveStreamCardView.swift
//  Lume
//
//  Card view for displaying a live stream channel
//

import SwiftUI

struct LiveStreamCardView: View {
    let stream: LiveStream

    var body: some View {
        HStack(spacing: 12) {
            // Channel logo
            AsyncImage(url: URL(string: stream.streamIcon ?? "")) { phase in
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
                        .aspectRatio(contentMode: .fit)
                case .failure:
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .overlay {
                            Image(systemName: "antenna.radiowaves.left.and.right")
                                .foregroundStyle(.secondary)
                        }
                @unknown default:
                    EmptyView()
                }
            }
            .frame(width: 60, height: 60)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 4) {
                Text(stream.name)
                    .font(.headline)
                    .lineLimit(1)

                // EPG info would go here (current and next show)
                Text("Live")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if stream.tvArchive > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "clock.arrow.circlepath")
                        Text("Catchup: \(stream.tvArchiveDuration)d")
                    }
                    .font(.caption2)
                    .foregroundStyle(.blue)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 8)
    }
}

#Preview {
    LiveStreamCardView(
        stream: LiveStream(
            id: "preview",
            streamId: 1,
            name: "Sample Channel"
        )
    )
    .padding()
}
