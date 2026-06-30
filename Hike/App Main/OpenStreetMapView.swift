//
//  OpenStreetMapView.swift
//  GetFly
//

import MapKit
import SwiftUI

private final class OpenStreetMapTileOverlay: MKTileOverlay {
    init() {
        super.init(urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png")
        canReplaceMapContent = true
    }
}

struct OpenStreetMapView: UIViewRepresentable {
    let homeCoordinate: CLLocationCoordinate2D
    let dronePosition: Coordinate3D
    let targetPosition: Coordinate3D
    let waypoints: [Waypoint]
    let flightTrail: [Coordinate3D]
    let isFlying: Bool
    let followDrone: Bool
    let activeWaypointIndex: Int?
    var onMapTap: ((Coordinate3D) -> Void)?

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView(frame: .zero)
        mapView.delegate = context.coordinator
        mapView.pointOfInterestFilter = .excludingAll
        mapView.showsCompass = true
        mapView.showsScale = true
        mapView.isRotateEnabled = false

        let overlay = OpenStreetMapTileOverlay()
        mapView.addOverlay(overlay, level: .aboveLabels)

        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        mapView.addGestureRecognizer(tap)

        context.coordinator.mapView = mapView
        context.coordinator.installAnnotationsIfNeeded(on: mapView)
        context.coordinator.syncMap(animated: false, forceRegion: true)
        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        context.coordinator.parent = self
        context.coordinator.syncMap(animated: true, forceRegion: false)
    }

    final class Coordinator: NSObject, MKMapViewDelegate {
        var parent: OpenStreetMapView
        weak var mapView: MKMapView?

        private var homeAnnotation: MapAnnotation?
        private var droneAnnotation: MapAnnotation?
        private var targetAnnotation: MapAnnotation?
        private var waypointAnnotations: [UUID: MapAnnotation] = [:]
        private var hasSetInitialRegion = false

        init(parent: OpenStreetMapView) {
            self.parent = parent
        }

        func installAnnotationsIfNeeded(on mapView: MKMapView) {
            if homeAnnotation == nil {
                homeAnnotation = MapAnnotation(kind: .home, coordinate: parent.homeCoordinate)
                mapView.addAnnotation(homeAnnotation!)
            }
            if droneAnnotation == nil {
                let geo = geo(for: parent.dronePosition)
                droneAnnotation = MapAnnotation(kind: .drone, coordinate: geo)
                mapView.addAnnotation(droneAnnotation!)
            }
            if targetAnnotation == nil {
                let geo = geo(for: parent.targetPosition)
                targetAnnotation = MapAnnotation(kind: .target, coordinate: geo)
                mapView.addAnnotation(targetAnnotation!)
            }
        }

        func syncMap(animated: Bool, forceRegion: Bool) {
            guard let mapView else { return }

            installAnnotationsIfNeeded(on: mapView)

            let home = parent.homeCoordinate
            let droneGeo = geo(for: parent.dronePosition)
            let targetGeo = geo(for: parent.targetPosition)

            homeAnnotation?.coordinate = home
            animateDrone(to: droneGeo)
            targetAnnotation?.coordinate = targetGeo

            syncWaypointAnnotations(on: mapView)
            syncOverlays(on: mapView, droneGeo: droneGeo, targetGeo: targetGeo)

            if forceRegion || !hasSetInitialRegion {
                let region = wideRegion(
                    home: home,
                    drone: droneGeo,
                    target: targetGeo,
                    waypoints: parent.waypoints.map { geo(for: $0.coordinate) },
                    trail: parent.flightTrail.map { geo(for: $0) }
                )
                mapView.setRegion(region, animated: animated)
                hasSetInitialRegion = true
            } else if parent.followDrone && parent.isFlying {
                let region = MKCoordinateRegion(center: droneGeo, span: mapView.region.span)
                mapView.setRegion(region, animated: animated)
            }
        }

        private func animateDrone(to coordinate: CLLocationCoordinate2D) {
            guard let droneAnnotation else { return }
            if parent.isFlying {
                UIView.animate(withDuration: 0.65, delay: 0, options: [.curveEaseInOut]) {
                    droneAnnotation.coordinate = coordinate
                }
            } else {
                droneAnnotation.coordinate = coordinate
            }
        }

