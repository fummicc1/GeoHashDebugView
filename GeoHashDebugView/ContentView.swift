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
    @State private var searchQuery: String = ""
    @State private var searchedCoordinates: [CLLocationCoordinate2D] = []
    
    var body: some View {
        NavigationStack {
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
                                .fontSize(for: geohash.precision)
                        }
                    ) {
                        Text(geohash.binary)
                            .fontSize(for: geohash.precision)
                    }
                }
                if !searchedCoordinates.isEmpty {
                    Annotation(coordinate: getCenter(in: searchedCoordinates)) {
                        Text(searchQuery).fontSize(for: .exact(digits: searchQuery.count * 5))
                    } label: {
                        EmptyView()
                    }

                    MapPolygon(coordinates: searchedCoordinates)
                        .foregroundStyle(Color.green.opacity(0.3))
                    MapPolyline(coordinates: searchedCoordinates)
                        .stroke(Color.green, lineWidth: 3)
                }
            }
            .ignoresSafeArea()
            .searchable(text: $searchQuery, prompt: "Enter GeoHash here")
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
            .onChange(of: searchQuery) {
                _,
                _ in
                Task {
                    guard let geohash = GeoHash(
                        geoHash: searchQuery,
                        precision: .exact(
                            digits: searchQuery.count * 5
                        )
                    ) else {
                        return
                    }
                    let bounds = geohash.getBound()
                    await MainActor.run {
                        let coordinates = bounds.map({
                            CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude)
                        }) + [CLLocationCoordinate2D(
                            latitude: bounds[0].latitude,
                            longitude: bounds[0].longitude
                        )]
                        searchedCoordinates = coordinates

                        // カメラを検索したgeohashの中心に移動
                        let center = getCenter(in: coordinates)
                        let latDelta = abs(bounds[1].latitude - bounds[2].latitude) * 2
                        let lonDelta = abs(bounds[1].longitude - bounds[0].longitude) * 2
                        withAnimation(.easeInOut(duration: 0.5)) {
                            cameraPosition = .region(
                                MKCoordinateRegion(
                                    center: center,
                                    span: MKCoordinateSpan(
                                        latitudeDelta: max(latDelta, 0.001),
                                        longitudeDelta: max(lonDelta, 0.001)
                                    )
                                )
                            )
                        }
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                HStack(spacing: 12) {
                    Image(systemName: "grid")
                        .foregroundStyle(.secondary)

                    Slider(
                        value: Binding<Double>(
                            get: { Double(bitsLength) },
                            set: { bitsLength = Int($0) }
                        ),
                        in: 0.0...50.0
                    )

                    Text("\(bitsLength)")
                        .font(.subheadline.weight(.semibold))
                        .monospacedDigit()
                        .frame(minWidth: 28, alignment: .trailing)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .glassEffect(.regular, in: .rect(cornerRadius: 20, style: .continuous))
                .padding(.horizontal)
                .padding(.bottom, 8)
            }
            .navigationTitle("GeoHash Debug")
            .navigationBarTitleDisplayMode(.inline)
            .containerBackground(.clear, for: .navigation)
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
                    )!,
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
    func fontSize(for precision: GeoHashBitsPrecision) -> some View {
        self.font(.system(size: 56 * (1 - Double(precision.rawValue) / 50)))
    }
}

#Preview {
    ContentView()
}
