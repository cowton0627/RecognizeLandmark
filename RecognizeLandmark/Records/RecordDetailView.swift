//
//  RecordDetailView.swift
//  RecognizeLandmark
//

import SwiftUI
import SwiftData
import MapKit
import CoreLocation

struct RecordDetailView: View {
    @Bindable var record: LandmarkRecord
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var fullImage: UIImage?
    @State private var showDeleteConfirmation = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                photoView

                VStack(alignment: .leading, spacing: 6) {
                    Text(record.recognizedName)
                        .font(.title.bold())
                    Label(record.timestamp.formatted(date: .long, time: .shortened),
                          systemImage: "clock")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Label("信心度 \(Int(record.confidence * 100))%",
                          systemImage: "chart.bar")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal)

                if let coordinate = record.coordinate {
                    mapView(coordinate: coordinate)
                        .frame(height: 200)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal)
                } else {
                    Label("(無位置資訊)", systemImage: "location.slash")
                        .foregroundStyle(.tertiary)
                        .font(.subheadline)
                        .padding(.horizontal)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("筆記")
                        .font(.headline)
                    TextEditor(text: $record.note)
                        .frame(minHeight: 120)
                        .padding(8)
                        .background(Color.secondary.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(alignment: .topLeading) {
                            if record.note.isEmpty {
                                Text("加上你對這個地方的描述...")
                                    .foregroundStyle(.tertiary)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 16)
                                    .allowsHitTesting(false)
                            }
                        }
                }
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
        .navigationTitle("詳情")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showDeleteConfirmation = true
                } label: {
                    Image(systemName: "trash")
                        .foregroundStyle(.red)
                }
            }
        }
        .confirmationDialog("確認刪除這筆記錄?",
                            isPresented: $showDeleteConfirmation,
                            titleVisibility: .visible) {
            Button("刪除", role: .destructive) { deleteRecord() }
            Button("取消", role: .cancel) {}
        }
        .task(id: record.photoFilename) {
            await loadFullImage()
        }
    }

    @ViewBuilder
    private var photoView: some View {
        if let fullImage {
            Image(uiImage: fullImage)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity)
        } else {
            Rectangle()
                .fill(Color.secondary.opacity(0.15))
                .aspectRatio(3/4, contentMode: .fit)
                .overlay(ProgressView())
        }
    }

    private func mapView(coordinate: CLLocationCoordinate2D) -> some View {
        Map(initialPosition: .region(MKCoordinateRegion(
            center: coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
        ))) {
            Marker(record.recognizedName, coordinate: coordinate)
        }
    }

    private func loadFullImage() async {
        let filename = record.photoFilename
        let image = await Task.detached(priority: .userInitiated) {
            try? PhotoStorage.shared.load(filename)
        }.value
        self.fullImage = image
    }

    private func deleteRecord() {
        let filename = record.photoFilename
        Task.detached(priority: .utility) {
            try? PhotoStorage.shared.delete(filename)
        }
        modelContext.delete(record)
        dismiss()
    }
}
