//
//  RecordsListView.swift
//  RecognizeLandmark
//

import SwiftUI
import SwiftData
import MapKit
import CoreLocation

struct RecordsListView: View {
    private enum DisplayMode: String, CaseIterable {
        case list = "列表"
        case map = "地圖"

        var icon: String { self == .list ? "list.bullet" : "map" }
    }

    @Query(sort: \LandmarkRecord.timestamp, order: .reverse)
    private var records: [LandmarkRecord]

    @Environment(\.modelContext) private var modelContext
    @State private var displayMode: DisplayMode = .list
    @State private var selectedClusterID: String?
    @State private var cameraPosition: MapCameraPosition = .automatic

    private var clusters: [RecordCluster] {
        RecordCluster.make(from: records)
    }

    private var selectedCluster: RecordCluster? {
        clusters.first { $0.id == selectedClusterID }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if records.isEmpty {
                    ContentUnavailableView(
                        "還沒有記錄",
                        systemImage: "photo.on.rectangle.angled",
                        description: Text("到「相機」分頁拍下你看到的景點")
                    )
                } else {
                    Picker("顯示方式", selection: $displayMode) {
                        ForEach(DisplayMode.allCases, id: \.self) { mode in
                            Label(mode.rawValue, systemImage: mode.icon).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    .padding(.vertical, 8)

                    switch displayMode {
                    case .list:
                        recordsList
                    case .map:
                        recordsMap
                    }
                }
            }
            .navigationTitle("我的足跡")
            .navigationDestination(for: LandmarkRecord.self) { record in
                RecordDetailView(record: record)
            }
            .onChange(of: displayMode) { _, mode in
                if mode == .map { fitMapToRecords() }
            }
        }
    }

