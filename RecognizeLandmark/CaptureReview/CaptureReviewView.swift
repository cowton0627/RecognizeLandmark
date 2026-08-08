//
//  CaptureReviewView.swift
//  RecognizeLandmark
//

import SwiftUI
import MapKit
import CoreLocation

struct CaptureReviewResult {
    let placeName: String
    let note: String
    let location: CLLocation?
    let capturedAt: Date
    let imageLabel: String?
    let imageConfidence: Double?
    let selectedFirst: Bool
    let manualName: Bool
}

struct CaptureReviewView: View {
    let image: UIImage
    let candidates: [CaptureCandidate]
    let location: CLLocation?
    let capturedAt: Date
    let onConfirm: (CaptureReviewResult) -> Void
    let onCancel: () -> Void

    @State private var name: String = ""
    @State private var note: String = ""
    @State private var displayedCandidates: [CaptureCandidate]
    @State private var selectedLocation: CLLocation?
    @State private var isLookingUp = false
    @State private var showLocationPicker = false
    @FocusState private var nameFocused: Bool

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var bestImageCandidate: CaptureCandidate? {
        displayedCandidates.first { $0.source == .image }
    }

    private var hasPlaceCandidate: Bool {
        displayedCandidates.contains { $0.source == .poi || $0.source == .geocode }
    }

    init(image: UIImage,
         candidates: [CaptureCandidate],
         location: CLLocation?,
         capturedAt: Date = Date(),
         onConfirm: @escaping (CaptureReviewResult) -> Void,
         onCancel: @escaping () -> Void) {
        self.image = image
        self.candidates = candidates
        self.location = location
        self.capturedAt = capturedAt
        self.onConfirm = onConfirm
        self.onCancel = onCancel
        _displayedCandidates = State(initialValue: candidates)
        _selectedLocation = State(initialValue: location)
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

                    if let bestImageCandidate {
                        Label(
                            "畫面內容：\(bestImageCandidate.name) · 影像辨識信心 \(Int((bestImageCandidate.confidence ?? 0) * 100))%",
                            systemImage: "camera.viewfinder"
                        )
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)
                    }

                    if !displayedCandidates.isEmpty {
                        candidateSection
                    } else {
                        Label("找不到辨識候選，請手動輸入地點名稱。", systemImage: "exclamationmark.magnifyingglass")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal)
                    }

                    if selectedLocation != nil && !hasPlaceCandidate {
                        Label("附近地點查詢沒有結果，可能是目前離線；仍可手動命名並保存。", systemImage: "wifi.slash")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal)
                    }

                    if let selectedLocation {
                        miniMap(coordinate: selectedLocation.coordinate)
                            .frame(height: 160)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .padding(.horizontal)
                    } else {
                        Label("(無位置資訊)", systemImage: "location.slash")
                            .font(.subheadline)
                            .foregroundStyle(.tertiary)
                            .padding(.horizontal)
                    }

                    locationActions

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
                        onConfirm(CaptureReviewResult(
                            placeName: trimmedName,
                            note: note,
                            location: selectedLocation,
                            capturedAt: capturedAt,
                            imageLabel: bestImageCandidate?.name,
                            imageConfidence: bestImageCandidate?.confidence,
                            selectedFirst: displayedCandidates.first?.name == trimmedName,
                            manualName: !displayedCandidates.contains { $0.name == trimmedName }
                        ))
                    }
                    .bold()
                    .disabled(trimmedName.isEmpty)
                }
            }
            .onAppear {
                if name.isEmpty {
                    name = displayedCandidates.first?.name ?? defaultFallback()
                }
            }
            .sheet(isPresented: $showLocationPicker) {
                LocationPickerView(initialLocation: selectedLocation) { newLocation in
                    selectedLocation = newLocation
                    showLocationPicker = false
                    Task { await refreshCandidates(at: newLocation) }
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
                    ForEach(displayedCandidates) { c in
                        candidateChip(c)
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    private var locationActions: some View {
        HStack {
            Button {
                showLocationPicker = true
            } label: {
                Label("修正位置", systemImage: "map")
            }
            Spacer()
            Button {
                guard let selectedLocation else { return }
                Task { await refreshCandidates(at: selectedLocation) }
            } label: {
                if isLookingUp {
                    ProgressView()
                } else {
                    Label("重新搜尋附近", systemImage: "arrow.clockwise")
                }
            }
            .disabled(selectedLocation == nil || isLookingUp)
        }
        .buttonStyle(.bordered)
        .padding(.horizontal)
    }

    @MainActor
    private func refreshCandidates(at location: CLLocation) async {
        isLookingUp = true
        let refreshed = await PlaceLookup.lookup(location)
        displayedCandidates = CaptureCandidate.dedupedByName(refreshed + displayedCandidates.filter { $0.source == .image })
        if let first = displayedCandidates.first { name = first.name }
        isLookingUp = false
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

private struct LocationPickerView: View {
    let initialLocation: CLLocation?
    let onSelect: (CLLocation) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var position: MapCameraPosition
    @State private var selection: CLLocationCoordinate2D?

    init(initialLocation: CLLocation?, onSelect: @escaping (CLLocation) -> Void) {
        self.initialLocation = initialLocation
        self.onSelect = onSelect
        let center = initialLocation?.coordinate ?? CLLocationCoordinate2D(latitude: 25.033, longitude: 121.5654)
        _position = State(initialValue: .region(MKCoordinateRegion(
            center: center,
            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        )))
        _selection = State(initialValue: initialLocation?.coordinate)
    }

    var body: some View {
        NavigationStack {
            MapReader { proxy in
                Map(position: $position) {
                    if let selection { Marker("選擇的位置", coordinate: selection) }
                }
                .mapControls { MapCompass(); MapScaleView() }
                .onTapGesture { point in
                    selection = proxy.convert(point, from: .local)
                }
            }
            .navigationTitle("點選正確位置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("套用") {
                        if let selection { onSelect(CLLocation(latitude: selection.latitude, longitude: selection.longitude)) }
                    }
                    .disabled(selection == nil)
                }
            }
        }
    }
}
