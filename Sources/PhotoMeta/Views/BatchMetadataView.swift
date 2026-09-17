import CoreLocation
import SwiftUI

/// Date/location editor applied to every photo currently in the batch.
struct BatchMetadataView: View {
    @EnvironmentObject private var library: PhotoLibrary
    @Environment(\.dismiss) private var dismiss

    @State private var date = Date()
    @State private var addressText = ""
    @State private var latitudeText = ""
    @State private var longitudeText = ""
    @State private var isGeocoding = false
    @State private var geocodeError: String?
    @State private var showCopyPicker = false
    @State private var isApplying = false

    private var coordinate: Coordinate? {
        guard let lat = Double(latitudeText), let lon = Double(longitudeText) else { return nil }
        return Coordinate(latitude: lat, longitude: lon)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Add Date & Location to \(library.selectedBatch.count) Photo\(library.selectedBatch.count == 1 ? "" : "s")")
                .font(.headline)

            DatePicker("Date & Time", selection: $date, displayedComponents: [.date, .hourAndMinute])
                .datePickerStyle(.field)

            GroupBox("Location") {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        TextField("Search address or place", text: $addressText)
                            .onSubmit { geocode() }
                        Button("Find") { geocode() }
                            .disabled(addressText.isEmpty || isGeocoding)
                    }
                    HStack {
                        TextField("Latitude", text: $latitudeText)
                        TextField("Longitude", text: $longitudeText)
                    }
                    .frame(maxWidth: 260)
                    if isGeocoding {
                        ProgressView().controlSize(.small)
                    }
                    if let geocodeError {
                        Text(geocodeError).foregroundStyle(.red).font(.caption)
                    }
                }
                .padding(.top, 4)
            }

            Button("Copy Date/Location From Existing Photo…") {
                showCopyPicker = true
            }
            .disabled(library.processedPhotos.isEmpty)

            Spacer()

            HStack {
                Button("Cancel", role: .cancel) { dismiss() }
                Spacer()
                Button("Apply to \(library.selectedBatch.count) Photos") {
                    apply()
                }
                .buttonStyle(.borderedProminent)
                .disabled(isApplying || library.selectedBatch.isEmpty)
            }
        }
        .padding()
        .frame(width: 480, height: 480)
        .sheet(isPresented: $showCopyPicker) {
            CopyMetadataPickerView { source in
                if let sourceDate = source.captureDate {
                    date = sourceDate
                }
                if let coord = source.coordinate {
                    latitudeText = String(coord.latitude)
                    longitudeText = String(coord.longitude)
                }
            }
        }
    }

    private func geocode() {
        isGeocoding = true
        geocodeError = nil
        CLGeocoder().geocodeAddressString(addressText) { placemarks, error in
            isGeocoding = false
            if let coordinate = placemarks?.first?.location?.coordinate {
                latitudeText = String(coordinate.latitude)
                longitudeText = String(coordinate.longitude)
            } else {
                geocodeError = error?.localizedDescription ?? "Location not found."
            }
        }
    }

    private func apply() {
        isApplying = true
        let targets = library.selectedBatch
        let finalDate = date
        let finalCoordinate = coordinate
        Task {
            await library.apply(date: finalDate, coordinate: finalCoordinate, to: targets)
            isApplying = false
            dismiss()
        }
    }
}