        private func syncWaypointAnnotations(on mapView: MKMapView) {
            let ids = Set(parent.waypoints.map(\.id))

            for (id, annotation) in waypointAnnotations where !ids.contains(id) {
                mapView.removeAnnotation(annotation)
                waypointAnnotations.removeValue(forKey: id)
            }

            for (index, waypoint) in parent.waypoints.enumerated() {
                let coordinate = geo(for: waypoint.coordinate)
                if let annotation = waypointAnnotations[waypoint.id] {
                    annotation.coordinate = coordinate
                    annotation.waypointNumber = index + 1
                    annotation.isActive = parent.activeWaypointIndex == index
                } else {
                    let annotation = MapAnnotation(kind: .waypoint, coordinate: coordinate)
                    annotation.waypointNumber = index + 1
                    annotation.isActive = parent.activeWaypointIndex == index
                    waypointAnnotations[waypoint.id] = annotation
                    mapView.addAnnotation(annotation)
                }
            }
        }

        private func syncOverlays(on mapView: MKMapView, droneGeo: CLLocationCoordinate2D, targetGeo: CLLocationCoordinate2D) {
            mapView.removeOverlays(mapView.overlays.filter { $0 is MKPolyline })

            if parent.flightTrail.count > 1 {
                var trail = parent.flightTrail.map { geo(for: $0) }
                addPolyline(&trail, color: UIColor.systemGreen.withAlphaComponent(0.85), width: 4, dashed: false, to: mapView)
            }

            if parent.waypoints.count > 1 {
                var mission = parent.waypoints.map { geo(for: $0.coordinate) }
                addPolyline(&mission, color: UIColor.systemBlue.withAlphaComponent(0.8), width: 4, dashed: false, to: mapView)
            } else if let waypoint = parent.waypoints.first {
                var single = [droneGeo, geo(for: waypoint.coordinate)]
                addPolyline(&single, color: UIColor.systemBlue.withAlphaComponent(0.8), width: 3, dashed: true, to: mapView)
            }

            var droneToTarget = [droneGeo, targetGeo]
            addPolyline(&droneToTarget, color: UIColor.systemOrange.withAlphaComponent(0.9), width: 3, dashed: true, to: mapView)
        }

        private func addPolyline(
            _ coordinates: inout [CLLocationCoordinate2D],
            color: UIColor,
            width: CGFloat,
            dashed: Bool,
            to mapView: MKMapView
        ) {
            guard coordinates.count > 1 else { return }
            let polyline = StyledPolyline(coordinates: &coordinates, count: coordinates.count)
            polyline.strokeColor = color
            polyline.lineWidth = width
            polyline.isDashed = dashed
            mapView.addOverlay(polyline)
        }

        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard let mapView, gesture.state == .ended else { return }
            let point = gesture.location(in: mapView)
            let coordinate = mapView.convert(point, toCoordinateFrom: mapView)
            let local = CoordinateConverter.localCoordinate(
                from: coordinate,
                home: parent.homeCoordinate,
                altitude: parent.targetPosition.z
            )
            parent.onMapTap?(local)
        }

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if overlay is MKTileOverlay {
                return MKTileOverlayRenderer(overlay: overlay)
            }

