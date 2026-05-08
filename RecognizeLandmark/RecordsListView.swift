//
//  RecordsListView.swift
//  RecognizeLandmark
//

import SwiftUI
import SwiftData

struct RecordsListView: View {
    @Query(sort: \LandmarkRecord.timestamp, order: .reverse)
    private var records: [LandmarkRecord]

    var body: some View {
        NavigationStack {
            Group {
                if records.isEmpty {
                    ContentUnavailableView(
                        "還沒有記錄",
                        systemImage: "photo.on.rectangle.angled",
                        description: Text("到「相機」分頁拍下你看到的景點")
                    )
                } else {
                    List {
                        ForEach(records) { record in
                            RecordRow(record: record)
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("我的記錄")
        }
    }
}

private struct RecordRow: View {
    let record: LandmarkRecord
    @State private var thumbnail: UIImage?

    var body: some View {
        HStack(spacing: 12) {
            thumbnailView
            VStack(alignment: .leading, spacing: 4) {
                Text(record.recognizedName)
                    .font(.headline)
                    .lineLimit(1)
                Text(record.timestamp.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(locationText)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            Spacer()
            Text("\(Int(record.confidence * 100))%")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
        .task(id: record.photoFilename) {
            await loadThumbnail()
        }
    }

    private var locationText: String {
        if let lat = record.latitude, let lon = record.longitude {
            return String(format: "%.4f, %.4f", lat, lon)
        }
        return "(無位置)"
    }

    @ViewBuilder
    private var thumbnailView: some View {
        if let thumbnail {
            Image(uiImage: thumbnail)
                .resizable()
                .scaledToFill()
                .frame(width: 64, height: 64)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        } else {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.secondary.opacity(0.15))
                .frame(width: 64, height: 64)
                .overlay {
                    Image(systemName: "photo")
                        .foregroundStyle(.secondary)
                }
        }
    }

    private func loadThumbnail() async {
        let filename = record.photoFilename
        let image = await Task.detached(priority: .userInitiated) {
            try? PhotoStorage.shared.load(filename)
        }.value
        self.thumbnail = image
    }
}
