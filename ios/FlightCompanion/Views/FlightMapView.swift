import SwiftUI
import MapKit
import CoreLocation

// ─────────────────────────────────────────────────────────────
// MARK: - Flight Map View (UIViewRepresentable for MKGeodesicPolyline)
// ─────────────────────────────────────────────────────────────
struct FlightMapView: View {
    let state: FlightState
    @State private var followAircraft = true

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            MapKitView(state: state, followAircraft: $followAircraft)
                .ignoresSafeArea()

            // Follow button
            Button {
                followAircraft.toggle()
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
}

// MARK: - UIViewRepresentable wrapper
struct MapKitView: UIViewRepresentable {
    let state: FlightState
    @Binding var followAircraft: Bool

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> MKMapView {
        let map = MKMapView()
        map.delegate = context.coordinator
        map.mapType = .hybridFlyover
        map.showsUserLocation = false
        map.isRotateEnabled = true
        map.isPitchEnabled = false

        // Fit to North Atlantic initially
        let region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 50, longitude: -30),
            span: MKCoordinateSpan(latitudeDelta: 55, longitudeDelta: 70)
        )
        map.setRegion(region, animated: false)
        return map
    }

    func updateUIView(_ map: MKMapView, context: Context) {
        context.coordinator.update(map: map, state: state, follow: followAircraft)
    }

    class Coordinator: NSObject, MKMapViewDelegate {
        private var aircraftAnnotation: AircraftMapAnnotation?
        private var originAnnotation:   AirportMapAnnotation?
        private var destAnnotation:     AirportMapAnnotation?
        private var routeOverlay:       MKPolyline?
        private var trailOverlay:       MKPolyline?
        private var waypointOverlays:   [MKCircle] = []

        // Persistent trail — seeded from origin on first load
        private var trailCoords: [CLLocationCoordinate2D] = []
        private var lastKnownOrigin: String = ""
        private var lastKnownSimbrief: Bool = false

        func update(map: MKMapView, state: FlightState, follow: Bool) {
            updateAircraft(map: map, state: state, follow: follow)
            updateRoute(map: map, state: state)
            updateTrail(map: map, state: state)
        }

        // MARK: Aircraft Annotation
        private func updateAircraft(map: MKMapView, state: FlightState, follow: Bool) {
            guard state.lat != 0 || state.lon != 0 else { return }
            let coord = CLLocationCoordinate2D(latitude: state.lat, longitude: state.lon)

            if let ann = aircraftAnnotation {
                UIView.animate(withDuration: 1.0) {
                    ann.coordinate = coord
                    ann.heading    = state.hdg
                    (map.view(for: ann) as? AircraftAnnotationView)?.updateHeading(state.hdg)
                }
            } else {
                let ann = AircraftMapAnnotation(coordinate: coord, heading: state.hdg)
                aircraftAnnotation = ann
                map.addAnnotation(ann)
            }

            if follow {
                let region = MKCoordinateRegion(center: coord,
                    span: MKCoordinateSpan(latitudeDelta: 8, longitudeDelta: 8))
                map.setRegion(region, animated: true)
            }
        }

        // MARK: Route + Waypoints
        private func updateRoute(map: MKMapView, state: FlightState) {
            guard let sb = state.simbrief else { return }

            // Only redraw when simbrief data changes
            let origICAO = sb.origin.icao
            if origICAO == lastKnownOrigin && lastKnownSimbrief { return }
            lastKnownOrigin   = origICAO
            lastKnownSimbrief = true

            // Remove old overlays + annotations
            if let r = routeOverlay { map.removeOverlay(r) }
            map.removeOverlays(waypointOverlays)
            waypointOverlays = []
            if let oa = originAnnotation { map.removeAnnotation(oa) }
            if let da = destAnnotation   { map.removeAnnotation(da) }

            // Build full coordinate list: origin → waypoints → destination
            var coords: [CLLocationCoordinate2D] = []
            if sb.origin.lat != 0 {
                coords.append(CLLocationCoordinate2D(latitude: sb.origin.lat, longitude: sb.origin.lon))
            }
            sb.waypoints.filter { $0.lat != 0 }.forEach {
                coords.append(CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lon))
            }
            if sb.destination.lat != 0 {
                coords.append(CLLocationCoordinate2D(latitude: sb.destination.lat, longitude: sb.destination.lon))
            }

            if coords.count >= 2 {
                // MKGeodesicPolyline renders great-circle arcs automatically
                let poly = MKGeodesicPolyline(coordinates: coords, count: coords.count)
                map.addOverlay(poly, level: .aboveRoads)
                routeOverlay = poly

                // Waypoint circles (subtle)
                sb.waypoints.prefix(80).filter { $0.lat != 0 }.forEach { wp in
                    let circle = MKCircle(center: CLLocationCoordinate2D(latitude: wp.lat, longitude: wp.lon), radius: 6000)
                    map.addOverlay(circle, level: .aboveRoads)
                    waypointOverlays.append(circle)
                }

                // Fit map to full route
                let allCoords = coords
                let minLat = allCoords.min(by: { $0.latitude  < $1.latitude  })!.latitude
                let maxLat = allCoords.max(by: { $0.latitude  < $1.latitude  })!.latitude
                let minLon = allCoords.min(by: { $0.longitude < $1.longitude })!.longitude
                let maxLon = allCoords.max(by: { $0.longitude < $1.longitude })!.longitude
                let centerLat = (minLat + maxLat) / 2
                let centerLon = (minLon + maxLon) / 2
                let spanLat   = (maxLat - minLat) * 1.4
                let spanLon   = (maxLon - minLon) * 1.4
                let region = MKCoordinateRegion(
                    center: CLLocationCoordinate2D(latitude: centerLat, longitude: centerLon),
                    span: MKCoordinateSpan(latitudeDelta: max(spanLat, 10), longitudeDelta: max(spanLon, 10))
                )
                map.setRegion(region, animated: true)
            }

            // Airport annotations
            if sb.origin.lat != 0 {
                let oa = AirportMapAnnotation(coordinate: .init(latitude: sb.origin.lat, longitude: sb.origin.lon),
                                              icao: sb.origin.icao, isOrigin: true)
                originAnnotation = oa
                map.addAnnotation(oa)
            }
            if sb.destination.lat != 0 {
                let da = AirportMapAnnotation(coordinate: .init(latitude: sb.destination.lat, longitude: sb.destination.lon),
                                              icao: sb.destination.icao, isOrigin: false)
                destAnnotation = da
                map.addAnnotation(da)
            }

            // Seed trail from departure airport
            if trailCoords.isEmpty, sb.origin.lat != 0 {
                trailCoords = [CLLocationCoordinate2D(latitude: sb.origin.lat, longitude: sb.origin.lon)]
            }
        }

        // MARK: Trail
        private func updateTrail(map: MKMapView, state: FlightState) {
            guard state.lat != 0 else { return }
            let coord = CLLocationCoordinate2D(latitude: state.lat, longitude: state.lon)

            // Only append if moved at least ~0.1 NM
            if let last = trailCoords.last {
                let dx = coord.latitude - last.latitude
                let dy = coord.longitude - last.longitude
                if sqrt(dx*dx + dy*dy) < 0.001 { return }
            }
            trailCoords.append(coord)
            if trailCoords.count > 3000 { trailCoords.removeFirst() }

            if let old = trailOverlay { map.removeOverlay(old) }
            guard trailCoords.count >= 2 else { return }
            let trail = MKPolyline(coordinates: trailCoords, count: trailCoords.count)
            map.addOverlay(trail, level: .aboveRoads)
            trailOverlay = trail
        }

        // MARK: MKMapViewDelegate — render overlays
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let poly = overlay as? MKPolyline {
                // Distinguish trail vs route by checking which one trailOverlay is
                if overlay as? MKPolyline === trailOverlay {
                    let r = MKPolylineRenderer(polyline: poly)
                    r.strokeColor = UIColor(red: 0.20, green: 0.83, blue: 0.60, alpha: 0.75)
                    r.lineWidth   = 2.5
                    r.lineCap     = .round
                    return r
                } else {
                    // Route line (geodesic)
                    let r = MKPolylineRenderer(polyline: poly)
                    r.strokeColor = UIColor.white.withAlphaComponent(0.45)
                    r.lineWidth   = 1.8
                    r.lineDashPattern = [8, 6]
                    return r
                }
            }
            if let circle = overlay as? MKCircle {
                let r = MKCircleRenderer(circle: circle)
                r.fillColor   = UIColor.white.withAlphaComponent(0.18)
                r.strokeColor = UIColor.white.withAlphaComponent(0.35)
                r.lineWidth   = 1
                return r
            }
            return MKOverlayRenderer(overlay: overlay)
        }

        // MARK: MKMapViewDelegate — render annotations
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            if let ac = annotation as? AircraftMapAnnotation {
                let id = "aircraft"
                let v  = mapView.dequeueReusableAnnotationView(withIdentifier: id) as? AircraftAnnotationView
                    ?? AircraftAnnotationView(annotation: ac, reuseIdentifier: id)
                v.updateHeading(ac.heading)
                return v
            }
            if let ap = annotation as? AirportMapAnnotation {
                let id = "airport"
                let v  = mapView.dequeueReusableAnnotationView(withIdentifier: id)
                    ?? MKAnnotationView(annotation: ap, reuseIdentifier: id)
                v.annotation = ap
                v.canShowCallout = false

                let size: CGFloat = 10
                let dot = UIView(frame: CGRect(x: 0, y: 0, width: size, height: size))
                dot.backgroundColor = ap.isOrigin
                    ? UIColor(red: 0.29, green: 0.83, blue: 0.60, alpha: 1)
                    : UIColor(red: 0.97, green: 0.44, blue: 0.44, alpha: 1)
                dot.layer.cornerRadius = size / 2
                dot.layer.shadowColor  = dot.backgroundColor?.cgColor
                dot.layer.shadowRadius = 4
                dot.layer.shadowOpacity = 0.8

                let label = UILabel()
                label.text      = ap.icao
                label.font      = .monospacedSystemFont(ofSize: 10, weight: .bold)
                label.textColor = ap.isOrigin
                    ? UIColor(red: 0.29, green: 0.83, blue: 0.60, alpha: 1)
                    : UIColor(red: 0.97, green: 0.44, blue: 0.44, alpha: 1)
                label.sizeToFit()

                let container = UIView(frame: CGRect(x: 0, y: 0, width: max(label.frame.width + 12, 30), height: label.frame.height + size + 6))
                dot.center = CGPoint(x: container.frame.width / 2, y: 0)
                label.center = CGPoint(x: container.frame.width / 2, y: dot.frame.maxY + 4 + label.frame.height / 2)
                container.addSubview(dot)
                container.addSubview(label)

                v.frame = container.bounds
                v.subviews.forEach { $0.removeFromSuperview() }
                v.addSubview(container)
                return v
            }
            return nil
        }
    }
}

