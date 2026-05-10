//
//  CaptureReviewView.swift
//  RecognizeLandmark
//

import SwiftUI
import MapKit
import CoreLocation

struct CaptureReviewView: View {
    let image: UIImage
    let candidates: [CaptureCandidate]
    let location: CLLocation?
    let onConfirm: (_ name: String, _ confidence: Double, _ note: String) -> Void
    let onCancel: () -> Void

    @State private var name: String = ""
    @State private var note: String = ""
    @FocusState private var nameFocused: Bool

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var selectedConfidence: Double {
        candidates.first(where: { $0.name == trimmedName })?.confidence ?? 0
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal)

                    nameSection

                    if !candidates.isEmpty {
                        candidateSection
                    }

                    if let location {
                        miniMap(coordinate: location.coordinate)
                            .frame(height: 160)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .padding(.horizontal)
                    } else {
                        Label("(無位置資訊)", systemImage: "location.slash")
                            .font(.subheadline)
                            .foregroundStyle(.tertiary)
                            .padding(.horizontal)
                    }

                    noteSection
                }
                .padding(.vertical)
            }
            .navigationTitle("確認記錄")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消", role: .cancel) { onCancel() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("儲存") {
                        onConfirm(trimmedName, selectedConfidence, note)
                    }
                    .bold()
                    .disabled(trimmedName.isEmpty)
                }
            }
            .onAppear {
                if name.isEmpty {
                    name = candidates.first?.name ?? defaultFallback()
                }
            }
        }
    }

    private var nameSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("名稱")
                .font(.headline)
            TextField("輸入地點名稱", text: $name)
                .textFieldStyle(.roundedBorder)
                .focused($nameFocused)
        }
        .padding(.horizontal)
    }

    private var candidateSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("候選")
                .font(.headline)
                .padding(.horizontal)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(candidates) { c in
                        candidateChip(c)
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    private var noteSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("筆記(可留空)")
                .font(.headline)
            TextEditor(text: $note)
                .frame(minHeight: 80)
                .padding(8)
                .background(Color.secondary.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .padding(.horizontal)
    }

    private func candidateChip(_ c: CaptureCandidate) -> some View {
        let isSelected = c.name == trimmedName
        return Button {
            name = c.name
            nameFocused = false
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Image(systemName: icon(for: c.source))
                        .font(.caption2)
                    Text(c.name)
                        .font(.subheadline)
                        .lineLimit(1)
                }
                if let secondary = c.secondaryText, !secondary.isEmpty {
                    Text(secondary)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.accentColor.opacity(0.18) : Color.secondary.opacity(0.12))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.accentColor : .clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func icon(for source: CaptureCandidate.Source) -> String {
        switch source {
        case .poi:      return "mappin.circle.fill"
        case .geocode:  return "location.fill"
        case .image:    return "camera.viewfinder"
        case .fallback: return "clock"
        }
    }

    private func miniMap(coordinate: CLLocationCoordinate2D) -> some View {
        Map(initialPosition: .region(MKCoordinateRegion(
            center: coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
        ))) {
            Marker(trimmedName.isEmpty ? "拍攝位置" : trimmedName, coordinate: coordinate)
        }
    }

    private func defaultFallback() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/MM/dd HH:mm"
        return formatter.string(from: Date()) + " 的記錄"
    }
}
