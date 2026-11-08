import CoreLocation
import SwiftUI

/// Date/location editor applied to every photo currently in the batch.
struct BatchMetadataView: View {
    @EnvironmentObject private var library: PhotoLibrary
    @Environment(\.dismiss) private var dismiss

    @State private var setDate = true
    @State private var date = Date()
    @State private var setLocation = true
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

    /// Nothing to do if neither field is turned on, or location is turned on
    /// but hasn't resolved to an actual coordinate yet.
    private var canApply: Bool {
        guard setDate || setLocation else { return false }
        if setLocation && coordinate == nil { return false }
        return true
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Update \(library.selectedBatch.count) Photo\(library.selectedBatch.count == 1 ? "" : "s")")
                .font(.headline)

            Toggle("Set Date", isOn: $setDate)
            DatePicker("Date & Time", selection: $date, displayedComponents: [.date, .hourAndMinute])
                .datePickerStyle(.field)
                .disabled(!setDate)
                .opacity(setDate ? 1 : 0.5)

            Toggle("Set Location", isOn: $setLocation)
            VStack(alignment: .leading, spacing: 8) {
                Text("Location")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack {
                    TextField("Search address or place", text: $addressText)
                        .textFieldStyle(.roundedBorder)
                        .disabled(!setLocation)
                        .onSubmit { geocode() }
                    Button("Find") { geocode() }
                        .disabled(addressText.isEmpty || isGeocoding || !setLocation)
                }
                HStack {
                    TextField("Latitude", text: $latitudeText)
                        .textFieldStyle(.roundedBorder)
                        .disabled(!setLocation)
                    TextField("Longitude", text: $longitudeText)
                        .textFieldStyle(.roundedBorder)
                        .disabled(!setLocation)
                }
                .frame(maxWidth: 280)
                if isGeocoding {
                    ProgressView().controlSize(.small)
                }
                if let geocodeError {
                    Text(geocodeError).foregroundStyle(.red).font(.caption)
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color.gray.opacity(0.08)))
            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.gray.opacity(0.25)))
            .opacity(setLocation ? 1 : 0.5)

            Button("Copy Date/Location From Existing Photo…") {
                showCopyPicker = true
            }
            .disabled(library.taggedPhotos.isEmpty)

            Spacer()

            HStack {
                Button("Cancel", role: .cancel) { dismiss() }
                Spacer()
                Button("Apply to \(library.selectedBatch.count) Photos") {
                    apply()
                }
                .buttonStyle(.borderedProminent)
                .disabled(isApplying || library.selectedBatch.isEmpty || !canApply)
            }
        }
        .padding()
        .frame(width: 480, height: 560)
        .sheet(isPresented: $showCopyPicker) {
            CopyMetadataPickerView { source in
                if let sourceDate = source.captureDate {
                    date = sourceDate
                    setDate = true
                }
                if let coord = source.coordinate {
                    latitudeText = String(coord.latitude)
                    longitudeText = String(coord.longitude)
                    setLocation = true
                }
            }
        }
    }

    private func geocode() {
        isGeocoding = true
        geocodeError = nil
        CLGeocoder().geocodeAddressString(addressText) { placemarks, error in
            // The completion handler isn't guaranteed to land on the main
            // thread, and these all drive SwiftUI state.
            DispatchQueue.main.async {
                isGeocoding = false
                if let coordinate = placemarks?.first?.location?.coordinate {
                    latitudeText = String(coordinate.latitude)
                    longitudeText = String(coordinate.longitude)
                } else {
                    geocodeError = error?.localizedDescription ?? "Location not found."
                }
            }
        }
    }

    private func apply() {
        isApplying = true
        let targets = library.selectedBatch
        let finalDate = setDate ? date : nil
        let finalCoordinate = setLocation ? coordinate : nil
        Task {
            await library.apply(date: finalDate, coordinate: finalCoordinate, to: targets)
            isApplying = false
            dismiss()
        }
    }
}
