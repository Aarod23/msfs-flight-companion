import SwiftUI
import MapKit

struct FlightMapView: View {
    let state: FlightState
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 40, longitude: -30),
        span: MKCoordinateSpan(latitudeDelta: 60, longitudeDelta: 60)
    )
    @State private var followAircraft = true

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Map(coordinateRegion: $region, annotationItems: annotations) { item in
                MapAnnotation(coordinate: item.coordinate) {
                    switch item.type {
                    case .aircraft:
                        AircraftAnnotationView(heading: state.hdg)
                    case .origin:
                        AirportAnnotationView(icao: item.label, color: Color(hex: "#4A9EFF"))
                    case .destination:
                        AirportAnnotationView(icao: item.label, color: Color(hex: "#22D3A5"))
                    }
                }
            }
            .mapStyle(.hybrid(elevation: .realistic))
            .ignoresSafeArea()
            .onAppear { updateRegion() }
            .onChange(of: state.lat) { _ in if followAircraft { updateRegion() } }

            // Follow button
            Button {
                followAircraft.toggle()
                if followAircraft { updateRegion() }
            } label: {
                Image(systemName: followAircraft ? "location.fill" : "location")
                    .font(.system(size: 16))
                    .foregroundColor(followAircraft ? Color(hex: "#4A9EFF") : .white)
                    .padding(12)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
            }
            .padding(16)
        }
    }

    func updateRegion() {
        guard state.lat != 0 || state.lon != 0 else { return }
        withAnimation(.easeInOut(duration: 1)) {
            region.center = CLLocationCoordinate2D(latitude: state.lat, longitude: state.lon)
        }
    }

    var annotations: [MapAnnotationItem] {
        var items: [MapAnnotationItem] = []
        if state.lat != 0 {
            items.append(.init(id: "aircraft", type: .aircraft, coordinate: .init(latitude: state.lat, longitude: state.lon), label: ""))
        }
        if let sb = state.simbrief {
            items.append(.init(id: "origin", type: .origin, coordinate: .init(latitude: sb.origin.lat, longitude: sb.origin.lon), label: sb.origin.icao))
            items.append(.init(id: "dest", type: .destination, coordinate: .init(latitude: sb.destination.lat, longitude: sb.destination.lon), label: sb.destination.icao))
        }
        return items
    }
}

struct MapAnnotationItem: Identifiable {
    let id: String
    let type: AnnotationType
    let coordinate: CLLocationCoordinate2D
    let label: String
    enum AnnotationType { case aircraft, origin, destination }
}

struct AircraftAnnotationView: View {
    let heading: Double
    var body: some View {
        Text("✈️")
            .font(.system(size: 24))
            .rotationEffect(.degrees(heading - 45))
            .shadow(color: Color(hex: "#4A9EFF"), radius: 8)
    }
}

struct AirportAnnotationView: View {
    let icao: String
    let color: Color
    var body: some View {
        VStack(spacing: 2) {
            Circle()
                .fill(color)
                .frame(width: 10, height: 10)
                .shadow(color: color, radius: 6)
            Text(icao)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(color)
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 3))
        }
    }
}
