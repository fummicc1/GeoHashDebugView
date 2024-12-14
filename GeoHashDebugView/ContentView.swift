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
import DequeModule

@globalActor
struct ComputationActor {
    actor ActorType {}
    static let shared = ActorType()
}

struct ContentData: Identifiable {
    var bound: [CLLocationCoordinate2D] = []
    var geohash: GeoHash
    
    var id: GeoHash {
        geohash
    }
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
    @State private var data: [ContentData] = []
    
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
            ForEach(data) {
                let geohash = $0.geohash
                let bound = $0.bound
                MapPolyline(coordinates: bound)
                    .stroke(Color.blue, lineWidth: 1)
                Annotation(
                    coordinate: getCenter(in: bound),
                    content: {
                        Text(geohash.geoHash)
                            .fontSize(for: geohash)
                    }
                ) {
                    Text(geohash.binary)
                        .fontSize(for: geohash)
                }
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
        var geoHashes = await Deque(
            [
                (
                    GeoHash(
                        latitude: coord.latitude,
                        longitude: coord.longitude,
                        precision: .exact(digits: bitsLength)
                    ),
                    0
                ),
            ]
        )
        var data: [ContentData] = []
        var seen: Set<GeoHash> = []
        while geoHashes.count > 0 {
            guard let (geoHash, depth) = geoHashes.popFirst() else {
                break
            }
            if depth > 4 {
                break
            }
            if seen.contains(geoHash) {
                continue
            }
            seen.insert(geoHash)
            let centerBound = geoHash.getBound().map({
                CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude)
            })
            data.append(
                .init(
                    bound: centerBound + [centerBound[0]],
                    geohash: geoHash
                )
            )
            for neighbor in geoHash.getNeighbors() {
                if seen.contains(neighbor) {
                    continue
                }
                let neighborBound = neighbor.getBound().map({
                    CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude)
                })
                data.append(
                    .init(
                        bound: neighborBound + [neighborBound[0]],
                        geohash: neighbor
                    )
                )
                geoHashes.append((neighbor, depth + 1))
            }
        }
        await MainActor.run { [data] in
            self.data = data
        }
    }

    private func getCenter(in bound: [CLLocationCoordinate2D]) -> CLLocationCoordinate2D {
        CLLocationCoordinate2D(
            latitude: (bound[1].latitude + bound[2].latitude) / 2,
            longitude: (bound[1].longitude + bound[0].longitude) / 2
        )
    }
}

extension View {
    func fontSize(for geohash: GeoHash) -> some View {
        self.font(.system(size: 56 * (1 - Double(geohash.precision.rawValue) / 50)))
    }
}

#Preview {
    ContentView()
}
