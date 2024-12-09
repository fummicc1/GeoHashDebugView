//
//  ContentView.swift
//  GeoHashDebugView
//
//  Created by Fumiya Tanaka on 2024/11/16.
//

import SwiftUI
import MapKit
import CoreLocation
import GeoHashFramework

@globalActor
struct ComputationActor {
    actor ActorType {}
    static let shared = ActorType()
}

struct ContentView: View {
    @State var bitsLength: Int = 40
    @State private var cameraPosition = MapCameraPosition.region(
        MKCoordinateRegion(
            // Tokyo Station in Japan
            center: CLLocationCoordinate2D(
                latitude: 35.681382,
                longitude: 139.766084
            ),
            span: MKCoordinateSpan(latitudeDelta: 360, longitudeDelta: 360)
        )
    )

    @State private var isLoading = false
    @State private var bounds: [[CLLocationCoordinate2D]] = []
    
    var body: some View {
        Text("\(bitsLength) bits precision")
        Slider(
            value: Binding<Double>(
                get: {
                    Double(bitsLength)
                },
                set: {
                    bitsLength = Int($0)
                }
            ),
            in: 0.0...50.0
        )
        Map(position: $cameraPosition) {
            ForEach(bounds) { bound in
                MapPolyline(coordinates: bound)
                    .stroke(Color.blue, lineWidth: 1)
                Annotation(
                    coordinate: getCenter(in: bound),
                    content: {
                        Text(
                            GeoHash(
                                latitude: getCenter(in: bound).latitude,
                                longitude: getCenter(in: bound).longitude
                            ).geoHash
                        )
                    }
                ) {}
            }
        }
        .onMapCameraChange { context in
            Task {
                if isLoading {
                    return
                }
                isLoading = true
                await updateBounds(coord: context.camera.centerCoordinate)
                isLoading = false
            }
        }
    }

    @ComputationActor
    private func updateBounds(coord: CLLocationCoordinate2D) async {
        var geoHashes = await [
            (
                GeoHash(
                    latitude: coord.latitude,
                    longitude: coord.longitude,
                    precision: .exact(digits: bitsLength)
                ),
                0
            )
        ]
        var bounds: [[CLLocationCoordinate2D]] = []
        var seen: Set<GeoHash> = []
        while geoHashes.count > 0 {
            let (geoHash, depth) = geoHashes.removeFirst()
            if depth >= 4 {
                break
            }
            if seen.contains(geoHash) {
                continue
            }
            seen.insert(geoHash)
            let centerBound = geoHash.getBound().map({
                CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude)
            })
            bounds.append(
                centerBound + [centerBound[0]]
            )
            for neighbor in geoHash.getNeighbors() {
                if seen.contains(neighbor) {
                    continue
                }
                let neighborBound = neighbor.getBound().map({
                    CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude)
                })
                bounds.append(
                    neighborBound + [neighborBound[0]]
                )
                geoHashes.append((neighbor, depth + 1))
            }
        }
        await MainActor.run { [bounds] in
            withAnimation {
                self.bounds = bounds
            }
        }
    }

    private func getCenter(in bound: [CLLocationCoordinate2D]) -> CLLocationCoordinate2D {
        CLLocationCoordinate2D(
            latitude: (bound[1].latitude + bound[2].latitude) / 2,
            longitude: (bound[1].longitude + bound[0].longitude) / 2
        )
    }
}

extension Array: @retroactive Identifiable where Element: Identifiable<String> {
    public var id: String {
        map { $0.id }.joined(separator: "|")
    }
}

extension CLLocationCoordinate2D: @retroactive Identifiable {
    public var id: String {
        "\(latitude),\(longitude)"
    }
}

#Preview {
    ContentView()
}