// MARK: - Annotation Models
class AircraftMapAnnotation: NSObject, MKAnnotation {
    @objc dynamic var coordinate: CLLocationCoordinate2D
    var heading: Double
    init(coordinate: CLLocationCoordinate2D, heading: Double) {
        self.coordinate = coordinate; self.heading = heading
    }
}

class AirportMapAnnotation: NSObject, MKAnnotation {
    var coordinate: CLLocationCoordinate2D
    var icao: String
    var isOrigin: Bool
    init(coordinate: CLLocationCoordinate2D, icao: String, isOrigin: Bool) {
        self.coordinate = coordinate; self.icao = icao; self.isOrigin = isOrigin
    }
}

// MARK: - Aircraft Annotation View
class AircraftAnnotationView: MKAnnotationView {
    private let imageView = UIImageView()

    override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        frame = CGRect(x: 0, y: 0, width: 40, height: 40)
        centerOffset = CGPoint(x: 0, y: 0)
        imageView.frame = bounds
        imageView.contentMode = .scaleAspectFit
        imageView.image = UIImage(systemName: "airplane")?.withRenderingMode(.alwaysTemplate)
        imageView.tintColor = .white
        imageView.layer.shadowColor = UIColor(red: 0.29, green: 0.62, blue: 1.0, alpha: 1).cgColor
        imageView.layer.shadowRadius  = 8
        imageView.layer.shadowOpacity = 0.9
        imageView.layer.shadowOffset  = .zero
        addSubview(imageView)
    }

    required init?(coder: NSCoder) { fatalError() }

    func updateHeading(_ heading: Double) {
        // SF Symbol "airplane" points up (north) = 0°, rotate to heading
        transform = CGAffineTransform(rotationAngle: CGFloat(heading * .pi / 180))
    }
}