            if let polyline = overlay as? StyledPolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)
                renderer.strokeColor = polyline.strokeColor
                renderer.lineWidth = polyline.lineWidth
                if polyline.isDashed {
                    renderer.lineDashPattern = [8, 6]
                }
                renderer.lineCap = .round
                return renderer
            }

            return MKOverlayRenderer(overlay: overlay)
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard let annotation = annotation as? MapAnnotation else { return nil }

            if annotation.kind == .drone {
                let id = "DroneAnnotation"
                let view = mapView.dequeueReusableAnnotationView(withIdentifier: id) as? DroneAnnotationView
                    ?? DroneAnnotationView(annotation: annotation, reuseIdentifier: id)
                view.annotation = annotation
                view.isFlying = parent.isFlying
                view.zPriority = .max
                return view
            }

            let identifier = "MapAnnotation-\(annotation.kind.rawValue)"
            let view = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView
                ?? MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)

            view.annotation = annotation
            view.canShowCallout = true
            view.displayPriority = .defaultHigh

            switch annotation.kind {
            case .home:
                view.markerTintColor = .systemPurple
                view.glyphImage = UIImage(systemName: "house.fill")
                view.title = "Home"
            case .target:
                view.markerTintColor = .systemOrange
                view.glyphImage = UIImage(systemName: "scope")
                view.title = "Target"
            case .waypoint:
                view.markerTintColor = annotation.isActive ? .systemYellow : .systemBlue
                view.glyphText = "\(annotation.waypointNumber)"
                view.title = annotation.isActive ? "Active waypoint" : "Waypoint \(annotation.waypointNumber)"
            case .drone:
                break
            }

            return view
        }

        private func geo(for local: Coordinate3D) -> CLLocationCoordinate2D {
            CoordinateConverter.coordinate(local, home: parent.homeCoordinate)
        }

        private func wideRegion(
            home: CLLocationCoordinate2D,
            drone: CLLocationCoordinate2D,
            target: CLLocationCoordinate2D,
            waypoints: [CLLocationCoordinate2D],
            trail: [CLLocationCoordinate2D]
        ) -> MKCoordinateRegion {
            let points = [home, drone, target] + waypoints + trail

            let minLat = points.map(\.latitude).min() ?? home.latitude
            let maxLat = points.map(\.latitude).max() ?? home.latitude
            let minLon = points.map(\.longitude).min() ?? home.longitude
            let maxLon = points.map(\.longitude).max() ?? home.longitude

            let center = CLLocationCoordinate2D(
                latitude: (minLat + maxLat) / 2,
                longitude: (minLon + maxLon) / 2
            )

            let latDelta = max((maxLat - minLat) * 2.8, 0.006)
            let lonDelta = max((maxLon - minLon) * 2.8, 0.006)
            return MKCoordinateRegion(center: center, span: MKCoordinateSpan(latitudeDelta: latDelta, longitudeDelta: lonDelta))
        }
    }
}

private final class StyledPolyline: MKPolyline {
    var strokeColor: UIColor = .systemBlue
    var lineWidth: CGFloat = 3
    var isDashed = false
}

private final class DroneAnnotationView: MKAnnotationView {
    var isFlying = false {
        didSet { updateAppearance(animated: true) }
    }

    override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        frame = CGRect(x: 0, y: 0, width: 36, height: 36)
        centerOffset = CGPoint(x: 0, y: -4)
        canShowCallout = true
        updateAppearance(animated: false)
    }

    required init?(coder aDecoder: NSCoder) {
        nil
    }

    private func updateAppearance(animated: Bool) {
        let image = UIImage(systemName: isFlying ? "airplane.circle.fill" : "airplane")
        if animated {
            UIView.transition(with: self, duration: 0.25, options: .transitionCrossDissolve) {
                self.image = image?.withTintColor(.systemGreen, renderingMode: .alwaysOriginal)
            }
        } else {
            self.image = image?.withTintColor(.systemGreen, renderingMode: .alwaysOriginal)
        }
        layer.removeAnimation(forKey: "pulse")
        if isFlying {
            let pulse = CABasicAnimation(keyPath: "transform.scale")
            pulse.fromValue = 1.0
            pulse.toValue = 1.18
            pulse.duration = 0.9
            pulse.autoreverses = true
            pulse.repeatCount = .infinity
            layer.add(pulse, forKey: "pulse")
        }
    }
}

private final class MapAnnotation: NSObject, MKAnnotation {
    enum Kind: String {
        case home
        case drone
        case target
        case waypoint
    }

    let kind: Kind
    dynamic var coordinate: CLLocationCoordinate2D
    var waypointNumber = 0
    var isActive = false

    init(kind: Kind, coordinate: CLLocationCoordinate2D) {
        self.kind = kind
        self.coordinate = coordinate
    }
}