    private var recordsList: some View {
        List {
            ForEach(records) { record in
                NavigationLink(value: record) {
                    RecordRow(record: record)
                }
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        deleteRecord(record)
                    } label: {
                        Label("刪除", systemImage: "trash")
                    }
                }
            }
        }
        .listStyle(.plain)
    }

    @ViewBuilder
    private var recordsMap: some View {
        if clusters.isEmpty {
            ContentUnavailableView(
                "沒有位置資訊",
                systemImage: "map",
                description: Text("可在記錄確認頁使用「修正位置」補上地點")
            )
        } else {
            Map(position: $cameraPosition) {
                ForEach(clusters) { cluster in
                    Annotation(cluster.primaryRecord.recognizedName,
                               coordinate: cluster.coordinate,
                               anchor: .bottom) {
                        Button {
                            selectedClusterID = cluster.id
                        } label: {
                            ZStack(alignment: .topTrailing) {
                                Image(systemName: selectedClusterID == cluster.id ? "mappin.circle.fill" : "mappin.circle")
                                    .font(.system(size: 34))
                                    .foregroundStyle(SwiftUI.Color(uiColor: Sketch.accentWarm))
                                    .background(Circle().fill(.white).padding(4))
                                if cluster.records.count > 1 {
                                    Text("\(cluster.records.count)")
                                        .font(.caption2.bold())
                                        .foregroundStyle(.white)
                                        .padding(5)
                                        .background(Circle().fill(.red))
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .mapStyle(.standard(elevation: .realistic))
            .mapControls {
                MapCompass()
                MapScaleView()
                MapUserLocationButton()
            }
            .safeAreaInset(edge: .bottom) {
                if let selectedCluster {
                    MapRecordPreview(cluster: selectedCluster)
                        .padding(.horizontal)
                        .padding(.bottom, 8)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.easeInOut(duration: 0.2), value: selectedClusterID)
        }
    }

    private func fitMapToRecords() {
        guard !clusters.isEmpty else { return }
        let latitudes = clusters.map(\.coordinate.latitude)
        let longitudes = clusters.map(\.coordinate.longitude)
        guard let minLatitude = latitudes.min(), let maxLatitude = latitudes.max(),
              let minLongitude = longitudes.min(), let maxLongitude = longitudes.max()
        else { return }

        let center = CLLocationCoordinate2D(
            latitude: (minLatitude + maxLatitude) / 2,
            longitude: (minLongitude + maxLongitude) / 2
        )
        let span = MKCoordinateSpan(
            latitudeDelta: max((maxLatitude - minLatitude) * 1.4, 0.01),
            longitudeDelta: max((maxLongitude - minLongitude) * 1.4, 0.01)
        )
        cameraPosition = .region(MKCoordinateRegion(center: center, span: span))
    }

    private func deleteRecord(_ record: LandmarkRecord) {
        let filename = record.photoFilename
        Task.detached(priority: .utility) {
            do {
                try PhotoStorage.shared.delete(filename)
            } catch {
                print("Failed to delete photo \(filename): \(error)")
            }
        }
        modelContext.delete(record)
    }
}

struct RecordCluster: Identifiable {
    var records: [LandmarkRecord]
    var coordinate: CLLocationCoordinate2D

    var id: String {
        String(format: "%.5f,%.5f", coordinate.latitude, coordinate.longitude)
    }

    var primaryRecord: LandmarkRecord { records[0] }

    static func make(from records: [LandmarkRecord], thresholdMeters: CLLocationDistance = 100) -> [RecordCluster] {
        var clusters: [RecordCluster] = []
        for record in records {
            guard let coordinate = record.coordinate else { continue }
            let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
            if let index = clusters.firstIndex(where: {
                CLLocation(latitude: $0.coordinate.latitude, longitude: $0.coordinate.longitude)
                    .distance(from: location) <= thresholdMeters
            }) {
                clusters[index].records.append(record)
                let coordinates = clusters[index].records.compactMap(\.coordinate)
                clusters[index].coordinate = CLLocationCoordinate2D(
                    latitude: coordinates.map(\.latitude).reduce(0, +) / Double(coordinates.count),
                    longitude: coordinates.map(\.longitude).reduce(0, +) / Double(coordinates.count)
                )
            } else {
                clusters.append(RecordCluster(records: [record], coordinate: coordinate))
            }
        }
        return clusters
    }
}

private struct MapRecordPreview: View {
    let cluster: RecordCluster
    @State private var thumbnail: UIImage?

    var body: some View {
        NavigationLink(value: cluster.primaryRecord) {
            HStack(spacing: 12) {
                Group {
                    if let thumbnail {
                        Image(uiImage: thumbnail)
                            .resizable()
                            .scaledToFill()
                    } else {
                        SwiftUI.Color.secondary.opacity(0.15)
                            .overlay(Image(systemName: "photo").foregroundStyle(.secondary))
                    }
                }
                .frame(width: 64, height: 64)
                .clipShape(RoundedRectangle(cornerRadius: 10))

                VStack(alignment: .leading, spacing: 4) {
                    Text(cluster.primaryRecord.recognizedName)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Text(cluster.primaryRecord.timestamp.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if cluster.records.count > 1 {
                        Text("這個地點共 \(cluster.records.count) 筆記錄")
                            .font(.caption)
                            .foregroundStyle(SwiftUI.Color(uiColor: Sketch.accentWarm))
                    }
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(.tertiary)
            }
            .padding(12)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.12), radius: 12, y: 5)
        }
        .buttonStyle(.plain)
        .task(id: cluster.primaryRecord.photoFilename) {
            let filename = cluster.primaryRecord.photoFilename
            thumbnail = await Task.detached(priority: .userInitiated) {
                try? PhotoStorage.shared.load(filename)
            }.value
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
                if let imageLabel = record.imageLabel {
                    Label(imageLabel, systemImage: "camera.viewfinder")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Text(record.timestamp.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(locationText)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            Spacer()
            if let confidence = record.effectiveImageConfidence {
                Text("影像 \(Int(confidence * 100))%")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            } else {
                Text("未評分")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
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
